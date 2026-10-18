// lib/services/tourist_arrival_service.dart
//
// Pure-Dart inference engine for the Sri Lanka Tourist Arrival predictor.
//
// It re-implements, byte-for-byte, the forward pass of the PyTorch
// `TourismDemandNet` model that was trained in the project notebook
// (docs/notebookae16ed5469 (1).ipynb). The trained weights, the
// StandardScaler statistics and all feature metadata were exported to
// `assets/model/tourism_arrival_model.json`, so no native ML runtime is
// needed — the whole network runs in plain Dart on every platform.
//
// Pipeline (identical to the notebook's `run_manual_inference`):
//   1. Build 7 continuous features: inflation, temperature, rainfall,
//      month_sin, month_cos, is_wet_zone, district_base_weight.
//   2. Standard-scale them with the training mean/scale.
//   3. Concatenate [district embedding(8) | continuous(7) | shocks(3)] = 18.
//      Emergency shock flags are always 0 for normal future travel.
//   4. MLP: Linear(18→64) → SiLU → BatchNorm1d(64) → Dropout(identity in
//      eval) → Linear(64→32) → SiLU → BatchNorm1d(32) → Linear(32→1).
//   5. Inverse-transform the log-target with expm1 and clamp at 0.
//
// Verified to reproduce the notebook's own sanity-check numbers exactly
// (e.g. Galle/January → 31,079, Trincomalee/July → 3,664).

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';

/// Result of a single tourist-arrival forecast.
class ArrivalPrediction {
  /// Estimated number of tourist arrivals for the district in the month.
  final int arrivals;

  /// District the forecast is for.
  final String district;

  /// 1–12 month that was predicted.
  final int month;

  /// Whether the district sits in the wet (southwest) agro-climatic zone.
  final bool isWetZone;

  /// District's historical share of national arrivals (0–1), used by the
  /// model as a capacity prior. Multiply by 100 for a percentage.
  final double districtBaseWeight;

  const ArrivalPrediction({
    required this.arrivals,
    required this.district,
    required this.month,
    required this.isWetZone,
    required this.districtBaseWeight,
  });

  String get zoneLabel => isWetZone ? 'Wet Zone' : 'Dry / Intermediate Zone';

  /// National capacity share as a percentage (e.g. 16.04).
  double get nationalSharePct => districtBaseWeight * 100.0;
}

/// Loads the exported model once and serves forecasts.
///
/// Use the shared [instance] so the ~115 KB weight file is parsed a single
/// time for the whole app.
class TouristArrivalService {
  TouristArrivalService._();

  /// Shared, lazily-loaded singleton.
  static final TouristArrivalService instance = TouristArrivalService._();

  static const String _assetPath = 'assets/model/tourism_arrival_model.json';

  // BatchNorm1d epsilon — PyTorch default.
  static const double _bnEps = 1e-5;

  bool _loaded = false;

  // Feature metadata.
  late Map<String, int> _districtToIdx;
  late Map<String, double> _districtWeightMap;
  late Set<String> _wetZoneDistricts;

  // StandardScaler params (7 continuous features).
  late List<double> _scalerMean;
  late List<double> _scalerScale;

  // Weights.
  late List<List<double>> _embedding; // [25][8]
  late List<List<double>> _w0; // Linear(18→64) weight [64][18]
  late List<double> _b0; // [64]
  late _BatchNorm _bn2; // BatchNorm1d(64)
  late List<List<double>> _w4; // Linear(64→32) weight [32][64]
  late List<double> _b4; // [32]
  late _BatchNorm _bn6; // BatchNorm1d(32)
  late List<List<double>> _w7; // Linear(32→1) weight [1][32]
  late List<double> _b7; // [1]

  bool get isLoaded => _loaded;

  /// Sorted list of districts the model understands, for a dropdown.
  List<String> get districts {
    final list = _districtToIdx.keys.toList()..sort();
    return list;
  }

  /// Parse and cache the exported model. Safe to call multiple times.
  Future<void> load() async {
    if (_loaded) return;

    final raw = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;

    final features = json['features'] as Map<String, dynamic>;
    _districtToIdx = (features['district_to_idx'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toInt()));
    _districtWeightMap =
        (features['district_weight_map'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
    _wetZoneDistricts = (features['wet_zone_districts'] as List<dynamic>)
        .map((e) => e as String)
        .toSet();

    final scaler = json['scaler_params'] as Map<String, dynamic>;
    _scalerMean = _toDoubleList(scaler['mean']);
    _scalerScale = _toDoubleList(scaler['scale']);

    final w = json['model_weights'] as Map<String, dynamic>;
    _embedding = _toMatrix(w['district_embedding.weight']);
    _w0 = _toMatrix(w['mlp.0.weight']);
    _b0 = _toDoubleList(w['mlp.0.bias']);
    _bn2 = _BatchNorm.fromJson(w, '2');
    _w4 = _toMatrix(w['mlp.4.weight']);
    _b4 = _toDoubleList(w['mlp.4.bias']);
    _bn6 = _BatchNorm.fromJson(w, '6');
    _w7 = _toMatrix(w['mlp.7.weight']);
    _b7 = _toDoubleList(w['mlp.7.bias']);

    _loaded = true;
  }

  /// Returns true if [district] is one the model was trained on.
  bool knowsDistrict(String district) => _districtToIdx.containsKey(district);

  /// Predict tourist arrivals for a [district] in [month] (1–12) under the
  /// given average [temperature] (°C), [rainfall] (mm) and [inflation] (%).
  ///
  /// Throws [StateError] if [load] has not completed, or [ArgumentError] for
  /// an unknown district / out-of-range month.
  ArrivalPrediction predict({
    required String district,
    required int month,
    required double temperature,
    required double rainfall,
    required double inflation,
  }) {
    if (!_loaded) {
      throw StateError('TouristArrivalService.load() must complete first.');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'must be between 1 and 12');
    }
    final idx = _districtToIdx[district];
    if (idx == null) {
      throw ArgumentError.value(district, 'district', 'unknown district');
    }

    final isWetZone = _wetZoneDistricts.contains(district);
    final baseWeight = _districtWeightMap[district] ?? 0.01;

    // 1. Continuous features, in the exact training column order:
    //    [inflation, temperature, rainfall, month_sin, month_cos,
    //     is_wet_zone, district_base_weight]
    final monthSin = math.sin(2 * math.pi * month / 12.0);
    final monthCos = math.cos(2 * math.pi * month / 12.0);
    final cont = <double>[
      inflation,
      temperature,
      rainfall,
      monthSin,
      monthCos,
      isWetZone ? 1.0 : 0.0,
      baseWeight,
    ];

    // 2. Standard-scale.
    final contScaled = List<double>.generate(
      cont.length,
      (i) => (cont[i] - _scalerMean[i]) / _scalerScale[i],
    );

    // 3. Input vector: embedding(8) + continuous(7) + shocks(3) = 18.
    //    Shock flags are 0 for ordinary future travel.
    final x = <double>[
      ..._embedding[idx],
      ...contScaled,
      0.0, 0.0, 0.0,
    ];

    // 4. Forward through the MLP.
    var h = _linear(x, _w0, _b0); // 18 → 64
    _siluInPlace(h);
    h = _bn2.apply(h);
    // Dropout(0.10) is the identity in eval mode.
    h = _linear(h, _w4, _b4); // 64 → 32
    _siluInPlace(h);
    h = _bn6.apply(h);
    final out = _linear(h, _w7, _b7); // 32 → 1
    final predictedLog = out[0];

    // 5. Inverse log1p transform, clamp at zero, round to whole tourists.
    final arrivals = math.max(0, _expm1(predictedLog).round());

    return ArrivalPrediction(
      arrivals: arrivals,
      district: district,
      month: month,
      isWetZone: isWetZone,
      districtBaseWeight: baseWeight,
    );
  }

  // ── Math helpers ──────────────────────────────────────────────────────

  /// Dense layer: y = W·x + b, with weight rows [out][in].
  static List<double> _linear(
    List<double> x,
    List<List<double>> weight,
    List<double> bias,
  ) {
    final out = List<double>.filled(weight.length, 0.0);
    for (var i = 0; i < weight.length; i++) {
      final row = weight[i];
      var sum = bias[i];
      for (var j = 0; j < x.length; j++) {
        sum += row[j] * x[j];
      }
      out[i] = sum;
    }
    return out;
  }

  /// SiLU / Swish: x * sigmoid(x), applied in place.
  static void _siluInPlace(List<double> x) {
    for (var i = 0; i < x.length; i++) {
      final v = x[i];
      x[i] = v / (1.0 + math.exp(-v));
    }
  }

  /// exp(x) - 1, matching numpy.expm1 behaviour closely enough for rounding.
  static double _expm1(double x) => math.exp(x) - 1.0;

  static List<double> _toDoubleList(dynamic v) =>
      (v as List<dynamic>).map((e) => (e as num).toDouble()).toList();

  static List<List<double>> _toMatrix(dynamic v) => (v as List<dynamic>)
      .map((row) => _toDoubleList(row))
      .toList(growable: false);
}

/// BatchNorm1d in evaluation mode:
///   y = (x - running_mean) / sqrt(running_var + eps) * weight + bias
class _BatchNorm {
  final List<double> weight;
  final List<double> bias;
  final List<double> runningMean;
  final List<double> runningVar;

  const _BatchNorm({
    required this.weight,
    required this.bias,
    required this.runningMean,
    required this.runningVar,
  });

  factory _BatchNorm.fromJson(Map<String, dynamic> w, String layer) {
    List<double> read(String name) =>
        TouristArrivalService._toDoubleList(w['mlp.$layer.$name']);
    return _BatchNorm(
      weight: read('weight'),
      bias: read('bias'),
      runningMean: read('running_mean'),
      runningVar: read('running_var'),
    );
  }

  List<double> apply(List<double> x) {
    final out = List<double>.filled(x.length, 0.0);
    for (var i = 0; i < x.length; i++) {
      out[i] = (x[i] - runningMean[i]) /
              math.sqrt(runningVar[i] + TouristArrivalService._bnEps) *
              weight[i] +
          bias[i];
    }
    return out;
  }
}

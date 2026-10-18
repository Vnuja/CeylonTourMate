import 'package:flutter_test/flutter_test.dart';
import 'package:ceylon_travel_planner/services/tourist_arrival_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('matches the notebook run: Galle, Dec 2026, current inflation 8%',
      () async {
    final s = TouristArrivalService.instance;
    await s.load();
    final r = s.forecast(
      district: 'Galle',
      targetYear: 2026,
      targetMonth: 12,
      currentInflation: 8.0,
      now: DateTime(2026, 10, 12),
    );
    // Notebook: 26.6 °C, 143.9 mm, 7.3 %, ~22,149 tourists.
    expect(r.temperature, closeTo(26.6, 0.05));
    expect(r.rainfall, closeTo(143.9, 0.1));
    expect(r.inflation, closeTo(7.3, 0.05));
    expect((r.arrivals - 22149).abs(), lessThan(25));
  });

  test('inflation: same-month keeps current rate, no crash for far future', () async {
    final s = TouristArrivalService.instance;
    await s.load();
    expect(
        s.predictInflation(
            currentRate: 3.0,
            asOfYear: 2026,
            asOfMonth: 10,
            targetYear: 2026,
            targetMonth: 10),
        3.0);
    final far = s.predictInflation(
        currentRate: 3.0,
        asOfYear: 2026,
        asOfMonth: 10,
        targetYear: 2030,
        targetMonth: 6);
    expect(far, closeTo(5.45, 0.5)); // reverts toward the long-run target
  });

  test('explanation: Shapley factors cover the five inputs, baseline is sane',
      () async {
    final s = TouristArrivalService.instance;
    await s.load();
    final r = s.forecast(
      district: 'Galle',
      targetYear: 2026,
      targetMonth: 12,
      currentInflation: 8.0,
      now: DateTime(2026, 10, 12),
    );
    final e = s.explain(r, currentInflation: 8.0, monthsAhead: 2);
    // ignore: avoid_print
    print('baseline=${e.baseline} overall=${e.overallPercent.toStringAsFixed(0)}%');
    // ignore: avoid_print
    print(e.headline);
    for (final f in e.factors) {
      // ignore: avoid_print
      print('${f.label} ${f.percent.toStringAsFixed(1)}% :: ${f.description}');
    }
    expect(e.factors.length, 5);
    expect(e.factors.first.key, 'district');
    expect(e.factors.first.percent, greaterThan(0));
    expect(e.baseline, inInclusiveRange(800, 3500)); // notebook: ~1,646
  });
}

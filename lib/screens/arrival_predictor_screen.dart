// lib/screens/arrival_predictor_screen.dart
//
// "Tourist Crowd Forecast" — lets a traveller pick a district and month,
// enter the expected weather and economy, and see how many tourists the
// trained demand model expects to arrive there that month.
//
// All inference runs on-device in pure Dart via [TouristArrivalService];
// there is no network call and no native ML runtime involved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/ceylon_theme.dart';
import '../services/tourist_arrival_service.dart';

class ArrivalPredictorScreen extends StatefulWidget {
  const ArrivalPredictorScreen({super.key});

  @override
  State<ArrivalPredictorScreen> createState() => _ArrivalPredictorScreenState();
}

class _ArrivalPredictorScreenState extends State<ArrivalPredictorScreen> {
  final _service = TouristArrivalService.instance;
  final _formKey = GlobalKey<FormState>();

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // Sensible defaults close to the dataset averages so a user can get a
  // forecast with just a district + month if they don't know the figures.
  final _tempCtrl = TextEditingController(text: '28');
  final _rainCtrl = TextEditingController(text: '150');
  final _inflationCtrl = TextEditingController(text: '8');

  String? _district;
  int _month = DateTime.now().month;

  bool _loading = true;
  String? _loadError;
  ArrivalPrediction? _result;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _service.load();
      setState(() {
        _district = _service.districts.first;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = 'Could not load the forecast model.\n$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tempCtrl.dispose();
    _rainCtrl.dispose();
    _inflationCtrl.dispose();
    super.dispose();
  }

  void _predict() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_district == null) return;

    final prediction = _service.predict(
      district: _district!,
      month: _month,
      temperature: double.parse(_tempCtrl.text.trim()),
      rainfall: double.parse(_rainCtrl.text.trim()),
      inflation: double.parse(_inflationCtrl.text.trim()),
    );

    setState(() => _result = prediction);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CeylonSpiceTheme.darkBg,
      appBar: AppBar(
        backgroundColor: CeylonSpiceTheme.darkSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: CeylonSpiceTheme.textPrimary),
        title: const Text(
          '📈 Tourist Crowd Forecast',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: CeylonSpiceTheme.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            color: CeylonSpiceTheme.saffron.withOpacity(0.5),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: CeylonSpiceTheme.saffron),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CeylonSpiceTheme.textSecondary),
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IntroCard(),
              const SizedBox(height: 20),
              _sectionLabel('Destination & timing'),
              const SizedBox(height: 12),
              _buildDistrictField(),
              const SizedBox(height: 16),
              _buildMonthField(),
              const SizedBox(height: 24),
              _sectionLabel('Expected conditions'),
              const SizedBox(height: 12),
              _buildNumberField(
                controller: _tempCtrl,
                label: 'Average temperature',
                suffix: '°C',
                icon: Icons.thermostat_rounded,
                min: -5,
                max: 50,
              ),
              const SizedBox(height: 16),
              _buildNumberField(
                controller: _rainCtrl,
                label: 'Average rainfall',
                suffix: 'mm',
                icon: Icons.water_drop_rounded,
                min: 0,
                max: 2000,
              ),
              const SizedBox(height: 16),
              _buildNumberField(
                controller: _inflationCtrl,
                label: 'Expected inflation',
                suffix: '%',
                icon: Icons.trending_up_rounded,
                min: -50,
                max: 200,
              ),
              const SizedBox(height: 28),
              _buildPredictButton(),
              if (_result != null) ...[
                const SizedBox(height: 28),
                _ResultCard(result: _result!, monthName: _monthNames[_month - 1]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: CeylonSpiceTheme.saffron,
        ),
      );

  Widget _buildDistrictField() {
    return _FieldShell(
      icon: Icons.place_rounded,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _district,
          isExpanded: true,
          dropdownColor: CeylonSpiceTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(Icons.arrow_drop_down,
              color: CeylonSpiceTheme.saffron),
          style: const TextStyle(
            color: CeylonSpiceTheme.textPrimary,
            fontSize: 16,
          ),
          items: _service.districts
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (v) => setState(() => _district = v),
        ),
      ),
    );
  }

  Widget _buildMonthField() {
    return _FieldShell(
      icon: Icons.calendar_month_rounded,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _month,
          isExpanded: true,
          dropdownColor: CeylonSpiceTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(Icons.arrow_drop_down,
              color: CeylonSpiceTheme.saffron),
          style: const TextStyle(
            color: CeylonSpiceTheme.textPrimary,
            fontSize: 16,
          ),
          items: [
            for (var m = 1; m <= 12; m++)
              DropdownMenuItem(value: m, child: Text(_monthNames[m - 1])),
          ],
          onChanged: (v) => setState(() => _month = v ?? _month),
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required IconData icon,
    required double min,
    required double max,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
      ],
      style: const TextStyle(color: CeylonSpiceTheme.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        labelStyle: const TextStyle(color: CeylonSpiceTheme.textSecondary),
        suffixStyle: const TextStyle(color: CeylonSpiceTheme.saffron),
        prefixIcon: Icon(icon, color: CeylonSpiceTheme.saffron, size: 20),
        filled: true,
        fillColor: CeylonSpiceTheme.inputBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: CeylonSpiceTheme.saffron.withOpacity(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CeylonSpiceTheme.saffron),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty || text == '-' || text == '.') {
          return 'Enter a value';
        }
        final parsed = double.tryParse(text);
        if (parsed == null) return 'Enter a valid number';
        if (parsed < min || parsed > max) {
          return 'Expected between $min and $max';
        }
        return null;
      },
    );
  }

  Widget _buildPredictButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _predict,
        style: ElevatedButton.styleFrom(
          backgroundColor: CeylonSpiceTheme.cinnamon,
          foregroundColor: CeylonSpiceTheme.coconutCream,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        icon: const Icon(Icons.insights_rounded),
        label: const Text(
          'Estimate crowd',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ─── Intro card ────────────────────────────────────────────────────────────

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.darkSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CeylonSpiceTheme.saffron.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CeylonSpiceTheme.saffron.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.groups_rounded,
                color: CeylonSpiceTheme.saffron, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Estimate how busy a district will be. Pick where and when '
              "you're travelling, add the weather and economy you expect, "
              'and get a forecast of monthly tourist arrivals.',
              style: TextStyle(
                color: CeylonSpiceTheme.textSecondary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Field shell (shared chrome for the dropdowns) ──────────────────────────

class _FieldShell extends StatelessWidget {
  final IconData icon;
  final Widget child;

  const _FieldShell({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CeylonSpiceTheme.saffron.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: CeylonSpiceTheme.saffron, size: 20),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─── Result card ────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final ArrivalPrediction result;
  final String monthName;

  const _ResultCard({required this.result, required this.monthName});

  String get _crowdLevel {
    final n = result.arrivals;
    if (n >= 20000) return 'Very busy';
    if (n >= 8000) return 'Busy';
    if (n >= 2000) return 'Moderate';
    return 'Quiet';
  }

  @override
  Widget build(BuildContext context) {
    final formatted = _withThousands(result.arrivals);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CeylonSpiceTheme.deepJungle.withOpacity(0.9),
            CeylonSpiceTheme.darkCard,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CeylonSpiceTheme.saffron.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: CeylonSpiceTheme.saffron.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded,
                  color: CeylonSpiceTheme.saffron, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${result.district} · $monthName',
                  style: const TextStyle(
                    color: CeylonSpiceTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _crowdChip(),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Estimated arrivals',
            style: TextStyle(
              color: CeylonSpiceTheme.textSecondary.withOpacity(0.9),
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '~$formatted',
                style: const TextStyle(
                  color: CeylonSpiceTheme.saffron,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Georgia',
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'tourists',
                style: TextStyle(
                  color: CeylonSpiceTheme.textSecondary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: CeylonSpiceTheme.saffron.withOpacity(0.15)),
          const SizedBox(height: 14),
          _detailRow(Icons.terrain_rounded, 'Climatic zone', result.zoneLabel),
          const SizedBox(height: 10),
          _detailRow(
            Icons.pie_chart_rounded,
            'National share',
            '${result.nationalSharePct.toStringAsFixed(2)}% of arrivals',
          ),
          const SizedBox(height: 14),
          Text(
            'Based on historical arrival patterns for this district and the '
            'conditions you entered. Treat it as a planning estimate, not a '
            'guarantee.',
            style: TextStyle(
              color: CeylonSpiceTheme.textSecondary.withOpacity(0.75),
              fontSize: 11.5,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _crowdChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.saffron.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CeylonSpiceTheme.saffron.withOpacity(0.5)),
      ),
      child: Text(
        _crowdLevel,
        style: const TextStyle(
          color: CeylonSpiceTheme.saffron,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: CeylonSpiceTheme.textSecondary, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: CeylonSpiceTheme.textSecondary,
            fontSize: 13.5,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: CeylonSpiceTheme.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static String _withThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

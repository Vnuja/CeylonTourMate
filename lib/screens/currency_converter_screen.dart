// lib/screens/currency_converter_screen.dart
//
// Traveller currency converter centred on the Sri Lankan Rupee. Fetches live
// rates (key-less) via [CurrencyService] with an offline fallback, and lets
// the user convert between LKR and the major tourist-source currencies.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/ceylon_theme.dart';
import '../services/currency_service.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final _service = CurrencyService.instance;
  final _amountCtrl = TextEditingController(text: '100');

  String _from = 'USD';
  String _to = 'LKR';

  CurrencyRates? _rates;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rates = await _service.getRates(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _rates = rates;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load exchange rates.';
          _loading = false;
        });
      }
    }
  }

  void _swap() {
    setState(() {
      final t = _from;
      _from = _to;
      _to = t;
    });
  }

  double get _amount => double.tryParse(_amountCtrl.text.trim()) ?? 0;

  double? get _converted => _rates?.convert(_amount, _from, _to);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CeylonSpiceTheme.darkBg,
      appBar: AppBar(
        backgroundColor: CeylonSpiceTheme.darkSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: CeylonSpiceTheme.textPrimary),
        title: const Text(
          '💱 Currency Converter',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: CeylonSpiceTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh rates',
            icon: const Icon(Icons.refresh_rounded,
                color: CeylonSpiceTheme.saffron),
            onPressed: _loading ? null : () => _load(forceRefresh: true),
          ),
        ],
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
    if (_error != null || _rates == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: CeylonSpiceTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _load(forceRefresh: true),
                child: const Text('Retry',
                    style: TextStyle(color: CeylonSpiceTheme.saffron)),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAmountField(),
            const SizedBox(height: 18),
            _buildCurrencyRow(
              label: 'From',
              value: _from,
              onChanged: (v) => setState(() => _from = v),
            ),
            _buildSwapButton(),
            _buildCurrencyRow(
              label: 'To',
              value: _to,
              onChanged: (v) => setState(() => _to = v),
            ),
            const SizedBox(height: 24),
            _buildResultCard(),
            const SizedBox(height: 20),
            _buildRateFootnote(),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextField(
      controller: _amountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        color: CeylonSpiceTheme.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: 'Amount',
        labelStyle: const TextStyle(color: CeylonSpiceTheme.textSecondary),
        prefixIcon: const Icon(Icons.payments_rounded,
            color: CeylonSpiceTheme.saffron),
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
      ),
    );
  }

  Widget _buildCurrencyRow({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CeylonSpiceTheme.saffron.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: const TextStyle(
                color: CeylonSpiceTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: CeylonSpiceTheme.darkCard,
                borderRadius: BorderRadius.circular(14),
                icon: const Icon(Icons.arrow_drop_down_rounded,
                    color: CeylonSpiceTheme.saffron),
                style: const TextStyle(
                  color: CeylonSpiceTheme.textPrimary,
                  fontSize: 16,
                ),
                items: CurrencyService.currencies.map((code) {
                  return DropdownMenuItem(
                    value: code,
                    child: Text(
                      '${CurrencyService.flagOf(code)}  $code · '
                      '${CurrencyService.nameOf(code)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) => onChanged(v ?? value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: GestureDetector(
          onTap: _swap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CeylonSpiceTheme.cinnamon,
              shape: BoxShape.circle,
              border: Border.all(color: CeylonSpiceTheme.saffron, width: 2),
            ),
            child: const Icon(Icons.swap_vert_rounded,
                color: CeylonSpiceTheme.coconutCream, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final converted = _converted;
    final resultText =
        converted == null ? '—' : _formatMoney(converted);
    final oneUnit = _rates?.convert(1, _from, _to);

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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatMoney(_amount)} ${CurrencyService.flagOf(_from)} $_from =',
            style: const TextStyle(
              color: CeylonSpiceTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  resultText,
                  style: const TextStyle(
                    color: CeylonSpiceTheme.saffron,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Georgia',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${CurrencyService.flagOf(_to)} $_to',
                style: const TextStyle(
                  color: CeylonSpiceTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (oneUnit != null) ...[
            const SizedBox(height: 14),
            Divider(color: CeylonSpiceTheme.saffron.withOpacity(0.15)),
            const SizedBox(height: 10),
            Text(
              '1 $_from = ${_formatMoney(oneUnit)} $_to',
              style: const TextStyle(
                color: CeylonSpiceTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRateFootnote() {
    final rates = _rates!;
    final local = rates.asOf.toLocal();
    final when =
        '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
    return Row(
      children: [
        Icon(
          rates.isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
          size: 15,
          color: rates.isOffline
              ? CeylonSpiceTheme.textSecondary
              : CeylonSpiceTheme.saffron,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            rates.isOffline
                ? 'Offline estimate — connect to refresh live rates.'
                : 'Live rates · updated $when',
            style: const TextStyle(
              color: CeylonSpiceTheme.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Format a money value with thousands separators and 2 decimals (or 0 for
  /// large whole-ish amounts in weak currencies).
  static String _formatMoney(double v) {
    final twoDp = v.toStringAsFixed(2);
    final parts = twoDp.split('.');
    final intPart = parts[0];
    final neg = intPart.startsWith('-');
    final digits = neg ? intPart.substring(1) : intPart;
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '${neg ? '-' : ''}$buf.${parts[1]}';
  }
}

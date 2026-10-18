// lib/services/currency_service.dart
//
// Live currency conversion for travellers, centred on the Sri Lankan Rupee.
//
// Rates are fetched from the free, key-less Open Exchange Rates community
// endpoint (https://open.er-api.com), which quotes 160+ currencies against
// USD and includes LKR. Results are cached in memory for a few hours, and a
// bundled offline fallback table keeps the converter usable with no network.

import 'dart:convert';
import 'package:http/http.dart' as http;

/// A fetched set of USD-based exchange rates with the time they were fetched.
class CurrencyRates {
  /// Map of ISO currency code → units per 1 USD (e.g. {'LKR': 330.5}).
  final Map<String, double> perUsd;

  /// When these rates were produced (UTC), as reported by the API or `now`.
  final DateTime asOf;

  /// True when these came from the bundled offline table, not the network.
  final bool isOffline;

  const CurrencyRates({
    required this.perUsd,
    required this.asOf,
    required this.isOffline,
  });

  /// Convert [amount] from [from] to [to] using USD as the pivot.
  /// Returns null if either currency is missing from the table.
  double? convert(double amount, String from, String to) {
    final rf = perUsd[from];
    final rt = perUsd[to];
    if (rf == null || rt == null || rf == 0) return null;
    final usd = amount / rf; // from → USD
    return usd * rt; // USD → to
  }
}

class CurrencyService {
  CurrencyService._();

  /// Shared singleton so the rate table is fetched once per session.
  static final CurrencyService instance = CurrencyService._();

  static const String _endpoint = 'https://open.er-api.com/v6/latest/USD';
  static const Duration _cacheTtl = Duration(hours: 6);

  CurrencyRates? _cache;

  /// Currencies surfaced in the converter UI — LKR plus the currencies of
  /// Sri Lanka's main tourist source markets. Each entry: code → (name, flag).
  static const Map<String, List<String>> currencyInfo = {
    'LKR': ['Sri Lankan Rupee', '🇱🇰'],
    'USD': ['US Dollar', '🇺🇸'],
    'EUR': ['Euro', '🇪🇺'],
    'GBP': ['British Pound', '🇬🇧'],
    'INR': ['Indian Rupee', '🇮🇳'],
    'AUD': ['Australian Dollar', '🇦🇺'],
    'CAD': ['Canadian Dollar', '🇨🇦'],
    'CNY': ['Chinese Yuan', '🇨🇳'],
    'JPY': ['Japanese Yen', '🇯🇵'],
    'AED': ['UAE Dirham', '🇦🇪'],
    'CHF': ['Swiss Franc', '🇨🇭'],
    'SGD': ['Singapore Dollar', '🇸🇬'],
    'THB': ['Thai Baht', '🇹🇭'],
    'RUB': ['Russian Ruble', '🇷🇺'],
  };

  /// Display order for the dropdowns.
  static List<String> get currencies => currencyInfo.keys.toList();

  static String nameOf(String code) =>
      currencyInfo[code]?[0] ?? code;

  static String flagOf(String code) =>
      currencyInfo[code]?[1] ?? '💱';

  // Approximate units-per-USD, used only when the network is unavailable so
  // the converter still gives a ballpark. Refreshed online whenever possible.
  static const Map<String, double> _offlineRates = {
    'USD': 1.0,
    'LKR': 305.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'INR': 83.0,
    'AUD': 1.52,
    'CAD': 1.36,
    'CNY': 7.2,
    'JPY': 150.0,
    'AED': 3.67,
    'CHF': 0.88,
    'SGD': 1.34,
    'THB': 35.0,
    'RUB': 92.0,
  };

  /// Returns cached rates when fresh, otherwise fetches live rates. On a
  /// network failure it returns the offline fallback table (never throws).
  Future<CurrencyRates> getRates({bool forceRefresh = false}) async {
    final cached = _cache;
    if (!forceRefresh &&
        cached != null &&
        !cached.isOffline &&
        DateTime.now().toUtc().difference(cached.asOf) < _cacheTtl) {
      return cached;
    }

    try {
      final resp = await http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['result'] == 'success' && data['rates'] is Map) {
          final rates = <String, double>{};
          (data['rates'] as Map).forEach((k, v) {
            if (v is num) rates[k as String] = v.toDouble();
          });
          DateTime asOf;
          final unix = data['time_last_update_unix'];
          if (unix is num) {
            asOf = DateTime.fromMillisecondsSinceEpoch(
              unix.toInt() * 1000,
              isUtc: true,
            );
          } else {
            asOf = DateTime.now().toUtc();
          }
          final result =
              CurrencyRates(perUsd: rates, asOf: asOf, isOffline: false);
          _cache = result;
          return result;
        }
      }
    } catch (_) {
      // fall through to offline table
    }

    return CurrencyRates(
      perUsd: Map<String, double>.from(_offlineRates),
      asOf: DateTime.now().toUtc(),
      isOffline: true,
    );
  }
}

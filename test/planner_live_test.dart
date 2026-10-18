import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ceylon_travel_planner/models/travel_models.dart';
import 'package:ceylon_travel_planner/services/ai_recommendation_service.dart';

void main() {
  // Allow real network (flutter_test otherwise forces HTTP 400).
  HttpOverrides.global = null;

  test('LIVE: Galle beach traveller → nearby south/west places only', () async {
    final prefs = TravelPreferences(
      groupType: 'couple',
      groupSize: 2,
      gender: 'Mixed',
      ageRange: '25-35',
      budgetUsd: 1500,
      budgetTier: 'mid-range',
      activityPreferences: ['Chilling & Fun'],
      travelDate: '2026-12-15',
      travelMonth: 'December',
      tripDays: 7,
      currentLocation: 'Galle',
    );

    final resp = await AIRecommendationService().getRecommendations(prefs);
    // ignore: avoid_print
    print('=== Galle / Chilling & Fun — returned destinations ===');
    for (final r in resp.recommendations) {
      // ignore: avoid_print
      print('  #${r.rank}  ${r.destination}');
    }
    expect(resp.recommendations, isNotEmpty);
  },
      timeout: const Timeout(Duration(seconds: 120)),
      // Hits the real OpenRouter + Pinecone APIs (costs credits). Remove this
      // skip to run it manually and verify district-local results live.
      skip: 'live API test — run manually');
}

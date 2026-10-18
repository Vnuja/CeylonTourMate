import 'package:flutter_test/flutter_test.dart';
import 'package:ceylon_travel_planner/models/travel_models.dart';
import 'package:ceylon_travel_planner/services/ai_recommendation_service.dart';

TravelPreferences p(String district, List<String> acts) => TravelPreferences(
      groupType: 'couple',
      groupSize: 2,
      gender: 'Mixed',
      ageRange: '25-35',
      budgetUsd: 1500,
      budgetTier: 'mid-range',
      activityPreferences: acts,
      travelDate: '2026-12-15',
      travelMonth: 'December',
      tripDays: 7,
      currentLocation: district,
    );

void main() {
  final svc = AIRecommendationService();
  final districts = AIRecommendationService.locationOptions
      .where((d) => d != AIRecommendationService.outsideSlOption)
      .toList();

  test('top-5 shortlist for every district / activity', () {
    for (final d in districts) {
      // ignore: avoid_print
      print('\n=== $d ===');
      for (final a in const [
        'Chilling & Fun',
        'Religious & Heritage',
        'Adventure',
      ]) {
        final top5 = svc.nearbyDestinationNames(p(d, [a])).take(5).toList();
        // ignore: avoid_print
        print('  ${a.padRight(22)}: ${top5.join(', ')}');
      }
    }
    expect(districts.length, 25);
  });
}

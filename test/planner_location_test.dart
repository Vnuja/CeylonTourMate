import 'package:flutter_test/flutter_test.dart';
import 'package:ceylon_travel_planner/models/travel_models.dart';
import 'package:ceylon_travel_planner/services/ai_recommendation_service.dart';

TravelPreferences prefsFor(String district, List<String> acts) =>
    TravelPreferences(
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

  test('Galle beach traveller → nearby south/west coast only', () {
    final names = svc.nearbyDestinationNames(prefsFor('Galle', ['Chilling & Fun']));
    // ignore: avoid_print
    print('Galle/beach -> $names');
    expect(names, isNotEmpty);
    // Must include genuinely nearby spots…
    expect(names.any((n) => n.contains('Unawatuna') || n.contains('Mirissa')),
        isTrue);
    // …and must NOT include far north/east places.
    for (final far in ['Jaffna', 'Trincomalee', 'Nilaveli', 'Pasikuda']) {
      expect(names.contains(far), isFalse, reason: '$far should be excluded');
    }
  });

  test('Kandy heritage traveller → interior temples, not the coast', () {
    final names =
        svc.nearbyDestinationNames(prefsFor('Kandy', ['Religious & Heritage']));
    // ignore: avoid_print
    print('Kandy/heritage -> $names');
    expect(names, isNotEmpty);
    expect(names.any((n) => n.contains('Kandy') || n.contains('Dambulla')),
        isTrue);
    expect(names.contains('Jaffna'), isFalse);
  });

  test('Colombo beach traveller → nearest beach/fun spots (across districts)', () {
    final names =
        svc.nearbyDestinationNames(prefsFor('Colombo', ['Chilling & Fun']));
    // ignore: avoid_print
    print('Colombo/beach -> $names');
    final top5 = names.take(5).toList();
    // ignore: avoid_print
    print('Colombo/beach top5 -> $top5');
    // Nearby-across-districts behaviour: the capital plus its closest beaches.
    expect(top5.contains('Colombo'), isTrue);
    expect(top5.contains('Mount Lavinia'), isTrue);
    // Must NOT contain genuinely far places (north/east coast).
    for (final far in ['Jaffna', 'Trincomalee', 'Nilaveli', 'Arugam Bay']) {
      expect(top5.contains(far), isFalse, reason: '$far is too far from Colombo');
    }
  });

  test('Outside Sri Lanka → no pinned shortlist (island-wide)', () {
    final names = svc.nearbyDestinationNames(
        prefsFor(AIRecommendationService.outsideSlOption, ['Chilling & Fun']));
    expect(names, isEmpty);
  });
}

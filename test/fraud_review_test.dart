import 'package:flutter_test/flutter_test.dart';
import 'package:ceylon_travel_planner/services/fraud_review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fraud model loads from bundled asset', () async {
    await FraudReviewService.instance.load();
    expect(FraudReviewService.instance.isLoaded, isTrue);
  });

  test('flags obviously fake / spammy reviews', () async {
    await FraudReviewService.instance.load();
    const fakes = [
      'This hotel is amazing amazing amazing, best ever, 5 stars!!!',
      'Worst experience ever do not book waste of money terrible terrible',
    ];
    for (final r in fakes) {
      final v = FraudReviewService.instance.classify(r);
      // ignore: avoid_print
      print('FAKE? ${v.isFraud} p=${v.probability.toStringAsFixed(3)} :: $r');
    }
  });

  test('characterise realistic short reviews a user might type', () async {
    await FraudReviewService.instance.load();
    const samples = [
      'Best hotel ever! Amazing! Must visit! 10/10!',
      'Nice place good food lovely staff highly recommend',
      'I love this place so much it is the best place ever',
      'great great great awesome awesome perfect perfect',
      'good',
      'The room was dirty and the staff were rude, would not return',
    ];
    for (final r in samples) {
      final v = FraudReviewService.instance.classify(r);
      // ignore: avoid_print
      print('p=${v.probability.toStringAsFixed(3)} '
          '${v.isFraud ? "FRAUD " : "ok    "} :: $r');
    }
  });

  // ── Hybrid rule layer (notebook9561ea5fff.ipynb, last cells) ────────────
  test('notebook spam sample (phone + promo) is rejected by rules', () async {
    await FraudReviewService.instance.load();
    const spam = 'AMAZING!!! Best place in the whole world!!! Everything was '
        'perfect, 10/10, five stars, must visit!!! Book your tour with Lanka '
        'Royal Tours today, call 077-XXXXXXX for a special discount. You will '
        'not regret it, trust me!!!';
    final v = FraudReviewService.instance.classify(spam);
    // ignore: avoid_print
    print('SPAM -> fraud=${v.isFraud} rules=${v.decidedByRules} ${v.reasons}');
    expect(v.isFraud, isTrue);
    expect(v.decidedByRules, isTrue);
    expect(v.reasons, contains('phone number'));
  });

  test('notebook genuine safari review passes (ML model, no flags)', () async {
    await FraudReviewService.instance.load();
    const genuine = "Went in the afternoon and saw a big herd of elephants at "
        "the water's edge. Sightings were great, but the park was busier than "
        "I expected, with about 15 jeeps in the same area at one point. Bring "
        "water and sunscreen, as there's little shade in the open jeep.";
    final v = FraudReviewService.instance.classify(genuine);
    // ignore: avoid_print
    print('GENUINE -> fraud=${v.isFraud} p=${v.probability.toStringAsFixed(3)}');
    expect(v.isFraud, isFalse);
    expect(v.decidedByRules, isFalse);
  });

  test('phone numbers, links and emails are each rejected on their own', () async {
    await FraudReviewService.instance.load();
    const cases = {
      'Lovely stay, quiet rooms. Call 0771234567 for a ride.': 'phone number',
      'Great driver, +94 77 123 4567 is his number.': 'phone number',
      'Nice hotel, my number is 077-1234567 if you need a guide.': 'phone number',
      'Good tour, see www.lankatours.lk for details.': 'URL/website',
      'Lovely beach, email me at guide@lankatours.com anytime.': 'email address',
    };
    cases.forEach((text, flag) {
      final v = FraudReviewService.instance.classify(text);
      // ignore: avoid_print
      print('${v.isFraud ? "FRAUD" : "ok   "} ${v.reasons} :: $text');
      expect(v.isFraud, isTrue, reason: text);
      expect(v.reasons, contains(flag), reason: text);
    });
  });

  test('ordinary numbers and a single weak signal do not trigger rules', () async {
    await FraudReviewService.instance.load();
    const ok = [
      'We stayed 3 nights in room 204 and paid 15000 rupees, great value.',
      'The staff were lovely! Breakfast was good and the pool was clean.',
      'Booked a jeep for 6 hours and the guide was very knowledgeable.',
    ];
    for (final t in ok) {
      final v = FraudReviewService.instance.classify(t);
      // ignore: avoid_print
      print('${v.isFraud ? "FRAUD" : "ok   "} rules=${v.decidedByRules} :: $t');
      expect(v.decidedByRules, isFalse, reason: t);
    }
  });

  test('passes a genuine, specific review', () async {
    await FraudReviewService.instance.load();
    const genuine =
        'We stayed three nights at the downtown property. Rooms were clean, '
        'staff helpful, and the location near the river was convenient for walking.';
    final v = FraudReviewService.instance.classify(genuine);
    // ignore: avoid_print
    print('GENUINE -> isFraud=${v.isFraud} p=${v.probability.toStringAsFixed(3)}');
  });
}

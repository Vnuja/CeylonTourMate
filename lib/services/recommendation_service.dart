import 'package:flutter/material.dart';
import '../models/destination.dart';

class RecommendationService {
  static const List<Destination> allDestinations = [
    Destination(
      name: 'Sigiriya',
      description: 'Iconic ancient rock fortress with frescoes and sweeping views.',
      category: 'Heritage',
      tags: ['sigiriya', 'rock', 'fortress', 'ancient', 'heritage', 'lion rock'],
      icon: Icons.terrain,
    ),
    Destination(
      name: 'Kandy',
      description: 'Cultural capital, home to the Temple of the Sacred Tooth Relic.',
      category: 'Culture',
      tags: ['kandy', 'temple', 'tooth', 'lake', 'culture', 'hill'],
      icon: Icons.temple_buddhist,
    ),
    Destination(
      name: 'Galle Fort',
      description: 'Dutch colonial fort city with cobbled streets and ocean views.',
      category: 'Heritage',
      tags: ['galle', 'fort', 'colonial', 'coastal', 'dutch'],
      icon: Icons.fort,
    ),
    Destination(
      name: 'Ella',
      description: 'Misty hill-country town famous for train rides and Nine Arch Bridge.',
      category: 'Hill Country',
      tags: ['ella', 'hill', 'train', 'bridge', 'mountain', 'tea', 'nine arch'],
      icon: Icons.landscape,
    ),
    Destination(
      name: 'Mirissa',
      description: 'Palm-fringed beach known for whale watching and surfing.',
      category: 'Beach',
      tags: ['mirissa', 'beach', 'whale', 'surf', 'coast', 'sea', 'sun'],
      icon: Icons.beach_access,
    ),
    Destination(
      name: 'Yala National Park',
      description: 'Premier wildlife park with the highest leopard density in the world.',
      category: 'Wildlife',
      tags: ['yala', 'safari', 'wildlife', 'leopard', 'animal', 'jungle', 'park'],
      icon: Icons.pets,
    ),
    Destination(
      name: 'Nuwara Eliya',
      description: 'Cool climate hill town surrounded by tea plantations.',
      category: 'Hill Country',
      tags: ['nuwara', 'eliya', 'tea', 'hill', 'mountain', 'cold', 'plantation'],
      icon: Icons.local_florist,
    ),
    Destination(
      name: 'Anuradhapura',
      description: 'Sacred ancient city with well-preserved ruins and stupas.',
      category: 'Heritage',
      tags: ['anuradhapura', 'ancient', 'ruins', 'stupa', 'sacred', 'temple'],
      icon: Icons.account_balance,
    ),
    Destination(
      name: 'Trincomalee',
      description: 'East-coast harbor city with pristine beaches and diving spots.',
      category: 'Beach',
      tags: ['trincomalee', 'trinco', 'beach', 'diving', 'coast', 'harbor'],
      icon: Icons.sailing,
    ),
    Destination(
      name: 'Arugam Bay',
      description: 'Laid-back surf town on the southeast coast.',
      category: 'Beach',
      tags: ['arugam', 'bay', 'surf', 'beach', 'coast', 'surfing'],
      icon: Icons.surfing,
    ),
    Destination(
      name: 'Dambulla Cave Temple',
      description: 'Cave complex with centuries-old Buddhist murals and statues.',
      category: 'Culture',
      tags: ['dambulla', 'cave', 'temple', 'buddhist', 'culture', 'murals'],
      icon: Icons.temple_hindu,
    ),
    Destination(
      name: 'Jaffna',
      description: 'Northern peninsula city with unique Tamil culture and cuisine.',
      category: 'Culture',
      tags: ['jaffna', 'north', 'tamil', 'culture', 'peninsula', 'food'],
      icon: Icons.explore,
    ),
    Destination(
      name: 'Polonnaruwa',
      description: 'Medieval capital with remarkably preserved stone carvings.',
      category: 'Heritage',
      tags: ['polonnaruwa', 'ancient', 'ruins', 'medieval', 'stone', 'carvings'],
      icon: Icons.museum,
    ),
    Destination(
      name: 'Udawalawe National Park',
      description: 'Open grasslands famous for large herds of wild elephants.',
      category: 'Wildlife',
      tags: ['udawalawe', 'elephant', 'safari', 'wildlife', 'park', 'animal'],
      icon: Icons.pets,
    ),
    Destination(
      name: 'Unawatuna',
      description: 'Sheltered bay beach popular for swimming and snorkeling.',
      category: 'Beach',
      tags: ['unawatuna', 'beach', 'swim', 'snorkel', 'bay', 'coast'],
      icon: Icons.beach_access,
    ),
    Destination(
      name: 'Horton Plains & World\'s End',
      description: 'Highland plateau with cloud forest trails and dramatic cliff views.',
      category: 'Hill Country',
      tags: ['horton', 'plains', 'world\'s end', 'hike', 'cliff', 'mountain', 'trek'],
      icon: Icons.hiking,
    ),
    Destination(
      name: 'Bentota',
      description: 'Golden beaches with water sports, rivers, and turtle hatcheries.',
      category: 'Beach',
      tags: ['bentota', 'beach', 'river', 'turtle', 'watersports', 'resort'],
      icon: Icons.kayaking,
    ),
    Destination(
      name: 'Adam\'s Peak',
      description: 'Sacred mountain pilgrimage with a famous sunrise hike.',
      category: 'Adventure',
      tags: ['adam', 'peak', 'sripada', 'hike', 'pilgrimage', 'mountain', 'sunrise'],
      icon: Icons.hiking,
    ),
    Destination(
      name: 'Bambarakanda Falls',
      description: 'Sri Lanka\'s tallest waterfall, tucked in the central highlands.',
      category: 'Nature',
      tags: ['bambarakanda', 'waterfall', 'falls', 'nature', 'hike'],
      icon: Icons.water,
    ),
    Destination(
      name: 'Negombo',
      description: 'Coastal town near the airport known for its lagoon and seafood.',
      category: 'Beach',
      tags: ['negombo', 'beach', 'lagoon', 'fish', 'seafood', 'coast'],
      icon: Icons.beach_access,
    ),
  ];

  static const List<Destination> defaultDestinations = [
    Destination(
      name: 'Sigiriya',
      description: 'Iconic ancient rock fortress with frescoes and sweeping views.',
      category: 'Heritage',
      tags: ['sigiriya'],
      icon: Icons.terrain,
    ),
    Destination(
      name: 'Kandy',
      description: 'Cultural capital, home to the Temple of the Sacred Tooth Relic.',
      category: 'Culture',
      tags: ['kandy'],
      icon: Icons.temple_buddhist,
    ),
    Destination(
      name: 'Mirissa',
      description: 'Palm-fringed beach known for whale watching and surfing.',
      category: 'Beach',
      tags: ['mirissa'],
      icon: Icons.beach_access,
    ),
    Destination(
      name: 'Yala National Park',
      description: 'Premier wildlife park with the highest leopard density in the world.',
      category: 'Wildlife',
      tags: ['yala'],
      icon: Icons.pets,
    ),
    Destination(
      name: 'Ella',
      description: 'Misty hill-country town famous for train rides and Nine Arch Bridge.',
      category: 'Hill Country',
      tags: ['ella'],
      icon: Icons.landscape,
    ),
    Destination(
      name: 'Galle Fort',
      description: 'Dutch colonial fort city with cobbled streets and ocean views.',
      category: 'Heritage',
      tags: ['galle'],
      icon: Icons.fort,
    ),
  ];

  /// Scores every destination against a set of free-text signal strings
  /// (internally these come from the user's saved album names, but this
  /// service has no knowledge of where the strings came from).
  static Map<Destination, int> _scoreAll(List<String> signals) {
    final scores = <Destination, int>{};
    final normalized = signals
        .map((s) => s.toLowerCase().trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (final dest in allDestinations) {
      int score = 0;
      final destNameLower = dest.name.toLowerCase();

      for (final signal in normalized) {
        // Strong signal: the name itself appears.
        if (signal.contains(destNameLower) || destNameLower.contains(signal)) {
          score += 5;
        }
        // Medium signal: a category word appears (e.g. "beach", "wildlife").
        if (signal.contains(dest.category.toLowerCase())) {
          score += 2;
        }
        // Weak signal: any tag keyword appears.
        for (final tag in dest.tags) {
          if (signal.contains(tag)) score += 1;
        }
      }

      if (score > 0) scores[dest] = score;
    }
    return scores;
  }

  /// Returns the top recommendations. Falls back to curated defaults
  /// when there isn't enough signal to personalize.
  static List<Destination> getRecommendations(List<String> signals, {int limit = 6}) {
    final scores = _scoreAll(signals);
    if (scores.isEmpty) return defaultDestinations.take(limit).toList();

    final sorted = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    return sorted.take(limit).toList();
  }

  /// Returns additional places not already shown, still preferring ones
  /// that match the signals, falling back to shuffled variety.
  static List<Destination> suggestMore(
    List<String> signals,
    List<String> alreadyShownNames, {
    int count = 4,
  }) {
    final scores = _scoreAll(signals);
    final remaining = allDestinations
        .where((d) => !alreadyShownNames.contains(d.name))
        .toList();

    if (remaining.isEmpty) return [];

    final hasAnyScore = remaining.any((d) => (scores[d] ?? 0) > 0);
    if (hasAnyScore) {
      remaining.sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    } else {
      remaining.shuffle();
    }

    return remaining.take(count).toList();
  }
}
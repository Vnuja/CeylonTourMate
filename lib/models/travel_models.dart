// ─── Travel Preference Model ─────────────────────────────────────────────────
class TravelPreferences {
  final String groupType;        // solo / couple / family / group
  final int groupSize;
  final String gender;           // male / female / mixed
  final String ageRange;         // e.g. "25-35"
  final double budgetUsd;
  final String budgetTier;       // budget / mid-range / luxury
  final List<String> activityPreferences;
  final String travelDate;       // ISO date YYYY-MM-DD
  final String travelMonth;
  final int tripDays;

  TravelPreferences({
    required this.groupType,
    required this.groupSize,
    required this.gender,
    required this.ageRange,
    required this.budgetUsd,
    required this.budgetTier,
    required this.activityPreferences,
    required this.travelDate,
    required this.travelMonth,
    required this.tripDays,
  });

  Map<String, dynamic> toJson() => {
    'group_type': groupType,
    'group_size': groupSize,
    'gender': gender,
    'age_range': ageRange,
    'budget_usd': budgetUsd,
    'budget_tier': budgetTier,
    'activity_preferences': activityPreferences,
    'travel_date': travelDate,
    'travel_month': travelMonth,
    'trip_days': tripDays,
  };
}

// ─── Activity Model ───────────────────────────────────────────────────────────
class Activity {
  final String name;
  final String priceUsd;
  final String? icon;

  Activity({required this.name, required this.priceUsd, this.icon});

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    name: json['name'] ?? '',
    priceUsd: json['price_usd']?.toString() ?? 'N/A',
  );
}

// ─── Hotel Tier Model ─────────────────────────────────────────────────────────
// Each package shows 3 comfort tiers (Budget / Mid-range / Luxury), and each
// tier suggests 3 concrete hotels — 9 hotel suggestions total per package.
class HotelTierOption {
  final String tier; // e.g. "Budget", "Mid-range", "Luxury"
  final List<String> hotels; // exactly 3 "Name (\$X/night)" style entries

  HotelTierOption({required this.tier, required this.hotels});

  factory HotelTierOption.fromJson(Map<String, dynamic> json) {
    final hotelsList = (json['hotels'] as List<dynamic>? ?? [])
        .map((h) => h.toString())
        .where((h) => h.trim().isNotEmpty)
        .toList();
    return HotelTierOption(
      tier: json['tier']?.toString() ?? '',
      hotels: hotelsList,
    );
  }
}

// ─── Recommendation Model ─────────────────────────────────────────────────────
class TravelRecommendation {
  final int rank;
  final String destination;
  final String weatherSuitability;
  final String packageName;
  final String packageCostPerPerson;
  final List<Activity> activities;
  final String accommodation;
  final String totalCostPerPerson;
  final String whySuitable;
  final String? imageUrl;
  final double? rating;
  // ── Detailed package info (hotel options, transport, entry fees) ──────────
  final List<HotelTierOption> hotelOptions;
  final String transportInfo;
  final String entryFees;

  TravelRecommendation({
    required this.rank,
    required this.destination,
    required this.weatherSuitability,
    required this.packageName,
    required this.packageCostPerPerson,
    required this.activities,
    required this.accommodation,
    required this.totalCostPerPerson,
    required this.whySuitable,
    this.imageUrl,
    this.rating,
    this.hotelOptions = const [],
    this.transportInfo = '',
    this.entryFees = '',
  });

  factory TravelRecommendation.fromJson(Map<String, dynamic> json) {
    final activitiesList = (json['activities'] as List<dynamic>? ?? [])
        .map((a) => Activity.fromJson(a as Map<String, dynamic>))
        .toList();

    final destinationName = json['destination'] ?? '';
    final hotelOptionsList = _parseHotelTiers(
      json['hotel_options'],
      destinationName,
    );

    return TravelRecommendation(
      rank: json['rank'] ?? 0,
      destination: destinationName,
      weatherSuitability: json['weather_suitability'] ?? '',
      packageName: json['package_name'] ?? '',
      packageCostPerPerson: json['package_cost_usd_per_person']?.toString() ?? '',
      activities: activitiesList,
      accommodation: json['accommodation'] ?? '',
      totalCostPerPerson: json['total_cost_per_person_usd']?.toString() ?? '',
      whySuitable: json['why_suitable'] ?? '',
      imageUrl: _getDestinationImage(destinationName),
      rating: _getDestinationRating(destinationName),
      hotelOptions: hotelOptionsList,
      transportInfo: json['transport']?.toString() ?? '',
      entryFees: json['entry_fees']?.toString() ?? '',
    );
  }

  // Fallback hotel names used to pad any tier that comes back short, or to
  // build tiers from scratch if the AI didn't return hotel_options at all.
  static const Map<String, List<String>> _fallbackHotelNames = {
    'Budget': [
      'Traveller\'s Rest Guesthouse (\$18-25/night)',
      'Backpacker\'s Nook Hostel (\$12-20/night)',
      'Sunrise Family Homestay (\$20-30/night)',
    ],
    'Mid-range': [
      'Boutique Garden Villa (\$60-85/night)',
      'Cinnamon Grove Inn (\$70-95/night)',
      'Hillside Comfort Hotel (\$65-90/night)',
    ],
    'Luxury': [
      'Heritage Resort & Spa (\$180-260/night)',
      'Ceylon Palm Grand Hotel (\$200-300/night)',
      'Emerald Bay Luxury Villas (\$220-320/night)',
    ],
  };

  // Builds exactly 3 tiers (Budget / Mid-range / Luxury), each with exactly
  // 3 hotel suggestions — 9 hotels total. Accepts the new nested
  // "hotel_options": [{"tier": "...", "hotels": [...]}] shape from the AI,
  // and also degrades gracefully if the AI returns the older flat list of
  // strings (or nothing at all), so the UI is never left with only 1 hotel.
  static List<HotelTierOption> _parseHotelTiers(
    dynamic rawHotelOptions,
    String destination,
  ) {
    const tierOrder = ['Budget', 'Mid-range', 'Luxury'];
    final Map<String, List<String>> byTier = {
      for (final t in tierOrder) t: <String>[],
    };

    if (rawHotelOptions is List) {
      for (final entry in rawHotelOptions) {
        if (entry is Map) {
          // New nested shape: {"tier": "Budget", "hotels": [...]}
          final tierName = (entry['tier'] ?? '').toString();
          final matchedTier = tierOrder.firstWhere(
            (t) => tierName.toLowerCase().contains(t.toLowerCase()),
            orElse: () => 'Mid-range',
          );
          final hotels = (entry['hotels'] as List<dynamic>? ?? [])
              .map((h) => h.toString())
              .where((h) => h.trim().isNotEmpty)
              .toList();
          byTier[matchedTier]!.addAll(hotels);
        } else {
          // Legacy flat shape: "Budget: Hotel Name (\$X/night)"
          final text = entry.toString();
          if (text.trim().isEmpty) continue;
          final matchedTier = tierOrder.firstWhere(
            (t) => text.toLowerCase().startsWith(t.toLowerCase()),
            orElse: () => 'Mid-range',
          );
          byTier[matchedTier]!.add(text);
        }
      }
    }

    // Pad every tier up to exactly 3 hotels, and trim any tier that came
    // back with more than 3.
    final result = <HotelTierOption>[];
    for (final tierName in tierOrder) {
      final hotels = List<String>.from(byTier[tierName] ?? []);
      final fallback = _fallbackHotelNames[tierName]!;
      var fallbackIndex = 0;
      while (hotels.length < 3 && fallbackIndex < fallback.length) {
        final candidate = destination.isNotEmpty
            ? '${fallback[fallbackIndex]} near $destination'
            : fallback[fallbackIndex];
        if (!hotels.any(
          (h) => h.toLowerCase() == candidate.toLowerCase(),
        )) {
          hotels.add(candidate);
        }
        fallbackIndex++;
      }
      result.add(
        HotelTierOption(tier: tierName, hotels: hotels.take(3).toList()),
      );
    }
    return result;
  }

  // Map destinations to curated Unsplash images
  static String? _getDestinationImage(String destination) {
    const imageMap = {
      'Sigiriya': 'assets/images/sigiriya.jpg',
      'Sigiriya Rock': 'assets/images/sigiriya2.jpg',
      'Ella': 'assets/images/ella.jpg',
      'Galle Fort': 'assets/images/gallefort2.jpg',
      'Galle': 'assets/images/gallefort.jpg',
      'Kandy': 'assets/images/kandy.jpg',
      'Temple of the Tooth Kandy': 'assets/images/kandy.jpg',
      'Nuwara Eliya': 'assets/images/nuwaraeliya.jpg',
      'Yala National Park': 'assets/images/yala.jpg',
      'Yala': 'assets/images/yala2.jpg',
      'Mirissa': 'assets/images/mirissa.jpg',
      'Bentota': 'assets/images/benthota.jpg',
      'Colombo': 'assets/images/colombo.jpg',
      'Dambulla Cave Temple': 'assets/images/dambulla.jpg',
      'Dambulla': 'assets/images/dambulla.jpg',
      'Anuradhapura': 'assets/images/anuradhapura.jpg',
      'Polonnaruwa': 'assets/images/polonnaruwa.jpg',
      'Trincomalee': 'assets/images/trincomalee.jpg',
      'Arugam Bay': 'assets/images/ArugamBay.jpg',
      'Udawalawe National Park': 'assets/images/Udawalawe.jpg',
      'Wilpattu National Park': 'assets/images/Wilpattu.jpg',
      'Horton Plains': 'assets/images/HortonPlains.jpg',
      'Knuckles Mountain Range': 'assets/images/Knuckles.jpg',
      'Jaffna': 'assets/images/Jaffna.jpg',
      'Unawatuna': 'assets/images/Unawatuna.jpg',
    };

    // Fuzzy match
    for (final entry in imageMap.entries) {
      if (destination.toLowerCase().contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(destination.toLowerCase().split(' ').first)) {
        return entry.value;
      }
    }
    // Default Sri Lanka
    return 'https://images.unsplash.com/photo-1568454537842-d933259bb258?w=800';
  }

  static double _getDestinationRating(String destination) {
    const ratingMap = {
      'Sigiriya': 4.9, 'Ella': 4.8, 'Galle': 4.7, 'Kandy': 4.8,
      'Nuwara Eliya': 4.6, 'Yala': 4.7, 'Mirissa': 4.6,
      'Bentota': 4.5, 'Colombo': 4.4, 'Dambulla': 4.7,
      'Anuradhapura': 4.8, 'Polonnaruwa': 4.7, 'Trincomalee': 4.6,
      'Arugam Bay': 4.7, 'Horton Plains': 4.6,
    };
    for (final entry in ratingMap.entries) {
      if (destination.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return 4.5;
  }
}

// ─── Full Recommendation Response ────────────────────────────────────────────
class RecommendationResponse {
  final List<TravelRecommendation> recommendations;
  final List<String> travelTips;

  RecommendationResponse({
    required this.recommendations,
    required this.travelTips,
  });

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) {
    final recs = (json['recommendations'] as List<dynamic>? ?? [])
        .map((r) => TravelRecommendation.fromJson(r as Map<String, dynamic>))
        .toList();
    final tips = (json['travel_tips'] as List<dynamic>? ?? [])
        .map((t) => t.toString())
        .toList();
    return RecommendationResponse(recommendations: recs, travelTips: tips);
  }
}
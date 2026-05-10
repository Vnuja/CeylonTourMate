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
  });

  factory TravelRecommendation.fromJson(Map<String, dynamic> json) {
    final activitiesList = (json['activities'] as List<dynamic>? ?? [])
        .map((a) => Activity.fromJson(a as Map<String, dynamic>))
        .toList();

    return TravelRecommendation(
      rank: json['rank'] ?? 0,
      destination: json['destination'] ?? '',
      weatherSuitability: json['weather_suitability'] ?? '',
      packageName: json['package_name'] ?? '',
      packageCostPerPerson: json['package_cost_usd_per_person']?.toString() ?? '',
      activities: activitiesList,
      accommodation: json['accommodation'] ?? '',
      totalCostPerPerson: json['total_cost_per_person_usd']?.toString() ?? '',
      whySuitable: json['why_suitable'] ?? '',
      imageUrl: _getDestinationImage(json['destination'] ?? ''),
      rating: _getDestinationRating(json['destination'] ?? ''),
    );
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

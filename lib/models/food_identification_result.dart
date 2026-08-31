// lib/models/food_identification_result.dart

/// Mirrors the Food Scanner web-app's /analyze JSON response.
class FoodIdentificationResult {
  final String foodName;
  final String description;
  final List<String> ingredients;
  final List<String> allergens;
  final String dietary;
  final String howToEat;
  final String howToMake;
  final String confidence;
  final bool inDatabase;

  const FoodIdentificationResult({
    required this.foodName,
    required this.description,
    required this.ingredients,
    required this.allergens,
    required this.dietary,
    required this.howToEat,
    required this.howToMake,
    required this.confidence,
    required this.inDatabase,
  });

  factory FoodIdentificationResult.fromJson(Map<String, dynamic> json) {
    List<String> _parseList(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      if (value is String) {
        // Sometimes the AI returns a comma-separated string
        return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    return FoodIdentificationResult(
      foodName:   json['food_name']?.toString()  ?? 'Unknown Food',
      description: json['description']?.toString() ?? '',
      ingredients: _parseList(json['ingredients']),
      allergens:   _parseList(json['allergens']),
      dietary:     json['dietary']?.toString()    ?? 'Not available',
      howToEat:    json['how_to_eat']?.toString() ?? 'Not available',
      howToMake:   json['how_to_make']?.toString() ?? 'Not available',
      confidence:  json['confidence']?.toString() ?? 'N/A',
      inDatabase:  json['in_database'] as bool?   ?? false,
    );
  }
}

// CeylonTourMate — AI Module Types (placeholder for future)

export interface FoodPrediction {
  label: string;
  confidence: number;
  foodInfo?: FoodInfo;
}

export interface FoodInfo {
  name: string;
  localName: string;
  description: string;
  ingredients: string[];
  spiceLevel: number; // 1-5
  isVegetarian: boolean;
  isVegan: boolean;
  isGlutenFree: boolean;
  commonAllergens: string[];
  calories: number;
}

export interface ContentSafetyResult {
  isSafe: boolean;
  safetyScore: number; // 0-100
  categories: SafetyCategory[];
  extractedText?: string;
  action: 'allow' | 'warn' | 'block';
}

export interface SafetyCategory {
  name: string;
  score: number;
  flagged: boolean;
}

export interface PlaceIdentification {
  placeId: string;
  name: string;
  sinhalaName?: string;
  tamilName?: string;
  category: string;
  confidence: number;
  description: string;
  historicalContext?: string;
  coordinates: { latitude: number; longitude: number };
  nearbyPlaces?: PlaceIdentification[];
}

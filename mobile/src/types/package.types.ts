// CeylonTourMate — Package & Recommendation Types (placeholder for future)

export interface TourPackage {
  id: string;
  name: string;
  category: PackageCategory;
  duration: number; // days
  price: number;
  currency: string;
  activities: string[];
  healthRestrictions: string[];
  weatherSuitability: string[];
  coordinates: { latitude: number; longitude: number };
  rating: number;
  reviewCount: number;
  images: string[];
  description: string;
  matchScore?: number;
  matchReasons?: string[];
}

export enum PackageCategory {
  CULTURAL = 'cultural',
  NATURE = 'nature',
  ADVENTURE = 'adventure',
  BEACH = 'beach',
  WILDLIFE = 'wildlife',
  WELLNESS = 'wellness',
}

export interface Booking {
  id: string;
  packageId: string;
  userId: string;
  startDate: string;
  endDate: string;
  participants: number;
  totalPrice: number;
  status: 'pending' | 'confirmed' | 'cancelled' | 'completed';
}

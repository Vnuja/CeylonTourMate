// CeylonTourMate — User & Auth Types

export enum UserRole {
  TOURIST = 'tourist',
  GUIDE = 'guide',
  DRIVER = 'driver',
  AGENCY_ADMIN = 'agency_admin',
  SYSTEM_ADMIN = 'system_admin',
}

export interface User {
  id: string;
  email: string;
  displayName: string;
  photoURL?: string;
  role: UserRole;
  phone?: string;
  createdAt: string;
  updatedAt: string;
}

export interface UserProfile extends User {
  interests: string[];
  healthConditions: string[];
  fitnessLevel: 'low' | 'moderate' | 'high';
  dietaryRestrictions: string[];
  allergens: string[];
  emergencyContacts: EmergencyContact[];
  pastTours: string[]; // tour IDs
}

export interface EmergencyContact {
  name: string;
  phone: string;
  relationship: string;
}

export interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  role: UserRole | null;
}

export interface LoginCredentials {
  email: string;
  password: string;
}

export interface RegisterData extends LoginCredentials {
  displayName: string;
  role?: UserRole;
  phone?: string;
}

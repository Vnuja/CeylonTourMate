// CeylonTourMate — Location Store (Zustand)
import { create } from 'zustand';
import { LocationPoint } from '../types';

interface LocationStore {
  currentLocation: LocationPoint | null;
  locationPermissionGranted: boolean;
  isWatchingLocation: boolean;
  locationError: string | null;

  setCurrentLocation: (location: LocationPoint) => void;
  setPermission: (granted: boolean) => void;
  setWatching: (watching: boolean) => void;
  setError: (error: string | null) => void;
}

export const useLocationStore = create<LocationStore>((set) => ({
  currentLocation: null,
  locationPermissionGranted: false,
  isWatchingLocation: false,
  locationError: null,

  setCurrentLocation: (location) => set({ currentLocation: location }),
  setPermission: (granted) => set({ locationPermissionGranted: granted }),
  setWatching: (watching) => set({ isWatchingLocation: watching }),
  setError: (error) => set({ locationError: error }),
}));

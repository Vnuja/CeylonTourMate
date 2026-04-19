// CeylonTourMate — Trip Store (Zustand) — CORE store for Live Monitoring
import { create } from 'zustand';
import {
  Trip,
  TripStatus,
  TripAlert,
  AlertSeverity,
  SOSEvent,
  SOSStatus,
  LocationPoint,
  VehicleLocationUpdate,
  TripProgressUpdate,
  SafetyStatus,
  Waypoint,
} from '../types';

interface TripStore {
  // Active trip data
  activeTrip: Trip | null;
  vehicleLocation: LocationPoint | null;
  previousLocations: LocationPoint[]; // breadcrumb trail
  safetyStatus: SafetyStatus | null;

  // Alerts
  alerts: TripAlert[];
  unacknowledgedCount: number;

  // SOS
  activeSOS: SOSEvent | null;
  sosHistory: SOSEvent[];

  // UI State
  isTracking: boolean;
  isSOSActive: boolean;
  mapFollowsVehicle: boolean;

  // Actions — Trip
  setActiveTrip: (trip: Trip) => void;
  clearActiveTrip: () => void;
  updateTripStatus: (status: TripStatus) => void;
  updateProgress: (update: TripProgressUpdate) => void;
  updateWaypoint: (waypointId: string, visited: boolean) => void;

  // Actions — Vehicle Location
  updateVehicleLocation: (update: VehicleLocationUpdate) => void;
  clearLocationHistory: () => void;

  // Actions — Alerts
  addAlert: (alert: TripAlert) => void;
  acknowledgeAlert: (alertId: string) => void;
  clearAlerts: () => void;
  setSafetyStatus: (status: SafetyStatus) => void;

  // Actions — SOS
  triggerSOS: (event: Omit<SOSEvent, 'id' | 'status' | 'triggeredAt'>) => void;
  cancelSOS: () => void;
  acknowledgeSOS: (respondedBy: string) => void;
  resolveSOS: () => void;

  // Actions — UI
  setTracking: (tracking: boolean) => void;
  setMapFollowsVehicle: (follows: boolean) => void;

  // Demo data for development
  loadDemoTrip: () => void;
}

export const useTripStore = create<TripStore>((set, get) => ({
  activeTrip: null,
  vehicleLocation: null,
  previousLocations: [],
  safetyStatus: null,
  alerts: [],
  unacknowledgedCount: 0,
  activeSOS: null,
  sosHistory: [],
  isTracking: false,
  isSOSActive: false,
  mapFollowsVehicle: true,

  // Trip actions
  setActiveTrip: (trip) => set({ activeTrip: trip, isTracking: true }),

  clearActiveTrip: () =>
    set({
      activeTrip: null,
      vehicleLocation: null,
      previousLocations: [],
      safetyStatus: null,
      alerts: [],
      unacknowledgedCount: 0,
      isTracking: false,
    }),

  updateTripStatus: (status) =>
    set((state) => ({
      activeTrip: state.activeTrip
        ? { ...state.activeTrip, status }
        : null,
    })),

  updateProgress: (update) =>
    set((state) => ({
      activeTrip: state.activeTrip
        ? {
            ...state.activeTrip,
            progress: update.progress,
            distanceRemaining: update.distanceRemaining,
            currentETA: update.currentETA,
          }
        : null,
    })),

  updateWaypoint: (waypointId, visited) =>
    set((state) => ({
      activeTrip: state.activeTrip
        ? {
            ...state.activeTrip,
            waypoints: state.activeTrip.waypoints.map((wp) =>
              wp.id === waypointId
                ? { ...wp, visited, actualArrival: visited ? new Date().toISOString() : undefined }
                : wp
            ),
          }
        : null,
    })),

  // Vehicle location
  updateVehicleLocation: (update) =>
    set((state) => {
      const newLocations = state.vehicleLocation
        ? [...state.previousLocations, state.vehicleLocation].slice(-100) // keep last 100 points
        : state.previousLocations;

      return {
        vehicleLocation: update.location,
        previousLocations: newLocations,
      };
    }),

  clearLocationHistory: () =>
    set({ previousLocations: [], vehicleLocation: null }),

  // Alerts
  addAlert: (alert) =>
    set((state) => ({
      alerts: [alert, ...state.alerts].slice(0, 50), // max 50 alerts
      unacknowledgedCount: state.unacknowledgedCount + 1,
    })),

  acknowledgeAlert: (alertId) =>
    set((state) => ({
      alerts: state.alerts.map((a) =>
        a.id === alertId ? { ...a, acknowledged: true } : a
      ),
      unacknowledgedCount: Math.max(0, state.unacknowledgedCount - 1),
    })),

  clearAlerts: () => set({ alerts: [], unacknowledgedCount: 0 }),

  setSafetyStatus: (status) => set({ safetyStatus: status }),

  // SOS
  triggerSOS: (eventData) => {
    const event: SOSEvent = {
      ...eventData,
      id: `sos-${Date.now()}`,
      status: SOSStatus.TRIGGERED,
      triggeredAt: new Date().toISOString(),
    };
    set({ activeSOS: event, isSOSActive: true });
  },

  cancelSOS: () =>
    set((state) => {
      if (state.activeSOS) {
        return {
          sosHistory: [
            { ...state.activeSOS, status: SOSStatus.CANCELLED },
            ...state.sosHistory,
          ],
          activeSOS: null,
          isSOSActive: false,
        };
      }
      return {};
    }),

  acknowledgeSOS: (respondedBy) =>
    set((state) => ({
      activeSOS: state.activeSOS
        ? {
            ...state.activeSOS,
            status: SOSStatus.ACKNOWLEDGED,
            acknowledgedAt: new Date().toISOString(),
            respondedBy,
          }
        : null,
    })),

  resolveSOS: () =>
    set((state) => {
      if (state.activeSOS) {
        return {
          sosHistory: [
            {
              ...state.activeSOS,
              status: SOSStatus.RESOLVED,
              resolvedAt: new Date().toISOString(),
            },
            ...state.sosHistory,
          ],
          activeSOS: null,
          isSOSActive: false,
        };
      }
      return {};
    }),

  // UI
  setTracking: (tracking) => set({ isTracking: tracking }),
  setMapFollowsVehicle: (follows) => set({ mapFollowsVehicle: follows }),

  // Demo data
  loadDemoTrip: () => {
    const demoTrip: Trip = {
      id: 'demo-trip-1',
      packageId: 'pkg-1',
      packageName: 'Sigiriya & Dambulla Heritage Tour',
      touristIds: ['demo-tourist-1'],
      driverId: 'demo-driver-1',
      guideId: 'demo-guide-1',
      vehicleInfo: {
        plateNumber: 'WP-CAB-1234',
        type: 'van',
        model: 'Toyota HiAce',
        color: 'White',
      },
      plannedRoute: [
        { latitude: 7.2906, longitude: 80.6337, timestamp: new Date().toISOString() },
        { latitude: 7.4675, longitude: 80.5236, timestamp: new Date().toISOString() },
        { latitude: 7.6101, longitude: 80.5550, timestamp: new Date().toISOString() },
        { latitude: 7.9570, longitude: 80.7603, timestamp: new Date().toISOString() },
      ],
      waypoints: [
        {
          id: 'wp-1',
          name: 'Kandy City Hotel',
          location: { latitude: 7.2906, longitude: 80.6337, timestamp: new Date().toISOString() },
          type: 'pickup',
          estimatedArrival: new Date().toISOString(),
          duration: 10,
          visited: true,
        },
        {
          id: 'wp-2',
          name: 'Dambulla Cave Temple',
          location: { latitude: 7.8568, longitude: 80.6498, timestamp: new Date().toISOString() },
          type: 'attraction',
          estimatedArrival: new Date(Date.now() + 2 * 3600000).toISOString(),
          duration: 90,
          visited: false,
        },
        {
          id: 'wp-3',
          name: 'Sigiriya Rock Fortress',
          location: { latitude: 7.9570, longitude: 80.7603, timestamp: new Date().toISOString() },
          type: 'attraction',
          estimatedArrival: new Date(Date.now() + 5 * 3600000).toISOString(),
          duration: 180,
          visited: false,
        },
      ],
      status: TripStatus.ACTIVE,
      startTime: new Date(Date.now() - 3600000).toISOString(),
      estimatedEndTime: new Date(Date.now() + 6 * 3600000).toISOString(),
      progress: 35,
      distanceTotal: 120,
      distanceRemaining: 78,
      currentETA: new Date(Date.now() + 2.5 * 3600000).toISOString(),
    };

    set({
      activeTrip: demoTrip,
      isTracking: true,
      vehicleLocation: {
        latitude: 7.4675,
        longitude: 80.5236,
        speed: 56,
        heading: 45,
        timestamp: new Date().toISOString(),
      },
      safetyStatus: {
        tripId: 'demo-trip-1',
        overallStatus: AlertSeverity.SAFE,
        activeAlerts: 0,
        lastChecked: new Date().toISOString(),
      },
    });
  },
}));

// CeylonTourMate — Trip & Live Monitoring Types

export interface LocationPoint {
  latitude: number;
  longitude: number;
  speed?: number; // km/h
  heading?: number; // degrees
  timestamp: string;
  accuracy?: number;
}

export enum TripStatus {
  SCHEDULED = 'scheduled',
  ACTIVE = 'active',
  PAUSED = 'paused',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
  EMERGENCY = 'emergency',
}

export interface Trip {
  id: string;
  packageId: string;
  packageName: string;
  touristIds: string[];
  driverId: string;
  guideId: string;
  vehicleInfo: VehicleInfo;
  plannedRoute: LocationPoint[];
  waypoints: Waypoint[];
  status: TripStatus;
  startTime: string;
  estimatedEndTime: string;
  actualEndTime?: string;
  progress: number; // 0-100
  distanceTotal: number; // km
  distanceRemaining: number; // km
  currentETA: string;
}

export interface VehicleInfo {
  plateNumber: string;
  type: 'car' | 'van' | 'bus' | 'tuk-tuk';
  model: string;
  color: string;
}

export interface Waypoint {
  id: string;
  name: string;
  location: LocationPoint;
  type: 'pickup' | 'dropoff' | 'attraction' | 'rest' | 'meal';
  estimatedArrival: string;
  actualArrival?: string;
  duration: number; // minutes
  visited: boolean;
}

// Alert System
export enum AlertSeverity {
  SAFE = 'safe',
  WARNING = 'warning',
  DANGER = 'danger',
}

export enum AlertType {
  ROUTE_DEVIATION = 'route_deviation',
  SPEED_ANOMALY = 'speed_anomaly',
  HARSH_BRAKING = 'harsh_braking',
  UNAUTHORIZED_STOP = 'unauthorized_stop',
  GEOFENCE_BREACH = 'geofence_breach',
  VEHICLE_STOPPED = 'vehicle_stopped',
  TRIP_DELAYED = 'trip_delayed',
  WEATHER_WARNING = 'weather_warning',
}

export interface TripAlert {
  id: string;
  tripId: string;
  type: AlertType;
  severity: AlertSeverity;
  title: string;
  message: string;
  coordinates: LocationPoint;
  timestamp: string;
  resolvedAt?: string;
  acknowledged: boolean;
}

// SOS
export enum SOSStatus {
  TRIGGERED = 'triggered',
  ACKNOWLEDGED = 'acknowledged',
  RESPONDING = 'responding',
  RESOLVED = 'resolved',
  CANCELLED = 'cancelled',
}

export interface SOSEvent {
  id: string;
  tripId: string;
  touristId: string;
  touristName: string;
  location: LocationPoint;
  message?: string;
  status: SOSStatus;
  triggeredAt: string;
  acknowledgedAt?: string;
  resolvedAt?: string;
  respondedBy?: string;
}

// Socket Events
export interface VehicleLocationUpdate {
  tripId: string;
  driverId: string;
  location: LocationPoint;
}

export interface TripProgressUpdate {
  tripId: string;
  progress: number;
  distanceRemaining: number;
  currentETA: string;
  currentSpeed: number;
}

export interface SafetyStatus {
  tripId: string;
  overallStatus: AlertSeverity;
  activeAlerts: number;
  lastChecked: string;
}

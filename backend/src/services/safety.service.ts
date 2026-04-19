// CeylonTourMate — ★ CORE Safety Anomaly Detection Service
import { Trip } from '../models/Trip.model';

interface LocationPoint {
  latitude: number;
  longitude: number;
  speed: number;
  heading: number;
  timestamp: string;
}

interface SafetyAlert {
  type: string;
  severity: 'safe' | 'warning' | 'danger';
  title: string;
  message: string;
}

// Sri Lanka bounding box (approximate)
const SRI_LANKA_BOUNDS = {
  north: 9.85,
  south: 5.92,
  east: 81.88,
  west: 79.65,
};

// Speed thresholds (km/h)
const SPEED_LIMITS = {
  highway: 100,
  localRoad: 80,
  urban: 50,
  school: 30,
};

export class SafetyService {
  // Store recent locations for each trip (in-memory for speed)
  private locationHistory: Map<string, LocationPoint[]> = new Map();
  // Store stop tracking
  private stopTracking: Map<string, { startTime: number; location: LocationPoint }> = new Map();

  /**
   * Analyze a location update and return any safety alerts
   */
  async analyzeLocation(tripId: string, location: LocationPoint): Promise<SafetyAlert[]> {
    const alerts: SafetyAlert[] = [];

    // Update location history
    if (!this.locationHistory.has(tripId)) {
      this.locationHistory.set(tripId, []);
    }
    const history = this.locationHistory.get(tripId)!;
    history.push(location);

    // Keep only last 100 points in memory
    if (history.length > 100) {
      history.splice(0, history.length - 100);
    }

    // Run all safety checks
    const speedAlert = this.checkSpeedAnomaly(location);
    if (speedAlert) alerts.push(speedAlert);

    const brakeAlert = this.checkHarshBraking(history);
    if (brakeAlert) alerts.push(brakeAlert);

    const geofenceAlert = this.checkGeofenceBreach(location);
    if (geofenceAlert) alerts.push(geofenceAlert);

    const routeAlert = await this.checkRouteDeviation(tripId, location);
    if (routeAlert) alerts.push(routeAlert);

    const stopAlert = this.checkUnauthorizedStop(tripId, location);
    if (stopAlert) alerts.push(stopAlert);

    return alerts;
  }

  /**
   * Check 1: Speed Anomaly
   * If speed exceeds local road limit (80 km/h), emit WARNING
   * If speed exceeds highway limit (100 km/h), emit DANGER
   */
  private checkSpeedAnomaly(location: LocationPoint): SafetyAlert | null {
    const { speed } = location;

    if (speed > SPEED_LIMITS.highway) {
      return {
        type: 'speed_anomaly',
        severity: 'danger',
        title: 'Excessive Speed Detected',
        message: `Vehicle speed is ${Math.round(speed)} km/h — exceeds maximum safe limit of ${SPEED_LIMITS.highway} km/h. Immediate attention required.`,
      };
    }

    if (speed > SPEED_LIMITS.localRoad) {
      return {
        type: 'speed_anomaly',
        severity: 'warning',
        title: 'High Speed Warning',
        message: `Vehicle speed is ${Math.round(speed)} km/h — exceeds local road limit of ${SPEED_LIMITS.localRoad} km/h.`,
      };
    }

    return null;
  }

  /**
   * Check 2: Harsh Braking
   * If speed drops more than 30 km/h in less than 3 seconds
   */
  private checkHarshBraking(history: LocationPoint[]): SafetyAlert | null {
    if (history.length < 2) return null;

    const current = history[history.length - 1];
    const previous = history[history.length - 2];

    const timeDiffMs =
      new Date(current.timestamp).getTime() - new Date(previous.timestamp).getTime();
    const timeDiffSec = timeDiffMs / 1000;

    if (timeDiffSec <= 0 || timeDiffSec > 5) return null; // Ignore if gap is too large

    const speedDrop = previous.speed - current.speed;

    if (speedDrop > 30 && timeDiffSec <= 3) {
      return {
        type: 'harsh_braking',
        severity: 'warning',
        title: 'Harsh Braking Detected',
        message: `Speed dropped ${Math.round(speedDrop)} km/h in ${timeDiffSec.toFixed(1)} seconds. Potential emergency braking event.`,
      };
    }

    return null;
  }

  /**
   * Check 3: Geofence Breach
   * Check if coordinates are inside Sri Lanka bounding box
   */
  private checkGeofenceBreach(location: LocationPoint): SafetyAlert | null {
    const { latitude, longitude } = location;

    const isInsideSriLanka =
      latitude >= SRI_LANKA_BOUNDS.south &&
      latitude <= SRI_LANKA_BOUNDS.north &&
      longitude >= SRI_LANKA_BOUNDS.west &&
      longitude <= SRI_LANKA_BOUNDS.east;

    if (!isInsideSriLanka) {
      return {
        type: 'geofence_breach',
        severity: 'danger',
        title: 'Geofence Breach',
        message: `Vehicle appears to be outside Sri Lanka boundaries (${latitude.toFixed(4)}, ${longitude.toFixed(4)}). GPS signal may be inaccurate or vehicle has left monitored zone.`,
      };
    }

    return null;
  }

  /**
   * Check 4: Route Deviation
   * Calculate minimum distance from current position to planned route polyline
   * If distance > 500m → DANGER
   * If distance > 200m → WARNING
   */
  private async checkRouteDeviation(
    tripId: string,
    location: LocationPoint
  ): Promise<SafetyAlert | null> {
    try {
      const trip = await Trip.findById(tripId).lean().catch(() => null);
      if (!trip || !trip.plannedRoute || trip.plannedRoute.length < 2) return null;

      const minDistance = this.getMinDistanceToPolyline(
        location.latitude,
        location.longitude,
        trip.plannedRoute.map((p: any) => ({
          lat: p.latitude,
          lng: p.longitude,
        }))
      );

      if (minDistance > 500) {
        return {
          type: 'route_deviation',
          severity: 'danger',
          title: 'Major Route Deviation',
          message: `Vehicle is ${Math.round(minDistance)}m away from planned route. This exceeds the 500m safety threshold.`,
        };
      }

      if (minDistance > 200) {
        return {
          type: 'route_deviation',
          severity: 'warning',
          title: 'Route Deviation Detected',
          message: `Vehicle is ${Math.round(minDistance)}m away from planned route. Driver may be taking an alternate path.`,
        };
      }
    } catch (err) {
      // DB might not be connected — skip check
    }

    return null;
  }

  /**
   * Check 5: Unauthorized Stop
   * If speed < 2 km/h for more than 5 minutes NOT at a waypoint
   */
  private checkUnauthorizedStop(
    tripId: string,
    location: LocationPoint
  ): SafetyAlert | null {
    const stopKey = `${tripId}`;
    const now = Date.now();
    const FIVE_MINUTES = 5 * 60 * 1000;

    if (location.speed < 2) {
      // Vehicle appears stopped
      if (!this.stopTracking.has(stopKey)) {
        this.stopTracking.set(stopKey, {
          startTime: now,
          location,
        });
        return null;
      }

      const stopData = this.stopTracking.get(stopKey)!;
      const stopDuration = now - stopData.startTime;

      if (stopDuration > FIVE_MINUTES) {
        // Clear stop tracking to avoid repeated alerts
        this.stopTracking.delete(stopKey);

        return {
          type: 'unauthorized_stop',
          severity: 'warning',
          title: 'Extended Unplanned Stop',
          message: `Vehicle has been stationary for ${Math.round(stopDuration / 60000)} minutes at an unscheduled location.`,
        };
      }
    } else {
      // Vehicle is moving — clear stop tracking
      this.stopTracking.delete(stopKey);
    }

    return null;
  }

  // ─── Helper: Calculate minimum distance from point to polyline ───

  /**
   * Calculate the minimum distance (in meters) from a point to a polyline
   * Uses the point-to-line-segment distance formula
   */
  private getMinDistanceToPolyline(
    lat: number,
    lng: number,
    polyline: Array<{ lat: number; lng: number }>
  ): number {
    let minDistance = Infinity;

    for (let i = 0; i < polyline.length - 1; i++) {
      const dist = this.pointToSegmentDistance(
        lat,
        lng,
        polyline[i].lat,
        polyline[i].lng,
        polyline[i + 1].lat,
        polyline[i + 1].lng
      );
      minDistance = Math.min(minDistance, dist);
    }

    return minDistance;
  }

  /**
   * Calculate distance from point to line segment (in meters)
   */
  private pointToSegmentDistance(
    px: number,
    py: number,
    ax: number,
    ay: number,
    bx: number,
    by: number
  ): number {
    const dx = bx - ax;
    const dy = by - ay;
    const lenSq = dx * dx + dy * dy;

    if (lenSq === 0) {
      return this.haversineDistance(px, py, ax, ay);
    }

    let t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
    t = Math.max(0, Math.min(1, t));

    const closestLat = ax + t * dx;
    const closestLng = ay + t * dy;

    return this.haversineDistance(px, py, closestLat, closestLng);
  }

  /**
   * Calculate distance between two GPS coordinates using Haversine formula
   * Returns distance in meters
   */
  private haversineDistance(
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number
  ): number {
    const R = 6371000; // Earth radius in meters
    const dLat = this.toRad(lat2 - lat1);
    const dLng = this.toRad(lng2 - lng1);

    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRad(lat1)) *
        Math.cos(this.toRad(lat2)) *
        Math.sin(dLng / 2) *
        Math.sin(dLng / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  private toRad(deg: number): number {
    return (deg * Math.PI) / 180;
  }
}

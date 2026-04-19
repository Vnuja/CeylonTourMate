// CeylonTourMate — ★ CORE Live Monitor Screen
import React, { useEffect, useCallback, useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Dimensions,
  ScrollView,
  Animated,
  RefreshControl,
  StatusBar,
  Platform,
} from 'react-native';
import MapView, { Marker, Polyline, PROVIDER_GOOGLE } from 'react-native-maps';
import { useTripStore, useLocationStore, useAuthStore } from '../../store';
import { socketManager } from '../../services/socket';
import { AlertSeverity, TripStatus } from '../../types';
import { Colors, Spacing, Typography, Layout, BorderRadius } from '../../theme';

// Components
import { VehicleMarker } from '../../components/live/VehicleMarker';
import { AlertCard } from '../../components/live/AlertCard';
import { SOSButton } from '../../components/live/SOSButton';
import { StatsRow } from '../../components/live/StatsRow';
import { SpeedChip } from '../../components/live/SpeedChip';
import { ETAChip } from '../../components/live/ETAChip';
import { TripHeader } from '../../components/live/TripHeader';
import { NoTripView } from '../../components/live/NoTripView';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const MAP_HEIGHT = SCREEN_HEIGHT * Layout.mapHeightRatio;

export const LiveMonitorScreen: React.FC = () => {
  const mapRef = useRef<MapView>(null);
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const [refreshing, setRefreshing] = useState(false);

  // Store state
  const activeTrip = useTripStore((s) => s.activeTrip);
  const vehicleLocation = useTripStore((s) => s.vehicleLocation);
  const previousLocations = useTripStore((s) => s.previousLocations);
  const alerts = useTripStore((s) => s.alerts);
  const safetyStatus = useTripStore((s) => s.safetyStatus);
  const isTracking = useTripStore((s) => s.isTracking);
  const mapFollowsVehicle = useTripStore((s) => s.mapFollowsVehicle);
  const loadDemoTrip = useTripStore((s) => s.loadDemoTrip);
  const user = useAuthStore((s) => s.user);

  // Initialize — connect socket and load demo data
  useEffect(() => {
    // Fade in animation
    Animated.timing(fadeAnim, {
      toValue: 1,
      duration: 600,
      useNativeDriver: true,
    }).start();

    // Load demo trip for development
    if (!activeTrip) {
      loadDemoTrip();
    }

    // Connect socket
    socketManager.connect();

    return () => {
      // Cleanup on unmount
    };
  }, []);

  // Join trip room when active trip changes
  useEffect(() => {
    if (activeTrip?.id) {
      socketManager.joinTrip(activeTrip.id);
    }
    return () => {
      if (activeTrip?.id) {
        socketManager.leaveTrip(activeTrip.id);
      }
    };
  }, [activeTrip?.id]);

  // Animate map to vehicle position
  useEffect(() => {
    if (vehicleLocation && mapFollowsVehicle && mapRef.current) {
      mapRef.current.animateToRegion(
        {
          latitude: vehicleLocation.latitude,
          longitude: vehicleLocation.longitude,
          latitudeDelta: 0.02,
          longitudeDelta: 0.02,
        },
        800
      );
    }
  }, [vehicleLocation, mapFollowsVehicle]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadDemoTrip();
    setTimeout(() => setRefreshing(false), 1000);
  }, []);

  // Determine overall status color
  const getStatusColor = () => {
    if (!safetyStatus) return Colors.status.safe;
    switch (safetyStatus.overallStatus) {
      case AlertSeverity.DANGER:
        return Colors.status.danger;
      case AlertSeverity.WARNING:
        return Colors.status.warning;
      default:
        return Colors.status.safe;
    }
  };

  // No active trip view
  if (!activeTrip) {
    return <NoTripView />;
  }

  return (
    <Animated.View style={[styles.container, { opacity: fadeAnim }]}>
      <StatusBar barStyle="light-content" backgroundColor={Colors.background.primary} />

      {/* Trip Header */}
      <TripHeader
        tripName={activeTrip.packageName}
        status={activeTrip.status}
        vehicleInfo={activeTrip.vehicleInfo}
      />

      {/* Map Section — 55% of screen */}
      <View style={styles.mapContainer}>
        <MapView
          ref={mapRef}
          style={styles.map}
          provider={PROVIDER_GOOGLE}
          initialRegion={{
            latitude: vehicleLocation?.latitude || 7.8731,
            longitude: vehicleLocation?.longitude || 80.7718,
            latitudeDelta: 0.05,
            longitudeDelta: 0.05,
          }}
          customMapStyle={darkMapStyle}
          showsUserLocation={true}
          showsMyLocationButton={false}
          showsCompass={false}
          rotateEnabled={true}
          pitchEnabled={true}
        >
          {/* Planned Route — Blue dashed line */}
          {activeTrip.plannedRoute.length > 1 && (
            <Polyline
              coordinates={activeTrip.plannedRoute.map((p) => ({
                latitude: p.latitude,
                longitude: p.longitude,
              }))}
              strokeColor="rgba(91, 155, 213, 0.6)"
              strokeWidth={4}
              lineDashPattern={[10, 8]}
            />
          )}

          {/* Actual Path Taken — Green solid line */}
          {previousLocations.length > 1 && (
            <Polyline
              coordinates={previousLocations.map((p) => ({
                latitude: p.latitude,
                longitude: p.longitude,
              }))}
              strokeColor={Colors.primary.green}
              strokeWidth={4}
            />
          )}

          {/* Vehicle Marker */}
          {vehicleLocation && (
            <VehicleMarker
              coordinate={{
                latitude: vehicleLocation.latitude,
                longitude: vehicleLocation.longitude,
              }}
              heading={vehicleLocation.heading || 0}
              vehicleType={activeTrip.vehicleInfo.type}
            />
          )}

          {/* Waypoint Markers */}
          {activeTrip.waypoints.map((wp) => (
            <Marker
              key={wp.id}
              coordinate={{
                latitude: wp.location.latitude,
                longitude: wp.location.longitude,
              }}
              title={wp.name}
              description={wp.visited ? '✅ Visited' : `ETA: ${new Date(wp.estimatedArrival).toLocaleTimeString()}`}
            >
              <View style={[styles.waypointMarker, wp.visited && styles.waypointVisited]}>
                <Text style={styles.waypointEmoji}>
                  {wp.type === 'pickup' ? '📍' : wp.type === 'attraction' ? '🏛️' : wp.type === 'meal' ? '🍽️' : '📌'}
                </Text>
              </View>
            </Marker>
          ))}
        </MapView>

        {/* Floating Speed Chip */}
        <SpeedChip
          speed={vehicleLocation?.speed || 0}
          safetyColor={getStatusColor()}
        />

        {/* Floating ETA Chip */}
        <ETAChip eta={activeTrip.currentETA} />

        {/* Connection indicator */}
        <View style={styles.connectionBadge}>
          <View style={[styles.connectionDot, { backgroundColor: socketManager.isConnected() ? Colors.status.safe : Colors.status.danger }]} />
          <Text style={styles.connectionText}>
            {socketManager.isConnected() ? 'LIVE' : 'OFFLINE'}
          </Text>
        </View>
      </View>

      {/* Bottom Section — Stats + Alerts + SOS */}
      <ScrollView
        style={styles.bottomSection}
        contentContainerStyle={styles.bottomContent}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={onRefresh}
            tintColor={Colors.primary.green}
            colors={[Colors.primary.green]}
          />
        }
      >
        {/* Stats Row */}
        <StatsRow
          progress={activeTrip.progress}
          distanceRemaining={activeTrip.distanceRemaining}
          safetyStatus={safetyStatus?.overallStatus || AlertSeverity.SAFE}
          statusColor={getStatusColor()}
        />

        {/* Alert Feed */}
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Activity Feed</Text>
          <View style={styles.alertBadge}>
            <Text style={styles.alertBadgeText}>{alerts.length}</Text>
          </View>
        </View>

        {alerts.length > 0 ? (
          alerts.slice(0, 10).map((alert, index) => (
            <AlertCard
              key={alert.id}
              alert={alert}
              index={index}
              onAcknowledge={() =>
                useTripStore.getState().acknowledgeAlert(alert.id)
              }
            />
          ))
        ) : (
          <View style={styles.emptyAlerts}>
            <Text style={styles.emptyAlertsEmoji}>✅</Text>
            <Text style={styles.emptyAlertsText}>All systems normal</Text>
            <Text style={styles.emptyAlertsSubtext}>
              No alerts — your trip is on track
            </Text>
          </View>
        )}

        {/* SOS spacer */}
        <View style={{ height: 100 }} />
      </ScrollView>

      {/* SOS Button — Fixed at bottom */}
      <SOSButton
        tripId={activeTrip.id}
        touristId={user?.id || 'unknown'}
        currentLocation={vehicleLocation}
      />
    </Animated.View>
  );
};

// Google Maps dark theme style
const darkMapStyle = [
  { elementType: "geometry", stylers: [{ color: "#1d2c4d" }] },
  { elementType: "labels.text.fill", stylers: [{ color: "#8ec3b9" }] },
  { elementType: "labels.text.stroke", stylers: [{ color: "#1a3646" }] },
  { featureType: "water", elementType: "geometry.fill", stylers: [{ color: "#0e1626" }] },
  { featureType: "road", elementType: "geometry", stylers: [{ color: "#304a7d" }] },
  { featureType: "road", elementType: "geometry.stroke", stylers: [{ color: "#1f2835" }] },
  { featureType: "road.highway", elementType: "geometry", stylers: [{ color: "#2c6675" }] },
  { featureType: "poi", elementType: "geometry", stylers: [{ color: "#283d6a" }] },
  { featureType: "transit", elementType: "geometry", stylers: [{ color: "#2f3948" }] },
  { featureType: "landscape", elementType: "geometry", stylers: [{ color: "#1a2138" }] },
];

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background.primary,
  },
  mapContainer: {
    height: MAP_HEIGHT,
    width: SCREEN_WIDTH,
    position: 'relative',
  },
  map: {
    ...StyleSheet.absoluteFillObject,
  },
  waypointMarker: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.background.card,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: Colors.primary.gold,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 5,
  },
  waypointVisited: {
    borderColor: Colors.status.safe,
    opacity: 0.7,
  },
  waypointEmoji: {
    fontSize: 16,
  },
  connectionBadge: {
    position: 'absolute',
    top: Platform.OS === 'ios' ? 50 : 10,
    right: 12,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(13, 17, 23, 0.85)',
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: BorderRadius.full,
    gap: 6,
  },
  connectionDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  connectionText: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.bold,
    letterSpacing: 1,
  },
  bottomSection: {
    flex: 1,
    backgroundColor: Colors.background.primary,
  },
  bottomContent: {
    padding: Spacing.lg,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: Spacing.xl,
    marginBottom: Spacing.md,
  },
  sectionTitle: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.semiBold,
  },
  alertBadge: {
    backgroundColor: Colors.background.tertiary,
    paddingHorizontal: 10,
    paddingVertical: 3,
    borderRadius: BorderRadius.full,
  },
  alertBadgeText: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.sm,
    fontWeight: Typography.fontWeight.medium,
  },
  emptyAlerts: {
    alignItems: 'center',
    paddingVertical: Spacing['3xl'],
    backgroundColor: Colors.background.card,
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
    borderColor: Colors.border.subtle,
  },
  emptyAlertsEmoji: {
    fontSize: 36,
    marginBottom: Spacing.md,
  },
  emptyAlertsText: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.semiBold,
    marginBottom: Spacing.xs,
  },
  emptyAlertsSubtext: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.md,
  },
});

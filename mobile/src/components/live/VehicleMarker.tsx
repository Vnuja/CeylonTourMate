// CeylonTourMate — Animated Vehicle Marker Component
import React, { useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Animated as RNAnimated } from 'react-native';
import { Marker } from 'react-native-maps';
import { Colors } from '../../theme';

interface VehicleMarkerProps {
  coordinate: { latitude: number; longitude: number };
  heading: number;
  vehicleType: 'car' | 'van' | 'bus' | 'tuk-tuk';
}

const vehicleEmojis: Record<string, string> = {
  car: '🚗',
  van: '🚐',
  bus: '🚌',
  'tuk-tuk': '🛺',
};

export const VehicleMarker: React.FC<VehicleMarkerProps> = ({
  coordinate,
  heading,
  vehicleType,
}) => {
  const pulseAnim = useRef(new RNAnimated.Value(1)).current;

  useEffect(() => {
    const pulse = RNAnimated.loop(
      RNAnimated.sequence([
        RNAnimated.timing(pulseAnim, {
          toValue: 1.3,
          duration: 1200,
          useNativeDriver: true,
        }),
        RNAnimated.timing(pulseAnim, {
          toValue: 1,
          duration: 1200,
          useNativeDriver: true,
        }),
      ])
    );
    pulse.start();
    return () => pulse.stop();
  }, []);

  return (
    <Marker
      coordinate={coordinate}
      anchor={{ x: 0.5, y: 0.5 }}
      flat={true}
      rotation={heading}
    >
      <View style={styles.container}>
        {/* Pulse ring */}
        <RNAnimated.View
          style={[
            styles.pulseRing,
            {
              transform: [{ scale: pulseAnim }],
              opacity: pulseAnim.interpolate({
                inputRange: [1, 1.3],
                outputRange: [0.4, 0],
              }),
            },
          ]}
        />
        {/* Vehicle icon */}
        <View style={styles.markerBody}>
          <Text style={styles.vehicleEmoji}>{vehicleEmojis[vehicleType] || '🚗'}</Text>
        </View>
        {/* Direction indicator */}
        <View style={styles.directionArrow}>
          <View style={styles.arrowInner} />
        </View>
      </View>
    </Marker>
  );
};

const styles = StyleSheet.create({
  container: {
    width: 60,
    height: 60,
    justifyContent: 'center',
    alignItems: 'center',
  },
  pulseRing: {
    position: 'absolute',
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: Colors.primary.green,
  },
  markerBody: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: Colors.background.card,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 3,
    borderColor: Colors.primary.green,
    shadowColor: Colors.primary.green,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.5,
    shadowRadius: 8,
    elevation: 8,
  },
  vehicleEmoji: {
    fontSize: 24,
  },
  directionArrow: {
    position: 'absolute',
    top: -4,
    width: 0,
    height: 0,
    borderLeftWidth: 6,
    borderRightWidth: 6,
    borderBottomWidth: 10,
    borderLeftColor: 'transparent',
    borderRightColor: 'transparent',
    borderBottomColor: Colors.primary.green,
  },
  arrowInner: {
    position: 'absolute',
    top: 3,
    left: -3,
    width: 0,
    height: 0,
    borderLeftWidth: 3,
    borderRightWidth: 3,
    borderBottomWidth: 6,
    borderLeftColor: 'transparent',
    borderRightColor: 'transparent',
    borderBottomColor: Colors.background.card,
  },
});

// CeylonTourMate — Speed Chip (floating on map)
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Typography, BorderRadius, Spacing } from '../../theme';

interface SpeedChipProps {
  speed: number;
  safetyColor: string;
}

export const SpeedChip: React.FC<SpeedChipProps> = ({ speed, safetyColor }) => {
  return (
    <View style={styles.container}>
      <View style={[styles.dot, { backgroundColor: safetyColor }]} />
      <Text style={styles.speed}>{Math.round(speed)}</Text>
      <Text style={styles.unit}>km/h</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    bottom: 16,
    left: 16,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(13, 17, 23, 0.9)',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: BorderRadius.full,
    gap: 6,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 5,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  speed: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.bold,
  },
  unit: {
    color: Colors.text.tertiary,
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.medium,
  },
});

// CeylonTourMate — Trip Header Component
import React from 'react';
import { View, Text, StyleSheet, Platform } from 'react-native';
import { TripStatus, VehicleInfo } from '../../types';
import { Colors, Spacing, Typography, BorderRadius } from '../../theme';

interface TripHeaderProps {
  tripName: string;
  status: TripStatus;
  vehicleInfo: VehicleInfo;
}

const statusConfig: Record<TripStatus, { label: string; color: string; emoji: string }> = {
  [TripStatus.ACTIVE]: { label: 'ACTIVE', color: Colors.status.safe, emoji: '🟢' },
  [TripStatus.SCHEDULED]: { label: 'SCHEDULED', color: Colors.status.info, emoji: '📅' },
  [TripStatus.PAUSED]: { label: 'PAUSED', color: Colors.status.warning, emoji: '⏸️' },
  [TripStatus.COMPLETED]: { label: 'COMPLETED', color: Colors.text.tertiary, emoji: '✅' },
  [TripStatus.CANCELLED]: { label: 'CANCELLED', color: Colors.status.danger, emoji: '❌' },
  [TripStatus.EMERGENCY]: { label: 'EMERGENCY', color: Colors.status.danger, emoji: '🆘' },
};

export const TripHeader: React.FC<TripHeaderProps> = ({
  tripName,
  status,
  vehicleInfo,
}) => {
  const config = statusConfig[status];

  return (
    <View style={styles.container}>
      <View style={styles.content}>
        <View style={styles.titleRow}>
          <Text style={styles.tripName} numberOfLines={1}>
            {tripName}
          </Text>
          <View style={[styles.statusBadge, { backgroundColor: config.color + '22' }]}>
            <Text style={styles.statusEmoji}>{config.emoji}</Text>
            <Text style={[styles.statusText, { color: config.color }]}>{config.label}</Text>
          </View>
        </View>

        <View style={styles.vehicleRow}>
          <Text style={styles.vehicleInfo}>
            🚐 {vehicleInfo.model} • {vehicleInfo.plateNumber} • {vehicleInfo.color}
          </Text>
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: Colors.background.secondary,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border.subtle,
    paddingTop: Platform.OS === 'ios' ? 54 : 30,
  },
  content: {
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
  },
  titleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: Spacing.sm,
  },
  tripName: {
    flex: 1,
    color: Colors.text.primary,
    fontSize: Typography.fontSize.xl,
    fontWeight: Typography.fontWeight.bold,
  },
  statusBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: BorderRadius.full,
    gap: 4,
  },
  statusEmoji: {
    fontSize: 10,
  },
  statusText: {
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.bold,
    letterSpacing: 0.5,
  },
  vehicleRow: {
    marginTop: Spacing.xs,
  },
  vehicleInfo: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.sm,
  },
});

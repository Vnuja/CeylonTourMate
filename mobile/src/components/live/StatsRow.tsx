// CeylonTourMate — Stats Row Component (Progress, Distance, Safety)
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { AlertSeverity } from '../../types';
import { Colors, Spacing, Typography, BorderRadius } from '../../theme';

interface StatsRowProps {
  progress: number;
  distanceRemaining: number;
  safetyStatus: AlertSeverity;
  statusColor: string;
}

export const StatsRow: React.FC<StatsRowProps> = ({
  progress,
  distanceRemaining,
  safetyStatus,
  statusColor,
}) => {
  const safetyLabel =
    safetyStatus === AlertSeverity.DANGER
      ? 'AT RISK'
      : safetyStatus === AlertSeverity.WARNING
      ? 'CAUTION'
      : 'ALL CLEAR';

  return (
    <View style={styles.container}>
      {/* Progress Card */}
      <View style={styles.card}>
        <Text style={styles.cardLabel}>Progress</Text>
        <Text style={styles.cardValue}>{Math.round(progress)}%</Text>
        <View style={styles.progressBar}>
          <View
            style={[
              styles.progressFill,
              {
                width: `${Math.min(progress, 100)}%`,
                backgroundColor: Colors.primary.green,
              },
            ]}
          />
        </View>
      </View>

      {/* Distance Card */}
      <View style={styles.card}>
        <Text style={styles.cardLabel}>Remaining</Text>
        <Text style={styles.cardValue}>
          {distanceRemaining > 0 ? `${distanceRemaining.toFixed(1)}` : '0'}
        </Text>
        <Text style={styles.cardUnit}>km</Text>
      </View>

      {/* Safety Card */}
      <View style={[styles.card, { borderColor: statusColor + '44' }]}>
        <Text style={styles.cardLabel}>Safety</Text>
        <View style={[styles.statusDot, { backgroundColor: statusColor }]} />
        <Text style={[styles.statusText, { color: statusColor }]}>
          {safetyLabel}
        </Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    gap: Spacing.sm,
  },
  card: {
    flex: 1,
    backgroundColor: Colors.background.card,
    borderRadius: BorderRadius.md,
    padding: Spacing.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: Colors.border.subtle,
  },
  cardLabel: {
    color: Colors.text.tertiary,
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.medium,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: Spacing.xs,
  },
  cardValue: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize['2xl'],
    fontWeight: Typography.fontWeight.bold,
  },
  cardUnit: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.xs,
    marginTop: 2,
  },
  progressBar: {
    width: '100%',
    height: 4,
    backgroundColor: Colors.background.tertiary,
    borderRadius: 2,
    marginTop: Spacing.sm,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 2,
  },
  statusDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginVertical: Spacing.xs,
  },
  statusText: {
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.bold,
    letterSpacing: 0.5,
  },
});

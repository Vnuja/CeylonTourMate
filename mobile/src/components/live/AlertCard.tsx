// CeylonTourMate — Alert Card Component
import React, { useRef, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Animated } from 'react-native';
import { TripAlert, AlertSeverity, AlertType } from '../../types';
import { Colors, Spacing, Typography, BorderRadius } from '../../theme';

interface AlertCardProps {
  alert: TripAlert;
  index: number;
  onAcknowledge: () => void;
}

const alertIcons: Record<AlertType, string> = {
  [AlertType.ROUTE_DEVIATION]: '🔀',
  [AlertType.SPEED_ANOMALY]: '⚡',
  [AlertType.HARSH_BRAKING]: '🛑',
  [AlertType.UNAUTHORIZED_STOP]: '⏸️',
  [AlertType.GEOFENCE_BREACH]: '🚧',
  [AlertType.VEHICLE_STOPPED]: '🅿️',
  [AlertType.TRIP_DELAYED]: '⏰',
  [AlertType.WEATHER_WARNING]: '🌧️',
};

const severityLabels: Record<AlertSeverity, string> = {
  [AlertSeverity.SAFE]: 'SAFE',
  [AlertSeverity.WARNING]: 'WARNING',
  [AlertSeverity.DANGER]: 'DANGER',
};

export const AlertCard: React.FC<AlertCardProps> = ({ alert, index, onAcknowledge }) => {
  const slideAnim = useRef(new Animated.Value(50)).current;
  const opacityAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.parallel([
      Animated.spring(slideAnim, {
        toValue: 0,
        delay: index * 80,
        tension: 80,
        friction: 12,
        useNativeDriver: true,
      }),
      Animated.timing(opacityAnim, {
        toValue: 1,
        delay: index * 80,
        duration: 300,
        useNativeDriver: true,
      }),
    ]).start();
  }, []);

  const severityColors = Colors.alert[alert.severity] || Colors.alert.safe;
  const timeAgo = getTimeAgo(alert.timestamp);

  return (
    <Animated.View
      style={[
        styles.container,
        {
          backgroundColor: severityColors.bg,
          borderLeftColor: severityColors.border,
          transform: [{ translateY: slideAnim }],
          opacity: opacityAnim,
        },
      ]}
    >
      <View style={styles.header}>
        <View style={styles.iconContainer}>
          <Text style={styles.icon}>{alertIcons[alert.type] || '⚠️'}</Text>
        </View>

        <View style={styles.headerText}>
          <Text style={[styles.title, { color: severityColors.text }]}>
            {alert.title}
          </Text>
          <Text style={styles.timestamp}>{timeAgo}</Text>
        </View>

        <View style={[styles.severityBadge, { backgroundColor: severityColors.border + '22' }]}>
          <Text style={[styles.severityText, { color: severityColors.text }]}>
            {severityLabels[alert.severity]}
          </Text>
        </View>
      </View>

      <Text style={styles.message}>{alert.message}</Text>

      {!alert.acknowledged && alert.severity !== AlertSeverity.SAFE && (
        <TouchableOpacity
          style={[styles.actionButton, { borderColor: severityColors.border + '44' }]}
          onPress={onAcknowledge}
          activeOpacity={0.7}
        >
          <Text style={[styles.actionText, { color: severityColors.text }]}>
            Acknowledge
          </Text>
        </TouchableOpacity>
      )}

      {alert.acknowledged && (
        <View style={styles.acknowledgedBadge}>
          <Text style={styles.acknowledgedText}>✓ Acknowledged</Text>
        </View>
      )}
    </Animated.View>
  );
};

function getTimeAgo(timestamp: string): string {
  const now = new Date();
  const then = new Date(timestamp);
  const diffMs = now.getTime() - then.getTime();
  const diffMins = Math.floor(diffMs / 60000);

  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;

  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24) return `${diffHours}h ago`;

  return then.toLocaleDateString();
}

const styles = StyleSheet.create({
  container: {
    borderRadius: BorderRadius.md,
    borderLeftWidth: 4,
    padding: Spacing.md,
    marginBottom: Spacing.sm,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: Spacing.sm,
  },
  iconContainer: {
    width: 32,
    height: 32,
    borderRadius: 8,
    backgroundColor: 'rgba(255,255,255,0.06)',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: Spacing.sm,
  },
  icon: {
    fontSize: 16,
  },
  headerText: {
    flex: 1,
  },
  title: {
    fontSize: Typography.fontSize.md,
    fontWeight: Typography.fontWeight.semiBold,
  },
  timestamp: {
    fontSize: Typography.fontSize.xs,
    color: Colors.text.tertiary,
    marginTop: 2,
  },
  severityBadge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: BorderRadius.sm,
  },
  severityText: {
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.bold,
    letterSpacing: 0.5,
  },
  message: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.sm,
    lineHeight: Typography.lineHeight.md,
  },
  actionButton: {
    marginTop: Spacing.sm,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.sm,
    borderWidth: 1,
    alignItems: 'center',
  },
  actionText: {
    fontSize: Typography.fontSize.sm,
    fontWeight: Typography.fontWeight.semiBold,
  },
  acknowledgedBadge: {
    marginTop: Spacing.sm,
    alignItems: 'flex-end',
  },
  acknowledgedText: {
    color: Colors.text.tertiary,
    fontSize: Typography.fontSize.xs,
    fontStyle: 'italic',
  },
});

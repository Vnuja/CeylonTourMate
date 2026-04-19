// CeylonTourMate — No Active Trip View
import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { useTripStore } from '../../store';
import { Colors, Spacing, Typography, BorderRadius } from '../../theme';

export const NoTripView: React.FC = () => {
  const loadDemoTrip = useTripStore((s) => s.loadDemoTrip);

  return (
    <View style={styles.container}>
      <Text style={styles.emoji}>📡</Text>
      <Text style={styles.title}>No Active Trip</Text>
      <Text style={styles.subtitle}>
        When your tour begins, you'll see live tracking,{'\n'}
        real-time alerts, and safety monitoring here.
      </Text>

      <View style={styles.featureList}>
        <FeatureItem emoji="🗺️" title="Live GPS Tracking" />
        <FeatureItem emoji="🛡️" title="Safety Monitoring" />
        <FeatureItem emoji="🚨" title="SOS Emergency" />
        <FeatureItem emoji="📊" title="Route Analytics" />
      </View>

      <TouchableOpacity
        style={styles.demoButton}
        onPress={loadDemoTrip}
        activeOpacity={0.8}
      >
        <Text style={styles.demoButtonText}>Load Demo Trip</Text>
        <Text style={styles.demoButtonSubtext}>Try the live monitoring features</Text>
      </TouchableOpacity>
    </View>
  );
};

const FeatureItem: React.FC<{ emoji: string; title: string }> = ({ emoji, title }) => (
  <View style={styles.featureItem}>
    <Text style={styles.featureEmoji}>{emoji}</Text>
    <Text style={styles.featureText}>{title}</Text>
  </View>
);

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background.primary,
    justifyContent: 'center',
    alignItems: 'center',
    padding: Spacing['3xl'],
  },
  emoji: {
    fontSize: 64,
    marginBottom: Spacing.xl,
  },
  title: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize['3xl'],
    fontWeight: Typography.fontWeight.bold,
    marginBottom: Spacing.md,
  },
  subtitle: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.md,
    textAlign: 'center',
    lineHeight: Typography.lineHeight.lg,
    marginBottom: Spacing['3xl'],
  },
  featureList: {
    width: '100%',
    gap: Spacing.md,
    marginBottom: Spacing['3xl'],
  },
  featureItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.background.card,
    padding: Spacing.lg,
    borderRadius: BorderRadius.md,
    borderWidth: 1,
    borderColor: Colors.border.subtle,
    gap: Spacing.md,
  },
  featureEmoji: {
    fontSize: 24,
  },
  featureText: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.medium,
  },
  demoButton: {
    width: '100%',
    backgroundColor: Colors.primary.green,
    paddingVertical: Spacing.lg,
    borderRadius: BorderRadius.lg,
    alignItems: 'center',
    shadowColor: Colors.primary.green,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 5,
  },
  demoButtonText: {
    color: Colors.white,
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.bold,
  },
  demoButtonSubtext: {
    color: 'rgba(255,255,255,0.7)',
    fontSize: Typography.fontSize.sm,
    marginTop: 2,
  },
});

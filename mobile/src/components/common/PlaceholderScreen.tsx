// CeylonTourMate — Reusable Placeholder Screen for future modules
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Spacing, Typography, BorderRadius } from '../../theme';

interface PlaceholderScreenProps {
  emoji: string;
  title: string;
  subtitle: string;
  features: string[];
  accentColor?: string;
}

export const PlaceholderScreen: React.FC<PlaceholderScreenProps> = ({
  emoji,
  title,
  subtitle,
  features,
  accentColor = Colors.primary.green,
}) => {
  return (
    <View style={styles.container}>
      <View style={[styles.emojiCircle, { borderColor: accentColor + '44' }]}>
        <Text style={styles.emoji}>{emoji}</Text>
      </View>

      <Text style={styles.title}>{title}</Text>
      <Text style={styles.subtitle}>{subtitle}</Text>

      <View style={styles.badge}>
        <Text style={[styles.badgeText, { color: accentColor }]}>Coming Soon</Text>
      </View>

      <View style={styles.featuresContainer}>
        <Text style={styles.featuresTitle}>Planned Features</Text>
        {features.map((feature, index) => (
          <View key={index} style={styles.featureRow}>
            <View style={[styles.featureDot, { backgroundColor: accentColor }]} />
            <Text style={styles.featureText}>{feature}</Text>
          </View>
        ))}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background.primary,
    justifyContent: 'center',
    alignItems: 'center',
    padding: Spacing['3xl'],
  },
  emojiCircle: {
    width: 100,
    height: 100,
    borderRadius: 50,
    borderWidth: 2,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: Colors.background.card,
    marginBottom: Spacing.xl,
  },
  emoji: {
    fontSize: 48,
  },
  title: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize['2xl'],
    fontWeight: Typography.fontWeight.bold,
    marginBottom: Spacing.sm,
    textAlign: 'center',
  },
  subtitle: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.md,
    textAlign: 'center',
    lineHeight: Typography.lineHeight.lg,
    marginBottom: Spacing.xl,
  },
  badge: {
    backgroundColor: Colors.background.card,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.full,
    borderWidth: 1,
    borderColor: Colors.border.default,
    marginBottom: Spacing['3xl'],
  },
  badgeText: {
    fontSize: Typography.fontSize.sm,
    fontWeight: Typography.fontWeight.bold,
    letterSpacing: 1.5,
    textTransform: 'uppercase',
  },
  featuresContainer: {
    width: '100%',
    backgroundColor: Colors.background.card,
    borderRadius: BorderRadius.lg,
    padding: Spacing.xl,
    borderWidth: 1,
    borderColor: Colors.border.subtle,
  },
  featuresTitle: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.sm,
    fontWeight: Typography.fontWeight.bold,
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginBottom: Spacing.lg,
  },
  featureRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
    marginBottom: Spacing.md,
  },
  featureDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  featureText: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize.md,
  },
});

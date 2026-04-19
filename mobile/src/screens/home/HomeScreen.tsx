// CeylonTourMate — Home Screen
import React from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity, Platform,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useAuthStore } from '../../store';
import { Colors, Spacing, Typography, BorderRadius } from '../../theme';

const moduleCards = [
  {
    id: 'live',
    emoji: '📡',
    title: 'Live Monitoring',
    subtitle: 'Real-time vehicle tracking & safety',
    color: Colors.status.safe,
    tab: 'Live',
    active: true,
  },
  {
    id: 'tours',
    emoji: '🎒',
    title: 'Smart Packages',
    subtitle: 'AI-powered tour recommendations',
    color: Colors.primary.gold,
    tab: 'Tours',
    active: false,
  },
  {
    id: 'scan',
    emoji: '📸',
    title: 'Image AI',
    subtitle: 'Food recognition & content safety',
    color: Colors.accent.coral,
    tab: 'Scan',
    active: false,
  },
  {
    id: 'places',
    emoji: '🏛️',
    title: 'Place Lens',
    subtitle: 'Sri Lankan landmark identification',
    color: Colors.accent.indigo,
    tab: 'Places',
    active: false,
  },
];

export const HomeScreen: React.FC = () => {
  const navigation = useNavigation<any>();
  const user = useAuthStore((s) => s.user);

  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  };

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      showsVerticalScrollIndicator={false}
    >
      {/* Header */}
      <View style={styles.header}>
        <View>
          <Text style={styles.greeting}>{getGreeting()} 👋</Text>
          <Text style={styles.userName}>{user?.displayName || 'Explorer'}</Text>
        </View>
        <View style={styles.avatarPlaceholder}>
          <Text style={styles.avatarEmoji}>🧑‍🦱</Text>
        </View>
      </View>

      {/* Hero card */}
      <View style={styles.heroCard}>
        <Text style={styles.heroEmoji}>🇱🇰</Text>
        <Text style={styles.heroTitle}>Welcome to Sri Lanka</Text>
        <Text style={styles.heroSubtitle}>
          Explore the island's wonders with AI-powered assistance
        </Text>
      </View>

      {/* Module Cards */}
      <Text style={styles.sectionTitle}>Explore Modules</Text>

      {moduleCards.map((card) => (
        <TouchableOpacity
          key={card.id}
          style={[styles.moduleCard, !card.active && styles.moduleCardInactive]}
          onPress={() => card.active && navigation.navigate(card.tab)}
          activeOpacity={card.active ? 0.7 : 1}
        >
          <View style={[styles.moduleIcon, { backgroundColor: card.color + '1A' }]}>
            <Text style={styles.moduleEmoji}>{card.emoji}</Text>
          </View>
          <View style={styles.moduleTextContainer}>
            <Text style={styles.moduleTitle}>{card.title}</Text>
            <Text style={styles.moduleSubtitle}>{card.subtitle}</Text>
          </View>
          {card.active ? (
            <View style={[styles.activeBadge, { backgroundColor: card.color + '22' }]}>
              <Text style={[styles.activeBadgeText, { color: card.color }]}>ACTIVE</Text>
            </View>
          ) : (
            <View style={styles.comingSoonBadge}>
              <Text style={styles.comingSoonText}>SOON</Text>
            </View>
          )}
        </TouchableOpacity>
      ))}

      {/* Quick Stats */}
      <Text style={styles.sectionTitle}>Quick Stats</Text>
      <View style={styles.statsRow}>
        <View style={styles.statCard}>
          <Text style={styles.statValue}>0</Text>
          <Text style={styles.statLabel}>Trips</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statValue}>0</Text>
          <Text style={styles.statLabel}>Places</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statValue}>0 km</Text>
          <Text style={styles.statLabel}>Traveled</Text>
        </View>
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background.primary,
  },
  content: {
    padding: Spacing.lg,
    paddingTop: Platform.OS === 'ios' ? 60 : 40,
    paddingBottom: 100,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.xl,
  },
  greeting: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.md,
  },
  userName: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize['2xl'],
    fontWeight: Typography.fontWeight.bold,
    marginTop: 2,
  },
  avatarPlaceholder: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: Colors.background.card,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: Colors.primary.green,
  },
  avatarEmoji: {
    fontSize: 24,
  },
  heroCard: {
    backgroundColor: Colors.background.card,
    borderRadius: BorderRadius.xl,
    padding: Spacing['2xl'],
    alignItems: 'center',
    marginBottom: Spacing['2xl'],
    borderWidth: 1,
    borderColor: Colors.border.subtle,
  },
  heroEmoji: {
    fontSize: 48,
    marginBottom: Spacing.md,
  },
  heroTitle: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize.xl,
    fontWeight: Typography.fontWeight.bold,
    marginBottom: Spacing.xs,
  },
  heroSubtitle: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.md,
    textAlign: 'center',
  },
  sectionTitle: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.semiBold,
    marginBottom: Spacing.md,
    marginTop: Spacing.md,
  },
  moduleCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.background.card,
    borderRadius: BorderRadius.lg,
    padding: Spacing.lg,
    marginBottom: Spacing.md,
    borderWidth: 1,
    borderColor: Colors.border.subtle,
    gap: Spacing.md,
  },
  moduleCardInactive: {
    opacity: 0.55,
  },
  moduleIcon: {
    width: 48,
    height: 48,
    borderRadius: BorderRadius.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  moduleEmoji: {
    fontSize: 24,
  },
  moduleTextContainer: {
    flex: 1,
  },
  moduleTitle: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.semiBold,
  },
  moduleSubtitle: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.sm,
    marginTop: 2,
  },
  activeBadge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: BorderRadius.full,
  },
  activeBadgeText: {
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.bold,
    letterSpacing: 0.5,
  },
  comingSoonBadge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: BorderRadius.full,
    backgroundColor: Colors.background.tertiary,
  },
  comingSoonText: {
    color: Colors.text.tertiary,
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.bold,
    letterSpacing: 0.5,
  },
  statsRow: {
    flexDirection: 'row',
    gap: Spacing.sm,
  },
  statCard: {
    flex: 1,
    backgroundColor: Colors.background.card,
    borderRadius: BorderRadius.md,
    padding: Spacing.lg,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: Colors.border.subtle,
  },
  statValue: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize.xl,
    fontWeight: Typography.fontWeight.bold,
  },
  statLabel: {
    color: Colors.text.tertiary,
    fontSize: Typography.fontSize.xs,
    marginTop: 4,
  },
});

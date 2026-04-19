// CeylonTourMate — Profile Screen
import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Platform } from 'react-native';
import { useAuthStore } from '../../store';
import { Colors, Spacing, Typography, BorderRadius } from '../../theme';

export const ProfileScreen: React.FC = () => {
  const user = useAuthStore((s) => s.user);
  const role = useAuthStore((s) => s.role);
  const logout = useAuthStore((s) => s.logout);

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
    >
      {/* Profile Header */}
      <View style={styles.header}>
        <View style={styles.avatar}>
          <Text style={styles.avatarEmoji}>🧑‍🦱</Text>
        </View>
        <Text style={styles.name}>{user?.displayName || 'User'}</Text>
        <Text style={styles.email}>{user?.email || 'user@example.com'}</Text>
        <View style={styles.roleBadge}>
          <Text style={styles.roleText}>{role?.toUpperCase() || 'TOURIST'}</Text>
        </View>
      </View>

      {/* Menu Items */}
      <View style={styles.menuSection}>
        <MenuItem emoji="👤" label="Edit Profile" />
        <MenuItem emoji="🏥" label="Health & Allergies" />
        <MenuItem emoji="📞" label="Emergency Contacts" />
        <MenuItem emoji="🔔" label="Notifications" />
        <MenuItem emoji="🌙" label="Appearance" />
        <MenuItem emoji="❓" label="Help & Support" />
      </View>

      {/* Logout */}
      <TouchableOpacity
        style={styles.logoutButton}
        onPress={logout}
        activeOpacity={0.7}
      >
        <Text style={styles.logoutText}>Sign Out</Text>
      </TouchableOpacity>

      <Text style={styles.version}>CeylonTourMate v1.0.0</Text>
    </ScrollView>
  );
};

const MenuItem: React.FC<{ emoji: string; label: string }> = ({ emoji, label }) => (
  <TouchableOpacity style={styles.menuItem} activeOpacity={0.7}>
    <Text style={styles.menuEmoji}>{emoji}</Text>
    <Text style={styles.menuLabel}>{label}</Text>
    <Text style={styles.menuArrow}>›</Text>
  </TouchableOpacity>
);

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
    alignItems: 'center',
    marginBottom: Spacing['2xl'],
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: Colors.background.card,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 3,
    borderColor: Colors.primary.green,
    marginBottom: Spacing.md,
  },
  avatarEmoji: {
    fontSize: 36,
  },
  name: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize['2xl'],
    fontWeight: Typography.fontWeight.bold,
  },
  email: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.md,
    marginTop: 4,
  },
  roleBadge: {
    marginTop: Spacing.sm,
    backgroundColor: Colors.primary.green + '22',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.full,
  },
  roleText: {
    color: Colors.primary.green,
    fontSize: Typography.fontSize.sm,
    fontWeight: Typography.fontWeight.bold,
    letterSpacing: 1,
  },
  menuSection: {
    backgroundColor: Colors.background.card,
    borderRadius: BorderRadius.lg,
    borderWidth: 1,
    borderColor: Colors.border.subtle,
    overflow: 'hidden',
    marginBottom: Spacing['2xl'],
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.lg,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border.subtle,
  },
  menuEmoji: {
    fontSize: 20,
    marginRight: Spacing.md,
  },
  menuLabel: {
    flex: 1,
    color: Colors.text.primary,
    fontSize: Typography.fontSize.md,
    fontWeight: Typography.fontWeight.medium,
  },
  menuArrow: {
    color: Colors.text.tertiary,
    fontSize: Typography.fontSize.xl,
  },
  logoutButton: {
    backgroundColor: Colors.status.danger + '15',
    borderRadius: BorderRadius.lg,
    padding: Spacing.lg,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: Colors.status.danger + '33',
    marginBottom: Spacing.xl,
  },
  logoutText: {
    color: Colors.status.danger,
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.semiBold,
  },
  version: {
    color: Colors.text.tertiary,
    fontSize: Typography.fontSize.sm,
    textAlign: 'center',
  },
});

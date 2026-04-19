// CeylonTourMate — Splash Screen (loading)
import React, { useEffect } from 'react';
import { View, Text, StyleSheet, ActivityIndicator } from 'react-native';
import { useAuthStore } from '../../store';
import { Colors, Typography } from '../../theme';

export const SplashScreen: React.FC = () => {
  const restoreSession = useAuthStore((s) => s.restoreSession);

  useEffect(() => {
    restoreSession();
  }, []);

  return (
    <View style={styles.container}>
      <Text style={styles.emoji}>🇱🇰</Text>
      <Text style={styles.title}>CeylonTourMate</Text>
      <Text style={styles.subtitle}>Your Smart Travel Companion</Text>
      <ActivityIndicator
        size="large"
        color={Colors.primary.green}
        style={styles.loader}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background.primary,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emoji: {
    fontSize: 72,
    marginBottom: 16,
  },
  title: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize['4xl'],
    fontWeight: Typography.fontWeight.bold,
  },
  subtitle: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.md,
    marginTop: 8,
    marginBottom: 40,
  },
  loader: {
    marginTop: 20,
  },
});

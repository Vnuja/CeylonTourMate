// CeylonTourMate — Login Screen
import React, { useState } from 'react';
import {
  View, Text, StyleSheet, TextInput, TouchableOpacity, ScrollView, Platform, KeyboardAvoidingView,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useAuthStore } from '../../store';
import { useGoogleAuth } from '../../hooks/useGoogleAuth';
import { UserRole } from '../../types';
import { Colors, Spacing, Typography, BorderRadius } from '../../theme';
import { Alert, ActivityIndicator } from 'react-native';

export const LoginScreen: React.FC = () => {
  const navigation = useNavigation<any>();
  const { signIn: googleSignIn, disabled: googleDisabled } = useGoogleAuth();
  const login = useAuthStore((s) => s.login);
  const socialLogin = useAuthStore((s) => s.socialLogin);
  const loginAsDemo = useAuthStore((s) => s.loginAsDemo);
  const isLoading = useAuthStore((s) => s.isLoading);

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const handleLogin = async () => {
    if (!email || !password) {
      setError('Please enter both email and password');
      return;
    }
    setError('');

    try {
      await login({ email, password });
    } catch (error: any) {
      Alert.alert('Login Failed', error.response?.data?.error || 'Invalid credentials');
    }
  };

  const handleGoogleLogin = async () => {
    googleSignIn();
  };

  const handleDemoLogin = (role: UserRole) => {
    loginAsDemo(role);
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        {/* Branding */}
        <View style={styles.branding}>
          <Text style={styles.logo}>🇱🇰</Text>
          <Text style={styles.appName}>CeylonTourMate</Text>
          <Text style={styles.tagline}>Your Smart Travel Companion</Text>
        </View>

        {/* Login Form */}
        <View style={styles.form}>
          <Text style={styles.formTitle}>Sign In</Text>

          {error ? <Text style={styles.errorText}>{error}</Text> : null}

          <View style={styles.inputContainer}>
            <Text style={styles.inputLabel}>Email</Text>
            <TextInput
              style={[styles.input, error && !email && styles.inputError]}
              value={email}
              onChangeText={(text) => {
                setEmail(text);
                if (error) setError('');
              }}
              placeholder="Enter your email"
              placeholderTextColor={Colors.text.tertiary}
              keyboardType="email-address"
              autoCapitalize="none"
              editable={!isLoading}
            />
          </View>

          <View style={styles.inputContainer}>
            <Text style={styles.inputLabel}>Password</Text>
            <TextInput
              style={[styles.input, error && !password && styles.inputError]}
              value={password}
              onChangeText={(text) => {
                setPassword(text);
                if (error) setError('');
              }}
              placeholder="Enter your password"
              placeholderTextColor={Colors.text.tertiary}
              secureTextEntry
              editable={!isLoading}
            />
          </View>

          <TouchableOpacity 
            style={[styles.loginButton, isLoading && { opacity: 0.7 }]} 
            activeOpacity={0.8}
            onPress={handleLogin}
            disabled={isLoading}
          >
            {isLoading ? (
              <ActivityIndicator color={Colors.white} />
            ) : (
              <Text style={styles.loginButtonText}>Sign In</Text>
            )}
          </TouchableOpacity>

          <View style={styles.divider}>
            <View style={styles.dividerLine} />
            <Text style={styles.dividerText}>or continue with</Text>
            <View style={styles.dividerLine} />
          </View>

          <TouchableOpacity 
            style={[styles.googleButton, googleDisabled && { opacity: 0.5 }]} 
            onPress={handleGoogleLogin}
            activeOpacity={0.7}
            disabled={googleDisabled}
          >
            <View style={styles.googleIconContainer}>
              <Text style={styles.googleIconText}>G</Text>
            </View>
            <Text style={styles.googleButtonText}>Sign in with Google</Text>
          </TouchableOpacity>

          <TouchableOpacity
            onPress={() => navigation.navigate('Register')}
            style={styles.registerLink}
          >
            <Text style={styles.registerText}>
              Don't have an account?{' '}
              <Text style={styles.registerTextBold}>Sign Up</Text>
            </Text>
          </TouchableOpacity>
        </View>

        {/* Demo Login */}
        <View style={styles.demoSection}>
          <Text style={styles.demoTitle}>Quick Demo Access</Text>
          <Text style={styles.demoSubtitle}>Try different user roles</Text>

          <View style={styles.demoButtons}>
            {[
              { role: UserRole.TOURIST, emoji: '🧳', label: 'Tourist' },
              { role: UserRole.GUIDE, emoji: '🧑‍🏫', label: 'Guide' },
              { role: UserRole.DRIVER, emoji: '🚐', label: 'Driver' },
              { role: UserRole.AGENCY_ADMIN, emoji: '🏢', label: 'Admin' },
            ].map((item) => (
              <TouchableOpacity
                key={item.role}
                style={styles.demoButton}
                onPress={() => handleDemoLogin(item.role)}
                activeOpacity={0.7}
              >
                <Text style={styles.demoEmoji}>{item.emoji}</Text>
                <Text style={styles.demoLabel}>{item.label}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background.primary,
  },
  content: {
    padding: Spacing['2xl'],
    paddingTop: Platform.OS === 'ios' ? 80 : 60,
    paddingBottom: 40,
  },
  branding: {
    alignItems: 'center',
    marginBottom: Spacing['3xl'],
  },
  logo: {
    fontSize: 56,
    marginBottom: Spacing.md,
  },
  appName: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize['3xl'],
    fontWeight: Typography.fontWeight.bold,
  },
  tagline: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.md,
    marginTop: 4,
  },
  form: {
    backgroundColor: Colors.background.card,
    borderRadius: BorderRadius.xl,
    padding: Spacing['2xl'],
    borderWidth: 1,
    borderColor: Colors.border.subtle,
    marginBottom: Spacing['2xl'],
  },
  formTitle: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize.xl,
    fontWeight: Typography.fontWeight.bold,
    marginBottom: Spacing.xl,
  },
  inputContainer: {
    marginBottom: Spacing.lg,
  },
  inputLabel: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.sm,
    fontWeight: Typography.fontWeight.medium,
    marginBottom: Spacing.sm,
  },
  input: {
    backgroundColor: Colors.background.tertiary,
    borderRadius: BorderRadius.md,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    color: Colors.text.primary,
    fontSize: Typography.fontSize.md,
    borderWidth: 1,
    borderColor: Colors.border.default,
  },
  loginButton: {
    backgroundColor: Colors.primary.green,
    borderRadius: BorderRadius.md,
    paddingVertical: Spacing.lg,
    alignItems: 'center',
    marginTop: Spacing.md,
    shadowColor: Colors.primary.green,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 5,
  },
  loginButtonText: {
    color: Colors.white,
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.bold,
  },
  registerLink: {
    alignItems: 'center',
    marginTop: Spacing.lg,
  },
  registerText: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.md,
  },
  registerTextBold: {
    color: Colors.primary.green,
    fontWeight: Typography.fontWeight.semiBold,
  },
  errorText: {
    color: Colors.accent.coral,
    fontSize: Typography.fontSize.sm,
    marginBottom: Spacing.md,
    fontWeight: Typography.fontWeight.medium,
  },
  inputError: {
    borderColor: Colors.accent.coral,
  },
  divider: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: Spacing.xl,
  },
  dividerLine: {
    flex: 1,
    height: 1,
    backgroundColor: Colors.border.subtle,
  },
  dividerText: {
    color: Colors.text.tertiary,
    fontSize: Typography.fontSize.xs,
    marginHorizontal: Spacing.md,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  googleButton: {
    backgroundColor: Colors.white,
    borderRadius: BorderRadius.md,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#DADCE0',
    flexDirection: 'row',
    justifyContent: 'center',
  },
  googleIconContainer: {
    marginRight: Spacing.md,
    width: 20,
    height: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  googleIconText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#4285F4', // Google Blue
  },
  googleButtonText: {
    color: '#3C4043', // Google Text Gray
    fontSize: Typography.fontSize.md,
    fontWeight: Typography.fontWeight.medium,
  },
  demoSection: {
    alignItems: 'center',
  },
  demoTitle: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.md,
    fontWeight: Typography.fontWeight.semiBold,
    marginBottom: 4,
  },
  demoSubtitle: {
    color: Colors.text.tertiary,
    fontSize: Typography.fontSize.sm,
    marginBottom: Spacing.lg,
  },
  demoButtons: {
    flexDirection: 'row',
    gap: Spacing.md,
  },
  demoButton: {
    flex: 1,
    backgroundColor: Colors.background.card,
    borderRadius: BorderRadius.md,
    paddingVertical: Spacing.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: Colors.border.default,
  },
  demoEmoji: {
    fontSize: 24,
    marginBottom: 4,
  },
  demoLabel: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.medium,
  },
});

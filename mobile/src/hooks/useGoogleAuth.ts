// CeylonTourMate — Google Auth Hook
import * as WebBrowser from 'expo-web-browser';
import * as Google from 'expo-auth-session/providers/google';
import { useEffect } from 'react';
import { useAuthStore } from '../store';
import { Alert } from 'react-native';

WebBrowser.maybeCompleteAuthSession();

export const useGoogleAuth = () => {
  const socialLogin = useAuthStore((s) => s.socialLogin);
  const isLoading = useAuthStore((s) => s.isLoading);

  const [request, response, promptAsync] = Google.useAuthRequest({
    clientId: process.env.EXPO_PUBLIC_GOOGLE_CLIENT_ID,
    iosClientId: process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID,
    androidClientId: process.env.EXPO_PUBLIC_GOOGLE_CLIENT_ID,
    redirectUri: 'https://auth.expo.io/@vnuja/ceylontourmate',
  });

  useEffect(() => {
    if (response?.type === 'success') {
      const { authentication } = response;
      if (authentication?.accessToken) {
        handleSocialLogin(authentication.accessToken);
      }
    } else if (response?.type === 'error') {
      Alert.alert('Google Sign In Error', 'Unable to complete Google authentication.');
    }
  }, [response]);

  const handleSocialLogin = async (token: string) => {
    try {
      // Fetch user profile from Google using the access token
      const userInfoResponse = await fetch('https://www.googleapis.com/userinfo/v2/me', {
        headers: { Authorization: `Bearer ${token}` },
      });

      if (!userInfoResponse.ok) {
        throw new Error('Failed to fetch user info from Google');
      }

      const user = await userInfoResponse.json();

      // Send the Google user data to our backend to sign in/up
      await socialLogin({
        email: user.email,
        displayName: user.name || user.given_name || 'Google User',
        photoURL: user.picture,
      });
    } catch (error: any) {
      console.error('Social Login Error:', error);
      Alert.alert('Google Auth Error', error.message || 'Failed to complete login');
    }
  };

  return {
    signIn: () => promptAsync(), // Remove { useProxy: true }
    disabled: !request || isLoading,
  };
};

// CeylonTourMate — Main Tab Navigator (role-based)
import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { View, Text, StyleSheet } from 'react-native';
import { useAuthStore } from '../store';
import { UserRole } from '../types';
import { Colors, Spacing, Typography } from '../theme';

// Screen imports
import { HomeScreen } from '../screens/home/HomeScreen';
import { LiveMonitorScreen } from '../screens/live/LiveMonitorScreen';
import { ToursScreen } from '../screens/tours/ToursScreen';
import { ScanScreen } from '../screens/scan/ScanScreen';
import { PlacesScreen } from '../screens/places/PlacesScreen';
import { ProfileScreen } from '../screens/profile/ProfileScreen';

export type MainTabParamList = {
  Home: undefined;
  Tours: undefined;
  Live: undefined;
  Scan: undefined;
  Places: undefined;
  Profile: undefined;
};

const Tab = createBottomTabNavigator<MainTabParamList>();

// Tab icon component using emoji (replace with vector icons in production)
const TabIcon = ({ emoji, focused }: { emoji: string; focused: boolean }) => (
  <View style={[styles.iconContainer, focused && styles.iconContainerFocused]}>
    <Text style={[styles.iconEmoji, focused && styles.iconEmojiFocused]}>{emoji}</Text>
  </View>
);

export const MainTabNavigator: React.FC = () => {
  const role = useAuthStore((s) => s.role);

  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarStyle: styles.tabBar,
        tabBarActiveTintColor: Colors.primary.green,
        tabBarInactiveTintColor: Colors.text.tertiary,
        tabBarLabelStyle: styles.tabLabel,
        tabBarHideOnKeyboard: true,
      }}
    >
      <Tab.Screen
        name="Home"
        component={HomeScreen}
        options={{
          tabBarIcon: ({ focused }) => <TabIcon emoji="🏠" focused={focused} />,
        }}
      />

      <Tab.Screen
        name="Tours"
        component={ToursScreen}
        options={{
          tabBarIcon: ({ focused }) => <TabIcon emoji="🎒" focused={focused} />,
        }}
      />

      <Tab.Screen
        name="Live"
        component={LiveMonitorScreen}
        options={{
          tabBarIcon: ({ focused }) => <TabIcon emoji="📡" focused={focused} />,
          tabBarLabel: 'Live Track',
          tabBarBadge: undefined, // Set dynamically for active alerts
        }}
      />

      {/* Only show Scan & Places for Tourist and Guide roles */}
      {(role === UserRole.TOURIST || role === UserRole.GUIDE || !role) && (
        <>
          <Tab.Screen
            name="Scan"
            component={ScanScreen}
            options={{
              tabBarIcon: ({ focused }) => <TabIcon emoji="📸" focused={focused} />,
            }}
          />

          <Tab.Screen
            name="Places"
            component={PlacesScreen}
            options={{
              tabBarIcon: ({ focused }) => <TabIcon emoji="🏛️" focused={focused} />,
            }}
          />
        </>
      )}

      <Tab.Screen
        name="Profile"
        component={ProfileScreen}
        options={{
          tabBarIcon: ({ focused }) => <TabIcon emoji="👤" focused={focused} />,
        }}
      />
    </Tab.Navigator>
  );
};

const styles = StyleSheet.create({
  tabBar: {
    backgroundColor: Colors.background.secondary,
    borderTopColor: Colors.border.default,
    borderTopWidth: 1,
    height: 70,
    paddingBottom: 8,
    paddingTop: 8,
    elevation: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
  },
  tabLabel: {
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.medium,
    marginTop: 2,
  },
  iconContainer: {
    width: 36,
    height: 36,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
  iconContainerFocused: {
    backgroundColor: 'rgba(29, 158, 117, 0.15)',
  },
  iconEmoji: {
    fontSize: 20,
    opacity: 0.6,
  },
  iconEmojiFocused: {
    fontSize: 22,
    opacity: 1,
  },
});

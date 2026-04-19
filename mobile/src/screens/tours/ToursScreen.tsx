// CeylonTourMate — Tours Placeholder Screen
import React from 'react';
import { PlaceholderScreen } from '../../components/common/PlaceholderScreen';
import { Colors } from '../../theme';

export const ToursScreen: React.FC = () => {
  return (
    <PlaceholderScreen
      emoji="🎒"
      title="Smart Packages"
      subtitle="AI-powered tour recommendations tailored to your interests, health, and weather conditions."
      accentColor={Colors.primary.gold}
      features={[
        'AI match scoring based on your preferences',
        'Real-time weather-adjusted suggestions',
        'Health & dietary compatibility checks',
        'Collaborative filtering from similar travelers',
        'One-tap booking with itinerary preview',
      ]}
    />
  );
};

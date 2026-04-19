// CeylonTourMate — Scan Placeholder Screen
import React from 'react';
import { PlaceholderScreen } from '../../components/common/PlaceholderScreen';
import { Colors } from '../../theme';

export const ScanScreen: React.FC = () => {
  return (
    <PlaceholderScreen
      emoji="📸"
      title="Image AI"
      subtitle="Point your camera at food or content for instant AI-powered recognition and safety analysis."
      accentColor={Colors.accent.coral}
      features={[
        'Sri Lankan food recognition (30+ dishes)',
        'Allergen & dietary alerts',
        'Nutrition information display',
        'Content safety moderation',
        'Hate speech & harmful content detection',
      ]}
    />
  );
};

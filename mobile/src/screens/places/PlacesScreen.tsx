// CeylonTourMate — Places Placeholder Screen
import React from 'react';
import { PlaceholderScreen } from '../../components/common/PlaceholderScreen';
import { Colors } from '../../theme';

export const PlacesScreen: React.FC = () => {
  return (
    <PlaceholderScreen
      emoji="🏛️"
      title="Place Lens"
      subtitle="Identify Sri Lankan landmarks, wildlife, and heritage sites using your camera."
      accentColor={Colors.accent.indigo}
      features={[
        '200+ Sri Lankan landmarks & sites',
        'Heritage, nature, wildlife identification',
        'Historical context & visitor info',
        'Audio guide narration',
        'Nearby attractions discovery',
      ]}
    />
  );
};

// CeylonTourMate — ETA Chip (floating on map)
import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Typography, BorderRadius } from '../../theme';

interface ETAChipProps {
  eta: string; // ISO timestamp
}

export const ETAChip: React.FC<ETAChipProps> = ({ eta }) => {
  const [timeLeft, setTimeLeft] = useState('');

  useEffect(() => {
    const updateTimeLeft = () => {
      const now = new Date();
      const etaDate = new Date(eta);
      const diffMs = etaDate.getTime() - now.getTime();

      if (diffMs <= 0) {
        setTimeLeft('Arrived');
        return;
      }

      const hours = Math.floor(diffMs / 3600000);
      const mins = Math.floor((diffMs % 3600000) / 60000);

      if (hours > 0) {
        setTimeLeft(`${hours}h ${mins}m`);
      } else {
        setTimeLeft(`${mins} min`);
      }
    };

    updateTimeLeft();
    const interval = setInterval(updateTimeLeft, 30000); // Update every 30s
    return () => clearInterval(interval);
  }, [eta]);

  return (
    <View style={styles.container}>
      <Text style={styles.label}>ETA</Text>
      <Text style={styles.time}>{timeLeft}</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    bottom: 16,
    right: 16,
    alignItems: 'center',
    backgroundColor: 'rgba(13, 17, 23, 0.9)',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: BorderRadius.full,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 5,
  },
  label: {
    color: Colors.text.tertiary,
    fontSize: 9,
    fontWeight: Typography.fontWeight.bold,
    letterSpacing: 1,
    textTransform: 'uppercase',
  },
  time: {
    color: Colors.primary.lightGreen,
    fontSize: Typography.fontSize.md,
    fontWeight: Typography.fontWeight.bold,
  },
});

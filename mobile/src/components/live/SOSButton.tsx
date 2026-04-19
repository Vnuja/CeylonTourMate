// CeylonTourMate — SOS Emergency Button
import React, { useRef, useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableWithoutFeedback,
  Animated,
  Modal,
  TouchableOpacity,
  Vibration,
} from 'react-native';
import { socketManager } from '../../services/socket';
import { useTripStore } from '../../store';
import { LocationPoint } from '../../types';
import { Colors, Spacing, Typography, BorderRadius } from '../../theme';

interface SOSButtonProps {
  tripId: string;
  touristId: string;
  currentLocation: LocationPoint | null;
}

const SOS_HOLD_DURATION = 3000; // 3 seconds to activate
const SOS_CANCEL_COUNTDOWN = 5; // 5 seconds to cancel after triggering

export const SOSButton: React.FC<SOSButtonProps> = ({
  tripId,
  touristId,
  currentLocation,
}) => {
  const [isHolding, setIsHolding] = useState(false);
  const [showCancelModal, setShowCancelModal] = useState(false);
  const [cancelCountdown, setCancelCountdown] = useState(SOS_CANCEL_COUNTDOWN);
  const holdProgress = useRef(new Animated.Value(0)).current;
  const holdAnimation = useRef<Animated.CompositeAnimation | null>(null);
  const cancelTimer = useRef<NodeJS.Timeout | null>(null);
  const pulseAnim = useRef(new Animated.Value(1)).current;

  const triggerSOS = useTripStore((s) => s.triggerSOS);
  const cancelSOS = useTripStore((s) => s.cancelSOS);

  // Pulse animation for the button
  useEffect(() => {
    const pulse = Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue: 1.03,
          duration: 1500,
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue: 1,
          duration: 1500,
          useNativeDriver: true,
        }),
      ])
    );
    pulse.start();
    return () => pulse.stop();
  }, []);

  // Handle SOS hold start
  const onPressIn = useCallback(() => {
    setIsHolding(true);
    Vibration.vibrate(50);

    holdAnimation.current = Animated.timing(holdProgress, {
      toValue: 1,
      duration: SOS_HOLD_DURATION,
      useNativeDriver: false,
    });

    holdAnimation.current.start(({ finished }) => {
      if (finished) {
        // SOS activated!
        Vibration.vibrate([0, 200, 100, 200, 100, 500]);
        activateSOS();
      }
    });
  }, [tripId, touristId, currentLocation]);

  // Handle SOS hold release
  const onPressOut = useCallback(() => {
    setIsHolding(false);

    if (holdAnimation.current) {
      holdAnimation.current.stop();
    }

    Animated.timing(holdProgress, {
      toValue: 0,
      duration: 200,
      useNativeDriver: false,
    }).start();
  }, []);

  // Activate SOS
  const activateSOS = () => {
    setIsHolding(false);
    setShowCancelModal(true);
    setCancelCountdown(SOS_CANCEL_COUNTDOWN);

    // Start cancel countdown
    cancelTimer.current = setInterval(() => {
      setCancelCountdown((prev) => {
        if (prev <= 1) {
          // Countdown finished — send SOS
          clearInterval(cancelTimer.current!);
          setShowCancelModal(false);
          sendSOSToServer();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  };

  // Actually send SOS
  const sendSOSToServer = () => {
    triggerSOS({
      tripId,
      touristId,
      touristName: 'Tourist',
      location: currentLocation || {
        latitude: 0,
        longitude: 0,
        timestamp: new Date().toISOString(),
      },
      message: 'Emergency SOS triggered by tourist',
    });

    socketManager.sendSOS({
      tripId,
      touristId,
      lat: currentLocation?.latitude || 0,
      lng: currentLocation?.longitude || 0,
      message: 'Emergency SOS triggered',
    });
  };

  // Cancel SOS
  const handleCancelSOS = () => {
    if (cancelTimer.current) {
      clearInterval(cancelTimer.current);
    }
    setShowCancelModal(false);
    setCancelCountdown(SOS_CANCEL_COUNTDOWN);
    holdProgress.setValue(0);
    cancelSOS();
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (cancelTimer.current) {
        clearInterval(cancelTimer.current);
      }
    };
  }, []);

  const progressWidth = holdProgress.interpolate({
    inputRange: [0, 1],
    outputRange: ['0%', '100%'],
  });

  const progressColor = holdProgress.interpolate({
    inputRange: [0, 0.5, 1],
    outputRange: [Colors.status.danger, '#FF4444', '#FF0000'],
  });

  return (
    <>
      <Animated.View
        style={[
          styles.container,
          { transform: [{ scale: pulseAnim }] },
        ]}
      >
        <TouchableWithoutFeedback
          onPressIn={onPressIn}
          onPressOut={onPressOut}
        >
          <View style={styles.button}>
            {/* Progress overlay */}
            <Animated.View
              style={[
                styles.progressOverlay,
                {
                  width: progressWidth,
                  backgroundColor: progressColor,
                },
              ]}
            />

            {/* Button content */}
            <View style={styles.buttonContent}>
              <Text style={styles.sosIcon}>🆘</Text>
              <View>
                <Text style={styles.sosText}>SOS EMERGENCY</Text>
                <Text style={styles.sosSubtext}>
                  {isHolding ? 'Keep holding...' : 'Hold 3 seconds to activate'}
                </Text>
              </View>
            </View>
          </View>
        </TouchableWithoutFeedback>
      </Animated.View>

      {/* Cancel Modal */}
      <Modal
        visible={showCancelModal}
        transparent
        animationType="fade"
        onRequestClose={handleCancelSOS}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.countdownCircle}>
              <Text style={styles.countdownNumber}>{cancelCountdown}</Text>
            </View>

            <Text style={styles.modalTitle}>🆘 SOS Activating</Text>
            <Text style={styles.modalMessage}>
              Emergency alert will be sent to your tour guide and agency in{' '}
              {cancelCountdown} seconds
            </Text>

            <TouchableOpacity
              style={styles.cancelButton}
              onPress={handleCancelSOS}
              activeOpacity={0.8}
            >
              <Text style={styles.cancelButtonText}>CANCEL SOS</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </>
  );
};

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.xl,
    paddingTop: Spacing.sm,
    backgroundColor: Colors.background.primary + 'E6',
  },
  button: {
    height: 60,
    borderRadius: BorderRadius.lg,
    backgroundColor: Colors.status.danger,
    overflow: 'hidden',
    shadowColor: Colors.status.danger,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 10,
  },
  progressOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    bottom: 0,
    opacity: 0.3,
  },
  buttonContent: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.md,
  },
  sosIcon: {
    fontSize: 28,
  },
  sosText: {
    color: Colors.white,
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.bold,
    letterSpacing: 2,
  },
  sosSubtext: {
    color: 'rgba(255,255,255,0.7)',
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.medium,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.85)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: Spacing['2xl'],
  },
  modalContent: {
    backgroundColor: Colors.background.card,
    borderRadius: BorderRadius.xl,
    padding: Spacing['3xl'],
    alignItems: 'center',
    width: '100%',
    maxWidth: 340,
    borderWidth: 2,
    borderColor: Colors.status.danger,
  },
  countdownCircle: {
    width: 80,
    height: 80,
    borderRadius: 40,
    borderWidth: 4,
    borderColor: Colors.status.danger,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: Spacing.xl,
  },
  countdownNumber: {
    color: Colors.status.danger,
    fontSize: Typography.fontSize['4xl'],
    fontWeight: Typography.fontWeight.bold,
  },
  modalTitle: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize['2xl'],
    fontWeight: Typography.fontWeight.bold,
    marginBottom: Spacing.md,
    textAlign: 'center',
  },
  modalMessage: {
    color: Colors.text.secondary,
    fontSize: Typography.fontSize.md,
    textAlign: 'center',
    lineHeight: Typography.lineHeight.lg,
    marginBottom: Spacing['2xl'],
  },
  cancelButton: {
    width: '100%',
    paddingVertical: Spacing.lg,
    borderRadius: BorderRadius.md,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderWidth: 1,
    borderColor: Colors.border.strong,
    alignItems: 'center',
  },
  cancelButtonText: {
    color: Colors.text.primary,
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.bold,
    letterSpacing: 1,
  },
});

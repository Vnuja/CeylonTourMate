// CeylonTourMate — Socket.IO Connection Manager
import { io, Socket } from 'socket.io-client';
import { useAuthStore } from '../store/authStore';
import { useTripStore } from '../store/tripStore';
import { useUIStore } from '../store/uiStore';
import {
  VehicleLocationUpdate,
  TripProgressUpdate,
  TripAlert,
  SOSEvent,
  AlertSeverity,
} from '../types';

const SOCKET_URL = process.env.EXPO_PUBLIC_SOCKET_URL || 'http://localhost:3001';

class SocketManager {
  private socket: Socket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;
  private currentTripId: string | null = null;

  // Connect to socket server
  connect(): void {
    if (this.socket?.connected) return;

    const token = useAuthStore.getState().token;

    this.socket = io(SOCKET_URL, {
      auth: { token },
      transports: ['websocket', 'polling'],
      reconnection: true,
      reconnectionAttempts: this.maxReconnectAttempts,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 10000,
      timeout: 10000,
    });

    this.setupEventListeners();
  }

  // Disconnect from socket server
  disconnect(): void {
    if (this.currentTripId) {
      this.leaveTrip(this.currentTripId);
    }
    this.socket?.disconnect();
    this.socket = null;
    this.reconnectAttempts = 0;
  }

  // Join a trip room for real-time updates
  joinTrip(tripId: string): void {
    if (!this.socket?.connected) {
      console.warn('[Socket] Not connected. Connecting first...');
      this.connect();
    }

    this.currentTripId = tripId;
    this.socket?.emit('trip:join', { tripId });
    console.log(`[Socket] Joined trip room: ${tripId}`);
  }

  // Leave a trip room
  leaveTrip(tripId: string): void {
    this.socket?.emit('trip:leave', { tripId });
    this.currentTripId = null;
    console.log(`[Socket] Left trip room: ${tripId}`);
  }

  // Send driver location update (for Driver role)
  sendLocationUpdate(update: VehicleLocationUpdate): void {
    this.socket?.emit('driver:locationUpdate', update);
  }

  // Trigger SOS emergency
  sendSOS(data: { tripId: string; touristId: string; lat: number; lng: number; message?: string }): void {
    this.socket?.emit('tourist:sos', data);
    console.log('[Socket] SOS triggered:', data);
  }

  // Cancel SOS
  cancelSOS(tripId: string): void {
    this.socket?.emit('tourist:cancelSOS', { tripId });
  }

  // Acknowledge alert (for Guide/Driver)
  acknowledgeAlert(alertId: string, tripId: string): void {
    this.socket?.emit('alert:acknowledge', { alertId, tripId });
  }

  // Setup all event listeners
  private setupEventListeners(): void {
    if (!this.socket) return;

    // Connection events
    this.socket.on('connect', () => {
      console.log('[Socket] Connected:', this.socket?.id);
      this.reconnectAttempts = 0;
      useUIStore.getState().setOffline(false);

      // Rejoin trip room if was previously in one
      if (this.currentTripId) {
        this.socket?.emit('trip:join', { tripId: this.currentTripId });
      }
    });

    this.socket.on('disconnect', (reason) => {
      console.log('[Socket] Disconnected:', reason);
      if (reason === 'io server disconnect') {
        // Server forced disconnect — reconnect manually
        this.socket?.connect();
      }
    });

    this.socket.on('connect_error', (error) => {
      this.reconnectAttempts++;
      console.error('[Socket] Connection error:', error.message);

      if (this.reconnectAttempts >= this.maxReconnectAttempts) {
        useUIStore.getState().addNotification({
          title: 'Connection Lost',
          message: 'Unable to establish real-time connection. Retrying...',
          type: 'error',
        });
      }
    });

    // ─── Live Monitoring Events ───

    // Vehicle location update
    this.socket.on('vehicle:location', (data: VehicleLocationUpdate) => {
      useTripStore.getState().updateVehicleLocation(data);
    });

    // Trip progress update
    this.socket.on('trip:progress', (data: TripProgressUpdate) => {
      useTripStore.getState().updateProgress(data);
    });

    // Safety alert
    this.socket.on('vehicle:alert', (alert: TripAlert) => {
      useTripStore.getState().addAlert(alert);

      // Show notification for WARNING and DANGER
      if (alert.severity !== AlertSeverity.SAFE) {
        useUIStore.getState().addNotification({
          title: `⚠️ ${alert.title}`,
          message: alert.message,
          type: alert.severity === AlertSeverity.DANGER ? 'error' : 'warning',
        });
      }
    });

    // Safety status update
    this.socket.on('trip:safetyStatus', (status: any) => {
      useTripStore.getState().setSafetyStatus(status);
    });

    // SOS acknowledged by guide/admin
    this.socket.on('sos:acknowledged', (data: { respondedBy: string }) => {
      useTripStore.getState().acknowledgeSOS(data.respondedBy);
      useUIStore.getState().addNotification({
        title: '🆘 SOS Acknowledged',
        message: `Your SOS has been received. ${data.respondedBy} is responding.`,
        type: 'info',
      });
    });

    // SOS received (for guides/admins)
    this.socket.on('sos:received', (event: SOSEvent) => {
      useUIStore.getState().addNotification({
        title: '🆘 EMERGENCY SOS',
        message: `${event.touristName} has triggered an SOS! Location received.`,
        type: 'error',
      });
    });

    // Waypoint reached
    this.socket.on('trip:waypointReached', (data: { waypointId: string }) => {
      useTripStore.getState().updateWaypoint(data.waypointId, true);
    });
  }

  // Check connection status
  isConnected(): boolean {
    return this.socket?.connected ?? false;
  }

  // Get socket ID
  getSocketId(): string | undefined {
    return this.socket?.id;
  }
}

// Singleton instance
export const socketManager = new SocketManager();

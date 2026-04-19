// CeylonTourMate — ★ CORE Socket.IO Monitoring Server
import { Server as SocketIOServer, Socket } from 'socket.io';
import Redis from 'ioredis';
import { v4 as uuidv4 } from 'uuid';
import { SafetyService } from '../services/safety.service';
import { LocationHistory } from '../models/LocationHistory.model';
import { Alert as AlertModel } from '../models/Alert.model';
import { SOSEvent } from '../models/SOSEvent.model';
import { Trip } from '../models/Trip.model';

interface LocationUpdate {
  tripId: string;
  driverId: string;
  lat: number;
  lng: number;
  speed: number;
  heading: number;
  timestamp: string;
  accuracy?: number;
}

interface SOSData {
  tripId: string;
  touristId: string;
  lat: number;
  lng: number;
  message?: string;
}

// Buffer for batch-persisting location points
const locationBuffers: Map<string, LocationUpdate[]> = new Map();
const BATCH_PERSIST_SIZE = 10;

export function setupMonitoringSocket(io: SocketIOServer, redis?: Redis | null): void {
  const safetyService = new SafetyService();

  io.on('connection', (socket: Socket) => {
    console.log(`[Socket] Client connected: ${socket.id}`);

    // ─── Join Trip Room ───
    socket.on('trip:join', async (data: { tripId: string }) => {
      const { tripId } = data;
      if (!tripId) return;

      socket.join(`trip:${tripId}`);
      console.log(`[Socket] ${socket.id} joined trip:${tripId}`);

      // Send current vehicle location from Redis cache if available
      if (redis) {
        try {
          const cached = await redis.get(`trip:${tripId}:location`);
          if (cached) {
            socket.emit('vehicle:location', JSON.parse(cached));
          }
        } catch (err) {
          console.warn('[Socket] Redis read error:', err);
        }
      }

      // Send recent alerts
      try {
        const recentAlerts = await AlertModel.find({ tripId })
          .sort({ timestamp: -1 })
          .limit(20)
          .lean();

        if (recentAlerts.length > 0) {
          socket.emit('trip:alertHistory', recentAlerts);
        }
      } catch (err) {
        // DB might not be connected in demo mode
      }
    });

    // ─── Leave Trip Room ───
    socket.on('trip:leave', (data: { tripId: string }) => {
      socket.leave(`trip:${data.tripId}`);
      console.log(`[Socket] ${socket.id} left trip:${data.tripId}`);
    });

    // ─── Driver Location Update (CORE EVENT) ───
    socket.on('driver:locationUpdate', async (data: LocationUpdate) => {
      const { tripId, driverId, lat, lng, speed, heading, timestamp } = data;

      if (!tripId || lat === undefined || lng === undefined) {
        socket.emit('error', { message: 'Invalid location update data' });
        return;
      }

      const locationPayload = {
        tripId,
        driverId,
        location: {
          latitude: lat,
          longitude: lng,
          speed: speed || 0,
          heading: heading || 0,
          timestamp: timestamp || new Date().toISOString(),
        },
      };

      // 1. Cache latest location in Redis (TTL 30 seconds)
      if (redis) {
        try {
          await redis.setex(
            `trip:${tripId}:location`,
            30,
            JSON.stringify(locationPayload)
          );
        } catch (err) {
          console.warn('[Socket] Redis write error:', err);
        }
      }

      // 2. Broadcast to all clients in the trip room
      io.to(`trip:${tripId}`).emit('vehicle:location', locationPayload);

      // 3. Buffer for batch persistence to MongoDB
      if (!locationBuffers.has(tripId)) {
        locationBuffers.set(tripId, []);
      }
      const buffer = locationBuffers.get(tripId)!;
      buffer.push(data);

      if (buffer.length >= BATCH_PERSIST_SIZE) {
        // Persist batch to MongoDB
        try {
          const docs = buffer.map((loc) => ({
            tripId: loc.tripId,
            driverId: loc.driverId,
            latitude: loc.lat,
            longitude: loc.lng,
            speed: loc.speed,
            heading: loc.heading,
            timestamp: new Date(loc.timestamp),
          }));
          await LocationHistory.insertMany(docs).catch(() => {});
        } catch (err) {
          // Silently fail — demo mode might not have DB
        }
        locationBuffers.set(tripId, []);
      }

      // 4. Run safety anomaly detection
      try {
        const alerts = await safetyService.analyzeLocation(tripId, {
          latitude: lat,
          longitude: lng,
          speed: speed || 0,
          heading: heading || 0,
          timestamp: timestamp || new Date().toISOString(),
        });

        // Emit any generated alerts
        for (const alert of alerts) {
          const alertDoc = {
            id: uuidv4(),
            tripId,
            ...alert,
            timestamp: new Date().toISOString(),
            acknowledged: false,
          };

          // Broadcast alert to trip room
          io.to(`trip:${tripId}`).emit('vehicle:alert', alertDoc);

          // Persist alert to MongoDB
          try {
            await AlertModel.create({
              ...alertDoc,
              coordinates: { latitude: lat, longitude: lng },
            });
          } catch (err) {
            // DB might not be connected
          }
        }

        // Emit safety status update
        const activeAlertCount = alerts.filter(
          (a) => a.severity === 'warning' || a.severity === 'danger'
        ).length;

        const overallStatus =
          alerts.some((a) => a.severity === 'danger')
            ? 'danger'
            : alerts.some((a) => a.severity === 'warning')
            ? 'warning'
            : 'safe';

        io.to(`trip:${tripId}`).emit('trip:safetyStatus', {
          tripId,
          overallStatus,
          activeAlerts: activeAlertCount,
          lastChecked: new Date().toISOString(),
        });
      } catch (err) {
        console.error('[Safety] Analysis error:', err);
      }

      // 5. Calculate and emit progress update
      try {
        const trip = await Trip.findById(tripId).lean().catch(() => null);
        if (trip && trip.distanceTotal > 0) {
          // Simple progress calculation based on distance
          const progressUpdate = {
            tripId,
            progress: Math.min(100, trip.progress + 0.1),
            distanceRemaining: Math.max(0, trip.distanceRemaining - 0.05),
            currentETA: trip.currentETA?.toISOString() || new Date().toISOString(),
            currentSpeed: speed || 0,
          };
          io.to(`trip:${tripId}`).emit('trip:progress', progressUpdate);
        }
      } catch (err) {
        // DB might not be connected
      }
    });

    // ─── Tourist SOS Emergency ───
    socket.on('tourist:sos', async (data: SOSData) => {
      const { tripId, touristId, lat, lng, message } = data;

      console.log(`[SOS] 🆘 EMERGENCY from ${touristId} on trip ${tripId}`);

      const sosEvent = {
        id: uuidv4(),
        tripId,
        touristId,
        touristName: 'Tourist', // In production, look up from DB
        location: { latitude: lat, longitude: lng, timestamp: new Date().toISOString() },
        message: message || 'Emergency SOS triggered',
        status: 'triggered' as const,
        triggeredAt: new Date().toISOString(),
      };

      // Broadcast SOS to all relevant parties
      // 1. To all members of the trip room (guide, driver, other tourists)
      io.to(`trip:${tripId}`).emit('sos:received', sosEvent);

      // 2. To agency room if it exists
      io.to(`agency:default`).emit('sos:received', sosEvent);

      // 3. Acknowledge back to the tourist
      socket.emit('sos:acknowledged', {
        respondedBy: 'System',
        message: 'Your SOS has been received. Help is on the way.',
      });

      // Persist SOS event to MongoDB
      try {
        await SOSEvent.create({
          tripId,
          touristId,
          touristName: sosEvent.touristName,
          latitude: lat,
          longitude: lng,
          message: sosEvent.message,
          status: 'triggered',
          triggeredAt: new Date(),
        });
      } catch (err) {
        console.error('[SOS] Failed to persist SOS event:', err);
      }

      // Update trip status to emergency
      try {
        await Trip.findByIdAndUpdate(tripId, { status: 'emergency' }).catch(() => {});
      } catch (err) {
        // DB might not be connected
      }
    });

    // ─── Cancel SOS ───
    socket.on('tourist:cancelSOS', async (data: { tripId: string }) => {
      console.log(`[SOS] SOS cancelled for trip ${data.tripId}`);

      io.to(`trip:${data.tripId}`).emit('sos:cancelled', {
        tripId: data.tripId,
        cancelledAt: new Date().toISOString(),
      });

      // Update SOS status in DB
      try {
        await SOSEvent.findOneAndUpdate(
          { tripId: data.tripId, status: 'triggered' },
          { status: 'cancelled' }
        ).catch(() => {});

        await Trip.findByIdAndUpdate(data.tripId, { status: 'active' }).catch(() => {});
      } catch (err) {
        // DB might not be connected
      }
    });

    // ─── Alert Acknowledgement ───
    socket.on('alert:acknowledge', async (data: { alertId: string; tripId: string }) => {
      io.to(`trip:${data.tripId}`).emit('alert:acknowledged', {
        alertId: data.alertId,
        acknowledgedAt: new Date().toISOString(),
      });

      try {
        await AlertModel.findByIdAndUpdate(data.alertId, {
          acknowledged: true,
          acknowledgedBy: socket.id,
        }).catch(() => {});
      } catch (err) {
        // DB might not be connected
      }
    });

    // ─── Disconnect ───
    socket.on('disconnect', (reason) => {
      console.log(`[Socket] Client disconnected: ${socket.id} (${reason})`);
    });
  });

  console.log('✅ Socket.IO monitoring server initialized');
}

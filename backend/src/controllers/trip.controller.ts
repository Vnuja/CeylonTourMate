// CeylonTourMate — Trip Controller
import { Request, Response } from 'express';
import { Trip } from '../models/Trip.model';
import { Alert } from '../models/Alert.model';
import { LocationHistory } from '../models/LocationHistory.model';
import { SOSEvent } from '../models/SOSEvent.model';

export class TripController {
  // Get all trips
  async getAllTrips(req: Request, res: Response): Promise<void> {
    try {
      const trips = await Trip.find()
        .sort({ createdAt: -1 })
        .limit(50)
        .lean();
      res.json({ data: trips, count: trips.length });
    } catch (error) {
      res.status(500).json({ error: 'Failed to fetch trips' });
    }
  }

  // Get active trips
  async getActiveTrips(req: Request, res: Response): Promise<void> {
    try {
      const trips = await Trip.find({ status: { $in: ['active', 'emergency'] } })
        .sort({ startTime: -1 })
        .lean();
      res.json({ data: trips, count: trips.length });
    } catch (error) {
      res.status(500).json({ error: 'Failed to fetch active trips' });
    }
  }

  // Get trip by ID
  async getTripById(req: Request, res: Response): Promise<void> {
    try {
      const trip = await Trip.findById(req.params.id).lean();
      if (!trip) {
        res.status(404).json({ error: 'Trip not found' });
        return;
      }
      res.json({ data: trip });
    } catch (error) {
      res.status(500).json({ error: 'Failed to fetch trip' });
    }
  }

  // Create trip
  async createTrip(req: Request, res: Response): Promise<void> {
    try {
      const trip = await Trip.create(req.body);
      res.status(201).json({ data: trip });
    } catch (error) {
      res.status(500).json({ error: 'Failed to create trip' });
    }
  }

  // Update trip status
  async updateTripStatus(req: Request, res: Response): Promise<void> {
    try {
      const { status } = req.body;
      const trip = await Trip.findByIdAndUpdate(
        req.params.id,
        { status },
        { new: true }
      ).lean();

      if (!trip) {
        res.status(404).json({ error: 'Trip not found' });
        return;
      }
      res.json({ data: trip });
    } catch (error) {
      res.status(500).json({ error: 'Failed to update trip status' });
    }
  }

  // Get alerts for a trip
  async getTripAlerts(req: Request, res: Response): Promise<void> {
    try {
      const alerts = await Alert.find({ tripId: req.params.id })
        .sort({ timestamp: -1 })
        .limit(100)
        .lean();
      res.json({ data: alerts, count: alerts.length });
    } catch (error) {
      res.status(500).json({ error: 'Failed to fetch alerts' });
    }
  }

  // Get location history for a trip
  async getLocationHistory(req: Request, res: Response): Promise<void> {
    try {
      const history = await LocationHistory.find({ tripId: req.params.id })
        .sort({ timestamp: -1 })
        .limit(500)
        .lean();
      res.json({ data: history, count: history.length });
    } catch (error) {
      res.status(500).json({ error: 'Failed to fetch location history' });
    }
  }

  // Get SOS events for a trip
  async getSOSEvents(req: Request, res: Response): Promise<void> {
    try {
      const events = await SOSEvent.find({ tripId: req.params.id })
        .sort({ triggeredAt: -1 })
        .lean();
      res.json({ data: events, count: events.length });
    } catch (error) {
      res.status(500).json({ error: 'Failed to fetch SOS events' });
    }
  }

  // Create a demo trip for development testing
  async createDemoTrip(req: Request, res: Response): Promise<void> {
    try {
      const demoTrip = await Trip.create({
        packageId: 'demo-pkg-1',
        packageName: 'Sigiriya & Dambulla Heritage Tour',
        touristIds: ['demo-tourist-1'],
        driverId: 'demo-driver-1',
        guideId: 'demo-guide-1',
        vehicleInfo: {
          plateNumber: 'WP-CAB-1234',
          type: 'van',
          model: 'Toyota HiAce',
          color: 'White',
        },
        plannedRoute: [
          { latitude: 7.2906, longitude: 80.6337 },
          { latitude: 7.4675, longitude: 80.5236 },
          { latitude: 7.6101, longitude: 80.5550 },
          { latitude: 7.8568, longitude: 80.6498 },
          { latitude: 7.9570, longitude: 80.7603 },
        ],
        waypoints: [
          {
            name: 'Kandy City Hotel',
            location: { latitude: 7.2906, longitude: 80.6337 },
            type: 'pickup',
            estimatedArrival: new Date(),
            duration: 10,
            visited: true,
          },
          {
            name: 'Dambulla Cave Temple',
            location: { latitude: 7.8568, longitude: 80.6498 },
            type: 'attraction',
            estimatedArrival: new Date(Date.now() + 2 * 3600000),
            duration: 90,
            visited: false,
          },
          {
            name: 'Sigiriya Rock Fortress',
            location: { latitude: 7.9570, longitude: 80.7603 },
            type: 'attraction',
            estimatedArrival: new Date(Date.now() + 5 * 3600000),
            duration: 180,
            visited: false,
          },
        ],
        status: 'active',
        startTime: new Date(),
        estimatedEndTime: new Date(Date.now() + 8 * 3600000),
        progress: 0,
        distanceTotal: 120,
        distanceRemaining: 120,
        currentETA: new Date(Date.now() + 3 * 3600000),
      });

      res.status(201).json({ data: demoTrip, message: 'Demo trip created' });
    } catch (error) {
      res.status(500).json({ error: 'Failed to create demo trip' });
    }
  }
}

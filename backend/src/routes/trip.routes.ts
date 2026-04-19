// CeylonTourMate — Trip Routes (REST API)
import { Router } from 'express';
import { TripController } from '../controllers/trip.controller';

const router = Router();
const controller = new TripController();

// Trip CRUD
router.get('/', controller.getAllTrips);
router.get('/active', controller.getActiveTrips);
router.get('/:id', controller.getTripById);
router.post('/', controller.createTrip);
router.patch('/:id/status', controller.updateTripStatus);

// Trip monitoring data
router.get('/:id/alerts', controller.getTripAlerts);
router.get('/:id/location-history', controller.getLocationHistory);
router.get('/:id/sos-events', controller.getSOSEvents);

// Demo endpoints
router.post('/demo/create', controller.createDemoTrip);

export const tripRoutes = router;

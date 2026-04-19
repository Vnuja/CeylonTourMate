// CeylonTourMate — Location History Model
import mongoose, { Schema, Document } from 'mongoose';

export interface ILocationHistory extends Document {
  tripId: string;
  driverId: string;
  latitude: number;
  longitude: number;
  speed: number;
  heading: number;
  accuracy?: number;
  timestamp: Date;
}

const LocationHistorySchema = new Schema({
  tripId: { type: String, required: true, index: true },
  driverId: { type: String, required: true },
  latitude: { type: Number, required: true },
  longitude: { type: Number, required: true },
  speed: { type: Number, default: 0 },
  heading: { type: Number, default: 0 },
  accuracy: { type: Number },
  timestamp: { type: Date, default: Date.now, index: true },
});

// Compound index for efficient queries
LocationHistorySchema.index({ tripId: 1, timestamp: -1 });

// TTL index — auto-delete location data older than 30 days
LocationHistorySchema.index({ timestamp: 1 }, { expireAfterSeconds: 30 * 24 * 3600 });

export const LocationHistory = mongoose.model<ILocationHistory>(
  'LocationHistory',
  LocationHistorySchema
);

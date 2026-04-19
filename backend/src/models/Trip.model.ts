// CeylonTourMate — Trip Model (MongoDB/Mongoose)
import mongoose, { Schema, Document } from 'mongoose';

export interface ITrip extends Document {
  packageId: string;
  packageName: string;
  touristIds: string[];
  driverId: string;
  guideId: string;
  vehicleInfo: {
    plateNumber: string;
    type: 'car' | 'van' | 'bus' | 'tuk-tuk';
    model: string;
    color: string;
  };
  plannedRoute: Array<{ latitude: number; longitude: number; timestamp?: Date }>;
  waypoints: Array<{
    name: string;
    location: { latitude: number; longitude: number };
    type: 'pickup' | 'dropoff' | 'attraction' | 'rest' | 'meal';
    estimatedArrival: Date;
    actualArrival?: Date;
    duration: number;
    visited: boolean;
  }>;
  status: 'scheduled' | 'active' | 'paused' | 'completed' | 'cancelled' | 'emergency';
  startTime: Date;
  estimatedEndTime: Date;
  actualEndTime?: Date;
  progress: number;
  distanceTotal: number;
  distanceRemaining: number;
  currentETA: Date;
  createdAt: Date;
  updatedAt: Date;
}

const WaypointSchema = new Schema({
  name: { type: String, required: true },
  location: {
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true },
  },
  type: {
    type: String,
    enum: ['pickup', 'dropoff', 'attraction', 'rest', 'meal'],
    default: 'attraction',
  },
  estimatedArrival: { type: Date },
  actualArrival: { type: Date },
  duration: { type: Number, default: 30 }, // minutes
  visited: { type: Boolean, default: false },
});

const TripSchema = new Schema(
  {
    packageId: { type: String, required: true, index: true },
    packageName: { type: String, required: true },
    touristIds: [{ type: String }],
    driverId: { type: String, required: true, index: true },
    guideId: { type: String, required: true },
    vehicleInfo: {
      plateNumber: { type: String, required: true },
      type: { type: String, enum: ['car', 'van', 'bus', 'tuk-tuk'], default: 'van' },
      model: { type: String },
      color: { type: String },
    },
    plannedRoute: [
      {
        latitude: Number,
        longitude: Number,
        timestamp: Date,
      },
    ],
    waypoints: [WaypointSchema],
    status: {
      type: String,
      enum: ['scheduled', 'active', 'paused', 'completed', 'cancelled', 'emergency'],
      default: 'scheduled',
      index: true,
    },
    startTime: { type: Date },
    estimatedEndTime: { type: Date },
    actualEndTime: { type: Date },
    progress: { type: Number, default: 0, min: 0, max: 100 },
    distanceTotal: { type: Number, default: 0 },
    distanceRemaining: { type: Number, default: 0 },
    currentETA: { type: Date },
  },
  {
    timestamps: true,
  }
);

// Index for finding active trips
TripSchema.index({ status: 1, driverId: 1 });
TripSchema.index({ status: 1, touristIds: 1 });

export const Trip = mongoose.model<ITrip>('Trip', TripSchema);

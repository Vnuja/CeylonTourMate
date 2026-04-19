// CeylonTourMate — Alert Model
import mongoose, { Schema, Document } from 'mongoose';

export interface IAlert extends Document {
  tripId: string;
  type: string;
  severity: 'safe' | 'warning' | 'danger';
  title: string;
  message: string;
  coordinates: { latitude: number; longitude: number };
  data?: Record<string, any>;
  acknowledged: boolean;
  acknowledgedBy?: string;
  resolvedAt?: Date;
  timestamp: Date;
}

const AlertSchema = new Schema(
  {
    tripId: { type: String, required: true, index: true },
    type: {
      type: String,
      required: true,
      enum: [
        'route_deviation',
        'speed_anomaly',
        'harsh_braking',
        'unauthorized_stop',
        'geofence_breach',
        'vehicle_stopped',
        'trip_delayed',
        'weather_warning',
      ],
    },
    severity: {
      type: String,
      enum: ['safe', 'warning', 'danger'],
      default: 'warning',
    },
    title: { type: String, required: true },
    message: { type: String, required: true },
    coordinates: {
      latitude: { type: Number, required: true },
      longitude: { type: Number, required: true },
    },
    data: { type: Schema.Types.Mixed },
    acknowledged: { type: Boolean, default: false },
    acknowledgedBy: { type: String },
    resolvedAt: { type: Date },
    timestamp: { type: Date, default: Date.now },
  },
  {
    timestamps: true,
  }
);

AlertSchema.index({ tripId: 1, timestamp: -1 });
AlertSchema.index({ severity: 1, acknowledged: 1 });

export const Alert = mongoose.model<IAlert>('Alert', AlertSchema);

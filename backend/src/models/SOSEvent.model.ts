// CeylonTourMate — SOS Event Model
import mongoose, { Schema, Document } from 'mongoose';

export interface ISOSEvent extends Document {
  tripId: string;
  touristId: string;
  touristName: string;
  latitude: number;
  longitude: number;
  message?: string;
  status: 'triggered' | 'acknowledged' | 'responding' | 'resolved' | 'cancelled';
  respondedBy?: string;
  triggeredAt: Date;
  acknowledgedAt?: Date;
  resolvedAt?: Date;
  outcome?: string;
}

const SOSEventSchema = new Schema(
  {
    tripId: { type: String, required: true, index: true },
    touristId: { type: String, required: true },
    touristName: { type: String, default: 'Tourist' },
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true },
    message: { type: String },
    status: {
      type: String,
      enum: ['triggered', 'acknowledged', 'responding', 'resolved', 'cancelled'],
      default: 'triggered',
    },
    respondedBy: { type: String },
    triggeredAt: { type: Date, default: Date.now },
    acknowledgedAt: { type: Date },
    resolvedAt: { type: Date },
    outcome: { type: String },
  },
  {
    timestamps: true,
  }
);

SOSEventSchema.index({ status: 1, triggeredAt: -1 });

export const SOSEvent = mongoose.model<ISOSEvent>('SOSEvent', SOSEventSchema);

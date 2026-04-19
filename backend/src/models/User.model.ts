// CeylonTourMate — User Model
import mongoose, { Schema, Document } from 'mongoose';

export interface IUser extends Document {
  email: string;
  password?: string;
  displayName: string;
  photoURL?: string;
  role: 'tourist' | 'guide' | 'driver' | 'agency_admin' | 'system_admin';
  phone?: string;
  firebaseUid?: string;
  interests: string[];
  healthConditions: string[];
  fitnessLevel: 'low' | 'moderate' | 'high';
  dietaryRestrictions: string[];
  allergens: string[];
  emergencyContacts: Array<{
    name: string;
    phone: string;
    relationship: string;
  }>;
  pastTours: string[];
  createdAt: Date;
  updatedAt: Date;
}

const UserSchema = new Schema(
  {
    email: { type: String, required: true, unique: true, lowercase: true },
    password: { type: String, select: false },
    displayName: { type: String, required: true },
    photoURL: { type: String },
    role: {
      type: String,
      enum: ['tourist', 'guide', 'driver', 'agency_admin', 'system_admin'],
      default: 'tourist',
    },
    phone: { type: String },
    firebaseUid: { type: String, unique: true, sparse: true },
    interests: [{ type: String }],
    healthConditions: [{ type: String }],
    fitnessLevel: {
      type: String,
      enum: ['low', 'moderate', 'high'],
      default: 'moderate',
    },
    dietaryRestrictions: [{ type: String }],
    allergens: [{ type: String }],
    emergencyContacts: [
      {
        name: String,
        phone: String,
        relationship: String,
      },
    ],
    pastTours: [{ type: String }],
  },
  {
    timestamps: true,
    toJSON: {
      virtuals: true,
      transform: (_doc, ret) => {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
    toObject: {
      virtuals: true,
      transform: (_doc, ret) => {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

export const User = mongoose.model<IUser>('User', UserSchema);

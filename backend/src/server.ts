// CeylonTourMate — Backend Server Entry Point
import express from 'express';
import http from 'http';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { Server as SocketIOServer } from 'socket.io';
import { connectDatabase } from './config/database';
import { createRedisClient } from './config/redis';
import { setupMonitoringSocket } from './sockets/monitoring.socket';
import { tripRoutes } from './routes/trip.routes';
import { authRoutes } from './routes/auth.routes';
import { errorMiddleware } from './middleware/error.middleware';

dotenv.config();

const PORT = process.env.PORT || 3001;

async function startServer() {
  const app = express();
  const server = http.createServer(app);

  // ─── Middleware ───
  app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
  app.use(helmet());
  app.use(morgan('dev'));
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));

  // ─── Health check ───
  app.get('/health', (_req, res) => {
    res.json({
      status: 'ok',
      service: 'CeylonTourMate API',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    });
  });

  // ─── API Routes ───
  app.use('/api/auth', authRoutes);
  app.use('/api/trips', tripRoutes);

  // Placeholder routes for future modules
  app.get('/api/packages', (_req, res) => {
    res.json({ message: 'Smart Packages — Coming Soon', data: [] });
  });
  app.get('/api/places', (_req, res) => {
    res.json({ message: 'Place Lens — Coming Soon', data: [] });
  });

  // ─── Error handling ───
  app.use(errorMiddleware);

  // ─── Database ───
  await connectDatabase();

  // ─── Redis ───
  let redis;
  try {
    redis = createRedisClient();
    console.log('✅ Redis client created');
  } catch (err) {
    console.warn('⚠️  Redis unavailable — running without cache');
  }

  // ─── Socket.IO ───
  const io = new SocketIOServer(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
    pingTimeout: 60000,
    pingInterval: 25000,
  });

  // Setup monitoring sockets (CORE)
  setupMonitoringSocket(io, redis);

  // ─── Start server ───
  server.listen(PORT, () => {
    console.log(`\n🇱🇰 CeylonTourMate API Server`);
    console.log(`   ├─ HTTP:   http://localhost:${PORT}`);
    console.log(`   ├─ Socket: ws://localhost:${PORT}`);
    console.log(`   ├─ Health: http://localhost:${PORT}/health`);
    console.log(`   └─ Env:    ${process.env.NODE_ENV || 'development'}\n`);
  });
}

startServer().catch((err) => {
  console.error('❌ Failed to start server:', err);
  process.exit(1);
});

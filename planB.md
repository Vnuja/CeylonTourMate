# CeylonTourMate — Focused Implementation Plan

## Scope

**CORE (Full Implementation):** Module 2 — Live Monitoring System
- Real-time GPS vehicle tracking with animated map markers
- Safety anomaly detection (speed, route deviation, harsh braking, geofence)
- SOS emergency system with long-press activation
- Alert feed with color-coded severity cards
- Socket.IO real-time communication with Redis

**Placeholders (Screens + Navigation only):**
- Module 1 — Smart Recommendations (placeholder screen with "Coming Soon")
- Module 3 — Image AI / Food Recognition (placeholder screen)
- Module 4 — Place Lens (placeholder screen)

## Architecture

```
CeylonTourMate/
├── mobile/                    # Expo React Native (TypeScript)
│   ├── src/
│   │   ├── navigation/        # Stack + Tab navigators, role-based
│   │   ├── screens/
│   │   │   ├── auth/          # Login, Register, Splash
│   │   │   ├── home/          # HomeScreen
│   │   │   ├── live/          # ★ CORE — LiveMonitorScreen (full)
│   │   │   ├── tours/         # Placeholder
│   │   │   ├── scan/          # Placeholder
│   │   │   └── places/        # Placeholder
│   │   ├── components/
│   │   │   ├── live/          # ★ VehicleMarker, AlertCard, SOSButton, etc.
│   │   │   ├── common/        # Header, LoadingScreen, PlaceholderScreen
│   │   │   └── ...
│   │   ├── store/             # Zustand stores
│   │   ├── services/          # API + Socket.IO
│   │   ├── hooks/             # Custom hooks
│   │   ├── theme/             # Colors, typography, spacing
│   │   └── types/             # TypeScript interfaces
│   └── app.config.js
│
├── backend/                   # Node.js + Express + TypeScript
│   └── src/
│       ├── config/            # DB, Redis, Firebase, env
│       ├── middleware/        # Auth, error handling, rate limit
│       ├── models/            # Mongoose schemas
│       ├── routes/            # Express routes
│       ├── controllers/       # Route handlers
│       ├── services/          # ★ safety.service.ts (anomaly detection)
│       ├── sockets/           # ★ monitoring.socket.ts (real-time)
│       └── server.ts          # Entry point
│
├── ai-service/                # Python FastAPI (placeholder)
│   └── app/
│       ├── main.py            # FastAPI with placeholder endpoints
│       └── routers/           # Stub routes
│
├── docker-compose.yml         # Local dev (MongoDB + Redis)
└── README.md
```

## Build Order
1. Project scaffolds (mobile + backend + AI service)
2. Theme, types, stores, services
3. Navigation with role-based routing
4. ★ Live Monitoring Screen (CORE) — full UI
5. ★ Backend real-time (Socket.IO + Safety service)
6. Placeholder screens for Modules 1, 3, 4
7. Auth screens (basic)
8. Docker compose + local dev setup

/**
 * Route Compliance & Geo-Fencing Module
 * Handles monitoring of route adherence and boundary checks.
 */

import { showSnackbar } from './notifications.js';
import { db, auth } from './firebase-config.js';
import { doc, setDoc, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";

// ── Configuration & Zones ──────────────────────────────────────
const GEOFENCE_ZONES = [
    {
        id: 'safe-kandy',
        name: 'Kandy Safe Zone',
        center: { lat: 7.2906, lng: 80.6337 },
        radius: 5000, // 5km
        type: 'safe',
        speedLimit: 40 // Urban limit
    },
    {
        id: 'danger-ella',
        name: 'Ella High-Risk Curve',
        center: { lat: 6.8724, lng: 81.0470 },
        radius: 2000, // 2km
        type: 'danger',
        speedLimit: 25 // Very slow for safety
    },
    {
        id: 'risk-colombo',
        name: 'Colombo Traffic Area',
        center: { lat: 6.9271, lng: 79.8612 },
        radius: 3000, // 3km
        type: 'warning',
        speedLimit: 50 // Standard urban
    },
    {
        id: 'highway-kadawatha',
        name: 'Kadawatha Highway',
        center: { lat: 7.0011, lng: 79.9515 },
        radius: 4000,
        type: 'safe',
        speedLimit: 100 // Expressway
    },
    {
        id: 'town-nittambuwa',
        name: 'Nittambuwa Town',
        center: { lat: 7.1444, lng: 80.0911 },
        radius: 2000,
        type: 'warning',
        speedLimit: 50
    },
    {
        id: 'town-warakapola',
        name: 'Warakapola Town',
        center: { lat: 7.2222, lng: 80.1981 },
        radius: 2000,
        type: 'warning',
        speedLimit: 50
    },
    {
        id: 'town-kegalle',
        name: 'Kegalle City',
        center: { lat: 7.2514, lng: 80.3464 },
        radius: 2500,
        type: 'warning',
        speedLimit: 40 // Hilly/Busy
    },
    {
        id: 'town-peradeniya',
        name: 'Peradeniya Junction',
        center: { lat: 7.2684, lng: 80.5966 },
        radius: 2000,
        type: 'warning',
        speedLimit: 40
    }
];

const COMPLIANCE_CONFIG = {
    DEVIATION_THRESHOLD_METERS: 500, // 500m deviation triggers alert
    STOP_THRESHOLD_MS: 300000,      // 5 minutes (300,000ms) for unauthorized stop
    SYNC_INTERVAL_MS: 10000,         // Sync compliance status every 10s
};

// ── State ──────────────────────────────────────────────────────
export const plannedTowns = [
    { lat: 6.933017796236391, lng: 79.8493524012534 }, // Fort (Start)
    { lat: 6.8921, lng: 80.2012 }, // Avissawella
    { lat: 6.6828, lng: 80.3992 }, // Ratnapura
    { lat: 6.6231, lng: 80.5406 }, // Pelmadulla
    { lat: 6.6500, lng: 80.7000 }, // Balangoda
    { lat: 6.7644, lng: 80.9161 }, // Beragala
    { lat: 6.7702, lng: 80.9575 }, // Haputale
    { lat: 6.8724, lng: 81.0470 }  // Ella (End)
];

export let targetRoute = [...plannedTowns];

let currentZone = null;
let lastSyncTime = 0;
export let isDeviated = false;
let stopStartTime = null;
let isStopAlertActive = false;
let lastSpeedAlertTime = 0;
const SPEED_COOLDOWN = 10000; // 10s cooldown between speeding alerts

// DOM Elements
let deviationValEl = null;
let geofenceStatusEl = null;
let complianceStatusShield = null;
let routeCard = null;
let geofenceCard = null;

// ── Public API ─────────────────────────────────────────────────

export function initComplianceModule() {
    console.log('[Compliance] Initializing module...');
    
    // Cache DOM
    deviationValEl = document.getElementById('route-deviation-val');
    geofenceStatusEl = document.getElementById('geofence-status-val');
    complianceStatusShield = document.getElementById('compliance-status');
    routeCard = document.getElementById('route-card');
    geofenceCard = document.getElementById('geofence-card');
}
 
/**
 * Update the target route points (usually called from Map module after Directions API)
 */
export function setTargetRoute(newRoute) {
    if (!newRoute || !Array.isArray(newRoute)) return;
    targetRoute = newRoute;
    console.log(`[Compliance] Route updated with ${targetRoute.length} points.`);
}

/**
 * Process new GPS position for compliance and geo-fencing
 */
export function processPositionUpdate(pos, speed = 0) {
    if (!pos) return;

    // 1. Check Geo-Fencing
    const zone = checkGeoFencing(pos);
    updateGeoFenceUI(zone);

    // 2. Check Route Compliance
    const deviation = calculateRouteDeviation(pos);
    updateRouteUI(deviation);

    // 3. Check Unauthorized Stops
    checkUnauthorizedStop(speed, zone);

    // 4. Check Speeding
    checkSpeedLimit(speed, zone);

    // 5. Overall status update
    updateOverallStatus(zone, deviation);

    // 6. Sync to Firebase
    syncComplianceToFirebase(zone, deviation);
}

function checkUnauthorizedStop(speed, zone) {
    // If vehicle is moving or in a safe zone, reset stop timer
    if (speed > 2 || zone?.type === 'safe') {
        stopStartTime = null;
        isStopAlertActive = false;
        return;
    }

    // Vehicle is stopped (speed < 2km/h) and not in a safe zone
    if (!stopStartTime) {
        stopStartTime = Date.now();
        return;
    }

    const stopDuration = Date.now() - stopStartTime;
    if (stopDuration > COMPLIANCE_CONFIG.STOP_THRESHOLD_MS && !isStopAlertActive) {
        isStopAlertActive = true;
        showSnackbar('Unauthorized Stop Detected: Please report your status.', 'warning', 8000);
        console.log('[Compliance] 🚨 Unauthorized Stop Alert!');
    }
}

/**
 * Compare current speed against zone-specific or default speed limits.
 */
function checkSpeedLimit(speed, zone) {
    const limit = zone?.speedLimit || 70; // Default 70 km/h for open roads
    
    if (speed > limit) {
        const now = Date.now();
        if (now - lastSpeedAlertTime > SPEED_COOLDOWN) {
            console.warn(`[Safety] Speeding Detected: ${Math.round(speed)} km/h in ${limit} km/h zone`);
            showSnackbar(`🚨 SLOW DOWN: Exceeding speed limit in ${zone ? zone.name : 'this area'} (${Math.round(speed)}/${limit} km/h)`, 'error', 7000);
            lastSpeedAlertTime = now;
            
            // Trigger intense vibration for speeding
            if (navigator.vibrate && navigator.userActivation?.hasBeenActive) {
                navigator.vibrate([300, 100, 300, 100, 300]);
            }
        }
    }
}

// ── Logic ──────────────────────────────────────────────────────

function checkGeoFencing(pos) {
    for (const zone of GEOFENCE_ZONES) {
        const distance = calculateDistance(pos, zone.center);
        if (distance <= zone.radius) {
            return zone;
        }
    }
    return null;
}

function calculateRouteDeviation(pos) {
    if (!targetRoute || targetRoute.length === 0) return 0;

    let minDistance = Infinity;
    
    // Find distance to the closest segment/point on target route
    for (const point of targetRoute) {
        const d = calculateDistance(pos, point);
        if (d < minDistance) minDistance = d;
    }

    return minDistance;
}

/**
 * Haversine distance formula
 */
function calculateDistance(p1, p2) {
    const R = 6371000; // Earth radius in meters
    const dLat = (p2.lat - p1.lat) * Math.PI / 180;
    const dLng = (p2.lng - p1.lng) * Math.PI / 180;
    const a = 
        Math.sin(dLat/2) * Math.sin(dLat/2) +
        Math.cos(p1.lat * Math.PI / 180) * Math.cos(p2.lat * Math.PI / 180) * 
        Math.sin(dLng/2) * Math.sin(dLng/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
}

// ── UI Updates ─────────────────────────────────────────────────

function updateGeoFenceUI(zone) {
    if (!geofenceStatusEl || !geofenceCard) return;

    if (zone) {
        geofenceStatusEl.textContent = zone.name;
        geofenceCard.className = `stat-card ${zone.type}`;
        
        if (zone.id !== currentZone?.id) {
            const typeLabel = zone.type.charAt(0).toUpperCase() + zone.type.slice(1);
            showSnackbar(`Entered ${zone.name} (${typeLabel} Zone)`, zone.type === 'safe' ? 'info' : zone.type);
        }
        currentZone = zone;
    } else {
        geofenceStatusEl.textContent = 'Normal Area';
        geofenceCard.className = 'stat-card';
        currentZone = null;
    }
}

function updateRouteUI(deviation) {
    if (!deviationValEl || !routeCard) return;

    const devMeters = Math.round(deviation);
    deviationValEl.textContent = devMeters >= 1000 ? `${(devMeters/1000).toFixed(1)}km` : `${devMeters}m`;

    if (devMeters > COMPLIANCE_CONFIG.DEVIATION_THRESHOLD_METERS) {
        routeCard.classList.add('deviation');
        if (!isDeviated) {
            showSnackbar(`Route Deviation Detected: ${devMeters}m off path`, 'warning');
            if (navigator.vibrate && navigator.userActivation?.hasBeenActive) {
                navigator.vibrate([200, 100, 200]);
            }
        }
        isDeviated = true;
    } else {
        routeCard.classList.remove('deviation');
        isDeviated = false;
    }
}

function updateOverallStatus(zone, deviation) {
    if (!complianceStatusShield) return;

    const isHighRisk = zone?.type === 'danger' || deviation > COMPLIANCE_CONFIG.DEVIATION_THRESHOLD_METERS * 2;
    const isWarning = zone?.type === 'warning' || deviation > COMPLIANCE_CONFIG.DEVIATION_THRESHOLD_METERS;

    if (isHighRisk) {
        complianceStatusShield.className = 'drowsy-shield danger';
        complianceStatusShield.innerHTML = '<span class="material-symbols-rounded">gpp_maybe</span> High Risk';
    } else if (isWarning) {
        complianceStatusShield.className = 'drowsy-shield warning';
        complianceStatusShield.innerHTML = '<span class="material-symbols-rounded">warning</span> Deviation';
    } else {
        complianceStatusShield.className = 'drowsy-shield safe';
        complianceStatusShield.innerHTML = '<span class="material-symbols-rounded">check_circle</span> On Route';
    }
}

// ── Firebase Sync ──────────────────────────────────────────────

async function syncComplianceToFirebase(zone, deviation) {
    if (!db || !auth.currentUser) return;

    const now = Date.now();
    // Sync if significant deviation OR zone change OR interval passed
    const isCritical = deviation > COMPLIANCE_CONFIG.DEVIATION_THRESHOLD_METERS || zone?.type === 'danger';
    
    if (!isCritical && (now - lastSyncTime < COMPLIANCE_CONFIG.SYNC_INTERVAL_MS)) return;
    lastSyncTime = now;

    try {
        const driverId = auth.currentUser.uid;
        const complianceData = {
            driverId: driverId,
            driverName: auth.currentUser.displayName || auth.currentUser.email?.split('@')[0] || 'Driver',
            driverEmail: auth.currentUser.email || '',
            onRoute: !isDeviated,
            deviationMeters: Math.round(deviation),
            currentZone: zone ? {
                id: zone.id,
                name: zone.name,
                type: zone.type
            } : null,
            complianceTimestamp: serverTimestamp()
        };

        await setDoc(doc(db, "active_trips", driverId), complianceData, { merge: true });
        console.log('[Firebase] Compliance synced');

    } catch (err) {
        console.error('[Firebase] Compliance sync failed:', err);
    }
}

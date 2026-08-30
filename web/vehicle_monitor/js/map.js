import { showSnackbar } from "./notifications.js";
import { processPositionUpdate, targetRoute, setTargetRoute, isDeviated, plannedTowns } from "./compliance.js";

let map;
let marker;
let polyline; // Actual trail (Red)
let plannedPolyline; // Target route (Green)
let mapInitPromise;
let watchId = null;
let routePath = [];
let lastPosition = null;
let lastTimestamp = null;
let geocoder = null;
let directionsService = null;
let directionsRenderer = null;
let deviationRenderer = null; // New Red renderer for off-route
let lastGeocodePos = null;
let lastTownName = null;
let isGeocoding = false;
let lastBrakeAlertTime = 0;
let lastDeviationRecalcTime = 0;
const DEVIATION_RECALC_INTERVAL = 10000; // Recalculate red route every 10s if off-track
const BRAKE_THRESHOLD = 15; // km/h drop per second
const BRAKE_COOLDOWN = 5000; // 5 seconds cooldown between alerts

// Export to window for Google Maps callback coordination
window.checkAndInitMap = initMapModule;

// If the API already loaded and called the stub, initialize now
if (window.mapsApiLoaded) {
    initMapModule();
}

export async function initMapModule() {

    if (mapInitPromise) return mapInitPromise;

    console.log("initMapModule called...");

    // Wait for the DOM element to be available (useful if dashboard isn't loaded yet)
    let mapElement = document.getElementById('google-map');
    let retryCount = 0;
    while (!mapElement && retryCount < 30) {
        await new Promise(resolve => setTimeout(resolve, 300));
        mapElement = document.getElementById('google-map');
        retryCount++;
    }

    if (!mapElement) {
        console.warn("Map element #google-map not found after waiting.");
        return;
    }

    const recenterBtn = document.getElementById('recenter-map');

    mapInitPromise = initializeMap(mapElement, recenterBtn).catch((error) => {
        mapInitPromise = null;
        console.error("Error initializing map module:", error);
    });

    return mapInitPromise;
}

async function initializeMap(mapElement, recenterBtn) {
    console.log("Initializing Map Module...");
    
    if (typeof google === 'undefined' || !google.maps) {
        console.error("Google Maps API not loaded.");
        return;
    }

    try {
        console.log("Creating map instance...");

        const MapConstructor = google.maps.Map;
        const PolylineConstructor = google.maps.Polyline;
        
        let AdvancedMarkerElement;
        let PinElement;

        if (google.maps.marker) {
            AdvancedMarkerElement = google.maps.marker.AdvancedMarkerElement;
            PinElement = google.maps.marker.PinElement;
        } else {
            const markerLibrary = await google.maps.importLibrary("marker");
            AdvancedMarkerElement = markerLibrary.AdvancedMarkerElement;
            PinElement = markerLibrary.PinElement;
        }

        if (typeof MapConstructor !== 'function') {
            throw new Error("Map constructor not found.");
        }

        // Default center (Sri Lanka) — will be overridden by real GPS
        const defaultCenter = { lat: 7.8731, lng: 80.7718 };

        map = new MapConstructor(mapElement, {
            center: defaultCenter,
            zoom: 15,
            disableDefaultUI: true,
            mapId: "4504f8b37365c3ae"
        });

        const pin = new PinElement({
            background: "#1a73e8",
            borderColor: "#ffffff",
            glyphColor: "#ffffff",
            scale: 1.2
        });

        marker = new AdvancedMarkerElement({
            position: defaultCenter,
            map: map,
            title: "My Vehicle",
            content: pin
        });

        polyline = new PolylineConstructor({
            path: [],
            geodesic: true,
            strokeColor: '#ff5252', // Red for actual trail
            strokeOpacity: 0.8,
            strokeWeight: 4,
            map: map
        });

        // Planned Route Polyline (Green)
        plannedPolyline = new PolylineConstructor({
            path: targetRoute,
            geodesic: true,
            strokeColor: '#4caf50', // Green for planned route
            strokeOpacity: 0.6,
            strokeWeight: 6,
            map: map
        });

        geocoder = new google.maps.Geocoder();
        directionsService = new google.maps.DirectionsService();
        directionsRenderer = new google.maps.DirectionsRenderer({
            map: map,
            suppressMarkers: true, // We use our own markers
            polylineOptions: {
                strokeColor: '#4caf50',
                strokeWeight: 6,
                strokeOpacity: 0.8
            }
        });

        // Initialize Deviation Renderer (Red)
        deviationRenderer = new google.maps.DirectionsRenderer({
            map: map,
            suppressMarkers: true,
            polylineOptions: {
                strokeColor: '#ff5252', // Red for "wrong road" path
                strokeWeight: 5,
                strokeOpacity: 0.7,
                zIndex: 50 // Slightly below the main green route or above? User said "under"
            }
        });

        // Fetch real road route
        calculateAndDisplayRoute();

        if (recenterBtn) {
            recenterBtn.addEventListener('click', () => {
                if (marker) {
                    map.panTo(marker.position);
                    map.setZoom(16);
                }
            });
        }

        // Start real GPS tracking
        startLiveTracking();

    } catch (error) {
        console.error("Failed to initialize map:", error);
        throw error;
    }
}

/**
 * Start watching the device's real GPS position.
 * Uses navigator.geolocation.watchPosition for continuous updates.
 */
function startLiveTracking() {
    if (!navigator.geolocation) {
        console.error("Geolocation is not supported by this browser.");
        showSnackbar("GPS not supported on this device.", "error");
        updateLocationUI(null, null, "GPS not supported");
        return;
    }

    showSnackbar("Acquiring GPS signal...", "info");

    watchId = navigator.geolocation.watchPosition(
        (position) => handlePositionUpdate(position),
        (error) => handlePositionError(error),
        {
            enableHighAccuracy: true,
            maximumAge: 3000,        // Accept cached position up to 3s old
            timeout: 15000           // Wait up to 15s for a fix
        }
    );

    console.log("GPS watchPosition started, watchId:", watchId);
}

/**
 * Called every time the device reports a new GPS position.
 */
function handlePositionUpdate(position) {
    const { latitude, longitude, speed, accuracy, heading } = position.coords;
    const timestamp = position.timestamp;

    const newPos = { lat: latitude, lng: longitude };

    console.log(`GPS Update — Lat: ${latitude.toFixed(5)}, Lng: ${longitude.toFixed(5)}, ` +
                `Speed: ${speed}, Accuracy: ${accuracy?.toFixed(1)}m`);

    // --- Calculate speed ---
    let speedKmh = 0;

    if (speed !== null && speed !== undefined && speed >= 0) {
        // Geolocation API reports speed in m/s
        speedKmh = speed * 3.6;
    } else if (lastPosition && lastTimestamp) {
        // Fallback: compute speed from distance / time between updates
        speedKmh = computeSpeedFallback(lastPosition, newPos, lastTimestamp, timestamp);
    }

    // --- Calculate heading/rotation ---
    let rotation = heading || 0;
    if ((!heading || heading < 0) && lastPosition && google.maps.geometry?.spherical) {
        try {
            const from = new google.maps.LatLng(lastPosition.lat, lastPosition.lng);
            const to = new google.maps.LatLng(latitude, longitude);
            rotation = google.maps.geometry.spherical.computeHeading(from, to);
        } catch (e) {
            rotation = 0;
        }
    }

    // --- Update marker ---
    if (marker) {
        marker.position = newPos;
        if (marker.content?.style) {
            marker.content.style.transform = `rotate(${rotation}deg)`;
        }
    }

    // --- Update polyline trail ---
    routePath.push(new google.maps.LatLng(latitude, longitude));
    if (polyline) {
        polyline.setPath(routePath);
    }

    // --- Pan map to follow ---
    if (map) {
        map.panTo(newPos);
    }

    // --- Update dashboard UI ---
    updateLocationUI(newPos, speedKmh, null, accuracy);

    // --- Update Town Name (Reverse Geocoding) ---
    updateTownName(newPos);

    // --- Process Compliance & Geo-Fencing ---
    processPositionUpdate(newPos, speedKmh);

    // --- Detect Sudden Brake ---
    detectSuddenBrake(speedKmh, timestamp);
    
    // --- Off-Route Recalculation (Red Route) ---
    handleOffRouteRecalc(newPos);

    // --- Save state for next calculation ---
    lastPosition = newPos;
    lastTimestamp = timestamp;
    lastSpeedKmh = speedKmh;
}

/**
 * Detect sudden deceleration (braking).
 */
function detectSuddenBrake(currentSpeed, currentTimestamp) {
    if (lastSpeedKmh === null || lastTimestamp === null) return;

    const timeDiffSeconds = (currentTimestamp - lastTimestamp) / 1000;
    
    // Ignore updates that are too far apart or too close
    if (timeDiffSeconds <= 0.1 || timeDiffSeconds > 3) return;

    const deceleration = (lastSpeedKmh - currentSpeed) / timeDiffSeconds;

    // Check if deceleration exceeds threshold and cooldown has passed
    if (deceleration > BRAKE_THRESHOLD) {
        const now = Date.now();
        if (now - lastBrakeAlertTime > BRAKE_COOLDOWN) {
            console.warn(`[Safety] Sudden Brake Detected: ${deceleration.toFixed(1)} km/h/s`);
            showSnackbar("⚠️ Sudden Braking Detected!", "warning");
            lastBrakeAlertTime = now;
            
            // Trigger vibration if supported
            if (navigator.vibrate && navigator.userActivation?.hasBeenActive) {
                navigator.vibrate([100, 50, 100]);
            }
        }
    }
}

let lastSpeedKmh = 0;

/**
 * Get the most recent GPS coordinates
 */
export function getCurrentPosition() {
    return lastPosition;
}

/**
 * Get the most recent calculated speed
 */
export function getCurrentSpeed() {
    return lastSpeedKmh;
}

/**
 * Fallback speed calculation when device doesn't provide coords.speed.
 * Uses Haversine distance between two GPS points divided by elapsed time.
 */
function computeSpeedFallback(prevPos, newPos, prevTime, newTime) {
    const R = 6371000; // Earth radius in meters
    const dLat = toRad(newPos.lat - prevPos.lat);
    const dLng = toRad(newPos.lng - prevPos.lng);
    const a = Math.sin(dLat / 2) ** 2 +
              Math.cos(toRad(prevPos.lat)) * Math.cos(toRad(newPos.lat)) *
              Math.sin(dLng / 2) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const distanceMeters = R * c;

    const elapsedSeconds = (newTime - prevTime) / 1000;
    if (elapsedSeconds <= 0) return 0;

    const speedMs = distanceMeters / elapsedSeconds;
    return speedMs * 3.6; // Convert m/s → km/h
}

function toRad(deg) {
    return deg * (Math.PI / 180);
}

/**
 * Handle geolocation errors gracefully.
 */
function handlePositionError(error) {
    let message = "GPS error.";
    switch (error.code) {
        case error.PERMISSION_DENIED:
            message = "Location permission denied. Please allow GPS access.";
            break;
        case error.POSITION_UNAVAILABLE:
            message = "GPS signal unavailable.";
            break;
        case error.TIMEOUT:
            message = "GPS request timed out.";
            break;
    }
    console.error("Geolocation error:", error.code, error.message);
    showSnackbar(message, "error");
    updateLocationUI(null, null, message);
}

/**
 * Perform reverse geocoding to get the nearest town name.
 * Throttled to avoid excessive API calls.
 */
async function updateTownName(pos) {
    if (!geocoder || !pos) return;

    // Only geocode if we moved more than ~100m or if it's the first time
    if (lastGeocodePos && google.maps.geometry?.spherical) {
        try {
            const dist = google.maps.geometry.spherical.computeDistanceBetween(
                new google.maps.LatLng(lastGeocodePos.lat, lastGeocodePos.lng),
                new google.maps.LatLng(pos.lat, pos.lng)
            );
            if (dist < 100 && lastTownName) return;
        } catch (e) {
            console.warn("Spherical geometry not available.");
        }
    }

    if (isGeocoding) return;
    isGeocoding = true;

    try {
        const response = await geocoder.geocode({ location: pos });
        if (response.results && response.results[0]) {
            const result = response.results[0];
            const sublocality = result.address_components.find(c => c.types.includes("sublocality_level_1"));
            const locality = result.address_components.find(c => c.types.includes("locality"));
            const town = sublocality?.long_name || locality?.long_name || "Unknown Area";
            
            applyTownName(town, pos);
        }
    } catch (error) {
        console.warn("Google Geocoding failed, trying fallback...", error.message);
        if (error.message && error.message.includes("REQUEST_DENIED")) {
            // Automatic fallback to OpenStreetMap if Google API is restricted
            await fallbackReverseGeocode(pos);
        }
    } finally {
        isGeocoding = false;
    }
}

/**
 * Fallback geocoder using OpenStreetMap (Nominatim)
 * No API key required for low-volume research use.
 */
async function fallbackReverseGeocode(pos) {
    try {
        const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.lat}&lon=${pos.lng}&zoom=10`;
        const response = await fetch(url, {
            headers: { 'User-Agent': 'CeylonTourMate-VehicleMonitor' }
        });
        const data = await response.json();
        
        if (data && data.address) {
            const town = data.address.suburb || data.address.town || data.address.village || data.address.city || "Unknown Area";
            console.log("Fallback Geocoded Town Name:", town);
            applyTownName(town, pos);
        }
    } catch (error) {
        console.error("Fallback Geocoding also failed:", error);
        // Last resort: show formatted coords
        applyTownName(`${pos.lat.toFixed(4)}, ${pos.lng.toFixed(4)}`, pos, true);
    }
}

function applyTownName(town, pos, isRaw = false) {
    lastTownName = isRaw ? null : town;
    lastGeocodePos = pos;
    
    const locationVal = document.getElementById('location-val');
    if (locationVal) locationVal.innerText = town;

    const locationName = document.getElementById('current-location-name');
    if (locationName) {
        const currentText = locationName.innerText;
        const accuracyPart = currentText.includes("±") ? " · ±" + currentText.split("±")[1] : "";
        locationName.innerText = `${town}${accuracyPart}`;
    }
}

/**
 * Update the dashboard speed / location / status UI cards.
 */
function updateLocationUI(pos, speedKmh, statusMessage, accuracy) {
    const locationName = document.getElementById('current-location-name');
    const speedVal = document.getElementById('speed-val');
    const locationVal = document.getElementById('location-val');

    if (statusMessage) {
        if (locationName) locationName.innerText = statusMessage;
        if (speedVal) speedVal.innerText = "-- km/h";
        if (locationVal) locationVal.innerText = "No signal";
        return;
    }

    if (speedVal && speedKmh !== null) {
        speedVal.innerText = `${speedKmh.toFixed(0)} km/h`;
    }

    if (locationVal && pos) {
        // If we have a town name, keep it. Otherwise show "Locating..."
        if (lastTownName) {
            locationVal.innerText = lastTownName;
        } else {
            locationVal.innerText = "Locating...";
        }
    }

    if (locationName) {
        if (lastTownName) {
            locationName.innerText = `${lastTownName} · ±${accuracy?.toFixed(0) || '0'}m`;
        } else if (accuracy !== undefined && accuracy !== null) {
            locationName.innerText = `GPS Active · ±${accuracy.toFixed(0)}m`;
        }
    }
}

/**
 * Calculate and display the real road route using Google Directions API.
 */
async function calculateAndDisplayRoute() {
    if (!directionsService || !directionsRenderer) return;

    // Create waypoints from intermediate points (excluding start and end)
    const waypoints = plannedTowns.slice(1, -1).map(point => ({
        location: new google.maps.LatLng(point.lat, point.lng),
        stopover: true
    }));

    const request = {
        origin: new google.maps.LatLng(plannedTowns[0].lat, plannedTowns[0].lng),
        destination: new google.maps.LatLng(plannedTowns[plannedTowns.length - 1].lat, plannedTowns[plannedTowns.length - 1].lng),
        waypoints: waypoints,
        optimizeWaypoints: false, // Keep the user's intended order
        travelMode: google.maps.TravelMode.DRIVING
    };

    directionsService.route(request, (result, status) => {
        if (status === 'OK') {
            directionsRenderer.setDirections(result);
            
            // Hide the manual straight-line polyline if we have a real route
            if (plannedPolyline) plannedPolyline.setMap(null);
            
            // Extract the high-fidelity path for compliance monitoring
            const path = result.routes[0].overview_path.map(p => ({
                lat: p.lat(),
                lng: p.lng()
            }));
            setTargetRoute(path);

            console.log("Real route loaded successfully.");
        } else {
            console.error("Directions request failed due to " + status);
            showSnackbar("Could not load road route. Using straight lines.", "warning");
        }
    });
}

/**
 * If the driver is off-route, show a Red path from current location to destination.
 */
function handleOffRouteRecalc(currentPos) {
    if (!isDeviated) {
        if (deviationRenderer) deviationRenderer.setMap(null);
        return;
    }

    const now = Date.now();
    if (now - lastDeviationRecalcTime < DEVIATION_RECALC_INTERVAL) return;
    lastDeviationRecalcTime = now;

    if (!directionsService || !deviationRenderer) return;

    // Ensure it shows on map
    deviationRenderer.setMap(map);

    // Filter waypoints: Only include waypoints from plannedTowns that are "ahead"
    // To keep it simple and follow user request, we include all intermediate towns.
    // Google Maps will efficiently route to the next logical one.
    const waypoints = plannedTowns.slice(1, -1).map(point => ({
        location: new google.maps.LatLng(point.lat, point.lng),
        stopover: true
    }));

    const request = {
        origin: currentPos,
        destination: new google.maps.LatLng(plannedTowns[plannedTowns.length - 1].lat, plannedTowns[plannedTowns.length - 1].lng),
        waypoints: waypoints,
        optimizeWaypoints: true, // Allow Google to skip waypoints we've already passed or that are behind us
        travelMode: google.maps.TravelMode.DRIVING
    };

    directionsService.route(request, (result, status) => {
        if (status === 'OK') {
            deviationRenderer.setDirections(result);
        } else {
            console.warn("Deviation route failed:", status);
        }
    });
}

/**
 * Stop GPS tracking (call when user signs out or leaves dashboard).
 */
export function stopLiveTracking() {
    if (watchId !== null) {
        navigator.geolocation.clearWatch(watchId);
        watchId = null;
        console.log("GPS tracking stopped.");
    }
    routePath = [];
    lastPosition = null;
    lastTimestamp = null;
}

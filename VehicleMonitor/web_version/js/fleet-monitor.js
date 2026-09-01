import { db, auth } from './firebase-config.js';
import { 
    collection, 
    onSnapshot, 
    doc, 
    setDoc, 
    query, 
    orderBy, 
    limit, 
    serverTimestamp 
} from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";
import { onAuthStateChanged, signOut } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-auth.js";

// ── State Management ───────────────────────────────────────────
let vehicles = new Map();
let markers = new Map();
let selectedVehicleId = null;
let inspectedVehicleId = null;
let searchQuery = "";
let drawerFilter = "all";
let map = null;
let geocoder = null;
let trafficLayer = null;
let isSatellite = false;
let AdvancedMarkerElement = null;
let PinElement = null;
const geocodeCache = new Map();
let alertsDocs = [];

// DOM Elements
const vehicleGrid = document.getElementById('vehicle-grid');
const alertsList = document.getElementById('global-alerts-list');
const searchInput = document.querySelector('.header-search input');
const activeCountEl = document.getElementById('active-count');
const warningCountEl = document.getElementById('warning-count');
const dangerCountEl = document.getElementById('danger-count');
const globalAlertCountEl = document.getElementById('global-alert-count');
const controlModal = document.getElementById('control-modal');
const closeModalBtn = document.querySelector('.close-modal');
const signoutBtn = document.getElementById('signout-btn');
const navOverview = document.getElementById('nav-overview');
const navMap = document.getElementById('nav-map');
const overviewSection = document.getElementById('overview-section');
const mapSection = document.getElementById('map-section');

// Map Floating UI Elements
const mapVehicleList = document.getElementById('map-vehicle-list');
const mapFleetDrawer = document.getElementById('map-fleet-drawer');
const mapVehicleDetail = document.getElementById('map-vehicle-detail');
const detailCloseBtn = document.getElementById('detail-close-btn');
const mapBtnFit = document.getElementById('map-btn-fit');
const mapBtnTraffic = document.getElementById('map-btn-traffic');
const mapBtnSatellite = document.getElementById('map-btn-satellite');
const mapBtnToggleList = document.getElementById('map-btn-toggle-list');
const drawerVehicleCount = document.getElementById('drawer-vehicle-count');

// ── Initialization ─────────────────────────────────────────────
function init() {
    console.log('[FleetMonitor] Initializing Admin Dashboard...');

    // 1. Auth Check
    onAuthStateChanged(auth, (user) => {
        if (!user) {
            console.warn('[FleetMonitor] Not authenticated. Redirecting to login...');
            window.location.href = 'index.html';
            return;
        }
        console.log('[FleetMonitor] Admin authenticated:', user.email);
        startListening();
        
        // Start heartbeat to refresh online status UI every 15 seconds
        setInterval(() => {
            renderFleet();
            renderMapDrawer();
            renderGlobalAlertsFeed();
            if (inspectedVehicleId && vehicles.has(inspectedVehicleId)) {
                updateInspectorCard(vehicles.get(inspectedVehicleId));
            }
            if (map) renderMarkers();
        }, 15000);
    });

    // 2. Event Listeners
    const simBtn = document.getElementById('btn-simulate-vehicle');
    if (simBtn) {
        simBtn.onclick = () => simulateDemoVehicle();
    }

    if (closeModalBtn) closeModalBtn.onclick = () => controlModal.classList.remove('active');
    
    if (signoutBtn) {
        signoutBtn.onclick = async () => {
            await signOut(auth);
            window.location.href = 'index.html';
        };
    }

    // 3. Command Buttons in Remote Modal
    document.querySelectorAll('.cmd-btn').forEach(btn => {
        btn.onclick = () => {
            const cmd = btn.dataset.cmd;
            if (selectedVehicleId) {
                sendRemoteCommand(selectedVehicleId, cmd);
            }
        };
    });

    // 4. Telemetry Sliders
    const speedRange = document.getElementById('speed-override');
    const speedVal = document.getElementById('speed-val');
    if (speedRange && speedVal) {
        speedRange.oninput = (e) => {
            speedVal.innerText = e.target.value;
        };
        speedRange.onchange = (e) => {
            if (selectedVehicleId) {
                updateTelemetryOverride(selectedVehicleId, { speed: parseInt(e.target.value) });
            }
        };
    }

    // 5. Search Filtering
    if (searchInput) {
        searchInput.oninput = (e) => {
            searchQuery = e.target.value.toLowerCase();
            renderFleet();
            renderMapDrawer();
            if (map) renderMarkers();
        };
    }

    // 6. View Navigation Switching
    if (navOverview) {
        navOverview.onclick = (e) => {
            e.preventDefault();
            showSection('overview');
        };
    }
    if (navMap) {
        navMap.onclick = (e) => {
            e.preventDefault();
            showSection('map');
            if (!map) {
                initMap();
            } else {
                renderMarkers();
                renderMapDrawer();
            }
        };
    }

    // 7. Map Toolbar Controls
    if (mapBtnFit) {
        mapBtnFit.onclick = () => fitMapToMarkers();
    }
    if (mapBtnTraffic) {
        mapBtnTraffic.onclick = () => toggleTraffic();
    }
    if (mapBtnSatellite) {
        mapBtnSatellite.onclick = () => toggleSatellite();
    }
    if (mapBtnToggleList) {
        mapBtnToggleList.onclick = () => {
            if (mapFleetDrawer) {
                mapFleetDrawer.classList.toggle('collapsed');
                mapBtnToggleList.classList.toggle('active', !mapFleetDrawer.classList.contains('collapsed'));
            }
        };
    }

    // 8. Map Drawer Filter Tabs
    document.querySelectorAll('.filter-tab').forEach(tab => {
        tab.onclick = () => {
            document.querySelectorAll('.filter-tab').forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            drawerFilter = tab.dataset.filter || 'all';
            renderMapDrawer();
        };
    });

    // 9. Inspector Detail Card Controls
    if (detailCloseBtn) {
        detailCloseBtn.onclick = () => {
            inspectedVehicleId = null;
            if (mapVehicleDetail) mapVehicleDetail.classList.remove('active');
        };
    }

    const detailCopyGpsBtn = document.getElementById('detail-copy-gps');
    if (detailCopyGpsBtn) {
        detailCopyGpsBtn.onclick = () => {
            const coords = document.getElementById('detail-coords')?.innerText;
            if (coords) copyToClipboard(coords, 'GPS Coordinates copied!');
        };
    }

    const detailBtnMaps = document.getElementById('detail-btn-maps');
    if (detailBtnMaps) {
        detailBtnMaps.onclick = () => {
            if (inspectedVehicleId && vehicles.has(inspectedVehicleId)) {
                const v = vehicles.get(inspectedVehicleId);
                if (v.gps) {
                    window.open(`https://www.google.com/maps/search/?api=1&query=${v.gps.lat},${v.gps.lng}`, '_blank');
                }
            }
        };
    }

    const detailBtnCall = document.getElementById('detail-btn-call');
    if (detailBtnCall) {
        detailBtnCall.onclick = () => {
            if (inspectedVehicleId && vehicles.has(inspectedVehicleId)) {
                startVoiceCall(vehicles.get(inspectedVehicleId));
            }
        };
    }

    const cmdCallDirect = document.getElementById('cmd-call-direct');
    if (cmdCallDirect) {
        cmdCallDirect.onclick = () => {
            if (selectedVehicleId && vehicles.has(selectedVehicleId)) {
                controlModal?.classList.remove('active');
                startVoiceCall(vehicles.get(selectedVehicleId));
            }
        };
    }

    // Call Modal Controls
    const closeCallModalBtn = document.getElementById('close-call-modal');
    const callBtnEnd = document.getElementById('call-btn-end');
    const callBtnMute = document.getElementById('call-btn-mute');
    const callBtnSpeaker = document.getElementById('call-btn-speaker');

    if (closeCallModalBtn) closeCallModalBtn.onclick = () => endVoiceCall();
    if (callBtnEnd) callBtnEnd.onclick = () => endVoiceCall();
    if (callBtnMute) {
        callBtnMute.onclick = () => {
            callBtnMute.classList.toggle('active');
            const isMuted = callBtnMute.classList.contains('active');
            callBtnMute.querySelector('span:last-child').innerText = isMuted ? 'Muted' : 'Mute';
            showToast(isMuted ? 'Microphone muted' : 'Microphone unmuted', 'info');
        };
    }
    if (callBtnSpeaker) {
        callBtnSpeaker.onclick = () => {
            callBtnSpeaker.classList.toggle('active');
            const isSpeaker = callBtnSpeaker.classList.contains('active');
            showToast(isSpeaker ? 'Speaker mode active' : 'Default audio output', 'info');
        };
    }
}

function showSection(section) {
    if (section === 'overview') {
        overviewSection.style.display = 'block';
        mapSection.style.display = 'none';
        navOverview.classList.add('active');
        navMap.classList.remove('active');
    } else {
        overviewSection.style.display = 'none';
        mapSection.style.display = 'block';
        navOverview.classList.remove('active');
        navMap.classList.add('active');
    }
}

// ── Google Map Initialization ─────────────────────────────────
async function initMap() {
    console.log('[FleetMonitor] Initializing Map...');
    const mapEl = document.getElementById('fleet-map');
    if (!mapEl) return;
    
    try {
        const { Map } = await google.maps.importLibrary("maps");
        const markerLib = await google.maps.importLibrary("marker");
        const { Geocoder } = await google.maps.importLibrary("geocoding");
        
        AdvancedMarkerElement = markerLib.AdvancedMarkerElement;
        PinElement = markerLib.PinElement;
        geocoder = new Geocoder();

        // Suppress fatal Maps API errors gracefully
        window.gm_authFailure = () => {
            console.warn('[FleetMonitor] Google Maps API key error / not activated. Please enable Maps JavaScript API in Google Cloud Console.');
            showToast('Google Maps API not activated. Please enable Maps JavaScript API in Google Cloud Console.', 'warning');
        };

        map = new Map(mapEl, {
            center: { lat: 7.8731, lng: 80.7718 }, // Sri Lanka center
            zoom: 8,
            mapId: "4504f8b37365c3ae",
            disableDefaultUI: false,
            zoomControl: true,
            mapTypeControl: false,
            streetViewControl: true,
            fullscreenControl: false,
            backgroundColor: "#050a07"
        });

        trafficLayer = new google.maps.TrafficLayer();

        // Render markers & drawer
        renderMarkers();
        renderMapDrawer();

        if (vehicles.size > 0) {
            fitMapToMarkers();
        }
        
    } catch (err) {
        console.error('[FleetMonitor] Map initialization failed:', err);
    }
}

function toggleTraffic() {
    if (!map || !trafficLayer) return;
    if (trafficLayer.getMap()) {
        trafficLayer.setMap(null);
        if (mapBtnTraffic) mapBtnTraffic.classList.remove('active');
        showToast('Traffic layer hidden');
    } else {
        trafficLayer.setMap(map);
        if (mapBtnTraffic) mapBtnTraffic.classList.add('active');
        showToast('Traffic layer enabled');
    }
}

function toggleSatellite() {
    if (!map) return;
    isSatellite = !isSatellite;
    map.setMapTypeId(isSatellite ? 'hybrid' : 'roadmap');
    if (mapBtnSatellite) {
        mapBtnSatellite.classList.toggle('active', isSatellite);
        mapBtnSatellite.querySelector('span:last-child').innerText = isSatellite ? 'Dark Map' : 'Satellite';
    }
    showToast(isSatellite ? 'Satellite view enabled' : 'Dark cyber map enabled');
}

// ── Real-time Data Listeners ──────────────────────────────────
function startListening() {
    // 1. Listen for Active Trips
    onSnapshot(collection(db, "active_trips"), (snapshot) => {
        const receiveTime = Date.now();
        snapshot.docChanges().forEach((change) => {
            const data = change.doc.data();
            const id = change.doc.id;

            if (change.type === "removed") {
                vehicles.delete(id);
                if (markers.has(id)) {
                    markers.get(id).map = null;
                    markers.delete(id);
                }
            } else {
                const existing = vehicles.get(id);
                vehicles.set(id, { 
                    ...existing,
                    id, 
                    ...data,
                    receivedAt: change.type === "modified" ? receiveTime : (existing ? existing.receivedAt : receiveTime)
                });
            }
        });

        renderFleet();
        renderMapDrawer();
        renderGlobalAlertsFeed();
        if (map) renderMarkers();
        if (inspectedVehicleId && vehicles.has(inspectedVehicleId)) {
            updateInspectorCard(vehicles.get(inspectedVehicleId));
        }
    }, (err) => {
        console.error('[FleetMonitor] Error listening to active_trips:', err);
    });

    // 2. Listen for Recent Alerts with query fallback
    try {
        const alertsQuery = query(collection(db, "alerts"), orderBy("timestamp", "desc"), limit(20));
        onSnapshot(alertsQuery, (snapshot) => {
            alertsDocs = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
            renderGlobalAlertsFeed();
        }, (err) => {
            console.warn('[FleetMonitor] Alerts query with orderBy failed, falling back to simple collection:', err);
            onSnapshot(collection(db, "alerts"), (snapshot) => {
                alertsDocs = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
                renderGlobalAlertsFeed();
            }, (fallbackErr) => {
                console.error('[FleetMonitor] Alerts collection fallback failed:', fallbackErr);
                renderGlobalAlertsFeed();
            });
        });
    } catch (err) {
        console.error('[FleetMonitor] Failed to setup alerts listener:', err);
        renderGlobalAlertsFeed();
    }
}

// ── Reverse Geocoding Helper ───────────────────────────────────
async function reverseGeocode(lat, lng, elementId) {
    const key = `${lat.toFixed(3)},${lng.toFixed(3)}`;
    if (geocodeCache.has(key)) {
        const cached = geocodeCache.get(key);
        const el = document.getElementById(elementId);
        if (el) el.innerText = cached;
        return cached;
    }

    if (!geocoder) return;

    try {
        geocoder.geocode({ location: { lat, lng } }, (results, status) => {
            if (status === "OK" && results && results[0]) {
                const address = results[0].formatted_address;
                geocodeCache.set(key, address);
                const el = document.getElementById(elementId);
                if (el) el.innerText = address;
            }
        });
    } catch (e) {
        console.warn('Geocode lookup failed:', e);
    }
}

// ── Rendering Logic: Fleet Overview ───────────────────────────
function renderFleet() {
    if (vehicles.size === 0) {
        vehicleGrid.innerHTML = `
            <div class="empty-state">
                <span class="material-symbols-rounded">radar</span>
                <p>No active vehicles detected on the network.</p>
            </div>
        `;
        return;
    }

    vehicleGrid.innerHTML = '';
    let onlineCount = 0;
    let warnings = 0;
    let dangers = 0;
    const now = Date.now();
    const ONLINE_THRESHOLD_MS = 120000; // 2 minutes

    const filteredVehicles = Array.from(vehicles.values()).filter(v => {
        const name = (v.driverName || 'Vehicle Monitor').toLowerCase();
        const id = v.id.toLowerCase();
        return name.includes(searchQuery) || id.includes(searchQuery);
    });

    filteredVehicles.forEach((v) => {
        const lastSeen = v.timestamp?.toDate ? v.timestamp.toDate().getTime() : 
                        (v.lastUpdated ? new Date(v.lastUpdated).getTime() : 
                        (v.timestamp ? new Date(v.timestamp).getTime() : Date.now()));
        
        const isRecentlyReceived = v.receivedAt && (now - v.receivedAt < ONLINE_THRESHOLD_MS);
        const timeDiff = now - lastSeen;
        const isOnline = isRecentlyReceived || (timeDiff < 300000 && timeDiff > -300000);
        
        const isSelf = auth.currentUser && v.id === auth.currentUser.uid;
        
        if (isOnline) onlineCount++;

        const eyeState = (v.eyeState || 'OPEN').toUpperCase();
        const isEyesClosed = eyeState === 'CLOSED' || (v.ear && v.ear < 0.22);
        
        const statusClass = (v.status?.toLowerCase() === 'drowsy' || isEyesClosed || v.status?.toLowerCase() === 'warning') ? 'warning' : 
                          (v.status?.toLowerCase() === 'danger' || (v.confidence > 80) ? 'danger' : 'safe');
        
        if (isOnline && (statusClass === 'warning' || isEyesClosed)) warnings++;
        if (isOnline && statusClass === 'danger') dangers++;

        const displayName = v.driverName || v.driverEmail?.split('@')[0] || `Vehicle ${v.id.substring(0, 4)}`;
        const displaySub = v.driverEmail || `Device ID: ${v.id.substring(0, 8)}`;
        
        // Exact GPS formatting
        const hasGps = v.gps && typeof v.gps.lat === 'number' && typeof v.gps.lng === 'number';
        const coordsText = hasGps ? `${v.gps.lat.toFixed(6)}°, ${v.gps.lng.toFixed(6)}°` : 'GPS Unavailable';
        const addressId = `addr-card-${v.id}`;
        
        if (hasGps) {
            reverseGeocode(v.gps.lat, v.gps.lng, addressId);
        }

        const routeStatusText = v.onRoute !== undefined ? (v.onRoute ? 'On Target Route' : `Off Route (${v.deviationMeters || 0}m)`) : 'Route Active';

        const card = document.createElement('div');
        card.className = `vehicle-card ${isOnline ? 'online' : 'offline'} status-${isOnline ? statusClass : 'offline'}`;
        
        card.innerHTML = `
            <div class="card-header">
                <div class="driver-info">
                    <div class="avatar">${displayName.charAt(0).toUpperCase()}</div>
                    <div class="driver-details">
                        <div style="display: flex; align-items: center; gap: 8px;">
                            <h3>${displayName}</h3>
                            ${isSelf ? '<span class="self-badge">YOU</span>' : ''}
                        </div>
                        <p>${displaySub}</p>
                        <div class="online-indicator-row">
                            <span class="status-dot ${isOnline ? 'online' : 'offline'}"></span>
                            <p>${isOnline ? 'Active Tracking' : 'Offline'}</p>
                        </div>
                    </div>
                </div>
                <div style="display: flex; flex-direction: column; align-items: flex-end; gap: 4px;">
                    <span class="status-badge ${isOnline ? statusClass : 'offline'}">${isOnline ? (isEyesClosed ? 'Drowsy / Alert' : (v.status || 'Safe')) : 'Inactive'}</span>
                    ${isOnline ? `<span class="eye-badge ${isEyesClosed ? 'closed' : 'open'}">
                        <span class="material-symbols-rounded" style="font-size: 0.85rem;">${isEyesClosed ? 'visibility_off' : 'visibility'}</span>
                        <span>Eyes: ${isEyesClosed ? 'Closed' : 'Open'}</span>
                    </span>` : ''}
                </div>
            </div>
            
            <div class="card-telemetry ${!isOnline ? 'dimmed' : ''}">
                <div class="tel-item">
                    <span class="tel-label"><span class="material-symbols-rounded">speed</span> Live Speed</span>
                    <span class="tel-value">${isOnline ? (v.speed || 0) : '--'} km/h</span>
                </div>
                <div class="tel-item">
                    <span class="tel-label"><span class="material-symbols-rounded">visibility</span> Eye State</span>
                    <span class="tel-value ${isEyesClosed ? 'danger-text' : ''}" style="font-size: 0.82rem;">${isOnline ? (isEyesClosed ? '⚠️ Closed (Sleepy)' : '👁️ Open (Alert)') : '--'}</span>
                </div>
                <div class="tel-item full-width">
                    <span class="tel-label"><span class="material-symbols-rounded">location_on</span> Exact GPS Location</span>
                    <div class="tel-value coords">
                        <span>${coordsText}</span>
                        ${hasGps ? `<span class="material-symbols-rounded" style="font-size: 0.9rem; cursor: pointer;" title="Copy GPS" id="copy-btn-${v.id}">content_copy</span>` : ''}
                    </div>
                    <div class="tel-address" id="${addressId}">${hasGps ? 'Locating address...' : 'Coordinates unavailable'}</div>
                </div>
            </div>

            <div class="card-footer">
                <span class="last-seen">Updated: ${formatTime(v.timestamp || v.lastUpdated)}</span>
                <div class="card-actions">
                    <button class="icon-btn btn-call" title="Call Driver Intercom" id="call-${v.id}">
                        <span class="material-symbols-rounded">call</span>
                    </button>
                    <button class="icon-btn btn-focus-map" title="View Exact Location on Map" id="map-focus-${v.id}">
                        <span class="material-symbols-rounded">map</span>
                    </button>
                    ${hasGps ? `
                    <button class="icon-btn btn-gmaps" title="Open in Google Maps" id="gmaps-${v.id}">
                        <span class="material-symbols-rounded">open_in_new</span>
                    </button>` : ''}
                    <button class="icon-btn btn-command" title="Send Command" id="cmd-${v.id}">
                        <span class="material-symbols-rounded">settings_remote</span>
                    </button>
                </div>
            </div>
        `;

        // Card button click handlers
        card.querySelector(`#call-${v.id}`)?.addEventListener('click', (e) => {
            e.stopPropagation();
            startVoiceCall(v);
        });

        card.querySelector(`#map-focus-${v.id}`)?.addEventListener('click', (e) => {
            e.stopPropagation();
            focusVehicleOnMap(v.id);
        });

        card.querySelector(`#copy-btn-${v.id}`)?.addEventListener('click', (e) => {
            e.stopPropagation();
            copyToClipboard(coordsText, `Copied ${displayName}'s GPS`);
        });

        card.querySelector(`#gmaps-${v.id}`)?.addEventListener('click', (e) => {
            e.stopPropagation();
            if (hasGps) window.open(`https://www.google.com/maps/search/?api=1&query=${v.gps.lat},${v.gps.lng}`, '_blank');
        });

        card.querySelector(`#cmd-${v.id}`)?.addEventListener('click', (e) => {
            e.stopPropagation();
            openControlCenter(v);
        });

        card.addEventListener('click', () => {
            focusVehicleOnMap(v.id);
        });

        vehicleGrid.appendChild(card);
    });

    activeCountEl.innerText = onlineCount;
    warningCountEl.innerText = warnings;
    dangerCountEl.innerText = dangers;
    
    const mapActiveEl = document.getElementById('map-active-vehicles');
    if (mapActiveEl) mapActiveEl.innerText = `${onlineCount} Vehicles Online`;
    if (drawerVehicleCount) drawerVehicleCount.innerText = onlineCount;
}

// ── Rendering Logic: Map Drawer ───────────────────────────────
function renderMapDrawer() {
    if (!mapVehicleList) return;

    const now = Date.now();
    const ONLINE_THRESHOLD_MS = 120000;

    let filtered = Array.from(vehicles.values()).filter(v => {
        const name = (v.driverName || 'Vehicle').toLowerCase();
        const id = v.id.toLowerCase();
        const matchesSearch = name.includes(searchQuery) || id.includes(searchQuery);
        if (!matchesSearch) return false;

        const lastSeen = v.timestamp?.toDate ? v.timestamp.toDate().getTime() : 
                        (v.timestamp ? new Date(v.timestamp).getTime() : Date.now());
        const isOnline = (v.receivedAt && (now - v.receivedAt < ONLINE_THRESHOLD_MS)) || Math.abs(now - lastSeen) < 600000;

        if (drawerFilter === 'online') return isOnline;
        if (drawerFilter === 'alert') return isOnline && (v.status === 'danger' || v.status === 'drowsy' || v.status === 'warning');
        return true;
    });

    if (filtered.length === 0) {
        mapVehicleList.innerHTML = `
            <div style="text-align: center; padding: 30px 10px; color: var(--fm-text-dim); font-size: 0.8rem;">
                No matching vehicles found
            </div>
        `;
        return;
    }

    mapVehicleList.innerHTML = '';

    filtered.forEach(v => {
        const displayName = v.driverName || v.driverEmail?.split('@')[0] || `Vehicle ${v.id.substring(0, 4)}`;
        const lastSeen = v.timestamp?.toDate ? v.timestamp.toDate().getTime() : 
                        (v.timestamp ? new Date(v.timestamp).getTime() : Date.now());
        const isOnline = (v.receivedAt && (now - v.receivedAt < ONLINE_THRESHOLD_MS)) || Math.abs(now - lastSeen) < 600000;
        const statusClass = !isOnline ? 'offline' : (v.status?.toLowerCase() === 'drowsy' || v.status?.toLowerCase() === 'warning' ? 'warning' : 
                          (v.status?.toLowerCase() === 'danger' || (v.confidence > 80) ? 'danger' : 'safe'));

        const item = document.createElement('div');
        item.className = `map-vehicle-item ${inspectedVehicleId === v.id ? 'selected' : ''}`;
        
        const hasGps = v.gps && typeof v.gps.lat === 'number' && typeof v.gps.lng === 'number';
        const coordsShort = hasGps ? `${v.gps.lat.toFixed(4)}, ${v.gps.lng.toFixed(4)}` : 'No GPS';

        item.innerHTML = `
            <div class="map-vehicle-item-header">
                <div class="item-driver">
                    <div class="item-avatar">${displayName.charAt(0).toUpperCase()}</div>
                    <div class="item-driver-info">
                        <h4>${displayName}</h4>
                        <p>${v.driverEmail || v.id.substring(0, 8)}</p>
                    </div>
                </div>
                <span class="status-badge ${statusClass}">${isOnline ? (v.status || 'Safe') : 'Offline'}</span>
            </div>
            <div class="item-stats-row">
                <div class="item-gps-badge">
                    <span class="material-symbols-rounded">pin_drop</span>
                    <span>${coordsShort}</span>
                </div>
                <span class="item-speed-badge">${isOnline ? `${v.speed || 0} km/h` : '--'}</span>
            </div>
        `;

        item.onclick = () => focusVehicleOnMap(v.id);
        mapVehicleList.appendChild(item);
    });
}

// ── Map Markers Rendering ─────────────────────────────────────
function renderMarkers() {
    if (!map) return;

    const now = Date.now();
    const ONLINE_THRESHOLD_MS = 120000;

    // Remove deleted vehicle markers
    for (const [id, marker] of markers) {
        if (!vehicles.has(id)) {
            marker.map = null;
            markers.delete(id);
        }
    }

    vehicles.forEach((v) => {
        const displayName = v.driverName || v.driverEmail?.split('@')[0] || `Vehicle ${v.id.substring(0, 4)}`;
        const isVisible = displayName.toLowerCase().includes(searchQuery) || v.id.toLowerCase().includes(searchQuery);
        
        if (!v.gps || !isVisible || typeof v.gps.lat !== 'number' || typeof v.gps.lng !== 'number') {
            if (markers.has(v.id)) {
                markers.get(v.id).map = null;
                markers.delete(v.id);
            }
            return;
        }

        const lastSeen = v.timestamp?.toDate ? v.timestamp.toDate().getTime() : 
                        (v.timestamp ? new Date(v.timestamp).getTime() : Date.now());
        
        const isRecentlyReceived = v.receivedAt && (now - v.receivedAt < ONLINE_THRESHOLD_MS);
        const timeDiff = now - lastSeen;
        const isOnline = isRecentlyReceived || (timeDiff < 600000 && timeDiff > -600000);
        
        const pos = { lat: v.gps.lat, lng: v.gps.lng };
        const statusClass = !isOnline ? 'offline' : (v.status?.toLowerCase() === 'drowsy' || v.status?.toLowerCase() === 'warning' ? 'warning' : 
                          (v.status?.toLowerCase() === 'danger' || (v.confidence > 80) ? 'danger' : 'safe'));

        if (markers.has(v.id)) {
            const marker = markers.get(v.id);
            marker.position = pos;
            updateMarkerPin(marker, displayName, v.speed || 0, statusClass);
        } else {
            if (AdvancedMarkerElement) {
                const marker = new AdvancedMarkerElement({
                    map: map,
                    position: pos,
                    title: displayName,
                    content: createMarkerPin(displayName, v.speed || 0, statusClass)
                });

                if (marker.addEventListener) {
                    marker.addEventListener('gmp-click', () => {
                        inspectVehicle(v);
                    });
                } else {
                    marker.addListener('gmp-click', () => {
                        inspectVehicle(v);
                    });
                }

                markers.set(v.id, marker);
            } else {
                // Fallback standard Google Maps Marker
                const marker = new google.maps.Marker({
                    map: map,
                    position: pos,
                    title: displayName
                });
                marker.addListener('click', () => {
                    inspectVehicle(v);
                });
                markers.set(v.id, marker);
            }
        }
    });
}

function createMarkerPin(name, speed, statusClass) {
    const pin = document.createElement('div');
    pin.className = `custom-marker-pin ${statusClass}`;
    pin.innerHTML = `
        <div class="marker-radar-ring"></div>
        <div class="marker-bubble ${statusClass}">
            <span class="material-symbols-rounded marker-icon">${statusClass === 'danger' ? 'warning' : 'directions_car'}</span>
            <span class="marker-name">${name}</span>
            <span class="marker-speed">${speed} km/h</span>
        </div>
        <div class="marker-pointer"></div>
    `;
    return pin;
}

function updateMarkerPin(marker, name, speed, statusClass) {
    if (marker.content) {
        marker.content.className = `custom-marker-pin ${statusClass}`;
        const bubble = marker.content.querySelector('.marker-bubble');
        if (bubble) {
            bubble.className = `marker-bubble ${statusClass}`;
            const nameEl = bubble.querySelector('.marker-name');
            const speedEl = bubble.querySelector('.marker-speed');
            const iconEl = bubble.querySelector('.marker-icon');
            if (nameEl) nameEl.innerText = name;
            if (speedEl) speedEl.innerText = `${speed} km/h`;
            if (iconEl) iconEl.innerText = statusClass === 'danger' ? 'warning' : 'directions_car';
        }
    }
}

// ── Inspector Detail Card on Map ──────────────────────────────
function inspectVehicle(vehicle) {
    inspectedVehicleId = vehicle.id;
    updateInspectorCard(vehicle);
    if (mapVehicleDetail) mapVehicleDetail.classList.add('active');
    renderMapDrawer();
}

function updateInspectorCard(v) {
    if (!v) return;

    const displayName = v.driverName || v.driverEmail?.split('@')[0] || `Vehicle ${v.id.substring(0, 4)}`;
    const now = Date.now();
    const lastSeen = v.timestamp?.toDate ? v.timestamp.toDate().getTime() : 
                    (v.timestamp ? new Date(v.timestamp).getTime() : Date.now());
    const isOnline = (v.receivedAt && (now - v.receivedAt < 120000)) || Math.abs(now - lastSeen) < 600000;
    const statusClass = !isOnline ? 'offline' : (v.status?.toLowerCase() === 'drowsy' || v.status?.toLowerCase() === 'warning' ? 'warning' : 
                      (v.status?.toLowerCase() === 'danger' || (v.confidence > 80) ? 'danger' : 'safe'));

    // Populate Inspector Elements
    const avatarEl = document.getElementById('detail-avatar');
    const nameEl = document.getElementById('detail-name');
    const subEl = document.getElementById('detail-sub');
    const statusBadgeEl = document.getElementById('detail-status-badge');
    const onlineDotEl = document.getElementById('detail-online-dot');
    const onlineTextEl = document.getElementById('detail-online-text');
    const lastSeenEl = document.getElementById('detail-last-seen');
    const coordsEl = document.getElementById('detail-coords');
    const addressEl = document.getElementById('detail-address');
    const speedEl = document.getElementById('detail-speed');
    const routeStatusEl = document.getElementById('detail-route-status');
    const deviationEl = document.getElementById('detail-deviation');
    const zoneEl = document.getElementById('detail-zone');

    if (avatarEl) avatarEl.innerText = displayName.charAt(0).toUpperCase();
    if (nameEl) nameEl.innerText = displayName;
    if (subEl) subEl.innerText = `ID: ${v.id.substring(0, 10)}`;
    
    if (statusBadgeEl) {
        statusBadgeEl.className = `status-badge ${statusClass}`;
        statusBadgeEl.innerText = isOnline ? (v.status || 'Safe') : 'Offline';
    }

    if (onlineDotEl) onlineDotEl.className = `status-dot ${isOnline ? 'online' : 'offline'}`;
    if (onlineTextEl) onlineTextEl.innerText = isOnline ? 'Active Tracking' : 'Offline';
    if (lastSeenEl) lastSeenEl.innerText = formatTime(v.timestamp);

    const hasGps = v.gps && typeof v.gps.lat === 'number' && typeof v.gps.lng === 'number';
    if (coordsEl) coordsEl.innerText = hasGps ? `${v.gps.lat.toFixed(6)}°, ${v.gps.lng.toFixed(6)}°` : 'Unavailable';
    
    if (addressEl) {
        if (hasGps) {
            addressEl.innerText = 'Resolving exact address...';
            reverseGeocode(v.gps.lat, v.gps.lng, 'detail-address');
        } else {
            addressEl.innerText = 'GPS coordinates unavailable';
        }
    }

    if (speedEl) speedEl.innerText = isOnline ? `${v.speed || 0} km/h` : '--';
    if (routeStatusEl) routeStatusEl.innerText = v.onRoute !== undefined ? (v.onRoute ? 'On Target Route' : 'Off Planned Path') : 'Tracking';
    if (deviationEl) deviationEl.innerText = v.deviationMeters !== undefined ? `${v.deviationMeters} m` : '0 m';
    if (zoneEl) zoneEl.innerText = v.currentZone?.name || 'Standard Corridor';
}

// ── Focus & Fly to Vehicle on Map ─────────────────────────────
function focusVehicleOnMap(vehicleId) {
    let vehicle = vehicles.get(vehicleId);
    if (!vehicle) {
        vehicle = Array.from(vehicles.values()).find(v => v.id === vehicleId || v.driverId === vehicleId || v.driverEmail === vehicleId);
    }

    showSection('map');

    if (!vehicle) {
        showToast('Vehicle is not actively transmitting on the network', 'warning');
        return;
    }

    if (!map) {
        initMap().then(() => {
            executeFocus(vehicle);
        });
    } else {
        executeFocus(vehicle);
    }
}

function executeFocus(vehicle) {
    if (!map) return;
    
    if (vehicle.gps && typeof vehicle.gps.lat === 'number' && typeof vehicle.gps.lng === 'number') {
        const pos = { lat: vehicle.gps.lat, lng: vehicle.gps.lng };
        map.panTo(pos);
        map.setZoom(16);
    } else {
        showToast(`Selected ${vehicle.driverName || 'vehicle'} (No GPS location fix)`, 'warning');
    }
    
    inspectVehicle(vehicle);
}

function fitMapToMarkers() {
    if (!map || markers.size === 0) return;
    const bounds = new google.maps.LatLngBounds();
    let hasCoords = false;
    
    markers.forEach(m => {
        if (m.position) {
            bounds.extend(m.position);
            hasCoords = true;
        }
    });

    if (hasCoords) {
        map.fitBounds(bounds, 80);
    } else {
        map.setCenter({ lat: 7.8731, lng: 80.7718 });
        map.setZoom(8);
    }
    showToast('Map fitted to all active vehicles');
}

// ── Global Alerts Rendering ───────────────────────────────────
function renderGlobalAlertsFeed() {
    if (!alertsList || !globalAlertCountEl) return;

    const allAlerts = [];
    const now = Date.now();
    const ONLINE_THRESHOLD_MS = 120000; // 2 minutes

    // 1. Live Active Alerts from currently online fleet
    vehicles.forEach((v) => {
        const lastSeen = v.timestamp?.toDate ? v.timestamp.toDate().getTime() : 
                        (v.timestamp ? new Date(v.timestamp).getTime() : (v.receivedAt || now));
        const isRecentlyReceived = v.receivedAt && (now - v.receivedAt < ONLINE_THRESHOLD_MS);
        const timeDiff = now - lastSeen;
        const isOnline = isRecentlyReceived || (timeDiff < 600000 && timeDiff > -600000);

        if (!isOnline) return;

        const st = (v.status || '').toLowerCase();
        const isDrowsy = st === 'drowsy' || st === 'danger' || st === 'microsleep' || (v.confidence > 80);
        const isWarning = st === 'warning' || st === 'fatigued' || (v.confidence > 50 && v.confidence <= 80);
        const isOffRoute = v.onRoute === false || (v.deviationMeters && v.deviationMeters > 50);
        const isSpeeding = v.speed && v.speed > 80;

        if (isDrowsy || isWarning || isOffRoute || isSpeeding) {
            let typeClass = isDrowsy ? 'danger' : 'warning';
            let title = v.driverName || v.driverEmail?.split('@')[0] || `Vehicle ${v.id.substring(0, 4)}`;
            let description = '';
            let icon = 'warning';
            let badgeText = typeClass === 'danger' ? 'Critical' : 'Warning';

            if (st === 'microsleep') {
                description = '🚨 Emergency: Microsleep detected';
                icon = 'emergency';
                typeClass = 'danger';
                badgeText = 'Emergency';
            } else if (isDrowsy) {
                description = `Drowsiness detected (${v.confidence || 90}% conf) — ${Math.round(v.speed || 0)} km/h`;
                icon = 'emergency';
                typeClass = 'danger';
                badgeText = 'Critical';
            } else if (isOffRoute) {
                description = `Off planned route (${v.deviationMeters || 0}m dev) — ${Math.round(v.speed || 0)} km/h`;
                icon = 'alt_route';
                typeClass = 'warning';
                badgeText = 'Deviation';
            } else if (isSpeeding) {
                description = `Speed limit warning: ${Math.round(v.speed)} km/h`;
                icon = 'speed';
                typeClass = 'warning';
                badgeText = 'Speed';
            } else {
                description = `Attention alert: ${v.status} — ${Math.round(v.speed || 0)} km/h`;
                icon = 'warning';
                typeClass = 'warning';
                badgeText = 'Warning';
            }

            allAlerts.push({
                id: `live_${v.id}`,
                driverId: v.id,
                driverName: title,
                typeClass: typeClass,
                icon: icon,
                badgeText: badgeText,
                description: description,
                timestamp: v.timestamp || v.receivedAt || new Date(),
                isLive: true
            });
        }
    });

    // 2. Historical & Logged Alerts from Firestore collection
    alertsDocs.forEach((a) => {
        // Skip if this driver already has an active live alert
        const driverKey = a.driverId || a.id;
        if (allAlerts.some(item => item.isLive && item.driverId === driverKey)) {
            return;
        }

        const st = (a.status || '').toLowerCase();
        const isDanger = st === 'drowsy' || st === 'danger' || st === 'microsleep' || a.type === 'drowsiness_alert' || (a.confidence > 80);
        const typeClass = isDanger ? 'danger' : 'warning';
        const driverName = a.driverName || a.driverEmail?.split('@')[0] || (a.driverId && vehicles.get(a.driverId)?.driverName) || 'Driver';
        
        let desc = '';
        let icon = typeClass === 'danger' ? 'emergency' : 'warning';
        let badgeText = typeClass === 'danger' ? 'Critical' : 'Warning';

        if (a.message) {
            desc = a.message;
        } else if (a.status) {
            desc = `${a.status.toUpperCase()} event — ${Math.round(a.speed || 0)} km/h`;
        } else if (a.type === 'drowsiness_alert') {
            desc = `Drowsiness incident logged — ${Math.round(a.speed || 0)} km/h`;
        } else {
            desc = `Incident logged — ${Math.round(a.speed || 0)} km/h`;
        }

        allAlerts.push({
            id: a.id || `${a.driverId}_${Math.random()}`,
            driverId: a.driverId || a.id,
            driverName: driverName,
            typeClass: typeClass,
            icon: icon,
            badgeText: badgeText,
            description: desc,
            timestamp: a.timestamp,
            isLive: false
        });
    });

    // Sort: Live alerts first, then newest historical alerts
    allAlerts.sort((a, b) => {
        if (a.isLive && !b.isLive) return -1;
        if (!a.isLive && b.isLive) return 1;
        const timeA = a.timestamp?.toDate ? a.timestamp.toDate().getTime() : (a.timestamp ? new Date(a.timestamp).getTime() : 0);
        const timeB = b.timestamp?.toDate ? b.timestamp.toDate().getTime() : (b.timestamp ? new Date(b.timestamp).getTime() : 0);
        return timeB - timeA;
    });

    globalAlertCountEl.innerText = allAlerts.length;

    if (allAlerts.length === 0) {
        alertsList.innerHTML = `
            <div class="notif-empty">
                <span class="material-symbols-rounded" style="display:block; font-size: 2rem; margin-bottom: 8px; opacity:0.35; color: #2ea043;">verified_user</span>
                No critical alerts detected
            </div>
        `;
        return;
    }

    alertsList.innerHTML = '';
    allAlerts.forEach((a) => {
        const item = document.createElement('div');
        item.className = `alert-item ${a.typeClass}-item ${a.isLive ? 'live-alert' : ''}`;
        item.style.cursor = 'pointer';
        item.title = 'Click to locate vehicle on map';
        item.innerHTML = `
            <div class="alert-icon ${a.typeClass}">
                <span class="material-symbols-rounded">${a.icon}</span>
            </div>
            <div class="alert-content">
                <div class="alert-header">
                    <h4>${escapeHtml(a.driverName)}</h4>
                    <div style="display: flex; gap: 4px; align-items: center;">
                        ${a.isLive ? '<span class="alert-badge live">LIVE</span>' : ''}
                        <span class="alert-badge ${a.typeClass}">${a.badgeText}</span>
                    </div>
                </div>
                <p>${escapeHtml(a.description)}</p>
                <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 4px;">
                    <span class="alert-time">${formatTime(a.timestamp)}</span>
                    <span style="font-size: 0.68rem; color: var(--fm-amber); display: inline-flex; align-items: center; gap: 2px; font-weight: 600;">
                        <span class="material-symbols-rounded" style="font-size: 0.85rem;">near_me</span> Track
                    </span>
                </div>
            </div>
        `;

        if (a.driverId) {
            item.onclick = (e) => {
                e.stopPropagation();
                focusVehicleOnMap(a.driverId);
            };
        }

        alertsList.appendChild(item);
    });
}

// ── Remote Controls ────────────────────────────────────────────
function openControlCenter(vehicle) {
    selectedVehicleId = vehicle.id;
    
    const modalName = document.getElementById('modal-vehicle-name');
    const modalId = document.getElementById('modal-vehicle-id');
    const modalIcon = document.getElementById('modal-vehicle-icon');

    if (modalName) modalName.innerText = vehicle.driverName || 'Vehicle';
    if (modalId) modalId.innerText = `ID: ${vehicle.id.substring(0, 12)}`;
    if (modalIcon) modalIcon.innerText = vehicle.driverName?.charAt(0).toUpperCase() || 'V';
    
    controlModal.classList.add('active');
}

async function sendRemoteCommand(driverId, type) {
    try {
        const message = getMessageForType(type);
        await setDoc(doc(db, "commands", driverId), {
            type: type,
            message: message,
            processed: false,
            timestamp: serverTimestamp()
        });
        showToast(`Command sent: ${type.toUpperCase()}`);
    } catch (err) {
        console.error('Failed to send command:', err);
        showToast('Error sending command', 'danger');
    }
}

async function updateTelemetryOverride(driverId, data) {
    try {
        await setDoc(doc(db, "telemetry_override", driverId), {
            ...data,
            timestamp: serverTimestamp()
        }, { merge: true });
        showToast(`Telemetry updated`);
    } catch (err) {
        console.error('Failed to update telemetry:', err);
    }
}

// ── Voice Intercom / Call System ──────────────────────────────
let activeCallVehicle = null;
let callTimerInterval = null;
let callDurationSecs = 0;
let callRingAudio = null;

function startVoiceCall(vehicle) {
    if (!vehicle) return;
    activeCallVehicle = vehicle;
    
    const callModal = document.getElementById('call-modal');
    const avatarEl = document.getElementById('call-avatar');
    const nameEl = document.getElementById('call-driver-name');
    const idEl = document.getElementById('call-vehicle-id');
    const statusEl = document.getElementById('call-status-text');
    const durationEl = document.getElementById('call-duration');
    const waveformEl = document.getElementById('audio-waveform');

    const displayName = vehicle.driverName || vehicle.driverEmail?.split('@')[0] || `Vehicle ${vehicle.id.substring(0, 4)}`;

    if (avatarEl) avatarEl.innerText = displayName.charAt(0).toUpperCase();
    if (nameEl) nameEl.innerText = displayName;
    if (idEl) idEl.innerText = `Vehicle ID: ${vehicle.id.substring(0, 12)} • ${vehicle.driverEmail || 'Driver App'}`;
    if (statusEl) {
        statusEl.innerText = "Calling Device...";
        statusEl.style.color = "#F0A500";
        statusEl.style.borderColor = "rgba(240, 165, 0, 0.4)";
        statusEl.style.background = "rgba(240, 165, 0, 0.15)";
    }
    if (durationEl) durationEl.innerText = "00:00";
    if (waveformEl) waveformEl.style.opacity = "0.3";

    if (callModal) callModal.classList.add('active');

    // Play ringing audio synthesizer
    playCallRingTone();

    // Send real-time call command to Firebase
    sendCallCommand(vehicle.id, 'incoming_call');

    // Simulate connection after ring
    clearInterval(callTimerInterval);
    callDurationSecs = 0;

    setTimeout(() => {
        if (!activeCallVehicle || activeCallVehicle.id !== vehicle.id) return;
        
        stopCallRingTone();
        if (statusEl) {
            statusEl.innerText = "🎙️ Intercom Connected";
            statusEl.style.color = "#3FB950";
            statusEl.style.borderColor = "rgba(63, 185, 80, 0.4)";
            statusEl.style.background = "rgba(63, 185, 80, 0.15)";
        }
        if (waveformEl) waveformEl.style.opacity = "1";

        callTimerInterval = setInterval(() => {
            callDurationSecs++;
            const mins = String(Math.floor(callDurationSecs / 60)).padStart(2, '0');
            const secs = String(callDurationSecs % 60).padStart(2, '0');
            if (durationEl) durationEl.innerText = `${mins}:${secs}`;
        }, 1000);

        showToast(`Intercom connected with ${displayName}`, 'success');
    }, 2200);
}

function endVoiceCall() {
    stopCallRingTone();
    clearInterval(callTimerInterval);

    if (activeCallVehicle) {
        sendCallCommand(activeCallVehicle.id, 'end_call');
        showToast(`Call ended with ${activeCallVehicle.driverName || 'Driver'}`);
    }

    activeCallVehicle = null;
    callDurationSecs = 0;

    const callModal = document.getElementById('call-modal');
    if (callModal) callModal.classList.remove('active');
}

async function sendCallCommand(driverId, type) {
    try {
        await setDoc(doc(db, "commands", driverId), {
            type: type,
            caller: "Fleet Operations Dispatch",
            message: type === 'incoming_call' ? "📞 Incoming call from Fleet Operations Dispatch" : "Call ended by dispatch.",
            processed: false,
            timestamp: serverTimestamp()
        });
    } catch (e) {
        console.warn('[FleetMonitor] Failed to send call command:', e);
    }
}

function playCallRingTone() {
    try {
        const AudioCtx = window.AudioContext || window.webkitAudioContext;
        if (!AudioCtx) return;
        callRingAudio = new AudioCtx();

        const osc = callRingAudio.createOscillator();
        const gain = callRingAudio.createGain();
        osc.connect(gain);
        gain.connect(callRingAudio.destination);

        osc.type = 'sine';
        osc.frequency.setValueAtTime(440, callRingAudio.currentTime);
        
        // Ringing pulses: 0.4s on, 0.2s on, pause
        gain.gain.setValueAtTime(0.15, callRingAudio.currentTime);
        gain.gain.setValueAtTime(0.01, callRingAudio.currentTime + 0.4);
        gain.gain.setValueAtTime(0.15, callRingAudio.currentTime + 0.6);
        gain.gain.setValueAtTime(0.01, callRingAudio.currentTime + 1.0);

        osc.start(callRingAudio.currentTime);
        osc.stop(callRingAudio.currentTime + 2.0);
    } catch (e) {
        console.warn('Call audio failed:', e);
    }
}

function stopCallRingTone() {
    if (callRingAudio) {
        try { callRingAudio.close(); } catch(e){}
        callRingAudio = null;
    }
}

// ── Helpers ───────────────────────────────────────────────────
function formatTime(timestamp) {
    if (!timestamp) return 'Just now';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    const now = Date.now();
    const diffSecs = Math.round((now - date.getTime()) / 1000);

    if (diffSecs < 10) return 'Just now';
    if (diffSecs < 60) return `${diffSecs}s ago`;
    if (diffSecs < 3600) return `${Math.floor(diffSecs / 60)}m ago`;

    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

function copyToClipboard(text, msg = 'Copied to clipboard') {
    navigator.clipboard.writeText(text).then(() => {
        showToast(msg);
    }).catch(err => {
        console.error('Copy failed:', err);
    });
}

function showToast(msg, type = 'success') {
    const container = document.getElementById('admin-toasts');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <span class="material-symbols-rounded" style="font-size: 1.1rem; color: ${type === 'success' ? 'var(--fm-amber)' : 'var(--fm-danger)'};">
            ${type === 'success' ? 'check_circle' : 'error'}
        </span>
        <span>${msg}</span>
    `;
    container.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// ── Demo Simulation Helper for Research Demonstrations ─────────
const DEMO_ROUTES = [
    { name: 'Vehicle CT-104 (Prius)', email: 'driver.prius@ceylontourmate.com', lat: 6.9271, lng: 79.8612, speed: 64, status: 'Safe', eyeState: 'OPEN', ear: 0.32 },
    { name: 'Vehicle CT-208 (KDH Van)', email: 'driver.kdh@ceylontourmate.com', lat: 7.2906, lng: 80.6337, speed: 45, status: 'Drowsy', eyeState: 'CLOSED', ear: 0.16 },
    { name: 'Vehicle CT-305 (Coaster)', email: 'driver.coaster@ceylontourmate.com', lat: 6.0535, lng: 80.2210, speed: 72, status: 'Safe', eyeState: 'OPEN', ear: 0.29 }
];
let demoIndex = 0;

async function simulateDemoVehicle() {
    try {
        const demo = DEMO_ROUTES[demoIndex % DEMO_ROUTES.length];
        demoIndex++;
        
        const demoId = `demo_vehicle_${demoIndex % 3 + 1}`;
        // Slight random jitter for live movement effect
        const latJitter = (Math.random() - 0.5) * 0.008;
        const lngJitter = (Math.random() - 0.5) * 0.008;
        
        const demoData = {
            driverId: demoId,
            driverName: demo.name,
            driverEmail: demo.email,
            status: demo.status,
            eyeState: demo.eyeState,
            ear: demo.ear,
            confidence: demo.eyeState === 'CLOSED' ? 88 : 12,
            gps: {
                lat: demo.lat + latJitter,
                lng: demo.lng + lngJitter,
                accuracy: 5,
                heading: Math.floor(Math.random() * 360)
            },
            speed: demo.speed + Math.floor(Math.random() * 8 - 4),
            timestamp: serverTimestamp(),
            lastUpdated: new Date().toISOString()
        };

        await setDoc(doc(db, "active_trips", demoId), demoData, { merge: true });
        showToast(`Simulated telemetry broadcast for ${demo.name}`, 'success');

        if (demo.eyeState === 'CLOSED') {
            await setDoc(doc(db, "alerts", `${demoId}_${Date.now()}`), {
                ...demoData,
                type: 'eye_closure_alert'
            });
        }
    } catch (err) {
        console.error('[FleetMonitor] Failed to simulate demo vehicle:', err);
        showToast('Failed to write demo vehicle to Firestore', 'error');
    }
}

// Run init
init();

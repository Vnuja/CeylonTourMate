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
let searchQuery = "";
let map = null;
let AdvancedMarkerElement = null;
let PinElement = null;

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
        
        // Start heartbeat to refresh online status UI every 30 seconds
        setInterval(() => {
            console.log('[FleetMonitor] Heartbeat refresh...');
            renderFleet();
            if (map) renderMarkers();
        }, 30000);
    });

    // 2. Event Listeners
    closeModalBtn.onclick = () => controlModal.classList.remove('active');
    
    signoutBtn.onclick = async () => {
        await signOut(auth);
        window.location.href = 'index.html';
    };

    // 3. Command Buttons
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
    speedRange.oninput = (e) => {
        speedVal.innerText = e.target.value;
    };
    speedRange.onchange = (e) => {
        if (selectedVehicleId) {
            updateTelemetryOverride(selectedVehicleId, { speed: parseInt(e.target.value) });
        }
    };

    // 5. Search Filtering
    searchInput.oninput = (e) => {
        searchQuery = e.target.value.toLowerCase();
        renderFleet();
        if (map) renderMarkers();
    };

    // 6. View Switching
    navOverview.onclick = (e) => {
        e.preventDefault();
        showSection('overview');
    };
    navMap.onclick = (e) => {
        e.preventDefault();
        showSection('map');
        if (!map) initMap();
    };
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

async function initMap() {
    console.log('[FleetMonitor] Initializing Map...');
    const mapEl = document.getElementById('fleet-map');
    
    try {
        const { Map } = await google.maps.importLibrary("maps");
        const markerLib = await google.maps.importLibrary("marker");
        AdvancedMarkerElement = markerLib.AdvancedMarkerElement;
        PinElement = markerLib.PinElement;

        map = new Map(mapEl, {
            center: { lat: 7.8731, lng: 80.7718 }, // Sri Lanka center
            zoom: 7,
            mapId: "4504f8b37365c3ae",
            disableDefaultUI: false,
            backgroundColor: "#0a0c10",
            styles: [
                { elementType: "geometry", stylers: [{ color: "#242f3e" }] },
                { elementType: "labels.text.stroke", stylers: [{ color: "#242f3e" }] },
                { elementType: "labels.text.fill", stylers: [{ color: "#746855" }] }
            ]
        });

        // Fit bounds to Sri Lanka initially or all markers
        if (vehicles.size > 0) {
            fitMapToMarkers();
        }

        // Initialize markers for existing vehicles
        renderMarkers();
        
    } catch (err) {
        console.error('Map initialization failed:', err);
    }
}

// ── Real-time Data Listeners ──────────────────────────────────
function startListening() {
    // 1. Listen for Active Trips
    onSnapshot(collection(db, "active_trips"), (snapshot) => {
        snapshot.docChanges().forEach((change) => {
            const data = change.doc.data();
            const id = change.doc.id;

            if (change.type === "removed") {
                vehicles.delete(id);
            } else {
                vehicles.set(id, { id, ...data });
            }
        });
        renderFleet();
        if (map) renderMarkers();
    });

    // 2. Listen for Recent Alerts
    const alertsQuery = query(collection(db, "alerts"), orderBy("timestamp", "desc"), limit(20));
    onSnapshot(alertsQuery, (snapshot) => {
        renderAlerts(snapshot);
    });
}

// ── Rendering Logic ───────────────────────────────────────────
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
        // Fallback to current time if timestamp is pending from server (null)
        const lastSeen = v.timestamp?.toDate ? v.timestamp.toDate().getTime() : 
                        (v.timestamp ? new Date(v.timestamp).getTime() : Date.now());
        
        // Account for potential clock skew (abs difference)
        const isOnline = Math.abs(now - lastSeen) < ONLINE_THRESHOLD_MS;
        const isSelf = auth.currentUser && v.id === auth.currentUser.uid;
        
        if (isOnline) onlineCount++;

        const statusClass = v.status?.toLowerCase() === 'drowsy' || v.status?.toLowerCase() === 'warning' ? 'warning' : 
                          (v.status?.toLowerCase() === 'danger' || (v.confidence > 80) ? 'danger' : 'safe');
        
        if (isOnline && statusClass === 'warning') warnings++;
        if (isOnline && statusClass === 'danger') dangers++;

        const displayName = v.driverName || v.driverEmail?.split('@')[0] || `Vehicle ${v.id.substring(0, 4)}`;
        const displaySub = v.driverEmail || `Device ID: ${v.id.substring(0, 8)}`;
        const card = document.createElement('div');
        card.className = `vehicle-card ${isOnline ? 'online' : 'offline'}`;
        card.onclick = () => openControlCenter(v);

        card.innerHTML = `
            <div class="card-header">
                <div class="driver-info">
                    <div class="avatar">${displayName.charAt(0)}</div>
                    <div class="driver-details">
                        <div style="display: flex; align-items: center; gap: 8px;">
                            <h3>${displayName}</h3>
                            ${isSelf ? '<span class="self-badge">YOU</span>' : ''}
                        </div>
                        <p style="font-size: 0.7rem; opacity: 0.6; margin-bottom: 4px;">${displaySub}</p>
                        <div class="online-indicator-row">
                            <span class="status-dot ${isOnline ? 'online' : 'offline'}"></span>
                            <p>${isOnline ? 'Active' : 'Offline'}</p>
                        </div>
                    </div>
                </div>
                <span class="status-badge ${isOnline ? statusClass : 'offline'}">${isOnline ? (v.status || 'Safe') : 'Inactive'}</span>
            </div>
            
            <div class="card-telemetry ${!isOnline ? 'dimmed' : ''}">
                <div class="tel-item">
                    <span class="tel-label">Live Speed</span>
                    <span class="tel-value">${isOnline ? (v.speed || 0) : '--'} km/h</span>
                </div>
                <div class="tel-item">
                    <span class="tel-label">AI Confidence</span>
                    <span class="tel-value">${isOnline ? (v.confidence || 0) : '--'}%</span>
                </div>
                <div class="tel-item" style="grid-column: span 2; margin-top: 8px;">
                    <span class="tel-label">Current GPS</span>
                    <span class="tel-value" style="font-size: 0.75rem;">${v.gps ? v.gps.lat.toFixed(4) + ', ' + v.gps.lng.toFixed(4) : 'Location Unavailable'}</span>
                </div>
            </div>

            <div class="card-footer">
                <span class="last-seen">Last seen: ${formatTime(v.timestamp)}</span>
                <div class="card-actions">
                    <button class="icon-btn" title="View Location"><span class="material-symbols-rounded">location_on</span></button>
                    <button class="icon-btn" title="Send Command"><span class="material-symbols-rounded">settings_remote</span></button>
                </div>
            </div>
        `;
        vehicleGrid.appendChild(card);
    });

    activeCountEl.innerText = onlineCount;
    warningCountEl.innerText = warnings;
    dangerCountEl.innerText = dangers;
    
    const mapActiveEl = document.getElementById('map-active-vehicles');
    if (mapActiveEl) mapActiveEl.innerText = `${onlineCount} Vehicles Online`;
}

function renderMarkers() {
    if (!map || !AdvancedMarkerElement) return;

    const bounds = new google.maps.LatLngBounds();
    let hasMarkers = false;

    // Remove markers for vehicles that are gone
    for (const [id, marker] of markers) {
        if (!vehicles.has(id)) {
            marker.map = null;
            markers.delete(id);
        }
    }

    // Add or update markers
    const now = Date.now();
    const ONLINE_THRESHOLD_MS = 120000;

    vehicles.forEach((v) => {
        const displayName = v.driverName || v.driverEmail?.split('@')[0] || `Vehicle ${v.id.substring(0, 4)}`;
        const isVisible = displayName.toLowerCase().includes(searchQuery) || v.id.toLowerCase().includes(searchQuery);
        
        if (!v.gps || !isVisible) {
            if (markers.has(v.id)) {
                markers.get(v.id).map = null;
                markers.delete(v.id);
            }
            return;
        }

        const lastSeen = v.timestamp?.toDate ? v.timestamp.toDate().getTime() : 
                        (v.timestamp ? new Date(v.timestamp).getTime() : Date.now());
        const isOnline = Math.abs(now - lastSeen) < ONLINE_THRESHOLD_MS;
        
        const pos = { lat: v.gps.lat, lng: v.gps.lng };
        const statusClass = !isOnline ? 'offline' : (v.status?.toLowerCase() === 'drowsy' || v.status?.toLowerCase() === 'warning' ? 'warning' : 
                          (v.status?.toLowerCase() === 'danger' || (v.confidence > 80) ? 'danger' : 'safe'));

        if (markers.has(v.id)) {
            const marker = markers.get(v.id);
            marker.position = pos;
            updateMarkerContent(marker, displayName, statusClass);
        } else {
            const marker = new AdvancedMarkerElement({
                map: map,
                position: pos,
                title: displayName,
                content: createMarkerContent(displayName, statusClass)
            });

            marker.addListener('click', () => {
                openControlCenter(v);
            });

            markers.set(v.id, marker);
        }
        
        bounds.extend(pos);
        hasMarkers = true;
    });

    // Auto-fit if it's the first render or markers moved significantly
    // (Disabled for now to avoid jumpy experience, but useful on initial load)
}

function fitMapToMarkers() {
    if (!map || markers.size === 0) return;
    const bounds = new google.maps.LatLngBounds();
    markers.forEach(m => bounds.extend(m.position));
    map.fitBounds(bounds);
}

function createMarkerContent(name, statusClass) {
    const div = document.createElement('div');
    div.className = `custom-marker ${statusClass}`;
    div.innerHTML = `
        <div class="marker-label">${name}</div>
    `;
    return div;
}

function updateMarkerContent(marker, name, statusClass) {
    if (marker.content) {
        marker.content.className = `custom-marker ${statusClass}`;
        marker.content.querySelector('.marker-label').innerText = name;
    }
}

function renderAlerts(snapshot) {
    globalAlertCountEl.innerText = snapshot.size;
    
    if (snapshot.empty) {
        alertsList.innerHTML = '<div class="notif-empty">No recent alerts</div>';
        return;
    }

    alertsList.innerHTML = '';
    snapshot.forEach((doc) => {
        const a = doc.data();
        const typeClass = a.status?.toLowerCase() === 'drowsy' || a.type === 'drowsiness_alert' ? 'danger' : 'warning';
        
        const item = document.createElement('div');
        item.className = 'alert-item';
        item.innerHTML = `
            <div class="alert-icon ${typeClass}">
                <span class="material-symbols-rounded">${typeClass === 'danger' ? 'emergency' : 'warning'}</span>
            </div>
            <div class="alert-content">
                <div class="alert-header">
                    <h4>${a.driverName || 'System'}</h4>
                    <span class="alert-badge ${typeClass}">${typeClass === 'danger' ? 'Critical' : 'Warning'}</span>
                </div>
                <p>${a.status || 'Status Alert'} Detected — Speed: ${a.speed || 0} km/h</p>
                <span class="alert-time">${formatTime(a.timestamp)}</span>
            </div>
        `;
        alertsList.appendChild(item);
    });
}

// ── Remote Controls ────────────────────────────────────────────
function openControlCenter(vehicle) {
    selectedVehicleId = vehicle.id;
    
    document.getElementById('modal-vehicle-name').innerText = vehicle.driverName || 'Vehicle';
    document.getElementById('modal-vehicle-id').innerText = `ID: ${vehicle.id.substring(0, 12)}`;
    document.getElementById('modal-vehicle-icon').innerText = vehicle.driverName?.charAt(0) || 'V';
    
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

function getMessageForType(type) {
    switch(type) {
        case 'drowsy': return "⚠️ DROWSINESS DETECTED: PLEASE FOCUS!";
        case 'microsleep': return "🚨 EMERGENCY: STOP THE VEHICLE IMMEDIATELY!";
        case 'deviation': return "ℹ️ ROUTE NOTICE: You are off the planned path.";
        case 'clear': return "All alerts cleared by admin.";
        default: return "System notification from admin.";
    }
}

// ── Helpers ───────────────────────────────────────────────────
function formatTime(timestamp) {
    if (!timestamp) return 'Just now';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

function showToast(msg, type = 'success') {
    const container = document.getElementById('admin-toasts');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerText = msg;
    container.appendChild(toast);
    
    // Simple toast style if not in CSS
    toast.style.background = type === 'success' ? '#238636' : '#da3633';
    toast.style.color = 'white';
    toast.style.padding = '12px 24px';
    toast.style.borderRadius = '8px';
    toast.style.marginBottom = '10px';
    toast.style.boxShadow = '0 4px 12px rgba(0,0,0,0.3)';
    toast.style.animation = 'slideIn 0.3s ease-out';

    setTimeout(() => {
        toast.style.opacity = '0';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// Run init
init();

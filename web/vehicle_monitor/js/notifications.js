import { getMessagingInstance, db, auth } from "./firebase-config.js";
import { doc, onSnapshot, updateDoc } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";
import { startDetection, stopDetection } from "./drowsiness.js";

/**
 * Notification System for CeylonTourMate Vehicle Monitor
 * Handles Snackbars/Banners and Browser Push Notifications
 */

export const initNotifications = async () => {
    // 1. Request permission for push notifications
    if ('Notification' in window) {
        if (Notification.permission !== 'granted' && Notification.permission !== 'denied') {
            const permission = await Notification.requestPermission();
            console.log('Push notification permission:', permission);
        }
    }

    // 2. Get the messaging instance (returns null if browser is unsupported)
    const messaging = await getMessagingInstance();
    if (!messaging) {
        console.warn('[Notifications] Firebase Messaging not supported in this browser. Push notifications disabled.');
        return;
    }

    // 3. Register Service Worker for background notifications (important for mobile)
    if ('serviceWorker' in navigator) {
        try {
            const registration = await navigator.serviceWorker.register('firebase-messaging-sw.js');
            console.log('Service Worker registered with scope:', registration.scope);

            // 4. Get FCM Token
            const { getToken } = await import("https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging.js");
            const vapidKey = 'BKWi6F_n6-e94USFNn8Wlqe4abz4CcqW3KqhnRqNxFeSTFQBE_KPbK1XkNQcC9Y_Z3OndlIqLLC6NQIdD2qUkms';
            if (vapidKey.length > 20 && !vapidKey.startsWith('YOUR_')) {
                const token = await getToken(messaging, { 
                    vapidKey,
                    serviceWorkerRegistration: registration 
                }).catch(err => {
                    console.warn('[Notifications] VAPID Key is invalid or push subscription failed:', err.message);
                    return null;
                });
                
                if (token) {
                    console.log('FCM Token:', token);
                }
            } else {
                console.warn('[Notifications] VAPID Key not configured. Push notifications will be limited.');
            }
        } catch (error) {
            console.warn('[Notifications] Service Worker registration failed:', error);
        }
    }

    // 5. Handle foreground messages
    const { onMessage } = await import("https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging.js");
    onMessage(messaging, (payload) => {
        console.log('Message received in foreground: ', payload);
        showSnackbar(payload.notification.body, 'info');
    });
};

/**
 * Listen for remote commands from the phone controller
 */
export const initRemoteCommands = () => {
    if (!db || !auth.currentUser) return;

    const driverId = auth.currentUser.uid;
    console.log('[Notifications] Initializing remote command listener for:', driverId);

    // Listen for the specific command document for this driver
    onSnapshot(doc(db, "commands", driverId), (snapshot) => {
        if (snapshot.exists()) {
            const data = snapshot.data();
            
            // Only process if it hasn't been processed yet
            if (!data.processed) {
                console.log('[Remote] Command received:', data.type, data.message);
                
                handleRemoteCommand(data.type, data.message);

                // Mark as processed immediately
                updateDoc(doc(db, "commands", driverId), {
                    processed: true
                });
            }
        }
    }, (error) => {
        console.error('[Remote] Listener error:', error);
        if (error.code === 'permission-denied' || error.message.includes('API has not been used')) {
            showSnackbar("Remote Monitoring: Firestore API not enabled. Check Console.", "error", 10000);
        }
    });
};

const handleRemoteCommand = (type, message) => {
    // Play alert sound for any remote trigger
    // Importing from drowsiness.js isn't clean here, but we can just use the global/notification logic
    
    switch (type) {
        case 'drowsy':
            showSnackbar(message, 'error', 8000);
            break;
        case 'microsleep':
            // Trigger the critical alert if possible
            // For now, use the snackbar + intense vibration
            showSnackbar(message, 'error', 10000);
            if (navigator.vibrate && navigator.userActivation?.hasBeenActive) {
                navigator.vibrate([500, 200, 500, 200, 500]);
            }
            break;
        case 'deviation':
            showSnackbar(message, 'warning', 6000);
            break;
        case 'distraction':
            showSnackbar(message, 'warning', 5000);
            break;
        case 'phone':
            showSnackbar(message, 'warning', 5000);
            break;
        case 'sudden_brake':
            showSnackbar(message, 'warning', 6000);
            if (navigator.vibrate && navigator.userActivation?.hasBeenActive) {
                navigator.vibrate([200, 100, 200]);
            }
            break;
        case 'start_ai':
            showSnackbar(message, 'success', 5000);
            startDetection();
            break;
        case 'stop_ai':
            showSnackbar(message, 'warning', 5000);
            stopDetection();
            break;
        case 'incoming_call':
            showIncomingCallDialog(message || "Fleet Operations Center is requesting a voice call.");
            break;
        case 'end_call':
            closeIncomingCallDialog();
            showSnackbar("Call ended by Fleet Dispatch.", 'info', 4000);
            break;
        case 'clear':
            // Clear current snackbars
            const snackbars = document.querySelectorAll('.snackbar');
            snackbars.forEach(s => {
                s.classList.remove('show');
                setTimeout(() => s.remove(), 300);
            });
            break;
        default:
            showSnackbar(message, 'info');
    }
};

// ── Incoming Dispatch Call Dialog for Driver ───────────────────
let incomingCallAudio = null;
let driverCallTimer = null;
let driverCallSeconds = 0;

function showIncomingCallDialog(message) {
    // Remove existing if present
    const existing = document.getElementById('driver-incoming-call-modal');
    if (existing) existing.remove();

    // Play ringing tone
    playDriverRingTone();

    // Vibrate phone
    if (navigator.vibrate) {
        navigator.vibrate([300, 200, 300, 200, 600]);
    }

    const modal = document.createElement('div');
    modal.id = 'driver-incoming-call-modal';
    modal.className = 'driver-call-overlay';
    modal.innerHTML = `
        <div class="driver-call-card">
            <div class="driver-call-pulse"></div>
            <div class="driver-call-avatar">
                <span class="material-symbols-rounded" style="font-size: 2.2rem; color: #FFFFFF;">support_agent</span>
            </div>
            <h3 style="margin-top: 14px; font-size: 1.3rem; color: #FFFFFF; font-weight: 700;">Fleet Dispatch</h3>
            <p style="color: #3FB950; font-size: 0.85rem; font-weight: 600; text-transform: uppercase; margin-top: 4px;" id="driver-call-status">Incoming Call...</p>
            <p style="color: rgba(255, 255, 255, 0.7); font-size: 0.85rem; margin: 10px 0 20px;">${message}</p>
            
            <div id="driver-call-timer" style="display: none; font-size: 1.4rem; font-weight: 700; color: #3FB950; margin-bottom: 18px; font-family: monospace;">00:00</div>

            <div class="driver-call-actions" id="driver-call-action-row">
                <button class="driver-call-btn decline" id="btn-driver-decline">
                    <span class="material-symbols-rounded">call_end</span>
                    <span>Decline</span>
                </button>
                <button class="driver-call-btn accept" id="btn-driver-accept">
                    <span class="material-symbols-rounded">call</span>
                    <span>Accept (Hands-free)</span>
                </button>
            </div>
        </div>
    `;

    document.body.appendChild(modal);
    setTimeout(() => modal.classList.add('active'), 10);

    modal.querySelector('#btn-driver-decline').onclick = () => {
        closeIncomingCallDialog();
        showSnackbar("Call declined", 'info');
    };

    modal.querySelector('#btn-driver-accept').onclick = () => {
        stopDriverRingTone();
        const statusText = modal.querySelector('#driver-call-status');
        const timerEl = modal.querySelector('#driver-call-timer');
        const actionRow = modal.querySelector('#driver-call-action-row');

        if (statusText) statusText.innerText = "🎙️ Intercom Connected";
        if (timerEl) timerEl.style.display = "block";

        driverCallSeconds = 0;
        clearInterval(driverCallTimer);
        driverCallTimer = setInterval(() => {
            driverCallSeconds++;
            const m = String(Math.floor(driverCallSeconds / 60)).padStart(2, '0');
            const s = String(driverCallSeconds % 60).padStart(2, '0');
            if (timerEl) timerEl.innerText = `${m}:${s}`;
        }, 1000);

        if (actionRow) {
            actionRow.innerHTML = `
                <button class="driver-call-btn decline" style="width: 100%; max-width: 220px;" id="btn-driver-hangup">
                    <span class="material-symbols-rounded">call_end</span>
                    <span>End Intercom</span>
                </button>
            `;
            modal.querySelector('#btn-driver-hangup').onclick = () => {
                closeIncomingCallDialog();
            };
        }
    };
}

function closeIncomingCallDialog() {
    stopDriverRingTone();
    clearInterval(driverCallTimer);
    const modal = document.getElementById('driver-incoming-call-modal');
    if (modal) {
        modal.classList.remove('active');
        setTimeout(() => modal.remove(), 300);
    }
}

function playDriverRingTone() {
    try {
        const AudioCtx = window.AudioContext || window.webkitAudioContext;
        if (!AudioCtx) return;
        incomingCallAudio = new AudioCtx();

        const osc = incomingCallAudio.createOscillator();
        const gain = incomingCallAudio.createGain();
        osc.connect(gain);
        gain.connect(incomingCallAudio.destination);

        osc.type = 'triangle';
        osc.frequency.setValueAtTime(520, incomingCallAudio.currentTime);
        
        gain.gain.setValueAtTime(0.2, incomingCallAudio.currentTime);
        gain.gain.setValueAtTime(0.01, incomingCallAudio.currentTime + 0.3);
        gain.gain.setValueAtTime(0.2, incomingCallAudio.currentTime + 0.5);
        gain.gain.setValueAtTime(0.01, incomingCallAudio.currentTime + 1.2);

        osc.start(incomingCallAudio.currentTime);
        osc.stop(incomingCallAudio.currentTime + 2.5);
    } catch(e) {}
}

function stopDriverRingTone() {
    if (incomingCallAudio) {
        try { incomingCallAudio.close(); } catch(e){}
        incomingCallAudio = null;
    }
}


/**
 * Shows a snackbar notification in the UI
 * @param {string} message - The message to display
 * @param {string} type - 'info', 'warning', or 'error'
 * @param {number} duration - Time in ms before it disappears
 */
export const showSnackbar = (message, type = 'info', duration = 5000) => {
    // 1. Save to list
    saveNotification(message, type);

    const container = document.getElementById('notification-container');
    if (!container) return;

    const snackbar = document.createElement('div');
    snackbar.className = `snackbar ${type}`;
    
    const icon = type === 'error' ? 'error' : (type === 'warning' ? 'warning' : (type === 'success' ? 'check_circle' : 'info'));
    
    snackbar.innerHTML = `
        <span class="material-symbols-rounded">${icon}</span>
        <div class="snackbar-content">
            <span class="snackbar-message">${message}</span>
        </div>
        <button class="snackbar-close">
            <span class="material-symbols-rounded">close</span>
        </button>
    `;

    container.appendChild(snackbar);

    // Trigger animation
    setTimeout(() => snackbar.classList.add('show'), 10);

    // Vibration feedback (only if user has interacted with the page)
    if (window.navigator.vibrate && navigator.userActivation?.hasBeenActive) {
        try {
            if (type === 'error') window.navigator.vibrate([100, 50, 100]);
            else if (type === 'warning') window.navigator.vibrate(100);
        } catch (e) {
            // Silently fail if blocked by browser policy
        }
    }

    const closeBtn = snackbar.querySelector('.snackbar-close');
    closeBtn.onclick = () => {
        snackbar.classList.remove('show');
        setTimeout(() => snackbar.remove(), 300);
    };

    if (duration > 0) {
        setTimeout(() => {
            if (snackbar.parentNode) {
                snackbar.classList.remove('show');
                setTimeout(() => snackbar.remove(), 300);
            }
        }, duration);
    }
    
    // Also trigger a push notification if permitted
    showPushNotification("Vehicle Alert", message);
};

// --- Notification List Logic ---

const STORAGE_KEY = 'v_monitor_notifs';

const saveNotification = (message, type) => {
    const notifs = getNotifications();
    const newNotif = {
        id: Date.now(),
        message,
        type,
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        date: new Date().toLocaleDateString()
    };
    notifs.unshift(newNotif);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(notifs.slice(0, 50))); // Keep last 50
    updateNotifUI();
};

export const getNotifications = () => {
    const stored = localStorage.getItem(STORAGE_KEY);
    return stored ? JSON.parse(stored) : [];
};

export const deleteNotification = (id) => {
    const notifs = getNotifications().filter(n => n.id !== id);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(notifs));
    updateNotifUI();
};

export const clearAllNotifications = () => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify([]));
    updateNotifUI();
};

export const updateNotifUI = () => {
    const notifs = getNotifications();
    const badge = document.getElementById('notif-badge');
    const list = document.getElementById('notif-list');
    
    if (badge) {
        badge.textContent = notifs.length;
        badge.classList.toggle('active', notifs.length > 0);
    }

    if (list) {
        if (notifs.length === 0) {
            list.innerHTML = '<div class="notif-empty">No new notifications</div>';
            return;
        }

        list.innerHTML = notifs.map(n => `
            <div class="notif-item">
                <div class="notif-item-icon ${n.type}">
                    <span class="material-symbols-rounded">${n.type === 'error' ? 'error' : (n.type === 'warning' ? 'warning' : (n.type === 'success' ? 'check_circle' : 'info'))}</span>
                </div>
                <div class="notif-item-content">
                    <span class="notif-item-msg">${n.message}</span>
                    <span class="notif-item-time">${n.time} • ${n.date}</span>
                </div>
                <button class="notif-item-delete" onclick="window.deleteNotif(${n.id})">
                    <span class="material-symbols-rounded">delete</span>
                </button>
            </div>
        `).join('');
    }
};

// Global helpers for inline onclicks
window.deleteNotif = deleteNotification;
window.clearAllNotifs = clearAllNotifications;


/**
 * Shows a browser push notification using Service Worker for better mobile support
 * @param {string} title 
 * @param {string} body 
 */
export const showPushNotification = async (title, body) => {
    if (!('Notification' in window) || Notification.permission !== 'granted') {
        return;
    }

    // Try to use Service Worker registration (required for mobile/background)
    if ('serviceWorker' in navigator) {
        const registration = await navigator.serviceWorker.ready;
        if (registration) {
            registration.showNotification(title, {
                body: body,
                icon: 'assets/icon-512.png',
                badge: 'assets/icon-512.png',
                vibrate: [100, 50, 100],
                data: {
                    dateOfArrival: Date.now(),
                    primaryKey: 1
                }
            });
            return;
        }
    }

    // Fallback to standard Notification (desktop only)
    new Notification(title, {
        body: body,
        icon: 'assets/icon-512.png'
    });
};


/**
 * Listen for remote telemetry overrides (Speed, Engine Temp)
 */
export const initRemoteTelemetry = () => {
    if (!db || !auth.currentUser) return;

    const driverId = auth.currentUser.uid;
    console.log('[Remote] Initializing telemetry override listener for:', driverId);

    onSnapshot(doc(db, "telemetry_override", driverId), (snapshot) => {
        if (snapshot.exists()) {
            const data = snapshot.data();
            console.log('[Remote] Telemetry override received:', data);
            
            // Update Speed UI
            const speedVal = document.getElementById('speed-val');
            if (speedVal && data.speed !== undefined) {
                speedVal.innerText = `${data.speed} km/h`;
                
                // Add a visual indicator that it's remote-controlled
                speedVal.classList.add('remote-updated');
                setTimeout(() => speedVal.classList.remove('remote-updated'), 2000);
            }

            // Update Engine Temp UI
            const tempVal = document.getElementById('temp-val');
            if (tempVal && data.engineTemp !== undefined) {
                tempVal.innerText = `${data.engineTemp} °C`;
                
                // Add visual indicator
                tempVal.classList.add('remote-updated');
                setTimeout(() => tempVal.classList.remove('remote-updated'), 2000);
            }
        }
    }, (error) => {
        console.error('[Remote] Telemetry listener error:', error);
    });
};

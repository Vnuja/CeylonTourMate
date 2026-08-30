import { messaging, db, auth } from "./firebase-config.js";
import { getToken, onMessage } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging.js";
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

    // 2. Register Service Worker for background notifications (important for mobile)
    if ('serviceWorker' in navigator) {
        try {
            const registration = await navigator.serviceWorker.register('firebase-messaging-sw.js');
            console.log('Service Worker registered with scope:', registration.scope);

            // 3. Get FCM Token
            // VAPID Key validation
            const vapidKey = 'BKWi6F_n6-e94USFNn8Wlqe4abz4CcqW3KqhnRqNxFeSTFQBE_KPbK1XkNQcC9Y_Z3OndlIqLLC6NQIdD2qUkms';
            if (vapidKey.length > 20 && !vapidKey.startsWith('YOUR_')) {
                const token = await getToken(messaging, { vapidKey }).catch(err => {
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

    // 4. Handle foreground messages
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

    // Vibration feedback
    if (window.navigator.vibrate && (navigator.userActivation?.hasBeenActive || document.hasFocus())) {
        try {
            if (type === 'error') window.navigator.vibrate([100, 50, 100]);
            else if (type === 'warning') window.navigator.vibrate(100);
        } catch (e) {
            // Silently fail if blocked by policy
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

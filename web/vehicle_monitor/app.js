import { login, logout, watchAuthState } from "./js/auth.js";
import { initGestures } from "./js/gestures.js";
import { elements, showLoader, updateUI, initElements } from "./js/ui.js";
import { loadComponent } from "./js/loader.js";
import { initLegal } from "./js/legal.js";
import { initMapModule, stopLiveTracking } from "./js/map.js";
import { initNotifications, updateNotifUI, clearAllNotifications, initRemoteCommands, initRemoteTelemetry } from "./js/notifications.js";
import { initDrowsinessDetection, stopDetection } from "./js/drowsiness.js";
import { initComplianceModule } from "./js/compliance.js";

async function initializeApp() {
    console.log("Initializing App...");
    showLoader(true);
    
    // 1. Load HTML Components with cache busting
    const timestamp = Date.now();
    try {
        await Promise.all([
            loadComponent(`components/login.html?v=${timestamp}`, 'screen-container'),
            loadComponent(`components/dashboard.html?v=${timestamp}`, 'screen-container')
        ]);
        console.log("Components loaded.");
    } catch (error) {
        console.error("Failed to load components:", error);
    }

    // 2. Initialize DOM references
    initElements();
    initLegal();
    initNotifications();
    updateNotifUI(); // Refresh list on start
    console.log("DOM elements and notifications initialized.");

    // 3. Set up Auth Listeners
    watchAuthState((user) => {
        console.log("Auth state changed:", user ? "User logged in" : "No user");
        updateUI(user);
        
        if (user) {
            // Verify DOM before initializing map
            const mapEl = document.getElementById('google-map');
            if (mapEl) {
                console.log("Map container found. Map will be initialized by callback or manual call.");
                // initMapModule(); // Let the Google Maps callback handle this or keep as fallback
            } else {
                console.log("Map container not yet in DOM. Waiting for dashboard...");
            }

            // Initialize drowsiness detection
            initDrowsinessDetection();

            // Initialize compliance module
            initComplianceModule();

            // Initialize remote triggers listener
            initRemoteCommands();
            
            // Initialize remote telemetry listener
            initRemoteTelemetry();
        } else {
            // User signed out — stop GPS tracking and drowsiness detection
            stopLiveTracking();
            stopDetection();
        }

    });

    // 4. Set up Event Listeners
    if (elements.signinBtn) {
        elements.signinBtn.addEventListener('click', async () => {
            showLoader(true);
            try {
                await login();
            } catch (error) {
                alert("Login failed: " + error.message);
                showLoader(false);
            }
        });
    }

    if (elements.signoutBtn) {
        elements.signoutBtn.addEventListener('click', async () => {
            showLoader(true);
            try {
                await logout();
            } catch (error) {
                console.error("Logout error:", error);
                showLoader(false);
            }
        });
    }

    // 5. Initialize Gestures
    initGestures(() => {
        if (elements.dashboardScreen && elements.dashboardScreen.classList.contains('active')) {
            console.log("Back gesture detected, signing out...");
            elements.signoutBtn.click();
            if (window.navigator.vibrate) window.navigator.vibrate(50);
        }
    });

    // 6. Notification Panel Listeners
    if (elements.notifBtn) {
        elements.notifBtn.addEventListener('click', () => {
            elements.notifPanel.classList.toggle('active');
        });
    }

    if (elements.closeNotifBtn) {
        elements.closeNotifBtn.addEventListener('click', () => {
            elements.notifPanel.classList.remove('active');
        });
    }

    if (elements.clearAllNotifBtn) {
        elements.clearAllNotifBtn.addEventListener('click', () => {
            clearAllNotifications();
        });
    }

    showLoader(false);
}



// Start the app
initializeApp();

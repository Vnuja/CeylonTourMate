import { login, logout, watchAuthState, checkRedirectResult } from "./js/auth.js";
import { initGestures } from "./js/gestures.js";
import { elements, showLoader, updateUI, initElements } from "./js/ui.js";
import { loadComponent } from "./js/loader.js";
import { initLegal } from "./js/legal.js";
import { initMapModule, stopLiveTracking } from "./js/map.js";
import { initNotifications, updateNotifUI, clearAllNotifications, initRemoteCommands, initRemoteTelemetry, showSnackbar } from "./js/notifications.js";
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

    // 3. Handle pending redirect sign-in result (from signInWithRedirect fallback)
    try {
        const redirectUser = await checkRedirectResult();
        if (redirectUser) {
            console.log("Redirect sign-in completed for:", redirectUser.email);
        }
    } catch (error) {
        console.error("Redirect sign-in error:", error);
        showSnackbar("Sign-in failed: " + _friendlyError(error), 'error', 8000);
        showLoader(false);
    }

    // 4. Set up Auth Listeners
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

    // 5. Set up Event Listeners
    if (elements.signinBtn) {
        elements.signinBtn.addEventListener('click', async () => {
            showLoader(true);
            try {
                await login();
                // If login() uses redirect, the page will navigate away.
                // If popup succeeded, auth state listener handles the rest.
            } catch (error) {
                showSnackbar("Sign-in failed: " + _friendlyError(error), 'error', 8000);
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

    // 6. Initialize Gestures
    initGestures(() => {
        if (elements.dashboardScreen && elements.dashboardScreen.classList.contains('active')) {
            console.log("Back gesture detected, signing out...");
            elements.signoutBtn.click();
            if (window.navigator.vibrate) window.navigator.vibrate(50);
        }
    });

    // 7. Notification Panel Listeners
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

/**
 * Returns a user-friendly error message for common Firebase Auth errors.
 * @param {Error} error
 * @returns {string}
 */
function _friendlyError(error) {
    switch (error.code) {
        case 'auth/unauthorized-domain':
            return 'This domain is not authorized. Please contact the administrator.';
        case 'auth/popup-blocked':
            return 'Popup was blocked by the browser. Please allow popups and try again.';
        case 'auth/popup-closed-by-user':
            return 'Sign-in was cancelled. Please try again.';
        case 'auth/network-request-failed':
            return 'Network error. Please check your connection and try again.';
        case 'auth/too-many-requests':
            return 'Too many attempts. Please wait a moment and try again.';
        default:
            return error.message || 'An unexpected error occurred.';
    }
}


// Start the app
initializeApp();

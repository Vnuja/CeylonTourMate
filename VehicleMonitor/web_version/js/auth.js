import {
    signInWithPopup,
    signInWithRedirect,
    getRedirectResult,
    signOut,
    onAuthStateChanged
} from "https://www.gstatic.com/firebasejs/10.8.0/firebase-auth.js";
import { auth, provider } from "./firebase-config.js";

/**
 * Attempts login via popup first; if the domain is unauthorized or popup is
 * blocked, falls back to redirect-based sign-in which is more reliable on
 * local network IP addresses (e.g. 192.168.x.x).
 */
export const login = async () => {
    try {
        await signInWithPopup(auth, provider);
    } catch (error) {
        const fallbackCodes = [
            'auth/unauthorized-domain',
            'auth/popup-blocked',
            'auth/popup-closed-by-user',
            'auth/cancelled-popup-request',
            'auth/operation-not-supported-in-this-environment'
        ];

        if (fallbackCodes.includes(error.code)) {
            console.warn(`[Auth] Popup failed (${error.code}), falling back to redirect sign-in...`);
            // Redirect-based sign-in — page will reload, result handled in checkRedirectResult()
            await signInWithRedirect(auth, provider);
        } else {
            console.error("[Auth] Login failed:", error);
            throw error;
        }
    }
};

/**
 * Call this once on app startup to capture any pending redirect result.
 * Returns the user if a redirect sign-in just completed, null otherwise.
 */
export const checkRedirectResult = async () => {
    try {
        const result = await getRedirectResult(auth);
        if (result?.user) {
            console.log("[Auth] Redirect sign-in completed:", result.user.email);
            return result.user;
        }
        return null;
    } catch (error) {
        console.error("[Auth] Redirect result error:", error);
        throw error;
    }
};

export const logout = async () => {
    try {
        await signOut(auth);
    } catch (error) {
        console.error("[Auth] Logout failed:", error);
        throw error;
    }
};

export const watchAuthState = (callback) => {
    onAuthStateChanged(auth, callback);
};

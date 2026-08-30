import { initializeApp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-app.js";
import { getAuth, GoogleAuthProvider } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-auth.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";

export const firebaseConfig = {
    apiKey: "AIzaSyCQ9XwaEWDPE3YEaD00AhKMN0dplkiTWAE",
    authDomain: "vehiclemonitor-5b1e8.firebaseapp.com",
    projectId: "vehiclemonitor-5b1e8",
    storageBucket: "vehiclemonitor-5b1e8.firebasestorage.app",
    messagingSenderId: "342502404771",
    appId: "1:342502404771:web:91ba8e2eca1a09cad24516"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const provider = new GoogleAuthProvider();

// Lazily initialize Firebase Messaging only when the browser supports it.
// getMessaging() requires Service Worker + navigator APIs that are unavailable
// in iframes, non-HTTPS contexts, or unsupported browsers.
let _messaging = null;
export const getMessagingInstance = async () => {
    if (_messaging) return _messaging;
    if (!('serviceWorker' in navigator) || !('Notification' in window)) {
        console.warn('[Firebase] This browser does not support Firebase Messaging.');
        return null;
    }
    try {
        const { getMessaging } = await import("https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging.js");
        _messaging = getMessaging(app);
        return _messaging;
    } catch (err) {
        console.warn('[Firebase] Failed to initialize Firebase Messaging:', err.message);
        return null;
    }
};

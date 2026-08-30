import { initializeApp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-app.js";
import { getAuth, GoogleAuthProvider } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-auth.js";
import { getMessaging } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging.js";
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
export const messaging = getMessaging(app);

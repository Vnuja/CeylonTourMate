importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js');

firebase.initializeApp({
    apiKey: "AIzaSyCQ9XwaEWDPE3YEaD00AhKMN0dplkiTWAE",
    authDomain: "vehiclemonitor-5b1e8.firebaseapp.com",
    projectId: "vehiclemonitor-5b1e8",
    storageBucket: "vehiclemonitor-5b1e8.firebasestorage.app",
    messagingSenderId: "342502404771",
    appId: "1:342502404771:web:91ba8e2eca1a09cad24516"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    
    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/vehicle_monitor/assets/icon-512.png'
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});

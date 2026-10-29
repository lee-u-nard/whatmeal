// Firebase Cloud Messaging Service Worker
// Required for web push notifications via firebase_messaging Flutter package.
// This file MUST be at the web root and named exactly "firebase-messaging-sw.js".

importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

// Initialize Firebase in the service worker with the same config as your app.
// These values are safe to be public (they identify the project, not authorize it).
firebase.initializeApp({
  apiKey: 'AIzaSyBOs6f2xaWkbFzPr4_5J_ainp61_k-1vfE',
  authDomain: 'whatmeal-101.firebaseapp.com',
  projectId: 'whatmeal-101',
  storageBucket: 'whatmeal-101.firebasestorage.app',
  messagingSenderId: '321735824503',
  appId: '1:321735824503:web:d8a72c9c67c85a39e42272',
  measurementId: 'G-6H2TGDSHW8',
});

const messaging = firebase.messaging();

// Handle background messages (app is not in foreground tab)
messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification ?? {};
  if (!title) return;
  self.registration.showNotification(title, {
    body: body ?? '',
    icon: '/icons/Icon-192.png',
  });
});

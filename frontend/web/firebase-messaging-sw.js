// Firebase Cloud Messaging Service Worker
// This file handles background push notifications for the web app
// Also integrates Flutter's PWA caching for offline support

// IMPORTANT: Import Flutter's service worker first for PWA caching
// This provides offline support and app shell caching
try {
  importScripts('flutter_service_worker.js');
  console.log('[FCM SW] ✅ Flutter service worker imported successfully');
} catch (error) {
  console.warn('[FCM SW] ⚠️  Flutter service worker not found (may not be built yet):', error.message);
  // Continue without Flutter caching - FCM will still work
}

// Import Firebase scripts from CDN
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

// ⚠️ SECURITY: Firebase config is injected at runtime from main Flutter app
// NO API keys are hardcoded in this file to prevent accidental Git exposure
// The main app sends the complete config via postMessage after service worker loads

let isFirebaseInitialized = false;

// Listen for Firebase config from main app
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'FIREBASE_CONFIG' && !isFirebaseInitialized) {
    console.log('[FCM SW] 🔧 Received Firebase config from main app');

    try {
      // Initialize Firebase with runtime config
      firebase.initializeApp(event.data.config);
      const messaging = firebase.messaging();
      isFirebaseInitialized = true;
      console.log('[FCM SW] ✅ Firebase initialized successfully with runtime config');

      // Set up background message handler
      messaging.onBackgroundMessage((payload) => {
        console.log('='.repeat(80));
        console.log('[FCM SW] 🔔🔔🔔 BACKGROUND MESSAGE RECEIVED 🔔🔔🔔');
        console.log('[FCM SW] Timestamp:', new Date().toISOString());
        console.log('[FCM SW] Full Payload:', JSON.stringify(payload, null, 2));
        console.log('='.repeat(80));

        // Customize notification
        const notificationTitle = payload.notification?.title || 'Disciplefy';
        const notificationBody = payload.notification?.body || 'You have a new notification';

        const notificationOptions = {
          body: notificationBody,
          icon: payload.notification?.icon || '/icons/Icon-192.png',
          badge: '/icons/Icon-192.png',
          tag: payload.data?.type || 'default',
          data: payload.data || {},
          requireInteraction: false,
        };

        // Add action buttons based on notification type
        if (payload.data?.type === 'daily_verse') {
          notificationOptions.actions = [
            { action: 'open', title: 'Read Verse', icon: '/icons/Icon-192.png' }
          ];
        } else if (payload.data?.type === 'recommended_topic') {
          notificationOptions.actions = [
            { action: 'open', title: 'View Topic', icon: '/icons/Icon-192.png' }
          ];
        }

        console.log('[FCM SW] 🔔 Showing notification...');
        return self.registration.showNotification(notificationTitle, notificationOptions)
          .then(() => {
            console.log('[FCM SW] ✅ ✅ ✅ NOTIFICATION DISPLAYED SUCCESSFULLY ✅ ✅ ✅');
          })
          .catch((error) => {
            console.error('[FCM SW] ❌ Failed to show notification:', error);
            throw error;
          });
      });

    } catch (error) {
      console.error('[FCM SW] ❌ Failed to initialize Firebase:', error);
    }
  }
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('[FCM SW] 👆 Notification clicked');
  event.notification.close();

  // Determine the URL to open based on notification data
  let urlToOpen = self.location.origin + '/';

  if (event.notification.data) {
    const data = event.notification.data;
    if (data.type === 'daily_verse') {
      urlToOpen = self.location.origin + '/';
    } else if (data.type === 'recommended_topic' && data.topic_id) {
      urlToOpen = self.location.origin + `/study-topics?topic_id=${data.topic_id}`;
    } else if (data.click_action) {
      urlToOpen = self.location.origin + data.click_action;
    }
  }

  // Open the app or focus existing window
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Check if there's already a window open
        for (const client of clientList) {
          if (client.url.includes(self.location.origin)) {
            // Post message to client for navigation
            client.postMessage({
              type: 'NOTIFICATION_CLICK',
              url: urlToOpen,
              data: event.notification.data
            });
            return client.focus();
          }
        }
        // No window found, open a new one
        if (clients.openWindow) {
          return clients.openWindow(urlToOpen);
        }
      })
  );
});

console.log('[FCM SW] Service worker registered and waiting for Firebase config from main app');

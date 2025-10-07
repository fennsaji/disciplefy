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

// Initialize Firebase in the service worker
// Note: These values will be replaced with actual Firebase config
// Run 'flutterfire configure' to generate firebase_options.dart
// Then update these values accordingly
const firebaseConfig = {
  apiKey: "AIzaSyDfCd9JuqJKvi3Dq2pD87ZXe6bhVYWoSmc",
  authDomain: "disciplefy---bible-study.firebaseapp.com",
  projectId: "disciplefy---bible-study",
  storageBucket: "disciplefy---bible-study.firebasestorage.app",
  messagingSenderId: "16888340359",
  appId: "1:16888340359:web:36ad4ae0d1ef1adf8e3d22",
  measurementId: "G-TY0KDPH5TS"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

// Retrieve Firebase Messaging instance
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('='.repeat(80));
  console.log('[FCM SW] 🔔🔔🔔 BACKGROUND MESSAGE RECEIVED 🔔🔔🔔');
  console.log('[FCM SW] Timestamp:', new Date().toISOString());
  console.log('[FCM SW] Full Payload:', JSON.stringify(payload, null, 2));
  console.log('[FCM SW] Notification:', payload.notification);
  console.log('[FCM SW] Data:', payload.data);
  console.log('[FCM SW] Message ID:', payload.messageId);
  console.log('[FCM SW] From:', payload.from);
  console.log('='.repeat(80));

  // Customize notification here
  const notificationTitle = payload.notification?.title || 'Disciplefy';
  const notificationBody = payload.notification?.body || 'You have a new notification';

  console.log('[FCM SW] 📝 Preparing notification...');
  console.log('[FCM SW]    Title:', notificationTitle);
  console.log('[FCM SW]    Body:', notificationBody);
  console.log('[FCM SW]    Type:', payload.data?.type || 'none');

  const notificationOptions = {
    body: notificationBody,
    icon: payload.notification?.icon || '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.type || 'default',
    data: payload.data || {},
    // Show notification for 10 seconds
    requireInteraction: false,
  };

  // Add action buttons based on notification type
  if (payload.data?.type === 'daily_verse') {
    notificationOptions.actions = [
      { action: 'open', title: 'Read Verse', icon: '/icons/Icon-192.png' },
      { action: 'dismiss', title: 'Dismiss' }
    ];
    console.log('[FCM SW] ✅ Added daily verse action buttons');
  } else if (payload.data?.type === 'recommended_topic') {
    notificationOptions.actions = [
      { action: 'open', title: 'View Topic', icon: '/icons/Icon-192.png' },
      { action: 'dismiss', title: 'Dismiss' }
    ];
    console.log('[FCM SW] ✅ Added recommended topic action buttons');
  }

  console.log('[FCM SW] 🔔 Showing notification...');
  console.log('[FCM SW] Notification options:', JSON.stringify(notificationOptions, null, 2));

  return self.registration.showNotification(notificationTitle, notificationOptions)
    .then(() => {
      console.log('[FCM SW] ✅ ✅ ✅ NOTIFICATION DISPLAYED SUCCESSFULLY ✅ ✅ ✅');
      console.log('='.repeat(80));
    })
    .catch((error) => {
      console.error('[FCM SW] ❌ ❌ ❌ FAILED TO SHOW NOTIFICATION ❌ ❌ ❌');
      console.error('[FCM SW] Error:', error);
      console.error('[FCM SW] Error details:', error.message, error.stack);
      console.log('='.repeat(80));
      throw error;
    });
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('='.repeat(80));
  console.log('[FCM SW] 👆👆👆 NOTIFICATION CLICKED 👆👆👆');
  console.log('[FCM SW] Notification:', event.notification);
  console.log('[FCM SW] Action:', event.action);
  console.log('[FCM SW] Data:', event.notification.data);
  console.log('='.repeat(80));

  event.notification.close();

  // Handle action buttons
  if (event.action === 'dismiss') {
    return;
  }

  // Determine the URL to open based on notification data
  let urlToOpen = self.location.origin + '/';

  if (event.notification.data) {
    const data = event.notification.data;

    if (data.type === 'daily_verse') {
      urlToOpen = self.location.origin + '/'; // Home page has daily verse
    } else if (data.type === 'recommended_topic' && data.topic_id) {
      urlToOpen = self.location.origin + `/study-topics?topic_id=${data.topic_id}`;
    } else if (data.click_action) {
      urlToOpen = self.location.origin + data.click_action;
    }
  }

  console.log('[FCM SW] 🔗 Opening URL:', urlToOpen);

  // Open the app or focus existing window
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        console.log('[FCM SW] 🔍 Found', clientList.length, 'client window(s)');

        // Check if there's already a window open with our app
        for (let i = 0; i < clientList.length; i++) {
          const client = clientList[i];
          console.log('[FCM SW] 🔍 Checking client:', client.url);

          if (client.url.includes(self.location.origin)) {
            console.log('[FCM SW] ✅ Found matching client, posting message');

            // Instead of navigate (which causes the error), post a message to the client
            // The client will handle the navigation
            client.postMessage({
              type: 'NOTIFICATION_CLICK',
              url: urlToOpen,
              data: event.notification.data
            });

            // Focus the client
            return client.focus();
          }
        }

        // No window found, open a new one
        console.log('[FCM SW] 🆕 No existing client found, opening new window');
        if (clients.openWindow) {
          return clients.openWindow(urlToOpen);
        }
      })
      .catch((error) => {
        console.error('[FCM SW] ❌ Error handling notification click:', error);
      })
  );
});

// Log service worker registration
console.log('[firebase-messaging-sw.js] Service worker registered and ready');

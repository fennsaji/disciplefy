// Firebase Cloud Messaging Service Worker
// This file handles background push notifications for the web app
// Also caches the app shell and assets (see App caching below)

// ---------------------------------------------------------------------------
// App caching
//
// Registered by flutter_bootstrap.js as /firebase-messaging-sw.js?v=<build>.
// The build hash in the URL makes every deploy install a new worker, which
// deletes the previous build's cache when it activates.
//
//  - Shell (navigations, *.js at the root incl. deferred *.part.js, manifests,
//    version.json): network-first, cache fallback (offline). Never stale.
//  - /assets/*: cache-first in a per-build cache (fonts, images, translations).
//  - /canvaskit/*: cache-first in a cache keyed by the Flutter engine revision
//    (read from flutter_bootstrap.js), so the ~7 MB engine survives deploys and
//    is replaced only when Flutter itself is upgraded.
//  - Everything else (other origins, APIs, non-GET): not intercepted.
// ---------------------------------------------------------------------------
const BUILD_VERSION = (() => {
  const v = new URL(self.location.href).searchParams.get('v');
  return v && !v.includes('{') ? v : null; // null: unversioned/dev, no caching
})();
const CACHE_PREFIX = 'disciplefy-';
const APP_CACHE = `${CACHE_PREFIX}app-${BUILD_VERSION}`;
const ENGINE_CACHE_PREFIX = `${CACHE_PREFIX}canvaskit-`;
let engineCacheName = null;

async function resolveEngineCache() {
  if (engineCacheName) return engineCacheName;
  try {
    const res = await fetch('/flutter_bootstrap.js', { cache: 'no-cache' });
    const match = /"engineRevision":"([0-9a-f]+)"/.exec(await res.text());
    if (match) engineCacheName = ENGINE_CACHE_PREFIX + match[1];
  } catch (_) {
    // Offline: fall back to the newest existing engine cache below.
  }
  if (!engineCacheName) {
    const names = (await caches.keys()).filter((n) => n.startsWith(ENGINE_CACHE_PREFIX));
    engineCacheName = names[names.length - 1] || null;
  }
  return engineCacheName;
}

self.addEventListener('install', (event) => {
  self.skipWaiting();
  if (BUILD_VERSION) event.waitUntil(resolveEngineCache());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keep = new Set([APP_CACHE, await resolveEngineCache()]);
    const names = await caches.keys();
    await Promise.all(names
      .filter((n) => n.startsWith(CACHE_PREFIX) && !keep.has(n))
      .map((n) => caches.delete(n)));
    await self.clients.claim();
  })());
});

function isCacheable(response) {
  return response && response.ok && response.type === 'basic';
}

async function networkFirst(request) {
  const cache = await caches.open(APP_CACHE);
  // Every route serves the same index.html; store it once under '/' so URLs
  // carrying OAuth codes or tokens never end up as cache keys.
  const key = request.mode === 'navigate' ? '/' : request;
  try {
    const response = await fetch(request);
    if (isCacheable(response) && !response.redirected) cache.put(key, response.clone());
    return response;
  } catch (error) {
    const cached = await cache.match(key);
    if (cached) return cached;
    throw error;
  }
}

async function cacheFirst(request, cacheName) {
  if (!cacheName) return fetch(request);
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (isCacheable(response)) cache.put(request, response.clone());
  return response;
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (!BUILD_VERSION || request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  const path = url.pathname;

  // Standalone pages (auth_redirect.html, offline.html, 404.html) are not the
  // app shell: leave them to the network.
  if (request.mode === 'navigate' && /\.html$/.test(path) && path !== '/index.html') return;

  if (path.startsWith('/canvaskit/')) {
    event.respondWith(resolveEngineCache().then((name) => cacheFirst(request, name)));
  } else if (path.startsWith('/assets/') && !/\/assets\/(AssetManifest|FontManifest)/.test(path)) {
    event.respondWith(cacheFirst(request, APP_CACHE));
  } else if (
    request.mode === 'navigate' ||
    /^\/[^/]+\.(js|json)$/.test(path) ||
    path.startsWith('/assets/')
  ) {
    event.respondWith(networkFirst(request));
  }
  // Anything else (icons, auth callbacks, .well-known, ...) goes to the network.
});

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

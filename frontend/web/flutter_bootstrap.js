{{flutter_js}}
{{flutter_build_config}}

// No serviceWorkerSettings: Flutter's own service worker is deprecated and its
// build output is a stub that unregisters whatever runs at scope "/" — which
// would remove the Firebase Messaging worker below.
_flutter.loader.load();

// One worker handles push (Firebase Messaging) and app caching. The build
// replaces the version token with a hash of this build, so every deploy has a
// new worker URL: the browser installs it, and it drops the previous build's
// caches when it activates.
// The token becomes a quoted string literal (plus a comment) at build time.
const appBuildVersion = {{flutter_service_worker_version}};
if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    navigator.serviceWorker
      .register('/firebase-messaging-sw.js?v=' + encodeURIComponent(appBuildVersion))
      .catch(function (error) {
        console.error('Service worker registration failed:', error);
      });
  });
}

/**
 * Store fallback for shareable deep links.
 *
 * When the native app is installed, Android App Links / iOS Universal Links
 * intercept these URLs and this page never loads. So if this script runs on a
 * mobile browser, the app is (almost always) not installed — send the visitor
 * to the store instead of the web app.
 *
 * Desktop always continues into the web app.
 *
 * Escape hatch: append `?web=1` to stay in the browser. The choice is
 * remembered for the session so a visitor is not bounced repeatedly.
 */
(function () {
  'use strict';

  // Keep in sync with the Android intent filters and the AASA paths.
  var DEEP_LINK_PREFIXES = ['/learning-path/', '/fellowship/join/'];

  var PLAY_STORE_URL =
    'https://play.google.com/store/apps/details?id=com.disciplefy.bible_study&hl=en_IN';

  // iOS listing does not exist yet — the app has not cleared App Review.
  // Set this to the apps.apple.com URL once it does; until then iOS visitors
  // stay on the web app rather than being sent to a broken link.
  var APP_STORE_URL = null;

  var STAY_ON_WEB_KEY = 'disciplefy_stay_on_web';

  function isDeepLinkPath(path) {
    for (var i = 0; i < DEEP_LINK_PREFIXES.length; i++) {
      if (path.indexOf(DEEP_LINK_PREFIXES[i]) === 0) return true;
    }
    return false;
  }

  function storeUrlForPlatform(ua) {
    // iPadOS 13+ reports as Macintosh; the touch check separates it from a Mac.
    var isIOS =
      /iPad|iPhone|iPod/.test(ua) ||
      (/Macintosh/.test(ua) && typeof document !== 'undefined' &&
        'ontouchend' in document);
    if (isIOS) return APP_STORE_URL;
    if (/Android/.test(ua)) return PLAY_STORE_URL;
    return null; // desktop — continue into the web app
  }

  try {
    var path = window.location.pathname || '';
    if (!isDeepLinkPath(path)) return;

    var params = new URLSearchParams(window.location.search || '');
    if (params.get('web') === '1') {
      try {
        window.sessionStorage.setItem(STAY_ON_WEB_KEY, '1');
      } catch (e) {
        /* private mode — honour the param for this page load only */
      }
      return;
    }

    try {
      if (window.sessionStorage.getItem(STAY_ON_WEB_KEY) === '1') return;
    } catch (e) {
      /* sessionStorage unavailable — fall through */
    }

    var storeUrl = storeUrlForPlatform(window.navigator.userAgent || '');
    if (!storeUrl) return;

    // replace() so the store does not become a back-button trap.
    window.location.replace(storeUrl);
  } catch (e) {
    // Never let this break the web app.
    if (window.console && window.console.warn) {
      window.console.warn('[deep-link-fallback] skipped:', e);
    }
  }
})();

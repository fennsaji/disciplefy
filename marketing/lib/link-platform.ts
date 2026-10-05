/**
 * Device detection for the link-in-bio page.
 *
 * The page is statically rendered, so the server cannot read the visitor's
 * user agent (reading `headers()` would make the route dynamic). Instead a
 * tiny inline script runs before first paint, classifies the device and sets
 * `data-platform` on <html>. CSS then reveals the matching call-to-action
 * slot, so the right store button is on screen from the first frame: no
 * client round trip, no flash, no layout shift.
 *
 * The rules mirror `platformFromUserAgent` in app-links.ts, plus
 * `navigator.userAgentData.platform` for Chromium builds that freeze the UA
 * string. In-app browsers (Instagram, Facebook, WhatsApp, Telegram) keep the
 * OS token in their UA — "iPhone" or "Android" — so they classify correctly.
 */
import type { StorePlatform } from "./app-links";

/**
 * Rendered as an inline <script> at the top of the page body, so it runs
 * before the call-to-action below it is parsed or painted. Self-contained
 * ES5 so it works in old webviews; any failure leaves the default slot.
 */
export const PLATFORM_SCRIPT =
  '(function(){try{var n=navigator,u=n.userAgent||"",' +
  'd=n.userAgentData,p=d&&d.platform?String(d.platform):"",' +
  'r="other";' +
  'if(/iPhone|iPad|iPod/i.test(u)||/^iOS$/i.test(p))r="ios";' +
  'else if(/Android/i.test(u)||/^Android$/i.test(p))r="android";' +
  'else if(/Macintosh/i.test(u)&&n.maxTouchPoints>1)r="ios";' +
  'document.documentElement.setAttribute("data-platform",r)}catch(e){}})();';

/**
 * Shows exactly one `[data-platform-slot]` per group. Before the script runs
 * (or with JavaScript off) the "other" slot shows: web app first, both
 * stores beside it — correct for every device, just not tailored.
 */
export const PLATFORM_STYLES =
  "[data-platform-slot]{display:none}" +
  'html:not([data-platform]) [data-platform-slot="other"],' +
  'html[data-platform="other"] [data-platform-slot="other"],' +
  'html[data-platform="ios"] [data-platform-slot="ios"],' +
  'html[data-platform="android"] [data-platform-slot="android"]{display:contents}';

export const PLATFORMS: StorePlatform[] = ["ios", "android", "other"];

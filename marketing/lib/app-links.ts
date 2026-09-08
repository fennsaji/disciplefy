/** Single source of truth for app store and web app URLs. */

export const APP_PACKAGE_ID = "com.disciplefy.bible_study";

export const PLAY_STORE_URL = `https://play.google.com/store/apps/details?id=${APP_PACKAGE_ID}&hl=en_IN`;

export const WEB_APP_URL = "https://app.disciplefy.in";

/**
 * The link to hand out whenever someone should "get the app": in-article
 * CTAs, house ads, share text. One page lists Android, iOS and web, so the
 * same URL works for every reader — no more platform-specific store links
 * in shared content.
 */
export const APP_LINKS_URL = "https://links.disciplefy.in";

/**
 * App Store numeric id, used for the iOS Smart App Banner.
 *
 * iOS has no equivalent of Android's intent fallback, so a shared link cannot
 * send a reader to the App Store when the app is missing. Apple's own banner
 * covers it: iOS shows OPEN when the app is installed and VIEW when it is not,
 * without the page having to guess which.
 */
export const APP_STORE_ID = "6778309947";

/** iOS App Store URL. Live — app cleared App Review. */
export const APP_STORE_URL: string | null =
  "https://apps.apple.com/in/app/disciplefy-bible-study-app/id6778309947";

/** Which app store to offer, based on the visitor's user agent. */
export type StorePlatform = "ios" | "android" | "other";

/**
 * Classifies a user agent for the shared-link landing page.
 *
 * iPadOS 13+ reports a Macintosh user agent, so an iPad is only
 * distinguishable by its touch support; callers pass that in.
 */
export function platformFromUserAgent(
  userAgent: string,
  hasTouch = false,
): StorePlatform {
  if (/iPhone|iPad|iPod/i.test(userAgent)) return "ios";
  if (/Android/i.test(userAgent)) return "android";
  if (/Macintosh/i.test(userAgent) && hasTouch) return "ios";
  return "other";
}

/** The store link to show for [platform], or null when there is none. */
export function storeUrlFor(platform: StorePlatform): string | null {
  if (platform === "ios") return APP_STORE_URL;
  if (platform === "android") return PLAY_STORE_URL;
  return null;
}

/**
 * Android intent URL that opens the app, or falls back to Play when it is not
 * installed.
 *
 * A plain https link cannot do this: with no app to claim it the browser just
 * loads the web app, so someone who was sent a post and does not have
 * Disciplefy ended up on the web onboarding flow instead of the store. Android
 * resolves `intent://` against the package and uses `browser_fallback_url`
 * when nothing handles it, which is the one mechanism that distinguishes the
 * two cases without guessing.
 *
 * iOS has no equivalent — a Universal Link opens the app when installed and
 * otherwise loads the URL in Safari — so iOS keeps the https link and the
 * store is offered separately.
 */
export function androidIntentUrl(httpsUrl: string): string {
  const url = new URL(httpsUrl);
  const target = `${url.host}${url.pathname}${url.search}`;
  const fallback = encodeURIComponent(PLAY_STORE_URL);
  return (
    `intent://${target}#Intent;scheme=https;package=${APP_PACKAGE_ID};` +
    `S.browser_fallback_url=${fallback};end`
  );
}

/** Single source of truth for app store and web app URLs. */

export const APP_PACKAGE_ID = "com.disciplefy.bible_study";

export const PLAY_STORE_URL = `https://play.google.com/store/apps/details?id=${APP_PACKAGE_ID}&hl=en_IN`;

export const WEB_APP_URL = "https://app.disciplefy.in";

/**
 * iOS App Store URL. Null until the app clears App Review — the /links page
 * renders a disabled "coming soon" row while this is null.
 */
export const APP_STORE_URL: string | null = null;

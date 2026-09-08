import { describe, expect, it } from "vitest";
import {
  APP_PACKAGE_ID,
  APP_STORE_URL,
  PLAY_STORE_URL,
  androidIntentUrl,
  platformFromUserAgent,
  storeUrlFor,
} from "./app-links";

const IPHONE =
  "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1";
const ANDROID =
  "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36";
const DESKTOP =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36";
const WHATSAPP_ANDROID =
  "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36 [FB_IAB/FB4A;FBAV/1.0]";

describe("platformFromUserAgent", () => {
  it("detects iOS", () => {
    expect(platformFromUserAgent(IPHONE)).toBe("ios");
  });

  it("detects Android", () => {
    expect(platformFromUserAgent(ANDROID)).toBe("android");
  });

  it("treats desktop as neither", () => {
    expect(platformFromUserAgent(DESKTOP)).toBe("other");
  });

  it("still detects Android inside a chat app's in-app browser", () => {
    expect(platformFromUserAgent(WHATSAPP_ANDROID)).toBe("android");
  });

  it("treats a touch Macintosh as an iPad", () => {
    // iPadOS 13+ reports a desktop user agent; touch support is the only tell.
    expect(platformFromUserAgent(DESKTOP, true)).toBe("ios");
    expect(platformFromUserAgent(DESKTOP, false)).toBe("other");
  });
});

describe("storeUrlFor", () => {
  it("offers the App Store on iOS", () => {
    expect(storeUrlFor("ios")).toBe(APP_STORE_URL);
  });

  it("offers Play on Android", () => {
    expect(storeUrlFor("android")).toBe(PLAY_STORE_URL);
  });

  it("offers no store on desktop", () => {
    expect(storeUrlFor("other")).toBeNull();
  });
});

describe("androidIntentUrl", () => {
  const shared =
    "https://app.disciplefy.in/fellowship/f1/post/p1";

  it("targets the app package and keeps the deep-link path", () => {
    const url = androidIntentUrl(shared);

    expect(url.startsWith("intent://app.disciplefy.in/fellowship/f1/post/p1#Intent;")).toBe(true);
    expect(url).toContain("scheme=https");
    expect(url).toContain(`package=${APP_PACKAGE_ID}`);
  });

  it("falls back to Play when nothing handles the intent", () => {
    // Without this, a reader who does not have the app lands on the web
    // onboarding flow instead of the store.
    expect(androidIntentUrl(shared)).toContain(
      `S.browser_fallback_url=${encodeURIComponent(PLAY_STORE_URL)}`,
    );
  });

  it("keeps a query string on the deep link", () => {
    expect(androidIntentUrl(`${shared}?source=share`)).toContain(
      "intent://app.disciplefy.in/fellowship/f1/post/p1?source=share#Intent;",
    );
  });
});

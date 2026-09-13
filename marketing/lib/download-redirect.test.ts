import { describe, expect, it } from "vitest";
import {
  APP_STORE_URL,
  PLAY_STORE_URL,
  WEB_APP_URL,
  downloadRedirectUrl,
  isLinkPreviewBot,
} from "./app-links";

const IPHONE =
  "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1";
const IPAD_MOBILE =
  "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1";
const ANDROID =
  "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36";
const ANDROID_INSTAGRAM =
  "Mozilla/5.0 (Linux; Android 14; SM-S918B Build/UP1A; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/126.0 Mobile Safari/537.36 Instagram 340.0.0.0";
const DESKTOP_MAC =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36";
const DESKTOP_WINDOWS =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0";

describe("downloadRedirectUrl", () => {
  it("sends Android to Google Play", () => {
    expect(downloadRedirectUrl(ANDROID)).toBe(PLAY_STORE_URL);
  });

  it("sends Android in-app browsers to Google Play", () => {
    expect(downloadRedirectUrl(ANDROID_INSTAGRAM)).toBe(PLAY_STORE_URL);
  });

  it("sends iPhone and iPad to the App Store", () => {
    expect(downloadRedirectUrl(IPHONE)).toBe(APP_STORE_URL);
    expect(downloadRedirectUrl(IPAD_MOBILE)).toBe(APP_STORE_URL);
  });

  it("sends desktop browsers to the web app", () => {
    expect(downloadRedirectUrl(DESKTOP_MAC)).toBe(WEB_APP_URL);
    expect(downloadRedirectUrl(DESKTOP_WINDOWS)).toBe(WEB_APP_URL);
  });

  it("sends an empty user agent to the web app", () => {
    expect(downloadRedirectUrl("")).toBe(WEB_APP_URL);
  });

  it("does not redirect link-preview crawlers, so shares keep their card", () => {
    for (const bot of [
      "WhatsApp/2.24.13.78 A",
      "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
      "TelegramBot (like TwitterBot)",
      "Twitterbot/1.0",
      "Slackbot-LinkExpanding 1.0 (+https://api.slack.com/robots)",
      "Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)",
      "LinkedInBot/1.0 (compatible; Mozilla/5.0; Apache-HttpClient +http://www.linkedin.com)",
    ]) {
      expect(isLinkPreviewBot(bot)).toBe(true);
      expect(downloadRedirectUrl(bot)).toBeNull();
    }
  });

  it("does not treat real browsers as bots", () => {
    for (const ua of [IPHONE, ANDROID, ANDROID_INSTAGRAM, DESKTOP_MAC, DESKTOP_WINDOWS]) {
      expect(isLinkPreviewBot(ua)).toBe(false);
    }
  });
});

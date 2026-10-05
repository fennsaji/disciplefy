import { describe, expect, it } from "vitest";
import { NextRequest } from "next/server";
import middleware from "./middleware";
import { APP_STORE_URL, PLAY_STORE_URL, WEB_APP_URL } from "./lib/app-links";

const IPHONE =
  "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1";
const ANDROID =
  "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36";
const DESKTOP =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36";
const WHATSAPP_CRAWLER = "WhatsApp/2.23.20.0";

function request(url: string, userAgent: string) {
  const { host } = new URL(url);
  return new NextRequest(url, { headers: { host, "user-agent": userAgent } });
}

const rewriteOf = (res: Response) => res.headers.get("x-middleware-rewrite");

describe("go.disciplefy.in download routing", () => {
  const entries = [
    "https://go.disciplefy.in/",
    "https://go.disciplefy.in",
    "https://go.disciplefy.in/?utm_source=instagram",
    "https://go.disciplefy.in/download",
    "https://go.disciplefy.in/download/",
  ];

  it.each(entries)("%s sends iPhone to the App Store", (url) => {
    const res = middleware(request(url, IPHONE));
    expect(res.status).toBe(302);
    expect(res.headers.get("location")).toBe(APP_STORE_URL);
    expect(res.headers.get("cache-control")).toBe("no-store");
    expect(res.headers.get("vary")).toBe("User-Agent");
  });

  it.each(entries)("%s sends Android to Google Play", (url) => {
    const res = middleware(request(url, ANDROID));
    expect(res.status).toBe(302);
    expect(res.headers.get("location")).toBe(PLAY_STORE_URL);
  });

  it.each(entries)("%s sends desktop to the web app", (url) => {
    const res = middleware(request(url, DESKTOP));
    expect(res.status).toBe(302);
    expect(res.headers.get("location")).toBe(new URL(WEB_APP_URL).href);
  });

  it.each(entries)("%s shows link-preview crawlers the download page", (url) => {
    const res = middleware(request(url, WHATSAPP_CRAWLER));
    expect(res.headers.get("location")).toBeNull();
    expect(rewriteOf(res)).toBe("https://go.disciplefy.in/go/download");
  });

  it("leaves other go paths on their landing pages", () => {
    const res = middleware(request("https://go.disciplefy.in/daily-verse", IPHONE));
    expect(res.headers.get("location")).toBeNull();
    expect(rewriteOf(res)).toBe("https://go.disciplefy.in/go/daily-verse");
  });
});

describe("links.disciplefy.in routing", () => {
  it("serves the links page at the host root", () => {
    const res = middleware(request("https://links.disciplefy.in/", IPHONE));
    expect(rewriteOf(res)).toBe("https://links.disciplefy.in/links");
  });
});

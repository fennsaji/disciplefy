// marketing/app/og/route.tsx
// Puppeteer-based OG image renderer for proper Indic script shaping.
// Chrome's built-in HarfBuzz engine handles Devanagari/Malayalam natively —
// no custom fonts needed.
import { NextRequest, NextResponse } from "next/server";
import puppeteer from "puppeteer-core";
import fs from "fs";
import path from "path";

// Node.js runtime — Puppeteer cannot run on edge
export const runtime = "nodejs";

async function getLaunchOptions(): Promise<{ executablePath: string; args: string[] }> {
  if (process.env.VERCEL || process.env.NODE_ENV === "production") {
    const chromium = (await import("@sparticuz/chromium")).default;
    return {
      executablePath: await chromium.executablePath(),
      args: chromium.args,
    };
  }
  // macOS local dev
  const candidates = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
  ];
  const executablePath = candidates.find((p) => fs.existsSync(p)) ?? candidates[0];
  return { executablePath, args: [] };
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function buildHtml(title: string, subtitle: string, splashB64: string | null): string {
  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: 1200px; height: 630px; overflow: hidden; }
  body {
    display: flex;
    width: 1200px;
    height: 630px;
    background: #0F172A;
  }
  .left {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: flex-start;
    flex: 1;
    padding: 60px 48px 60px 60px;
  }
  .brand {
    font-size: 28px;
    font-weight: 700;
    color: #A5B4FC;
    margin-bottom: 32px;
    letter-spacing: -0.3px;
  }
  .title {
    font-size: 52px;
    font-weight: 800;
    color: #A5B4FC;
    line-height: 1.15;
    margin-bottom: 20px;
  }
  .subtitle {
    font-size: 22px;
    color: #94A3B8;
    line-height: 1.4;
  }
  .domain {
    margin-top: 40px;
    font-size: 16px;
    color: #A5B4FC;
  }
  .right {
    display: flex;
    align-items: center;
    padding-right: 40px;
    flex-shrink: 0;
  }
  .splash {
    width: 300px;
    height: 300px;
    object-fit: cover;
    object-position: center top;
    border-radius: 24px;
  }
</style>
</head>
<body>
  <div class="left">
    <div class="brand">Disciplefy</div>
    <div class="title">${escapeHtml(title)}</div>
    <div class="subtitle">${escapeHtml(subtitle)}</div>
    <div class="domain">disciplefy.in</div>
  </div>
  ${splashB64 ? `<div class="right"><img class="splash" src="data:image/png;base64,${splashB64}" /></div>` : ""}
</body>
</html>`;
}

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const title = searchParams.get("title") ?? "Disciplefy";
  const subtitle = searchParams.get("subtitle") ?? "AI Bible Study in Your Language";

  // Splash image embedded as data URI (no external requests during render)
  let splashB64: string | null = null;
  try {
    const splashPath = path.join(process.cwd(), "public", "splash-og.png");
    if (fs.existsSync(splashPath)) splashB64 = fs.readFileSync(splashPath).toString("base64");
  } catch { /* skip */ }

  const html = buildHtml(title, subtitle, splashB64);
  const { executablePath, args } = await getLaunchOptions();

  const browser = await puppeteer.launch({
    executablePath,
    args: [
      ...args,
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu",
    ],
    headless: true,
  });

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1200, height: 630, deviceScaleFactor: 1 });
    await page.setContent(html, { waitUntil: "load" });
    const screenshot = await page.screenshot({ type: "png" });

    return new NextResponse(screenshot as unknown as BodyInit, {
      headers: {
        "Content-Type": "image/png",
        "Cache-Control": "public, max-age=86400, s-maxage=86400, stale-while-revalidate=604800",
      },
    });
  } finally {
    await browser.close();
  }
}

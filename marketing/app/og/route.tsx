// marketing/app/og/route.tsx
// Puppeteer-based OG image renderer for proper Indic script shaping.
// @vercel/og (Satori) lacks HarfBuzz, so Devanagari/Malayalam glyphs are misordered.
// Chrome renders the same HTML with full OpenType shaping.
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

function readFileBase64(filePath: string): string | null {
  try {
    if (fs.existsSync(filePath)) return fs.readFileSync(filePath).toString("base64");
  } catch { /* skip */ }
  return null;
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function buildHtml(params: {
  title: string;
  subtitle: string;
  poppinsB64: string | null;
  devanagariB64: string | null;
  malayalamB64: string | null;
  splashB64: string | null;
}): string {
  const { title, subtitle, poppinsB64, devanagariB64, malayalamB64, splashB64 } = params;

  const fontFaces = [
    poppinsB64 &&
      `@font-face { font-family: 'Poppins'; src: url('data:font/ttf;base64,${poppinsB64}') format('truetype'); font-weight: 800; }`,
    devanagariB64 &&
      `@font-face { font-family: 'Noto Sans Devanagari'; src: url('data:font/ttf;base64,${devanagariB64}') format('truetype'); font-weight: 700; }`,
    malayalamB64 &&
      `@font-face { font-family: 'Noto Sans Malayalam'; src: url('data:font/ttf;base64,${malayalamB64}') format('truetype'); font-weight: 700; }`,
  ]
    .filter(Boolean)
    .join("\n");

  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  ${fontFaces}
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
    font-family: 'Poppins', sans-serif;
    margin-bottom: 32px;
    letter-spacing: -0.3px;
  }
  .title {
    font-size: 52px;
    font-weight: 800;
    color: #A5B4FC;
    line-height: 1.15;
    margin-bottom: 20px;
    font-family: 'Poppins', 'Noto Sans Devanagari', 'Noto Sans Malayalam', sans-serif;
  }
  .subtitle {
    font-size: 22px;
    color: #94A3B8;
    line-height: 1.4;
    font-family: 'Poppins', 'Noto Sans Devanagari', 'Noto Sans Malayalam', sans-serif;
  }
  .domain {
    margin-top: 40px;
    font-size: 16px;
    color: #A5B4FC;
    font-family: 'Poppins', sans-serif;
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

  const fontsDir = path.join(process.cwd(), "public", "fonts");
  const poppinsB64 = readFileBase64(path.join(fontsDir, "Poppins-ExtraBold.ttf"));
  const devanagariB64 = readFileBase64(path.join(fontsDir, "NotoSansDevanagari-Bold.ttf"));
  const malayalamB64 = readFileBase64(path.join(fontsDir, "NotoSansMalayalam-Bold.ttf"));
  const splashB64 = readFileBase64(path.join(process.cwd(), "public", "splash-og.png"));

  const html = buildHtml({ title, subtitle, poppinsB64, devanagariB64, malayalamB64, splashB64 });

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
    // Wait for @font-face data URIs to finish loading before screenshotting
    await page.evaluateHandle(() => document.fonts.ready);
    const screenshot = await page.screenshot({ type: "png" });

    return new NextResponse(screenshot as unknown as BodyInit, {
      headers: {
        "Content-Type": "image/png",
        // CDN caches for 24 h; stale-while-revalidate keeps the old image
        // serving while regenerating — avoids cold-start latency for visitors.
        "Cache-Control": "public, max-age=86400, s-maxage=86400, stale-while-revalidate=604800",
      },
    });
  } finally {
    await browser.close();
  }
}

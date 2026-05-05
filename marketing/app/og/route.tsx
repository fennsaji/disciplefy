// marketing/app/og/route.tsx
// Edge-based OG image using @vercel/og (ImageResponse / satori).
// Fonts are loaded from /public/fonts/ — no Puppeteer or Chromium required.
//
// NOTE: satori/@resvg-wasm does not support Devanagari/Malayalam complex-script
// shaping. For Indic-script titles we show a branded fallback; the actual title
// still appears as text in the social-card meta tags.
import { ImageResponse } from "@vercel/og";
import type { NextRequest } from "next/server";

export const runtime = "edge";

function isIndicScript(text: string): boolean {
  return /[\u0900-\u097F\u0D00-\u0D7F]/.test(text);
}

export async function GET(req: NextRequest) {
  const { searchParams, origin } = new URL(req.url);
  const title = searchParams.get("title") ?? "Disciplefy";
  const subtitle = searchParams.get("subtitle") ?? "Bible Study in Your Language";

  const indic = isIndicScript(title);

  const poppinsData = await fetch(
    new URL("/fonts/Poppins-ExtraBold.ttf", origin)
  ).then((r) => r.arrayBuffer());

  // Shorten long titles so they don't overflow
  const displayTitle = title.length > 50 ? title.slice(0, 48) + "…" : title;
  const titleFontSize = displayTitle.length > 35 ? 42 : 54;

  return new ImageResponse(
    (
      <div
        style={{
          display: "flex",
          flexDirection: "row",
          width: "1200px",
          height: "630px",
          background: "linear-gradient(135deg, #0F172A 0%, #1E293B 100%)",
          fontFamily: "Poppins",
        }}
      >
        {/* ── Left panel ─────────────────────────────────────────── */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            flex: 1,
            padding: "64px 56px 64px 64px",
          }}
        >
          {/* Category badge */}
          <div
            style={{
              display: "flex",
              flexDirection: "row",
              alignItems: "center",
              marginBottom: 28,
            }}
          >
            <div
              style={{
                display: "flex",
                background: "rgba(165,180,252,0.15)",
                border: "1px solid rgba(165,180,252,0.35)",
                borderRadius: "20px",
                padding: "6px 16px",
                fontSize: 14,
                fontWeight: 700,
                color: "#A5B4FC",
                letterSpacing: "1.5px",
              }}
            >
              DISCIPLEFY BLOG
            </div>
          </div>

          {indic ? (
            /* Indic fallback — clean branded headline */
            <div
              style={{
                display: "flex",
                flexDirection: "column",
              }}
            >
              <div
                style={{
                  display: "flex",
                  fontSize: 56,
                  fontWeight: 700,
                  color: "#E2E8F0",
                  lineHeight: 1.1,
                  marginBottom: 16,
                }}
              >
                Bible Study
              </div>
              <div
                style={{
                  display: "flex",
                  fontSize: 34,
                  fontWeight: 700,
                  color: "#A5B4FC",
                  lineHeight: 1.2,
                  marginBottom: 24,
                }}
              >
                in Your Language
              </div>
              <div
                style={{
                  display: "flex",
                  fontSize: 18,
                  color: "#94A3B8",
                  lineHeight: 1.5,
                }}
              >
                Hindi · Malayalam · English
              </div>
            </div>
          ) : (
            /* Latin title */
            <div
              style={{
                display: "flex",
                flexDirection: "column",
              }}
            >
              <div
                style={{
                  display: "flex",
                  fontSize: titleFontSize,
                  fontWeight: 700,
                  color: "#E2E8F0",
                  lineHeight: 1.15,
                  marginBottom: 20,
                }}
              >
                {displayTitle}
              </div>
              <div
                style={{
                  display: "flex",
                  fontSize: 20,
                  color: "#94A3B8",
                  lineHeight: 1.5,
                }}
              >
                {subtitle}
              </div>
            </div>
          )}

          {/* Domain */}
          <div
            style={{
              display: "flex",
              marginTop: 44,
              fontSize: 15,
              color: "#475569",
              letterSpacing: "0.5px",
            }}
          >
            disciplefy.in
          </div>
        </div>

        {/* ── Right panel ────────────────────────────────────────── */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: "340px",
            padding: "40px",
          }}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={`${origin}/logo-dark.png`}
            width={240}
            alt=""
          />
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 630,
      fonts: [{ name: "Poppins", data: poppinsData, weight: 700 }],
      headers: {
        "Cache-Control":
          "public, max-age=86400, s-maxage=86400, stale-while-revalidate=604800",
      },
    }
  );
}

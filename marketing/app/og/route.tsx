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

// The font was refetched over HTTP on every invocation, an entire round trip
// before rasterising could begin — and that wait counts as Fluid Active CPU.
// Edge isolates are reused, so memoising at module scope means warm requests do
// no network work at all. Keyed by origin so preview and production can never
// serve each other's asset; a rejected fetch is evicted so one failure is not
// cached for the life of the isolate.
const poppinsByOrigin = new Map<string, Promise<ArrayBuffer>>();

function loadPoppins(origin: string): Promise<ArrayBuffer> {
  const cached = poppinsByOrigin.get(origin);
  if (cached) return cached;
  const pending = fetch(new URL("/fonts/Poppins-ExtraBold.ttf", origin))
    .then((r) => r.arrayBuffer())
    .catch((err) => {
      poppinsByOrigin.delete(origin);
      throw err;
    });
  poppinsByOrigin.set(origin, pending);
  return pending;
}

// Same fix, same reason: the logo was passed to satori as a bare `<img
// src="https://…/logo-dark.png">`, which satori fetches over the network on
// every single render, cache hit or not, on top of the font fetch above.
// Resolving it to a data URI once per isolate means rendering touches the
// network zero times on a warm request.
const logoDataUriByOrigin = new Map<string, Promise<string>>();

function loadLogoDataUri(origin: string): Promise<string> {
  const cached = logoDataUriByOrigin.get(origin);
  if (cached) return cached;
  const pending = fetch(new URL("/logo-dark.png", origin))
    .then(async (r) => {
      const bytes = await r.arrayBuffer();
      // Edge Runtime has no Buffer global; btoa needs a binary string, built
      // in chunks so a large PNG doesn't blow the call-stack via spread/apply.
      let binary = "";
      const chunk = 0x8000;
      const view = new Uint8Array(bytes);
      for (let i = 0; i < view.length; i += chunk) {
        binary += String.fromCharCode.apply(null, Array.from(view.subarray(i, i + chunk)));
      }
      return `data:image/png;base64,${btoa(binary)}`;
    })
    .catch((err) => {
      logoDataUriByOrigin.delete(origin);
      throw err;
    });
  logoDataUriByOrigin.set(origin, pending);
  return pending;
}

export async function GET(req: NextRequest) {
  const { searchParams, origin } = new URL(req.url);
  const title = searchParams.get("title") ?? "Disciplefy";
  const subtitle = searchParams.get("subtitle") ?? "From Believer to Disciple";

  const indic = isIndicScript(title);

  const [poppinsData, logoDataUri] = await Promise.all([
    loadPoppins(origin),
    loadLogoDataUri(origin),
  ]);

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
          height: "675px",
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
            padding: "64px 32px 64px 64px",
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
                From Believer
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
                to Disciple.
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
            width: "360px",
            paddingRight: "64px",
          }}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={logoDataUri}
            width={300}
            alt=""
          />
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 675,
      fonts: [{ name: "Poppins", data: poppinsData, weight: 700 }],
      headers: {
        "Cache-Control":
          "public, max-age=604800, s-maxage=604800, stale-while-revalidate=2592000",
      },
    }
  );
}

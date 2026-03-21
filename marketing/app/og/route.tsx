// marketing/app/og/route.tsx
import { ImageResponse } from "@vercel/og";
import { NextRequest } from "next/server";

export const runtime = "edge";

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const title = searchParams.get("title") ?? "Disciplefy";
  const subtitle =
    searchParams.get("subtitle") ?? "AI Bible Study in Your Language";

  // Font file must be placed at marketing/public/fonts/Poppins-ExtraBold.ttf before build.
  // Falls back gracefully to system font if the file is not yet present.
  let fontData: ArrayBuffer | null = null;
  try {
    const res = await fetch(new URL("/fonts/Poppins-ExtraBold.ttf", req.url));
    if (res.ok) fontData = await res.arrayBuffer();
  } catch {
    // Font not available yet — OG image renders with system font
  }

  // Load the splash image from the public folder
  let splashSrc: string | null = null;
  try {
    const res = await fetch(new URL("/splash-og.png", req.url));
    if (res.ok) {
      const buf = await res.arrayBuffer();
      const bytes = new Uint8Array(buf);
      let binary = "";
      for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i]);
      const b64 = btoa(binary);
      splashSrc = `data:image/png;base64,${b64}`;
    }
  } catch {
    // Image not available — renders without it
  }

  return new ImageResponse(
    (
      <div
        style={{
          display: "flex",
          width: "100%",
          height: "100%",
          background: "#0F172A",
          overflow: "hidden",
        }}
      >
        {/* Left — text content */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            alignItems: "flex-start",
            flex: 1,
            padding: "60px 48px 60px 60px",
          }}
        >
          <div
            style={{
              fontSize: 28,
              fontWeight: 700,
              color: "#A5B4FC",
              fontFamily: "Poppins",
              marginBottom: 32,
            }}
          >
            Disciplefy
          </div>
          <div
            style={{
              fontSize: 52,
              fontWeight: 800,
              color: "#A5B4FC",
              lineHeight: 1.1,
              marginBottom: 20,
              fontFamily: "Poppins",
            }}
          >
            {title}
          </div>
          <div
            style={{ fontSize: 22, color: "#94A3B8", fontFamily: "Poppins" }}
          >
            {subtitle}
          </div>
          <div
            style={{
              marginTop: 40,
              fontSize: 16,
              color: "#A5B4FC",
              fontFamily: "Poppins",
            }}
          >
            disciplefy.in
          </div>
        </div>

        {/* Right — splash image */}
        {splashSrc && (
          <div
            style={{
              display: "flex",
              alignItems: "center",
              paddingRight: 40,
              flexShrink: 0,
            }}
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={splashSrc}
              alt=""
              style={{
                width: 300,
                height: 300,
                objectFit: "cover",
                objectPosition: "center top",
                borderRadius: 24,
              }}
            />
          </div>
        )}
      </div>
    ),
    {
      width: 1200,
      height: 630,
      ...(fontData
        ? { fonts: [{ name: "Poppins", data: fontData, weight: 800 as const }] }
        : {}),
    }
  );
}

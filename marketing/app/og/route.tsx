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

  return new ImageResponse(
    (
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          alignItems: "flex-start",
          width: "100%",
          height: "100%",
          background: "#0F172A",
          padding: "60px",
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            marginBottom: "32px",
          }}
        >
          <div
            style={{
              fontSize: 28,
              fontWeight: 700,
              color: "#4F46E5",
              fontFamily: "Poppins",
            }}
          >
            Disciplefy
          </div>
        </div>
        <div
          style={{
            fontSize: 56,
            fontWeight: 800,
            color: "#F8FAFC",
            lineHeight: 1.1,
            marginBottom: 16,
            fontFamily: "Poppins",
          }}
        >
          {title}
        </div>
        <div
          style={{ fontSize: 24, color: "#94A3B8", fontFamily: "Poppins" }}
        >
          {subtitle}
        </div>
        <div
          style={{
            position: "absolute",
            bottom: 60,
            right: 60,
            fontSize: 120,
            opacity: 0.05,
            color: "#FFEEC0",
          }}
        >
          ✝
        </div>
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

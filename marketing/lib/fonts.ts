// marketing/lib/fonts.ts
import { Inter, Poppins, Noto_Sans_Devanagari, Noto_Sans_Malayalam } from "next/font/google";

// Primary UI font — preloaded (latin only, fast subset)
export const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

// Display / heading font — preloaded (latin only)
export const poppins = Poppins({
  weight: ["600", "700", "800"],
  subsets: ["latin"],
  variable: "--font-poppins",
  display: "swap",
});

// Hindi (Devanagari) — preload: false so English users don't pay the extra
// network request cost. Font is still lazy-loaded when the CSS variable is used.
export const notoDevanagari = Noto_Sans_Devanagari({
  weight: ["400", "700"],       // Removed "600" — not used; reduces font file size
  subsets: ["devanagari"],
  variable: "--font-noto-devanagari",
  display: "swap",
  preload: false,               // Don't block initial render for non-Hindi pages
});

// Malayalam — same rationale as Devanagari above
export const notoMalayalam = Noto_Sans_Malayalam({
  weight: ["400", "700"],       // Removed "600" — not used; reduces font file size
  subsets: ["malayalam"],
  variable: "--font-noto-malayalam",
  display: "swap",
  preload: false,               // Don't block initial render for non-Malayalam pages
});

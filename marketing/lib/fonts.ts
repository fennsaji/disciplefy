// marketing/lib/fonts.ts
import { Inter, Poppins, Noto_Sans_Devanagari, Noto_Sans_Malayalam } from "next/font/google";

export const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

export const poppins = Poppins({
  weight: ["600", "700", "800"],
  subsets: ["latin"],
  variable: "--font-poppins",
  display: "swap",
});

export const notoDevanagari = Noto_Sans_Devanagari({
  weight: ["400", "600", "700"],
  subsets: ["devanagari"],
  variable: "--font-noto-devanagari",
  display: "swap",
});

export const notoMalayalam = Noto_Sans_Malayalam({
  weight: ["400", "600", "700"],
  subsets: ["malayalam"],
  variable: "--font-noto-malayalam",
  display: "swap",
});

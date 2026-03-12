import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        // Brand tokens
        primary: "#4F46E5",
        "primary-hover": "#4338CA",
        accent: "#FFEEC0",
        gold: "#D4930A",
        "gold-light": "#FFEEC0",
        coral: "#FF6B6B",
        // Dark theme
        dark: {
          bg: "#0F172A",
          surface: "#1E293B",
          border: "rgba(255,255,255,0.1)",
          text: "#F8FAFC",
          muted: "#94A3B8",
        },
        // Light theme
        light: {
          bg: "#FAF8F5",
          surface: "#FFFFFF",
          border: "rgba(0,0,0,0.08)",
          text: "#1E1E1E",
          muted: "#6B7280",
        },
      },
      fontFamily: {
        sans: ["var(--font-inter)", "sans-serif"],
        display: ["var(--font-poppins)", "sans-serif"],
        devanagari: ["var(--font-noto-devanagari)", "sans-serif"],
        malayalam: ["var(--font-noto-malayalam)", "sans-serif"],
      },
      screens: {
        sm: "640px",
        md: "768px",
        lg: "1024px",
        xl: "1280px",
        "2xl": "1536px",
      },
    },
  },
  plugins: [],
};

export default config;

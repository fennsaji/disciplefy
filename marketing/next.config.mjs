import createNextIntlPlugin from "next-intl/plugin";
import createMDX from "@next/mdx";

const withNextIntl = createNextIntlPlugin("./i18n.ts");
const withMDX = createMDX({ extension: /\.mdx?$/ });

/** @type {import('next').NextConfig} */
const nextConfig = {
  pageExtensions: ["js", "jsx", "ts", "tsx", "md", "mdx"],
  experimental: { mdxRs: true },

  // ── policies.disciplefy.in redirects ──────────────────────────────────────
  // Redirects old policy subdomain URLs to canonical marketing site paths.
  async redirects() {
    return [
      {
        source: "/privacy-policy",
        destination: "https://www.disciplefy.in/privacy",
        permanent: true,
        has: [{ type: "host", value: "policies.disciplefy.in" }],
      },
      {
        source: "/terms-of-service",
        destination: "https://www.disciplefy.in/terms",
        permanent: true,
        has: [{ type: "host", value: "policies.disciplefy.in" }],
      },
      {
        source: "/cancellation-refund-policy",
        destination: "https://www.disciplefy.in/refund",
        permanent: true,
        has: [{ type: "host", value: "policies.disciplefy.in" }],
      },
      {
        source: "/",
        destination: "https://www.disciplefy.in/privacy",
        permanent: true,
        has: [{ type: "host", value: "policies.disciplefy.in" }],
      },
    ];
  },

  // ── Image optimisation ─────────────────────────────────────────────────────
  // Serve AVIF then WebP (30-50% smaller than JPEG on mobile).
  // Explicit device/image sizes avoid generating unnecessary responsive variants.
  images: {
    formats: ["image/avif", "image/webp"],
    // Mobile-first breakpoints: 640 covers most phones, 828 handles high-DPI phones
    deviceSizes: [640, 750, 828, 1080, 1200, 1920],
    // Small UI images (logos, icons, step thumbnails)
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 300, 384],
    // Cache optimised images for 1 year (CDN layer)
    minimumCacheTTL: 31536000,
  },

  // ── Gzip / Brotli compression ──────────────────────────────────────────────
  compress: true,
};

export default withNextIntl(withMDX(nextConfig));

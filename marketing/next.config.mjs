import createNextIntlPlugin from "next-intl/plugin";
import createMDX from "@next/mdx";

const withNextIntl = createNextIntlPlugin("./i18n.ts");
const withMDX = createMDX({ extension: /\.mdx?$/ });

const nextConfig = {
  pageExtensions: ["js", "jsx", "ts", "tsx", "md", "mdx"],
  experimental: { mdxRs: true },
};

export default withNextIntl(withMDX(nextConfig));

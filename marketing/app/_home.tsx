// marketing/app/_home.tsx
// Shared homepage component used by both EN (app/page.tsx) and locale pages (app/[locale]/page.tsx).
// This pattern avoids re-export issues with next-intl's static locale generation.
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { Hero } from "@/components/sections/Hero";
import { SocialProof } from "@/components/sections/SocialProof";
import { Features } from "@/components/sections/Features";
import { HowItWorks } from "@/components/sections/HowItWorks";
import { LanguageShowcase } from "@/components/sections/LanguageShowcase";
import { Testimonials } from "@/components/sections/Testimonials";
import { PricingPreview } from "@/components/sections/PricingPreview";
import { DownloadCTA } from "@/components/sections/DownloadCTA";

export function HomePage() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <SocialProof />
        <Features />
        <HowItWorks />
        <LanguageShowcase />
        <Testimonials />
        <PricingPreview />
        <DownloadCTA />
      </main>
      <Footer />
    </>
  );
}

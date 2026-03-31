// marketing/components/sections/HowItWorks.tsx
"use client";
import { useTranslations, useLocale } from "next-intl";
import Image from "next/image";
import { motion, useScroll, useTransform, useMotionValueEvent } from "framer-motion";
import { useRef, useState } from "react";
/* ── Inline SVG icons (no external dep) ────────────────── */

function IconBookOpen({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round">
      <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" />
      <path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" />
    </svg>
  );
}

function IconSparkles({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round">
      <path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z" />
      <path d="M5 3v4" /><path d="M19 17v4" /><path d="M3 5h4" /><path d="M17 19h4" />
    </svg>
  );
}

function IconMic({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
      <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
      <line x1="12" x2="12" y1="19" y2="22" />
    </svg>
  );
}

function IconCompass({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10" />
      <polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76" />
    </svg>
  );
}

function IconTrending({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round">
      <polyline points="22 7 13.5 15.5 8.5 10.5 2 17" />
      <polyline points="16 7 22 7 22 13" />
    </svg>
  );
}

function IconUsers({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round">
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
      <path d="M16 3.13a4 4 0 0 1 0 7.75" />
    </svg>
  );
}

type IconComponent = ({ className }: { className?: string }) => React.JSX.Element;

/* ── Step data ─────────────────────────────────────────── */

const STEP_KEYS = ["step1", "step2", "step3", "step4", "step5", "step6"] as const;

const STEP_ICONS: IconComponent[] = [IconBookOpen, IconSparkles, IconMic, IconCompass, IconTrending, IconUsers];

// Placeholder gradient tints per step (used until real screenshots exist)
const STEP_TINTS = [
  "from-primary/20 to-primary/5",
  "from-amber-400/20 to-amber-200/5",
  "from-emerald-400/20 to-emerald-200/5",
  "from-cyan-400/20 to-cyan-200/5",
  "from-violet-400/20 to-violet-200/5",
  "from-rose-400/20 to-rose-200/5",
];

/* ── Phone shell (shared) ──────────────────────────────── */

function PhoneShell({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`relative w-[300px] h-[640px] rounded-[12px] border-2 border-[var(--border)] bg-neutral-900 shadow-2xl overflow-hidden ${className}`}
    >
      {/* S26 Ultra — thin bezel frame */}
      <div className="absolute inset-0 rounded-[12px] border border-neutral-700/40" />
      {/* Punch-hole camera */}
      <div className="absolute top-3 left-1/2 -translate-x-1/2 w-2.5 h-2.5 rounded-full bg-neutral-800 ring-1 ring-neutral-600/50 z-20" />
      {/* Screen area — small padding around screenshot */}
      <div className="absolute inset-[6px] rounded-[8px] overflow-hidden">
        {children}
      </div>
    </div>
  );
}

/* ── Screenshot with locale-aware fallback ─────────────── */
// Place images at: public/screenshots/step1-en.png, step1-hi.png, etc.

function ScreenshotPlaceholder({ index }: { index: number }) {
  const Icon = STEP_ICONS[index];
  return (
    <div
      className={`w-full h-full bg-gradient-to-b ${STEP_TINTS[index]} flex flex-col items-center justify-center gap-4`}
    >
      <Icon className="w-12 h-12 text-[var(--muted)]" />
      <span className="text-xs text-[var(--muted)] font-medium">
        Step {index + 1}
      </span>
    </div>
  );
}

function Screenshot({ index, locale, alt }: { index: number; locale: string; alt: string }) {
  const [failed, setFailed] = useState(false);
  const src = `/screenshots/step${index + 1}-${locale}.jpg`;

  if (failed) return <ScreenshotPlaceholder index={index} />;

  return (
    <div className="relative w-full h-full">
      <Image
        src={src}
        alt={alt}
        fill
        className="object-cover object-top"
        sizes="300px"
        onError={() => setFailed(true)}
      />
    </div>
  );
}

/* ── Desktop step content ──────────────────────────────── */

function StepContent({
  index,
  isActive,
  title,
  desc,
}: {
  index: number;
  isActive: boolean;
  title: string;
  desc: string;
}) {
  const Icon = STEP_ICONS[index];
  return (
    <motion.div
      className="flex gap-5 items-start"
      animate={{
        opacity: isActive ? 1 : 0.3,
        y: isActive ? 0 : 10,
      }}
      transition={{ duration: 0.4, ease: "easeOut" }}
    >
      {/* Number badge */}
      <div
        className={`w-12 h-12 rounded-full flex items-center justify-center font-display font-bold text-lg shrink-0 transition-colors duration-300 ${
          isActive
            ? "bg-primary text-white shadow-lg shadow-primary/25"
            : "bg-[var(--surface)] text-[var(--muted)] border border-[var(--border)]"
        }`}
      >
        {index + 1}
      </div>
      <div className="flex-1">
        <div className="flex items-center gap-2 mb-2">
          <Icon
            className={`w-5 h-5 transition-colors duration-300 ${
              isActive ? "text-primary" : "text-[var(--muted)]"
            }`}
          />
          <h3 className="font-display font-semibold text-xl">{title}</h3>
        </div>
        <p className="text-[var(--muted)] leading-relaxed">{desc}</p>
        {/* Active indicator bar */}
        <motion.div
          className="h-0.5 bg-primary rounded-full mt-4"
          animate={{ width: isActive ? "60%" : "0%" }}
          transition={{ duration: 0.5, ease: "easeOut" }}
        />
      </div>
    </motion.div>
  );
}

/* ── Mobile step ───────────────────────────────────────── */

function MobileStep({
  index,
  locale,
  title,
  desc,
  alt,
}: {
  index: number;
  locale: string;
  title: string;
  desc: string;
  alt: string;
}) {
  const Icon = STEP_ICONS[index];
  return (
    <motion.div
      initial={{ opacity: 0, y: 30 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-50px" }}
      transition={{ duration: 0.5, delay: 0.1 }}
      className="flex flex-col items-center gap-6"
    >
      {/* Mini phone mockup */}
      <PhoneShell className="w-60 h-[520px]">
        <Screenshot index={index} locale={locale} alt={alt} />
      </PhoneShell>
      {/* Text */}
      <div className="text-center max-w-sm">
        <div className="flex items-center justify-center gap-3 mb-3">
          <div className="w-10 h-10 rounded-full bg-primary text-white flex items-center justify-center font-display font-bold text-lg">
            {index + 1}
          </div>
          <Icon className="w-5 h-5 text-primary" />
        </div>
        <h3 className="font-display font-semibold text-xl mb-2">{title}</h3>
        <p className="text-[var(--muted)] leading-relaxed">{desc}</p>
      </div>
    </motion.div>
  );
}

/* ── Main component ────────────────────────────────────── */

export function HowItWorks() {
  const t = useTranslations("howItWorks");
  const locale = useLocale();
  const sectionRef = useRef<HTMLDivElement>(null);
  const [activeStep, setActiveStep] = useState(0);

  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ["start start", "end end"],
  });

  // Per-screenshot opacity transforms with crossfade zones (6 steps)
  // Each step occupies ~16.67% of scroll. Crossfade zone ~3%.
  const opacity0 = useTransform(
    scrollYProgress,
    [0, 0.03, 0.13, 0.167],
    [1, 1, 1, 0]
  );
  const opacity1 = useTransform(
    scrollYProgress,
    [0.13, 0.167, 0.3, 0.333],
    [0, 1, 1, 0]
  );
  const opacity2 = useTransform(
    scrollYProgress,
    [0.3, 0.333, 0.467, 0.5],
    [0, 1, 1, 0]
  );
  const opacity3 = useTransform(
    scrollYProgress,
    [0.467, 0.5, 0.633, 0.667],
    [0, 1, 1, 0]
  );
  const opacity4 = useTransform(
    scrollYProgress,
    [0.633, 0.667, 0.8, 0.833],
    [0, 1, 1, 0]
  );
  const opacity5 = useTransform(
    scrollYProgress,
    [0.8, 0.833, 1.0],
    [0, 1, 1]
  );

  const screenshotOpacities = [opacity0, opacity1, opacity2, opacity3, opacity4, opacity5];

  // Track active step for text highlighting
  useMotionValueEvent(scrollYProgress, "change", (v) => {
    if (v < 0.167) setActiveStep(0);
    else if (v < 0.333) setActiveStep(1);
    else if (v < 0.5) setActiveStep(2);
    else if (v < 0.667) setActiveStep(3);
    else if (v < 0.833) setActiveStep(4);
    else setActiveStep(5);
  });

  return (
    <section className="bg-[var(--surface)]">
      {/* Section title */}
      <div className="pt-24 pb-12 text-center px-4">
        <motion.h2
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
          className="font-display font-bold text-3xl sm:text-4xl"
        >
          {t("title")}
        </motion.h2>
        <a
          href="#download"
          className="inline-block mt-4 text-sm text-[var(--muted)] hover:text-primary transition-colors underline underline-offset-4"
        >
          Skip to download ↓
        </a>
      </div>

      {/* ─── Desktop layout (lg+) ─── */}
      <div ref={sectionRef} className="hidden lg:block relative">
        {/* Height = 6 panels × 60vh */}
        <div className="max-w-7xl mx-auto px-8" style={{ minHeight: "360vh" }}>
          <div className="grid grid-cols-2 gap-16">
            {/* Left: Sticky phone mockup */}
            <div className="relative">
              <div className="sticky top-[10vh] h-[80vh] flex items-center justify-center">
                <PhoneShell>
                  {screenshotOpacities.map((opacity, i) => (
                    <motion.div
                      key={i}
                      className="absolute inset-0"
                      style={{ opacity }}
                    >
                      <Screenshot index={i} locale={locale} alt={t(`${STEP_KEYS[i]}.imageAlt`)} />
                    </motion.div>
                  ))}
                </PhoneShell>
              </div>
            </div>

            {/* Right: Step panels */}
            <div className="flex flex-col">
              {STEP_KEYS.map((key, i) => (
                <div
                  key={key}
                  className="min-h-[60vh] flex items-center"
                >
                  <StepContent
                    index={i}
                    isActive={activeStep === i}
                    title={t(`${key}.title`)}
                    desc={t(`${key}.desc`)}
                  />
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* ─── Mobile layout (<lg) ─── */}
      <div className="lg:hidden px-4 sm:px-6 pb-24">
        <div className="flex flex-col gap-16 max-w-md mx-auto">
          {STEP_KEYS.map((key, i) => (
            <MobileStep
              key={key}
              index={i}
              locale={locale}
              title={t(`${key}.title`)}
              desc={t(`${key}.desc`)}
              alt={t(`${key}.imageAlt`)}
            />
          ))}
        </div>
      </div>
    </section>
  );
}

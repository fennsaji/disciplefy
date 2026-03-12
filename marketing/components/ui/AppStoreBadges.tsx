// marketing/components/ui/AppStoreBadges.tsx
export function AppStoreBadges({ className }: { className?: string }) {
  return (
    <div className={`flex flex-wrap items-center gap-3 ${className}`}>
      {/* Google Play — live */}
      <a
        href="https://play.google.com/store/apps/details?id=com.disciplefy.bible_study&hl=en_IN"
        target="_blank"
        rel="noopener noreferrer"
        className="inline-flex items-center gap-2 bg-black text-white px-4 py-2.5 rounded-xl text-sm font-semibold hover:bg-gray-900 transition-colors"
        aria-label="Get it on Google Play"
      >
        <svg viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5">
          <path d="M3.18 23.76c.37.2.8.19 1.17-.03L16.83 12 12.5 7.67 3.18 23.76zm-1.62-2.1c-.12-.22-.18-.47-.18-.73V3.07c0-.26.06-.51.18-.73l9.5 9.66-9.5 9.66zm20.28-9.19c.41.22.66.61.66 1.02 0 .41-.25.8-.66 1.02l-2.7 1.54-3.45-3.51 3.45-3.51 2.7 1.44zM4.35.27l11.48 6.57L12.5 10.17 3.35.24c.37-.17.79-.16 1-.03z"/>
        </svg>
        Google Play
      </a>

      {/* Web App */}
      <a
        href="https://app.disciplefy.in"
        target="_blank"
        rel="noopener noreferrer"
        className="inline-flex items-center gap-2 bg-black text-white px-4 py-2.5 rounded-xl text-sm font-semibold hover:bg-gray-900 transition-colors"
        aria-label="Open Web App"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-5 h-5">
          <circle cx="12" cy="12" r="10"/>
          <path d="M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>
        </svg>
        Web App
      </a>

      {/* iOS — coming soon */}
      <div
        className="relative inline-flex items-center gap-2 bg-[var(--surface)] text-[var(--muted)] px-4 py-2.5 rounded-xl text-sm font-semibold border border-[var(--border)] cursor-not-allowed select-none"
        aria-label="App Store — Coming Soon"
      >
        <svg viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5">
          <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
        </svg>
        App Store
        <span className="absolute -top-2 -right-2 bg-primary text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full leading-none">
          Soon
        </span>
      </div>
    </div>
  );
}

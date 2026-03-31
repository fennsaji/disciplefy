// marketing/components/layout/Navbar.tsx
// PERFORMANCE NOTES:
// 1. No framer-motion — removed to eliminate SSR opacity:0 that caused 3-second black screen.
// 2. Mobile menu uses CSS max-height transition instead of AnimatePresence.
// 3. Navbar slides in via CSS animation (animate-navbar) — no JS dependency.
"use client";
import { useTranslations, useLocale } from "next-intl";
import { Link } from "@/lib/navigation";
import { useState, useEffect } from "react";
import { usePathname } from "next/navigation";
import Image from "next/image";
import { ThemeToggle } from "@/components/ui/ThemeToggle";
import { LocaleSwitcher } from "@/components/ui/LocaleSwitcher";

export function Navbar() {
  const t = useTranslations("nav");
  const locale = useLocale();
  const [menuOpen, setMenuOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const downloadUrl = locale === "en" ? "/download" : `/${locale}/download`;
  const buttonLabel = t("download");

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener("scroll", handleScroll, { passive: true });
    handleScroll();
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const pathname = usePathname();
  const isActiveLink = (href: string) => {
    const path = href.split("#")[0];
    if (path === "/") return pathname === "/" || /^\/[a-z]{2}\/?$/.test(pathname);
    return pathname === path || pathname.endsWith(path);
  };

  const navLinks = [
    { label: t("features"), href: "/#features" },
    { label: t("pricing"), href: "/pricing" },
    { label: t("about"), href: "/about" },
    { label: t("blog"), href: "/blog" },
  ];

  return (
    <nav
      className={`animate-navbar sticky top-0 z-50 border-b border-[var(--border)] transition-colors duration-300 ${
        scrolled
          ? "backdrop-blur-md bg-[var(--bg)]/80"
          : "bg-[var(--bg)]/90 backdrop-blur-sm"
      }`}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link href="/" className="flex items-center">
            <Image
              src="/logo-light.png"
              alt="Disciplefy"
              width={140}
              height={40}
              className="h-8 w-auto dark:hidden"
              priority
            />
            <Image
              src="/logo-dark.png"
              alt="Disciplefy"
              width={140}
              height={40}
              className="h-8 w-auto hidden dark:block"
              priority
            />
          </Link>

          {/* Desktop nav */}
          <div className="hidden md:flex items-center gap-6">
            {navLinks.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className={`text-sm transition-colors ${
                  isActiveLink(link.href)
                    ? "text-[var(--text)] font-semibold"
                    : "text-[var(--muted)] hover:text-[var(--text)]"
                }`}
                aria-current={isActiveLink(link.href) ? "page" : undefined}
              >
                {link.label}
              </Link>
            ))}
          </div>

          {/* Controls */}
          <div className="flex items-center gap-2">
            <LocaleSwitcher />
            <ThemeToggle />
            <Link
              href={downloadUrl}
              className="hidden md:inline-flex px-4 py-2 text-sm rounded-lg bg-primary text-white font-semibold hover:bg-primary-hover transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
            >
              {buttonLabel}
            </Link>
            {/* Mobile hamburger */}
            <button
              className="md:hidden p-2 text-[var(--muted)]"
              onClick={() => setMenuOpen(!menuOpen)}
              aria-label="Toggle menu"
              aria-expanded={menuOpen}
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                {menuOpen
                  ? <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  : <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />}
              </svg>
            </button>
          </div>
        </div>

        {/* Mobile menu — CSS max-height transition, no framer-motion */}
        <div
          className={`md:hidden overflow-hidden border-t border-[var(--border)] transition-all duration-300 ease-in-out ${
            menuOpen ? "max-h-96 opacity-100" : "max-h-0 opacity-0"
          }`}
        >
          <div className="py-4 flex flex-col gap-3">
            {navLinks.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className={`text-sm py-1 block transition-colors ${
                  isActiveLink(link.href)
                    ? "text-[var(--text)] font-semibold"
                    : "text-[var(--muted)] hover:text-[var(--text)]"
                }`}
                aria-current={isActiveLink(link.href) ? "page" : undefined}
                onClick={() => setMenuOpen(false)}
              >
                {link.label}
              </Link>
            ))}
            <Link
              href={downloadUrl}
              onClick={() => setMenuOpen(false)}
              className="w-full mt-2 min-h-[44px] flex items-center justify-center px-4 py-2 text-sm rounded-lg bg-primary text-white font-semibold hover:bg-primary-hover transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
            >
              {buttonLabel}
            </Link>
          </div>
        </div>
      </div>
    </nav>
  );
}

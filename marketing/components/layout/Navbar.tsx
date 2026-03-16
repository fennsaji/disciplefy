// marketing/components/layout/Navbar.tsx
"use client";
import { useTranslations } from "next-intl";
import { Link } from "@/lib/navigation"; // locale-aware Link — auto-prefixes /hi/ /ml/
import { useState, useEffect } from "react";
import Image from "next/image";
import { motion, AnimatePresence } from "framer-motion";
import { ThemeToggle } from "@/components/ui/ThemeToggle";
import { LocaleSwitcher } from "@/components/ui/LocaleSwitcher";
import { Button } from "@/components/ui/Button";

const PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.disciplefy.app";
const WEB_APP_URL = "https://app.disciplefy.in";

export function Navbar() {
  const t = useTranslations("nav");
  const [menuOpen, setMenuOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [downloadUrl, setDownloadUrl] = useState(WEB_APP_URL);
  const buttonLabel = downloadUrl === WEB_APP_URL ? t("openApp") : t("download");

  useEffect(() => {
    if (/android/i.test(navigator.userAgent)) {
      setDownloadUrl(PLAY_STORE_URL);
    }
  }, []);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener("scroll", handleScroll, { passive: true });
    handleScroll(); // check initial position
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const navLinks = [
    { label: t("features"), href: "/#features" },
    { label: t("pricing"), href: "/pricing" },
    { label: t("about"), href: "/about" },
    { label: t("blog"), href: "/blog" },
  ];

  return (
    <motion.nav
      initial={{ y: -20, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.4 }}
      className={`sticky top-0 z-50 border-b border-[var(--border)] transition-colors duration-300 ${
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
                className="text-sm text-[var(--muted)] hover:text-[var(--text)] transition-colors"
              >
                {link.label}
              </Link>
            ))}
          </div>

          {/* Controls */}
          <div className="flex items-center gap-2">
            <LocaleSwitcher />
            <ThemeToggle />
            <Button href={downloadUrl} size="sm" className="hidden md:inline-flex">
              {buttonLabel}
            </Button>
            {/* Mobile hamburger */}
            <button
              className="md:hidden p-2 text-[var(--muted)]"
              onClick={() => setMenuOpen(!menuOpen)}
              aria-label="Toggle menu"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                {menuOpen
                  ? <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  : <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />}
              </svg>
            </button>
          </div>
        </div>

        {/* Mobile menu */}
        <AnimatePresence>
          {menuOpen && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              transition={{ duration: 0.3 }}
              className="md:hidden overflow-hidden border-t border-[var(--border)]"
            >
              <div className="py-4 flex flex-col gap-3">
                {navLinks.map((link, index) => (
                  <motion.div
                    key={link.href}
                    initial={{ opacity: 0, x: -10 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ duration: 0.2, delay: 0.05 + index * 0.07 }}
                  >
                    <Link
                      href={link.href}
                      className="text-sm text-[var(--muted)] hover:text-[var(--text)] py-1 block"
                      onClick={() => setMenuOpen(false)}
                    >
                      {link.label}
                    </Link>
                  </motion.div>
                ))}
                <motion.div
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ duration: 0.2, delay: 0.05 + navLinks.length * 0.07 }}
                >
                  <Button href={downloadUrl} size="sm" className="w-full mt-2">
                    {buttonLabel}
                  </Button>
                </motion.div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </motion.nav>
  );
}

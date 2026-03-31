// marketing/components/ui/CookieConsent.tsx
"use client";
import { useEffect, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useTranslations } from "next-intl";
import Link from "next/link";

const STORAGE_KEY = "disciplefy-cookie-consent";

export function CookieConsent() {
  const t = useTranslations("cookieConsent");
  const [show, setShow] = useState(false);
  const acceptRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (!stored) setShow(true);
  }, []);

  useEffect(() => {
    if (show) {
      // Delay to allow animation to start before focusing
      const id = setTimeout(() => acceptRef.current?.focus(), 100);
      return () => clearTimeout(id);
    }
  }, [show]);

  function accept() {
    localStorage.setItem(STORAGE_KEY, "accepted");
    setShow(false);
    // Vercel Analytics auto-initialises; no manual init needed
  }

  function decline() {
    localStorage.setItem(STORAGE_KEY, "declined");
    setShow(false);
  }

  return (
    <AnimatePresence>
      {show && (
        <motion.div
          className="fixed bottom-0 left-0 right-0 z-50 p-4"
          initial={{ y: 100, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: 100, opacity: 0 }}
          transition={{ type: "spring", damping: 25, stiffness: 300 }}
        >
          <div
            role="dialog"
            aria-modal="true"
            aria-label={t("accept")}
            className="max-w-3xl mx-auto bg-[var(--surface)] border border-[var(--border)] rounded-2xl shadow-2xl p-4 flex flex-col sm:flex-row items-start sm:items-center gap-4"
          >
            <p className="text-sm text-[var(--muted)] flex-1">
              {t("message")}{" "}
              <Link href="/privacy" className="text-primary underline">{t("learnMore")}</Link>
            </p>
            <div className="flex gap-2 shrink-0">
              <button onClick={decline} className="px-4 py-2 text-sm text-[var(--muted)] hover:text-[var(--text)] rounded-lg border border-[var(--border)] transition-colors">
                {t("decline")}
              </button>
              <button ref={acceptRef} onClick={accept} className="px-4 py-2 text-sm bg-primary text-white rounded-lg hover:bg-primary-hover transition-colors">
                {t("accept")}
              </button>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

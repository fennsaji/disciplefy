// marketing/components/blog/BlogPostCTA.tsx
"use client";
import { useTranslations } from "next-intl";
import { Link } from "@/lib/navigation";

export function BlogPostCTA({ gradient }: { gradient: string }) {
  const t = useTranslations("blogPost");

  return (
    <div className="mt-16 rounded-2xl overflow-hidden border border-primary/20 dark:border-indigo-500/20">
      <div className={`h-1 bg-gradient-to-r ${gradient}`} />
      <div className="p-6 sm:p-8 bg-primary/5 dark:bg-indigo-500/5 text-center">
        <p className="font-display font-bold text-xl mb-2 text-gray-900 dark:text-white">
          {t("ctaTitle")}
        </p>
        <p className="text-sm text-gray-500 dark:text-slate-400 mb-5 max-w-md mx-auto">
          {t("ctaSubtitle")}
        </p>
        <Link
          href="/download"
          className={`inline-block bg-gradient-to-r ${gradient} text-white text-sm font-semibold px-7 py-3 rounded-xl shadow-md hover:shadow-lg hover:opacity-90 transition-all`}
        >
          {t("getApp")}
        </Link>
      </div>
    </div>
  );
}

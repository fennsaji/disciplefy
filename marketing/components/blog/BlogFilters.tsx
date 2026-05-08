'use client'
// marketing/components/blog/BlogFilters.tsx
import { useSearchParams } from 'next/navigation'
import { useRouter, usePathname } from '@/lib/navigation'
import { useCallback, useTransition } from 'react'
import type { Locale } from '@/i18n'

const LOCALE_LABELS: Record<string, string> = {
  en: 'English',
  hi: 'हिन्दी',
  ml: 'മലയാളം',
}

const selectClass =
  'appearance-none bg-[var(--surface)] border border-[var(--border)] text-sm rounded-xl px-3 py-2 pr-8 text-[var(--text)] focus:outline-none focus:border-primary/50 focus:ring-1 focus:ring-primary/30 transition-colors cursor-pointer'

export function BlogFilters({
  tags,
  activeTag,
  query,
  locale,
  learningPaths,
  activeLearningPath,
}: {
  tags: string[]
  activeTag?: string
  query?: string
  locale: string
  learningPaths?: { slug: string; title: string; post_count: number }[]
  activeLearningPath?: string
}) {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const [, startTransition] = useTransition()

  const pushParams = useCallback(
    (updates: Record<string, string | undefined>) => {
      const params = new URLSearchParams(searchParams.toString())
      params.delete('page')
      for (const [key, val] of Object.entries(updates)) {
        if (val) params.set(key, val)
        else params.delete(key)
      }
      startTransition(() => router.push(`${pathname}?${params.toString()}`))
    },
    [router, pathname, searchParams],
  )

  const switchLocale = useCallback(
    (newLocale: string) => {
      const params = new URLSearchParams(searchParams.toString())
      params.delete('page')
      const qs = params.toString()
      startTransition(() =>
        router.push(qs ? `/blog?${qs}` : '/blog', { locale: newLocale as Locale }),
      )
    },
    [router, searchParams],
  )

  return (
    <div className="flex flex-col sm:flex-row gap-3 mb-8 items-start sm:items-center">
      {/* Search input */}
      <div className="relative flex-1 w-full sm:max-w-sm">
        <svg
          className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[var(--muted)] pointer-events-none"
          fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}
        >
          <path strokeLinecap="round" strokeLinejoin="round"
            d="M21 21l-4.35-4.35M17 11A6 6 0 1 1 5 11a6 6 0 0 1 12 0z" />
        </svg>
        <input
          type="search"
          defaultValue={query}
          placeholder="Search articles…"
          className="w-full pl-9 pr-4 py-2 rounded-xl text-sm
                     bg-[var(--surface)] border border-[var(--border)]
                     text-[var(--text)] placeholder:text-[var(--muted)]
                     focus:outline-none focus:border-primary/50 focus:ring-1 focus:ring-primary/30
                     transition-colors"
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              pushParams({ q: (e.target as HTMLInputElement).value.trim() || undefined, tag: undefined })
            }
          }}
          onChange={(e) => {
            const val = e.target.value.trim()
            if (val === '') pushParams({ q: undefined })
          }}
        />
      </div>

      <div className="flex gap-2 flex-wrap">
        {/* Language dropdown */}
        <div className="relative">
          <select
            value={locale}
            onChange={(e) => switchLocale(e.target.value)}
            className={selectClass}
          >
            {Object.entries(LOCALE_LABELS).map(([loc, label]) => (
              <option key={loc} value={loc}>{label}</option>
            ))}
          </select>
          <svg className="absolute right-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-[var(--muted)] pointer-events-none" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
          </svg>
        </div>

        {/* Learning path dropdown */}
        {learningPaths && learningPaths.length > 0 && (
          <div className="relative">
            <select
              value={activeLearningPath ?? ''}
              onChange={(e) => pushParams({ learning_path: e.target.value || undefined, tag: undefined })}
              className={selectClass}
            >
              <option value="">All Paths</option>
              {learningPaths.map((lp) => (
                <option key={lp.slug} value={lp.slug}>
                  {lp.title} ({lp.post_count})
                </option>
              ))}
            </select>
            <svg className="absolute right-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-[var(--muted)] pointer-events-none" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
            </svg>
          </div>
        )}

        {/* Tag dropdown */}
        {tags.length > 0 && (
          <div className="relative">
            <select
              value={activeTag ?? ''}
              onChange={(e) => pushParams({ tag: e.target.value || undefined, learning_path: undefined })}
              className={selectClass}
            >
              <option value="">All Topics</option>
              {tags.map((t) => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
            <svg className="absolute right-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-[var(--muted)] pointer-events-none" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
            </svg>
          </div>
        )}
      </div>
    </div>
  )
}

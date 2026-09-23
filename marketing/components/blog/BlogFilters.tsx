'use client'
// marketing/components/blog/BlogFilters.tsx
import { useSearchParams } from 'next/navigation'
import { useRouter, usePathname } from '@/lib/navigation'
import { useCallback, useTransition } from 'react'
import { FilterDropdown, type DropdownOption } from '@/components/ui/FilterDropdown'
import type { Locale } from '@/i18n'

const LOCALE_LABELS: Record<string, string> = {
  en: 'English',
  hi: 'हिन्दी',
  ml: 'മലയാളം',
}

/* ------------------------------------------------------------------ */
/*  Icons (w-3.5 h-3.5)                                              */
/* ------------------------------------------------------------------ */

const GlobeIcon = (
  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
    <circle cx="12" cy="12" r="10" />
    <path d="M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10A15.3 15.3 0 0 1 12 2z" />
  </svg>
)
const PathIcon = (
  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M9 20l-5.447-2.724A1 1 0 0 1 3 16.382V5.618a1 1 0 0 1 1.447-.894L9 7m0 13l6-3m-6 3V7m6 10l5.447 2.724A1 1 0 0 0 21 18.382V7.618a1 1 0 0 0-.553-.894L15 4m0 13V4m0 0L9 7" />
  </svg>
)
const TagIcon = (
  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M7 7h.01M7 3h5a1.99 1.99 0 0 1 1.414.586l7 7a2 2 0 0 1 0 2.828l-7 7a2 2 0 0 1-2.828 0l-7-7A2 2 0 0 1 3 12V7a4 4 0 0 1 4-4z" />
  </svg>
)

/* ------------------------------------------------------------------ */
/*  BlogFilters                                                       */
/* ------------------------------------------------------------------ */

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

  const localeOptions: DropdownOption[] = Object.entries(LOCALE_LABELS).map(([loc, label]) => ({
    value: loc,
    label,
  }))

  const pathOptions: DropdownOption[] = [
    { value: '', label: 'All Paths' },
    ...(learningPaths ?? []).map((lp) => ({
      value: lp.slug,
      label: `${lp.title} (${lp.post_count})`,
    })),
  ]

  const tagOptions: DropdownOption[] = [
    { value: '', label: 'All Topics' },
    ...tags.map((t) => ({ value: t, label: t })),
  ]

  return (
    <div className="flex flex-col sm:flex-row gap-3 mb-10 items-start sm:items-center">
      {/* Search input */}
      <div className="relative flex-1 w-full sm:max-w-xs">
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
          className="w-full pl-9 pr-4 py-2 rounded-full text-sm
                     bg-[var(--surface)] border border-[var(--border)]
                     text-[var(--text)] placeholder:text-[var(--muted)]
                     focus:outline-none focus-visible:ring-2 focus-visible:ring-primary/30 focus-visible:ring-offset-1
                     hover:border-[var(--text)]/15 hover:shadow-sm
                     transition-all duration-200"
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

      <div className="flex gap-2 flex-wrap items-center">
        {/* Language */}
        <FilterDropdown
          options={localeOptions}
          value={locale}
          onChange={switchLocale}
          icon={GlobeIcon}
          placeholder="Language"
        />

        {/* Learning path */}
        {learningPaths && learningPaths.length > 0 && (
          <FilterDropdown
            options={pathOptions}
            value={activeLearningPath ?? ''}
            onChange={(val) => pushParams({ learning_path: val || undefined, tag: undefined })}
            icon={PathIcon}
            placeholder="All Paths"
          />
        )}

        {/* Tag */}
        {tags.length > 0 && (
          <FilterDropdown
            options={tagOptions}
            value={activeTag ?? ''}
            onChange={(val) => pushParams({ tag: val || undefined, learning_path: undefined })}
            icon={TagIcon}
            placeholder="All Topics"
          />
        )}
      </div>
    </div>
  )
}

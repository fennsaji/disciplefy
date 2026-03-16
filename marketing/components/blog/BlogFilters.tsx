'use client'
// marketing/components/blog/BlogFilters.tsx
import { useRouter, useSearchParams, usePathname } from 'next/navigation'
import { useCallback, useTransition } from 'react'

export function BlogFilters({
  tags,
  activeTag,
  query,
}: {
  tags: string[]
  activeTag?: string
  query?: string
}) {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const [, startTransition] = useTransition()

  const pushParams = useCallback(
    (updates: Record<string, string | undefined>) => {
      const params = new URLSearchParams(searchParams.toString())
      params.delete('page') // reset to page 1 on filter change
      for (const [key, val] of Object.entries(updates)) {
        if (val) params.set(key, val)
        else params.delete(key)
      }
      startTransition(() => router.push(`${pathname}?${params.toString()}`))
    },
    [router, pathname, searchParams],
  )

  return (
    <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center mb-8">
      {/* Search input */}
      <div className="relative flex-1 max-w-sm">
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

      {/* Tag pills */}
      {tags.length > 0 && (
        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => pushParams({ tag: undefined, q: query })}
            className={`px-3 py-1 rounded-full text-xs font-semibold transition-colors ${
              !activeTag
                ? 'bg-primary text-white'
                : 'bg-[var(--surface)] border border-[var(--border)] text-[var(--muted)] hover:border-primary/40 hover:text-[var(--text)]'
            }`}
          >
            All
          </button>
          {tags.map((t) => (
            <button
              key={t}
              onClick={() => pushParams({ tag: activeTag === t ? undefined : t, q: query })}
              className={`px-3 py-1 rounded-full text-xs font-semibold transition-colors ${
                activeTag === t
                  ? 'bg-primary text-white'
                  : 'bg-[var(--surface)] border border-[var(--border)] text-[var(--muted)] hover:border-primary/40 hover:text-[var(--text)]'
              }`}
            >
              {t}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

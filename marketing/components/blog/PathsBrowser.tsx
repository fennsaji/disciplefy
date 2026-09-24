'use client'
// marketing/components/blog/PathsBrowser.tsx
// Search + category/level filters over the learning-path grid. The whole list
// arrives with the page (a handful of paths), so filtering is done in memory
// rather than as a server round trip.
import { useEffect, useMemo, useState } from 'react'
import { Link } from '@/lib/navigation'
import { FilterDropdown, type DropdownOption } from '@/components/ui/FilterDropdown'
import type { LearningPathMeta } from '@/lib/blog'

const GRADIENTS = [
  'from-primary to-violet-500',
  'from-emerald-500 to-teal-500',
  'from-amber-500 to-orange-500',
  'from-sky-500 to-indigo-500',
  'from-rose-500 to-pink-500',
  'from-fuchsia-500 to-purple-500',
]

type Copy = {
  search: string
  allCategories: string
  allLevels: string
  article: string
  articles: string
  empty: string
  noMatches: string
  clear: string
  levels: Record<string, string>
  categories: Record<string, string>
}

const COPY: Record<string, Copy> = {
  en: {
    search: 'Search paths…',
    allCategories: 'All categories',
    allLevels: 'All levels',
    article: 'article',
    articles: 'articles',
    empty: 'No learning paths yet. Check back soon.',
    noMatches: 'No paths match that search.',
    clear: 'Clear filters',
    levels: { seeker: 'Seeker', follower: 'Follower', disciple: 'Disciple', leader: 'Leader' },
    categories: {},
  },
  hi: {
    search: 'पथ खोजें…',
    allCategories: 'सभी श्रेणियाँ',
    allLevels: 'सभी स्तर',
    article: 'लेख',
    articles: 'लेख',
    empty: 'अभी कोई अध्ययन पथ नहीं। जल्द वापस देखें।',
    noMatches: 'इस खोज से कोई पथ मेल नहीं खाता।',
    clear: 'फ़िल्टर हटाएँ',
    levels: { seeker: 'खोजी', follower: 'अनुयायी', disciple: 'शिष्य', leader: 'नेता' },
    categories: {
      Foundations: 'नींव',
      Growth: 'वृद्धि',
      'Service & Mission': 'सेवा और मिशन',
      Apologetics: 'विश्वास की रक्षा',
      'Life & Relationships': 'जीवन और रिश्ते',
      Theology: 'धर्मविज्ञान',
    },
  },
  ml: {
    search: 'പാതകൾ തിരയുക…',
    allCategories: 'എല്ലാ വിഭാഗങ്ങളും',
    allLevels: 'എല്ലാ നിലകളും',
    article: 'ലേഖനം',
    articles: 'ലേഖനങ്ങൾ',
    empty: 'ഇതുവരെ പഠന പാതകളൊന്നുമില്ല. ഉടൻ തിരിച്ചുവരൂ.',
    noMatches: 'ആ തിരയലുമായി ഒരു പാതയും ചേരുന്നില്ല.',
    clear: 'ഫിൽട്ടറുകൾ മായ്ക്കുക',
    levels: { seeker: 'അന്വേഷകൻ', follower: 'അനുയായി', disciple: 'ശിഷ്യൻ', leader: 'നേതാവ്' },
    categories: {
      Foundations: 'അടിസ്ഥാനങ്ങൾ',
      Growth: 'വളർച്ച',
      'Service & Mission': 'സേവനവും ദൗത്യവും',
      Apologetics: 'വിശ്വാസ സംരക്ഷണം',
      'Life & Relationships': 'ജീവിതവും ബന്ധങ്ങളും',
      Theology: 'ദൈവശാസ്ത്രം',
    },
  },
}

const SearchIcon = (
  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-4.35-4.35M17 11A6 6 0 1 1 5 11a6 6 0 0 1 12 0z" />
  </svg>
)
const GridIcon = (
  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M4 5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5zm10 0a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1V5zM4 15a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-4zm10 0a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1v-4z" />
  </svg>
)
const LevelIcon = (
  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
    <path strokeLinecap="round" strokeLinejoin="round" d="M4 19V11m6 8V5m6 14v-6" />
  </svg>
)

// Ranked, so the dropdown reads seeker → leader rather than alphabetically.
const LEVEL_ORDER = ['seeker', 'follower', 'disciple', 'leader']

// 'believer' is an older synonym for 'follower' still present on some rows.
// Folding it in keeps one level from showing up as two filter entries.
function normalizeLevel(level?: string): string {
  const l = (level ?? '').trim().toLowerCase()
  return l === 'believer' ? 'follower' : l
}

export function PathsBrowser({
  paths,
  locale,
  initialQuery = '',
  initialCategory = '',
  initialLevel = '',
}: {
  paths: LearningPathMeta[]
  locale: string
  initialQuery?: string
  initialCategory?: string
  initialLevel?: string
}) {
  const t = COPY[locale] ?? COPY.en
  const [query, setQuery] = useState(initialQuery)
  const [category, setCategory] = useState(initialCategory)
  const [level, setLevel] = useState(normalizeLevel(initialLevel))

  // Mirror the filters in the address bar so a copied link reopens the same
  // view. replaceState rather than the router: every path is already on the
  // page, so there is nothing to re-fetch, and a router push would also reset
  // the scroll position mid-typing. It replaces rather than pushes so the back
  // button leaves the page instead of walking back through each keystroke.
  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const set = (key: string, value: string) => {
      if (value) params.set(key, value)
      else params.delete(key)
    }
    set('q', query.trim())
    set('category', category)
    set('level', level)
    const qs = params.toString()
    window.history.replaceState(
      null,
      '',
      qs ? `${window.location.pathname}?${qs}` : window.location.pathname,
    )
  }, [query, category, level])

  const visible = useMemo(
    () => (paths ?? []).filter((p) => p.post_count > 0),
    [paths],
  )

  const categoryOptions: DropdownOption[] = useMemo(() => {
    const found = Array.from(
      new Set(visible.map((p) => p.category?.trim()).filter((c): c is string => !!c)),
    ).sort((a, b) => a.localeCompare(b))
    return [
      { value: '', label: t.allCategories },
      ...found.map((c) => ({ value: c, label: t.categories[c] ?? c })),
    ]
  }, [visible, t])

  const levelOptions: DropdownOption[] = useMemo(() => {
    const found = Array.from(
      new Set(visible.map((p) => normalizeLevel(p.disciple_level)).filter((l) => !!l)),
    ).sort((a, b) => {
      const ai = LEVEL_ORDER.indexOf(a)
      const bi = LEVEL_ORDER.indexOf(b)
      // Anything outside the known ladder sorts after it, alphabetically.
      if (ai === -1 && bi === -1) return a.localeCompare(b)
      if (ai === -1) return 1
      if (bi === -1) return -1
      return ai - bi
    })
    return [
      { value: '', label: t.allLevels },
      ...found.map((l) => ({ value: l, label: t.levels[l] ?? l })),
    ]
  }, [visible, t])

  const results = useMemo(() => {
    const q = query.trim().toLowerCase()
    return visible.filter((p) => {
      if (q && !p.title.toLowerCase().includes(q)) return false
      if (category && p.category?.trim() !== category) return false
      if (level && normalizeLevel(p.disciple_level) !== level) return false
      return true
    })
  }, [visible, query, category, level])

  const filtering = query.trim() !== '' || category !== '' || level !== ''

  if (visible.length === 0) {
    return (
      <div className="text-center py-20">
        <p className="text-[var(--muted)] text-lg">{t.empty}</p>
      </div>
    )
  }

  return (
    <>
      {/* Controls */}
      <div className="flex flex-col sm:flex-row gap-3 mb-10 items-start sm:items-center">
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
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t.search}
            aria-label={t.search}
            className="w-full pl-9 pr-4 py-2 rounded-full text-sm
                       bg-[var(--surface)] border border-[var(--border)]
                       text-[var(--text)] placeholder:text-[var(--muted)]
                       focus:outline-none focus-visible:ring-2 focus-visible:ring-primary/30 focus-visible:ring-offset-1
                       hover:border-[var(--text)]/15 hover:shadow-sm
                       transition-all duration-200"
          />
        </div>

        <div className="flex gap-2 flex-wrap items-center">
          {categoryOptions.length > 1 && (
            <FilterDropdown
              options={categoryOptions}
              value={category}
              onChange={setCategory}
              icon={GridIcon}
              placeholder={t.allCategories}
            />
          )}
          {levelOptions.length > 1 && (
            <FilterDropdown
              options={levelOptions}
              value={level}
              onChange={setLevel}
              icon={LevelIcon}
              placeholder={t.allLevels}
            />
          )}
          {filtering && (
            <button
              type="button"
              onClick={() => { setQuery(''); setCategory(''); setLevel('') }}
              className="text-sm px-3 py-1.5 rounded-full text-[var(--muted)]
                         hover:text-[var(--text)] transition-colors
                         focus:outline-none focus-visible:ring-2 focus-visible:ring-primary/30"
            >
              {t.clear}
            </button>
          )}
        </div>
      </div>

      {/* Results */}
      {results.length === 0 ? (
        <div className="text-center py-20">
          <span className="inline-flex text-[var(--muted)] opacity-50 mb-3">{SearchIcon}</span>
          <p className="text-[var(--muted)] text-lg">{t.noMatches}</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {results.map((path, i) => (
            <Link
              key={path.slug}
              href={{ pathname: '/blog', query: { learning_path: path.slug } }}
              className="group flex flex-col rounded-2xl bg-[var(--surface)] border border-[var(--border)] overflow-hidden hover:border-primary/40 hover:shadow-lg transition-all"
            >
              <div
                className={`h-1.5 w-full bg-gradient-to-r ${GRADIENTS[i % GRADIENTS.length]}`}
              />
              <div className="flex flex-col flex-1 p-6">
                <h2 className="font-display font-bold text-xl mb-3 text-[var(--text)] group-hover:text-primary transition-colors">
                  {path.title}
                </h2>
                {(path.category?.trim() || normalizeLevel(path.disciple_level)) && (
                  <div className="flex flex-wrap gap-1.5 mb-3">
                    {path.category?.trim() && (
                      <span className="text-xs px-2 py-0.5 rounded-full bg-primary/10 dark:bg-indigo-500/15 text-primary dark:text-indigo-300 font-medium">
                        {t.categories[path.category.trim()] ?? path.category.trim()}
                      </span>
                    )}
                    {normalizeLevel(path.disciple_level) && (
                      <span className="text-xs px-2 py-0.5 rounded-full bg-[var(--border)]/60 dark:bg-white/5 text-[var(--muted)] font-medium">
                        {t.levels[normalizeLevel(path.disciple_level)] ??
                          normalizeLevel(path.disciple_level)}
                      </span>
                    )}
                  </div>
                )}
                <span className="mt-auto inline-flex items-center text-sm font-medium text-[var(--muted)]">
                  {path.post_count}{' '}
                  {path.post_count === 1 ? t.article : t.articles}
                  <span className="ml-2 transition-transform group-hover:translate-x-1">
                    →
                  </span>
                </span>
              </div>
            </Link>
          ))}
        </div>
      )}
    </>
  )
}

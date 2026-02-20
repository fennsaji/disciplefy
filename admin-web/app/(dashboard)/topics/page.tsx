'use client'

import { Fragment, useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'
import type {
  StudyGuideListItem,
  InputType,
  StudyMode,
  LanguageCode,
} from '@/types/admin'

type InputTypeFilter = InputType | 'all'
type StudyModeFilter = StudyMode | 'all'
type LanguageFilter = LanguageCode | 'all'

export default function StudyGuidesPage() {
  const router = useRouter()
  const [guides, setGuides] = useState<StudyGuideListItem[]>([])
  const [filteredGuides, setFilteredGuides] = useState<StudyGuideListItem[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // Filters
  const [inputTypeFilter, setInputTypeFilter] = useState<InputTypeFilter>('all')
  const [studyModeFilter, setStudyModeFilter] = useState<StudyModeFilter>('all')
  const [languageFilter, setLanguageFilter] = useState<LanguageFilter>('all')
  const [searchQuery, setSearchQuery] = useState('')

  // Inline preview expand
  const [expandedId, setExpandedId] = useState<string | null>(null)
  const [expandedData, setExpandedData] = useState<Record<string, { summary?: string; interpretation?: string; loading: boolean }>>({})

  const handleToggleExpand = async (guideId: string) => {
    if (expandedId === guideId) {
      setExpandedId(null)
      return
    }
    setExpandedId(guideId)
    if (expandedData[guideId]) return // already loaded
    setExpandedData((prev) => ({ ...prev, [guideId]: { loading: true } }))
    try {
      const res = await fetch(`/api/admin/study-guide/${guideId}`, { credentials: 'include' })
      const data = await res.json()
      const g = data.study_guide
      setExpandedData((prev) => ({
        ...prev,
        [guideId]: {
          loading: false,
          summary: g?.content?.summary ?? g?.summary ?? '',
          interpretation: g?.content?.interpretation ?? g?.interpretation ?? '',
        },
      }))
    } catch {
      setExpandedData((prev) => ({ ...prev, [guideId]: { loading: false } }))
    }
  }

  // Stats
  const [stats, setStats] = useState({
    total: 0,
    totalUsage: 0,
    byInputType: {} as Record<string, number>,
    byLanguage: {} as Record<string, number>,
    byStudyMode: {} as Record<string, number>,
  })

  // Load guides
  useEffect(() => {
    loadGuides()
  }, [])

  // Apply filters
  useEffect(() => {
    let filtered = guides

    // Input type filter
    if (inputTypeFilter !== 'all') {
      filtered = filtered.filter((g) => g.input_type === inputTypeFilter)
    }

    // Study mode filter
    if (studyModeFilter !== 'all') {
      filtered = filtered.filter((g) => g.study_mode === studyModeFilter)
    }

    // Language filter
    if (languageFilter !== 'all') {
      filtered = filtered.filter((g) => g.language === languageFilter)
    }

    // Search filter
    if (searchQuery) {
      const query = searchQuery.toLowerCase()
      filtered = filtered.filter(
        (g) =>
          g.input_value.toLowerCase().includes(query) ||
          g.topic_title?.toLowerCase().includes(query) ||
          g.creator_name?.toLowerCase().includes(query)
      )
    }

    setFilteredGuides(filtered)
  }, [guides, inputTypeFilter, studyModeFilter, languageFilter, searchQuery])

  const loadGuides = async () => {
    setIsLoading(true)
    setError(null)
    try {
      const response = await fetch('/api/admin/topics')
      if (!response.ok) {
        throw new Error('Failed to load study guides')
      }
      const data = await response.json()
      const loadedGuides = data.study_guides || []
      setGuides(loadedGuides)

      // Calculate stats
      const byInputType: Record<string, number> = {}
      const byLanguage: Record<string, number> = {}
      const byStudyMode: Record<string, number> = {}
      let totalUsage = 0

      loadedGuides.forEach((guide: StudyGuideListItem) => {
        byInputType[guide.input_type] = (byInputType[guide.input_type] || 0) + 1
        byLanguage[guide.language] = (byLanguage[guide.language] || 0) + 1
        byStudyMode[guide.study_mode] = (byStudyMode[guide.study_mode] || 0) + 1
        totalUsage += guide.usage_count || 0
      })

      setStats({
        total: loadedGuides.length,
        totalUsage,
        byInputType,
        byLanguage,
        byStudyMode,
      })
    } catch (err) {
      console.error('Failed to load study guides:', err)
      setError('Failed to load study guides. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleEdit = (guide: StudyGuideListItem) => {
    // Build URL with pre-filled parameters
    const params = new URLSearchParams()
    params.set('input_type', guide.input_type)
    params.set('input_value', guide.input_value)
    params.set('study_mode', guide.study_mode)
    params.set('language', guide.language)
    router.push(`/study-generator?${params.toString()}`)
  }

  const handleDelete = async (guideId: string) => {
    const guide = guides.find((g) => g.id === guideId)
    if (!guide) return

    const confirmMessage =
      guide.usage_count && guide.usage_count > 0
        ? `Are you sure you want to delete this study guide? It is used by ${guide.usage_count} user(s).`
        : `Are you sure you want to delete this study guide?`

    if (!confirm(confirmMessage)) return

    try {
      const response = await fetch(`/api/admin/study-guide/${guideId}`, {
        method: 'DELETE',
      })

      if (!response.ok) {
        const data = await response.json()
        throw new Error(data.error || 'Failed to delete study guide')
      }

      await loadGuides()
    } catch (err: any) {
      console.error('Failed to delete study guide:', err)
      toast.error(err.message || 'Failed to delete study guide. Please try again.')
    }
  }

  const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    })
  }

  const getInputTypeIcon = (type: InputType) => {
    switch (type) {
      case 'topic':
        return '📖'
      case 'verse':
        return '📜'
      case 'question':
        return '❓'
      default:
        return '📄'
    }
  }

  const getStudyModeLabel = (mode: StudyMode) => {
    const labels: Record<StudyMode, string> = {
      quick: 'Quick',
      standard: 'Standard',
      deep: 'Deep',
      lectio: 'Lectio',
      sermon: 'Sermon',
      recommended: 'Recommended',
    }
    return labels[mode] || mode
  }

  const getLanguageLabel = (lang: LanguageCode) => {
    const labels: Record<LanguageCode, string> = {
      en: 'English',
      hi: 'हिन्दी',
      ml: 'മലയാളം',
    }
    return labels[lang] || lang
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Study Guides"
        description="View and manage generated study guides"
        actions={
          <button
            type="button"
            onClick={() => router.push('/study-generator')}
            className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600"
          >
            <svg
              className="h-5 w-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M12 4v16m8-8H4"
              />
            </svg>
            Generate New
          </button>
        }
      />

      {/* Stats Cards */}
      <div className="grid gap-4 md:grid-cols-4">
        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Total Guides</p>
              <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
                {stats.total}
              </p>
            </div>
            <div className="rounded-full bg-primary-100 p-3">
              <svg
                className="h-6 w-6 text-primary"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
                />
              </svg>
            </div>
          </div>
        </div>

        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Total Usage</p>
              <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
                {stats.totalUsage}
              </p>
            </div>
            <div className="rounded-full bg-green-100 p-3">
              <svg
                className="h-6 w-6 text-green-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
                />
              </svg>
            </div>
          </div>
        </div>

        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Most Used Type</p>
              <p className="mt-1 text-xs font-medium capitalize text-gray-700 dark:text-gray-300">
                {Object.entries(stats.byInputType).sort(
                  ([, a], [, b]) => b - a
                )[0]?.[0] || 'N/A'}
              </p>
              <p className="text-sm text-gray-500 dark:text-gray-400">
                {Object.entries(stats.byInputType).sort(
                  ([, a], [, b]) => b - a
                )[0]?.[1] || 0}{' '}
                guides
              </p>
            </div>
            <div className="rounded-full bg-purple-100 p-3">
              <svg
                className="h-6 w-6 text-purple-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                />
              </svg>
            </div>
          </div>
        </div>

        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Languages</p>
              <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
                {Object.keys(stats.byLanguage).length}
              </p>
            </div>
            <div className="rounded-full bg-blue-100 p-3">
              <svg
                className="h-6 w-6 text-blue-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129"
                />
              </svg>
            </div>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="space-y-4 rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
        <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          {/* Input Type Filter */}
          <div className="flex items-center gap-2">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Type:</label>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => setInputTypeFilter('all')}
                className={`rounded-lg px-3 py-1.5 text-sm font-medium transition-colors ${
                  inputTypeFilter === 'all'
                    ? 'bg-primary text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600'
                }`}
              >
                All
              </button>
              <button
                type="button"
                onClick={() => setInputTypeFilter('topic')}
                className={`rounded-lg px-3 py-1.5 text-sm font-medium transition-colors ${
                  inputTypeFilter === 'topic'
                    ? 'bg-primary text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600'
                }`}
              >
                📖 Topic
              </button>
              <button
                type="button"
                onClick={() => setInputTypeFilter('verse')}
                className={`rounded-lg px-3 py-1.5 text-sm font-medium transition-colors ${
                  inputTypeFilter === 'verse'
                    ? 'bg-primary text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600'
                }`}
              >
                📜 Verse
              </button>
              <button
                type="button"
                onClick={() => setInputTypeFilter('question')}
                className={`rounded-lg px-3 py-1.5 text-sm font-medium transition-colors ${
                  inputTypeFilter === 'question'
                    ? 'bg-primary text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600'
                }`}
              >
                ❓ Question
              </button>
            </div>
          </div>

          {/* Study Mode Filter */}
          <div className="flex items-center gap-2">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Mode:</label>
            <select
              value={studyModeFilter}
              onChange={(e) => setStudyModeFilter(e.target.value as StudyModeFilter)}
              className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
            >
              <option value="all">All Modes</option>
              <option value="quick">Quick</option>
              <option value="standard">Standard</option>
              <option value="deep">Deep</option>
              <option value="lectio">Lectio</option>
              <option value="sermon">Sermon</option>
            </select>
          </div>

          {/* Language Filter */}
          <div className="flex items-center gap-2">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Language:</label>
            <select
              value={languageFilter}
              onChange={(e) => setLanguageFilter(e.target.value as LanguageFilter)}
              className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
            >
              <option value="all">All Languages</option>
              <option value="en">English</option>
              <option value="hi">हिन्दी</option>
              <option value="ml">മലയാളം</option>
            </select>
          </div>
        </div>

        {/* Search */}
        <div className="relative flex-1 md:max-w-xs">
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search study guides..."
            className="w-full rounded-lg border border-gray-300 py-2 pl-10 pr-4 text-sm focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
          />
          <svg
            className="absolute left-3 top-2.5 h-5 w-5 text-gray-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            />
          </svg>
        </div>
      </div>

      {/* Error Message */}
      {error && (
        <div className="rounded-lg bg-red-50 p-4 dark:bg-red-900/20">
          <p className="text-sm text-red-800 dark:text-red-300">{error}</p>
        </div>
      )}

      {/* Loading State */}
      {isLoading && (
        <div className="flex items-center justify-center py-12">
          <div className="text-center">
            <div className="mx-auto h-12 w-12 animate-spin rounded-full border-4 border-primary border-t-transparent"></div>
            <p className="mt-4 text-sm text-gray-600 dark:text-gray-400">Loading study guides...</p>
          </div>
        </div>
      )}

      {/* Table */}
      {!isLoading && (
        <div className="overflow-hidden rounded-lg border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-800">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead className="bg-gray-50 dark:bg-gray-900">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Content
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Type
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Mode
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Language
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Usage
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Created
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Actions
                  </th>
                  {/* spacer keeps col count correct */}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200 bg-white dark:divide-gray-700 dark:bg-gray-800">
                {filteredGuides.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="px-6 py-8 text-center">
                      <p className="text-sm text-gray-500 dark:text-gray-400">
                        No study guides found. Try adjusting your filters or generate a new study guide.
                      </p>
                    </td>
                  </tr>
                ) : (
                  filteredGuides.map((guide) => (
                    <Fragment key={guide.id}>
                    <tr className={`hover:bg-gray-50 dark:hover:bg-gray-700/50 ${expandedId === guide.id ? 'bg-indigo-50/40 dark:bg-indigo-900/10' : ''}`}>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          {/* Expand toggle */}
                          <button
                            onClick={() => handleToggleExpand(guide.id)}
                            className={`shrink-0 rounded p-0.5 transition-colors ${expandedId === guide.id ? 'text-indigo-600 dark:text-indigo-400' : 'text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'}`}
                            title={expandedId === guide.id ? 'Collapse preview' : 'Expand preview'}
                          >
                            <svg className={`h-4 w-4 transition-transform ${expandedId === guide.id ? 'rotate-90' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                            </svg>
                          </button>
                          <span className="text-xl">{getInputTypeIcon(guide.input_type)}</span>
                          <div>
                            <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
                              {guide.input_value.length > 50
                                ? `${guide.input_value.substring(0, 50)}...`
                                : guide.input_value}
                            </p>
                            {guide.creator_name && (
                              <p className="text-xs text-gray-500 dark:text-gray-400">
                                by {guide.creator_name}
                              </p>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <span className="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium capitalize text-blue-800 dark:bg-blue-900/30 dark:text-blue-300">
                          {guide.input_type}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <span className="inline-flex items-center rounded-full bg-purple-100 px-2.5 py-0.5 text-xs font-medium capitalize text-purple-800 dark:bg-purple-900/30 dark:text-purple-300">
                          {getStudyModeLabel(guide.study_mode)}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <span className="text-sm text-gray-900 dark:text-gray-100">
                          {getLanguageLabel(guide.language)}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <span className="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-300">
                          {guide.usage_count || 0} users
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <span className="text-sm text-gray-500 dark:text-gray-400">
                          {formatDate(guide.created_at)}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          {/* View / Edit guide content */}
                          <button
                            onClick={() => router.push(`/topics/guide/${guide.id}`)}
                            className="rounded p-1 text-indigo-600 hover:bg-indigo-50 dark:text-indigo-400 dark:hover:bg-indigo-900/30"
                            title="View & Edit Guide"
                          >
                            <svg
                              className="h-5 w-5"
                              fill="none"
                              viewBox="0 0 24 24"
                              stroke="currentColor"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                              />
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                              />
                            </svg>
                          </button>
                          {/* Regenerate in study generator */}
                          <button
                            onClick={() => handleEdit(guide)}
                            className="rounded p-1 text-gray-600 hover:bg-gray-100 dark:text-gray-400 dark:hover:bg-gray-700"
                            title="Edit & Regenerate"
                          >
                            <svg
                              className="h-5 w-5"
                              fill="none"
                              viewBox="0 0 24 24"
                              stroke="currentColor"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                              />
                            </svg>
                          </button>
                          <button
                            onClick={() => handleDelete(guide.id)}
                            className="rounded p-1 text-red-600 hover:bg-red-50 dark:text-red-400 dark:hover:bg-red-900/20"
                            title="Delete"
                          >
                            <svg
                              className="h-5 w-5"
                              fill="none"
                              viewBox="0 0 24 24"
                              stroke="currentColor"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                              />
                            </svg>
                          </button>
                        </div>
                      </td>
                    </tr>
                    {/* Inline preview row */}
                    {expandedId === guide.id && (
                      <tr className="bg-indigo-50/60 dark:bg-indigo-900/10">
                        <td colSpan={8} className="px-8 pb-5 pt-3">
                          {expandedData[guide.id]?.loading ? (
                            <div className="flex items-center gap-2 text-sm text-gray-500 dark:text-gray-400">
                              <div className="h-4 w-4 animate-spin rounded-full border-2 border-primary border-t-transparent" />
                              Loading preview…
                            </div>
                          ) : (
                            <div className="space-y-3">
                              {expandedData[guide.id]?.summary && (
                                <div>
                                  <p className="mb-1 text-xs font-semibold uppercase tracking-wide text-indigo-600 dark:text-indigo-400">Summary</p>
                                  <p className="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap">
                                    {expandedData[guide.id].summary}
                                  </p>
                                </div>
                              )}
                              {expandedData[guide.id]?.interpretation && (
                                <div>
                                  <p className="mb-1 text-xs font-semibold uppercase tracking-wide text-indigo-600 dark:text-indigo-400">Interpretation</p>
                                  <p className="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap">
                                    {expandedData[guide.id].interpretation}
                                  </p>
                                </div>
                              )}
                              {!expandedData[guide.id]?.summary && !expandedData[guide.id]?.interpretation && (
                                <p className="text-sm text-gray-400 dark:text-gray-500">No preview content available.</p>
                              )}
                              <button
                                onClick={() => router.push(`/topics/guide/${guide.id}`)}
                                className="inline-flex items-center gap-1.5 rounded-lg border border-indigo-200 bg-white px-3 py-1.5 text-xs font-medium text-indigo-700 hover:bg-indigo-50 dark:border-indigo-400/20 dark:bg-transparent dark:text-indigo-300 dark:hover:bg-indigo-400/10"
                              >
                                Open full guide →
                              </button>
                            </div>
                          )}
                        </td>
                      </tr>
                    )}
                    </Fragment>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}

'use client'

import { useState, useEffect, useCallback } from 'react'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'
import { LoadingState } from '@/components/ui/loading-spinner'
import SuggestedVersesTable from '@/components/tables/suggested-verses-table'
import SuggestedVerseDialog from '@/components/dialogs/suggested-verse-dialog'

const CATEGORIES = [
  'all',
  'salvation',
  'comfort',
  'strength',
  'wisdom',
  'promise',
  'guidance',
  'faith',
  'love',
]

interface Translation {
  reference: string
  text: string
}

interface SuggestedVerse {
  id: string
  category: string
  display_order: number
  created_at: string
  translations: Record<string, Translation>
}

interface Stats {
  total: number
  by_category: Record<string, number>
  translation_coverage: {
    en: number
    hi: number
    ml: number
  }
}

export default function MemoryVersesPage() {
  const [verses, setVerses] = useState<SuggestedVerse[]>([])
  const [stats, setStats] = useState<Stats | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [categoryFilter, setCategoryFilter] = useState('all')

  // Dialog state
  const [dialogOpen, setDialogOpen] = useState(false)
  const [editingVerse, setEditingVerse] = useState<SuggestedVerse | null>(null)

  const fetchVerses = useCallback(async (category?: string) => {
    setLoading(true)
    setError(null)
    try {
      const params = new URLSearchParams({ limit: '200' })
      if (category && category !== 'all') params.set('category', category)

      const res = await fetch(`/api/admin/content/suggested-verses?${params}`)
      if (!res.ok) {
        const data = await res.json()
        throw new Error(data.error || 'Failed to fetch suggested verses')
      }
      const data = await res.json()
      setVerses(data.suggested_verses || [])
      setStats(data.stats || null)
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchVerses(categoryFilter)
  }, [fetchVerses, categoryFilter])

  const handleAdd = () => {
    setEditingVerse(null)
    setDialogOpen(true)
  }

  const handleEdit = (verse: SuggestedVerse) => {
    setEditingVerse(verse)
    setDialogOpen(true)
  }

  const handleDelete = async (id: string) => {
    try {
      const res = await fetch(`/api/admin/content/suggested-verses?id=${id}`, {
        method: 'DELETE',
      })
      if (!res.ok) {
        const data = await res.json()
        throw new Error(data.error || 'Failed to delete verse')
      }
      toast.success('Suggested verse deleted')
      fetchVerses(categoryFilter)
    } catch (err: any) {
      toast.error(err.message || 'Failed to delete verse')
    }
  }

  const handleSave = async (formData: {
    id?: string
    category: string
    display_order: number
    translations: Record<string, Translation>
  }) => {
    const isEdit = !!formData.id

    const res = await fetch('/api/admin/content/suggested-verses', {
      method: isEdit ? 'PATCH' : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(formData),
    })

    if (!res.ok) {
      const data = await res.json()
      throw new Error(data.error || `Failed to ${isEdit ? 'update' : 'create'} verse`)
    }

    toast.success(isEdit ? 'Verse updated successfully' : 'Verse added successfully')
    setDialogOpen(false)
    fetchVerses(categoryFilter)
  }

  const totalVerses = stats?.total ?? 0
  const enCoverage = stats ? stats.translation_coverage.en : 0
  const hiCoverage = stats ? stats.translation_coverage.hi : 0
  const mlCoverage = stats ? stats.translation_coverage.ml : 0

  return (
    <div className="space-y-6">
      <PageHeader
        title="Memory Verses"
        description="Manage suggested verses that appear when users add memory verses"
        actions={
          <button
            onClick={handleAdd}
            className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
            </svg>
            Add Verse
          </button>
        }
      />

      {/* Stats Grid */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Total Verses</p>
              <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">{totalVerses}</p>
            </div>
            <div className="rounded-full bg-purple-100 p-3 dark:bg-purple-900/30">
              <svg className="h-6 w-6 text-purple-600 dark:text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">English</p>
              <p className="mt-1 text-2xl font-semibold text-green-600 dark:text-green-400">{enCoverage}</p>
            </div>
            <div className="rounded-full bg-green-100 p-3 dark:bg-green-900/30">
              <svg className="h-6 w-6 text-green-600 dark:text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Hindi</p>
              <p className={`mt-1 text-2xl font-semibold ${hiCoverage === totalVerses && totalVerses > 0 ? 'text-green-600 dark:text-green-400' : 'text-yellow-600 dark:text-yellow-400'}`}>
                {hiCoverage}
              </p>
            </div>
            <div className="rounded-full bg-blue-100 p-3 dark:bg-blue-900/30">
              <svg className="h-6 w-6 text-blue-600 dark:text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" />
              </svg>
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Malayalam</p>
              <p className={`mt-1 text-2xl font-semibold ${mlCoverage === totalVerses && totalVerses > 0 ? 'text-green-600 dark:text-green-400' : 'text-yellow-600 dark:text-yellow-400'}`}>
                {mlCoverage}
              </p>
            </div>
            <div className="rounded-full bg-yellow-100 p-3 dark:bg-yellow-900/30">
              <svg className="h-6 w-6 text-yellow-600 dark:text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" />
              </svg>
            </div>
          </div>
        </div>
      </div>

      {/* Category Filter */}
      <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
        <div className="flex flex-wrap gap-2">
          {CATEGORIES.map((cat) => {
            const count = cat === 'all' ? totalVerses : (stats?.by_category[cat] ?? 0)
            return (
              <button
                key={cat}
                onClick={() => setCategoryFilter(cat)}
                className={`rounded-full px-3 py-1 text-xs font-medium transition-colors ${
                  categoryFilter === cat
                    ? 'bg-primary text-white'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600'
                }`}
              >
                {cat === 'all' ? 'All' : cat.charAt(0).toUpperCase() + cat.slice(1)}
                {' '}
                <span className={`${categoryFilter === cat ? 'text-white/70' : 'text-gray-400 dark:text-gray-500'}`}>
                  ({count})
                </span>
              </button>
            )
          })}
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="rounded-lg bg-red-50 p-4 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-400">
          {error}
        </div>
      )}

      {/* Table */}
      <div className="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm dark:border-gray-700 dark:bg-gray-800">
        {loading ? (
          <LoadingState label="Loading verses..." />
        ) : (
          <SuggestedVersesTable
            verses={verses}
            onEdit={handleEdit}
            onDelete={handleDelete}
          />
        )}
      </div>

      {/* Add/Edit Dialog */}
      <SuggestedVerseDialog
        isOpen={dialogOpen}
        verse={editingVerse}
        onClose={() => setDialogOpen(false)}
        onSave={handleSave}
      />
    </div>
  )
}

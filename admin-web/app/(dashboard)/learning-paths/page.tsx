'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'
import { LoadingState } from '@/components/ui/loading-spinner'
import { LearningPathsTable } from '@/components/tables/learning-paths-table'
import type { LearningPath } from '@/types/admin'
import {
  listLearningPaths,
  deleteLearningPath,
  reorderLearningPath,
  toggleLearningPath,
} from '@/lib/api/admin'

type StatusFilter = 'all' | 'active' | 'inactive'

export default function LearningPathsPage() {
  const router = useRouter()
  const [paths, setPaths] = useState<LearningPath[]>([])
  const [filteredPaths, setFilteredPaths] = useState<LearningPath[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // Filters
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all')
  const [searchQuery, setSearchQuery] = useState('')

  // Stats
  const [stats, setStats] = useState({
    total: 0,
    active: 0,
    featured: 0,
    totalEnrolled: 0,
  })

  // Load paths
  useEffect(() => {
    loadPaths()
  }, [])

  // Apply filters
  useEffect(() => {
    let filtered = paths

    // Status filter
    if (statusFilter === 'active') {
      filtered = filtered.filter((p) => p.is_active)
    } else if (statusFilter === 'inactive') {
      filtered = filtered.filter((p) => !p.is_active)
    }

    // Search filter
    if (searchQuery) {
      const query = searchQuery.toLowerCase()
      filtered = filtered.filter(
        (p) =>
          p.title.toLowerCase().includes(query) ||
          p.slug.toLowerCase().includes(query) ||
          p.description.toLowerCase().includes(query)
      )
    }

    setFilteredPaths(filtered)
  }, [paths, statusFilter, searchQuery])

  const loadPaths = async () => {
    setIsLoading(true)
    setError(null)
    try {
      const response = await listLearningPaths()
      const loadedPaths = response.learning_paths || []
      setPaths(loadedPaths)

      // Calculate stats
      setStats({
        total: loadedPaths.length,
        active: loadedPaths.filter((p) => p.is_active).length,
        featured: loadedPaths.filter((p) => p.is_featured).length,
        totalEnrolled: loadedPaths.reduce(
          (sum, p) => sum + (p.enrolled_count || 0),
          0
        ),
      })
    } catch (err) {
      console.error('Failed to load learning paths:', err)
      setError('Failed to load learning paths. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleEdit = async (path: LearningPath) => {
    // Navigate to dedicated edit page
    router.push(`/learning-paths/${path.id}/edit`)
  }

  const handleDelete = async (pathId: string) => {
    const path = paths.find((p) => p.id === pathId)
    if (!path) return

    const confirmMessage =
      path.topics_count && path.topics_count > 0
        ? `Are you sure you want to delete "${path.title}"? This will remove ${path.topics_count} topic association(s).`
        : `Are you sure you want to delete "${path.title}"?`

    if (!confirm(confirmMessage)) return

    try {
      await deleteLearningPath(pathId)
      await loadPaths()
    } catch (err) {
      console.error('Failed to delete learning path:', err)
      toast.error('Failed to delete learning path. Please try again.')
    }
  }

  const handleToggle = async (pathId: string, isActive: boolean) => {
    try {
      await toggleLearningPath(pathId, { is_active: isActive })
      await loadPaths()
    } catch (err) {
      console.error('Failed to toggle learning path:', err)
      toast.error('Failed to update status. Please try again.')
    }
  }

  const handleReorder = async (reorderedPaths: LearningPath[]) => {
    // Optimistic update
    setPaths(reorderedPaths)

    try {
      // Send reorder requests for each path
      for (const path of reorderedPaths) {
        await reorderLearningPath(path.id, {
          display_order: path.display_order,
        })
      }
      await loadPaths()
    } catch (err) {
      console.error('Failed to reorder learning paths:', err)
      toast.error('Failed to save new order. Please try again.')
      await loadPaths() // Reload to reset
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Learning Paths"
        description="Manage learning paths and organize study topics"
        actions={
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => router.push('/learning-paths/export')}
              className="flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-300 dark:hover:bg-gray-700"
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
                  d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
                />
              </svg>
              Export
            </button>
            <button
              type="button"
              onClick={() => router.push('/learning-paths/import')}
              className="flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-300 dark:hover:bg-gray-700"
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
                  d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"
                />
              </svg>
              Import
            </button>
            <button
              type="button"
              onClick={() => router.push('/learning-paths/create')}
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
              Create Path
            </button>
          </div>
        }
      />

      {/* Stats Cards */}
      <div className="grid gap-4 md:grid-cols-4">
        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Total Paths</p>
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
                  d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                />
              </svg>
            </div>
          </div>
        </div>

        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Active</p>
              <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
                {stats.active}
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
                  d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
            </div>
          </div>
        </div>

        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Featured</p>
              <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
                {stats.featured}
              </p>
            </div>
            <div className="rounded-full bg-yellow-100 p-3">
              <svg
                className="h-6 w-6 text-yellow-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
                />
              </svg>
            </div>
          </div>
        </div>

        <div className="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Total Enrolled</p>
              <p className="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
                {stats.totalEnrolled}
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
                  d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
                />
              </svg>
            </div>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-col gap-4 rounded-lg border border-gray-200 bg-white p-4 md:flex-row md:items-center md:justify-between dark:border-gray-700 dark:bg-gray-800">
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => setStatusFilter('all')}
            className={`rounded-lg px-3 py-1.5 text-sm font-medium transition-colors ${
              statusFilter === 'all'
                ? 'bg-primary text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600'
            }`}
          >
            All
          </button>
          <button
            type="button"
            onClick={() => setStatusFilter('active')}
            className={`rounded-lg px-3 py-1.5 text-sm font-medium transition-colors ${
              statusFilter === 'active'
                ? 'bg-primary text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600'
            }`}
          >
            Active
          </button>
          <button
            type="button"
            onClick={() => setStatusFilter('inactive')}
            className={`rounded-lg px-3 py-1.5 text-sm font-medium transition-colors ${
              statusFilter === 'inactive'
                ? 'bg-primary text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600'
            }`}
          >
            Inactive
          </button>
        </div>

        <div className="relative flex-1 md:max-w-xs">
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search paths..."
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
      {isLoading && <LoadingState label="Loading learning paths..." />}

      {/* Table */}
      {!isLoading && (
        <LearningPathsTable
          paths={filteredPaths}
          onEdit={handleEdit}
          onDelete={handleDelete}
          onToggle={handleToggle}
          onReorder={handleReorder}
        />
      )}
    </div>
  )
}

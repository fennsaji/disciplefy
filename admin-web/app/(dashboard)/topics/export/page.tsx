'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { useRouter } from 'next/navigation'
import { listTopics } from '@/lib/api/admin'
import type { RecommendedTopic } from '@/types/admin'

export default function ExportTopicsPage() {
  const router = useRouter()
  const [topics, setTopics] = useState<RecommendedTopic[]>([])
  const [selectedTopics, setSelectedTopics] = useState<Set<string>>(new Set())
  const [isLoading, setIsLoading] = useState(true)
  const [isExporting, setIsExporting] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [categoryFilter, setCategoryFilter] = useState<string>('all')

  useEffect(() => {
    loadTopics()
  }, [])

  const loadTopics = async () => {
    setIsLoading(true)
    try {
      const response = await listTopics()
      setTopics(response.topics || [])
    } catch (err) {
      console.error('Failed to load topics:', err)
      toast.error('Failed to load topics')
    } finally {
      setIsLoading(false)
    }
  }

  const toggleTopic = (topicId: string) => {
    const newSelected = new Set(selectedTopics)
    if (newSelected.has(topicId)) {
      newSelected.delete(topicId)
    } else {
      newSelected.add(topicId)
    }
    setSelectedTopics(newSelected)
  }

  const toggleAll = () => {
    if (selectedTopics.size === filteredTopics.length) {
      setSelectedTopics(new Set())
    } else {
      setSelectedTopics(new Set(filteredTopics.map(t => t.id)))
    }
  }

  const handleExport = async () => {
    if (selectedTopics.size === 0) {
      toast.error('Please select at least one topic to export')
      return
    }

    setIsExporting(true)
    try {
      // Fetch full details for each selected topic
      const topicsToExport = await Promise.all(
        Array.from(selectedTopics).map(async (topicId) => {
          const response = await fetch(`/api/admin/topics/${topicId}`)
          const data = await response.json()
          return data.topic
        })
      )

      // Create export object
      const exportData = {
        version: '1.0',
        exportDate: new Date().toISOString(),
        type: 'recommended-topics',
        count: topicsToExport.length,
        data: topicsToExport,
      }

      // Download as JSON file
      const blob = new Blob([JSON.stringify(exportData, null, 2)], {
        type: 'application/json',
      })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = `topics-export-${new Date().toISOString().split('T')[0]}.json`
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      URL.revokeObjectURL(url)

      toast.success(`Successfully exported ${topicsToExport.length} topic(s)`)
    } catch (err) {
      console.error('Export failed:', err)
      toast.error('Failed to export topics. Please try again.')
    } finally {
      setIsExporting(false)
    }
  }

  const filteredTopics = topics.filter((topic) => {
    // Category filter
    if (categoryFilter !== 'all' && topic.category !== categoryFilter) {
      return false
    }

    // Search filter
    if (searchQuery) {
      const query = searchQuery.toLowerCase()
      return (
        topic.title.toLowerCase().includes(query) ||
        topic.category.toLowerCase().includes(query) ||
        topic.tags?.some(tag => tag.toLowerCase().includes(query))
      )
    }

    return true
  })

  // Get unique categories
  const categories = Array.from(new Set(topics.map(t => t.category)))

  return (
    <div className="min-h-screen bg-gray-50 p-6 dark:bg-gray-900">
      <div className="mx-auto max-w-6xl">
        {/* Header */}
        <div className="mb-6">
          <button
            onClick={() => router.push('/topics')}
            className="mb-4 flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
          >
            <svg
              className="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M15 19l-7-7 7-7"
              />
            </svg>
            Back to Topics
          </button>
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">
                Export Topics
              </h1>
              <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
                Select topics to export as JSON file
              </p>
            </div>
            <button
              onClick={handleExport}
              disabled={selectedTopics.size === 0 || isExporting}
              className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:cursor-not-allowed disabled:opacity-50"
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
              {isExporting
                ? 'Exporting...'
                : `Export ${selectedTopics.size} Topic${selectedTopics.size !== 1 ? 's' : ''}`}
            </button>
          </div>
        </div>

        {/* Filters */}
        <div className="mb-4 flex gap-4">
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
          >
            <option value="all">All Categories</option>
            {categories.map((category) => (
              <option key={category} value={category}>
                {category}
              </option>
            ))}
          </select>
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search topics..."
            className="flex-1 rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-400"
          />
        </div>

        {/* Content */}
        <div className="overflow-hidden rounded-lg bg-white shadow dark:bg-gray-800 dark:shadow-gray-900">
          {isLoading ? (
            <div className="flex items-center justify-center py-12">
              <div className="text-center">
                <div className="mx-auto h-12 w-12 animate-spin rounded-full border-4 border-primary border-t-transparent"></div>
                <p className="mt-4 text-sm text-gray-600 dark:text-gray-400">Loading topics...</p>
              </div>
            </div>
          ) : (
            <>
              {/* Selection Header */}
              <div className="border-b border-gray-200 bg-gray-50 px-6 py-3 dark:border-gray-700 dark:bg-gray-700">
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={
                      selectedTopics.size > 0 &&
                      selectedTopics.size === filteredTopics.length
                    }
                    onChange={toggleAll}
                    className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary dark:border-gray-600 dark:bg-gray-600"
                  />
                  <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                    Select All ({selectedTopics.size} of {filteredTopics.length} selected)
                  </span>
                </label>
              </div>

              {/* List */}
              <div className="divide-y divide-gray-200 dark:divide-gray-700">
                {filteredTopics.length === 0 ? (
                  <div className="p-12 text-center">
                    <p className="text-gray-500 dark:text-gray-400">No topics found</p>
                  </div>
                ) : (
                  filteredTopics.map((topic) => (
                    <label
                      key={topic.id}
                      className="flex items-center gap-4 p-4 hover:bg-gray-50 cursor-pointer dark:hover:bg-gray-700"
                    >
                      <input
                        type="checkbox"
                        checked={selectedTopics.has(topic.id)}
                        onChange={() => toggleTopic(topic.id)}
                        className="h-5 w-5 rounded border-gray-300 text-primary focus:ring-primary dark:border-gray-600 dark:bg-gray-600"
                      />
                      <div className="flex-1">
                        <p className="font-medium text-gray-900 dark:text-gray-100">{topic.title}</p>
                        <div className="mt-1 flex items-center gap-3 text-xs text-gray-500 dark:text-gray-400">
                          <span>{topic.category}</span>
                          <span>•</span>
                          <span>{topic.input_type}</span>
                          <span>•</span>
                          <span>{topic.xp_value} XP</span>
                          {topic.tags && topic.tags.length > 0 && (
                            <>
                              <span>•</span>
                              <span>{topic.tags.join(', ')}</span>
                            </>
                          )}
                        </div>
                      </div>
                    </label>
                  ))
                )}
              </div>
            </>
          )}
        </div>

        {/* Info Card */}
        <div className="mt-6 rounded-lg border border-blue-200 bg-blue-50 p-4 dark:border-blue-900/30 dark:bg-blue-900/20">
          <div className="flex gap-3">
            <svg
              className="h-5 w-5 text-blue-600 dark:text-blue-400"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <div className="flex-1">
              <p className="text-sm font-medium text-blue-900 dark:text-blue-300">Export Information</p>
              <ul className="mt-2 space-y-1 text-sm text-blue-800 dark:text-blue-400">
                <li>• Exported data includes all topic details and translations</li>
                <li>• Use the Import feature to load this data in another environment</li>
                <li>• The JSON file can be version controlled for backup</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

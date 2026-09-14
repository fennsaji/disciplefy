'use client'

import { useState, useEffect, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragEndEvent,
} from '@dnd-kit/core'
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { reorderPathTopics, toggleTopicMilestone } from '@/lib/api/admin'
import { EditIcon, GenerateIcon, DragHandleIcon, actionButtonStyles } from '@/components/ui/action-icons'

interface PathTopicOrganizerProps {
  pathId: string
}

interface PathTopic {
  id: string
  title: string
  category: string
  xp_value: number
  position: number
  is_milestone: boolean
}

const BLOG_LOCALES = ['en', 'hi', 'ml'] as const
type BlogLocale = (typeof BLOG_LOCALES)[number]

interface LocaleBlogStatus {
  slug: string | null
  generating: boolean
  error: string | null
}

type TopicBlogStatus = Record<BlogLocale, LocaleBlogStatus>

/** How often blog status refreshes while a lesson's blogs are being written. */
const BLOG_POLL_MS = 10_000

function BlogStatusCell({
  status,
  onGenerate,
  disabled,
}: {
  status: TopicBlogStatus | undefined
  onGenerate: () => void
  disabled?: boolean
}) {
  if (!status) {
    return <span className="text-xs text-gray-400 dark:text-gray-500">—</span>
  }

  const missing = BLOG_LOCALES.filter((l) => !status[l]?.slug)
  const generating = BLOG_LOCALES.some((l) => status[l]?.generating)

  return (
    <div className="flex flex-wrap items-center gap-1">
      {BLOG_LOCALES.map((locale) => {
        const s = status[locale]
        const base =
          'inline-flex items-center rounded px-1.5 py-0.5 text-[11px] font-semibold uppercase leading-4'
        if (s?.slug) {
          return (
            <span
              key={locale}
              title={`Blog exists: ${s.slug}`}
              className={`${base} bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300`}
            >
              ✓ {locale}
            </span>
          )
        }
        if (s?.generating) {
          return (
            <span
              key={locale}
              title="Writing this blog now"
              className={`${base} animate-pulse bg-primary-100 text-primary-800 dark:bg-primary-900/30 dark:text-primary-300`}
            >
              {locale}
            </span>
          )
        }
        return (
          <span
            key={locale}
            title={s?.error ? `Last attempt failed: ${s.error}` : 'No blog yet'}
            className={
              s?.error
                ? `${base} bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-300`
                : `${base} bg-gray-100 text-gray-500 dark:bg-gray-700 dark:text-gray-400`
            }
          >
            {locale}
          </span>
        )
      })}
      {generating ? (
        <span className="text-xs text-primary-700 dark:text-primary-300">Writing…</span>
      ) : missing.length > 0 ? (
        <button
          type="button"
          onClick={onGenerate}
          disabled={disabled}
          title={`Generate the missing blogs (${missing.join(', ').toUpperCase()})`}
          className="rounded-md bg-primary px-2 py-1 text-xs font-medium text-white hover:bg-primary-600 disabled:cursor-not-allowed disabled:opacity-50"
        >
          Generate
        </button>
      ) : null}
    </div>
  )
}

function SortableRow({
  topic,
  index,
  blogStatus,
  onToggleMilestone,
  onEdit,
  onGenerateContent,
  onGenerateBlogs,
  disabled,
}: {
  topic: PathTopic
  index: number
  blogStatus: TopicBlogStatus | undefined
  onToggleMilestone: (topicId: string) => void
  onEdit: (topicId: string) => void
  onGenerateContent: (topicId: string) => void
  onGenerateBlogs: (topicId: string) => void
  disabled?: boolean
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: topic.id })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  }

  return (
    <tr
      ref={setNodeRef}
      style={style}
      className="border-b border-gray-200 bg-white align-top hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-800 dark:hover:bg-gray-700"
    >
      {/* Drag handle */}
      <td className="w-8 py-3 pl-2 pr-0 text-center sm:px-3">
        {!disabled && (
          <button
            type="button"
            className={actionButtonStyles.dragHandle}
            aria-label="Drag to reorder"
            {...attributes}
            {...listeners}
          >
            <DragHandleIcon />
          </button>
        )}
      </td>

      {/* Lesson: number, title, and on small screens the details the hidden columns carry */}
      <td className="py-3 pl-1 pr-2 sm:px-3">
        <div className="flex items-start gap-2">
          <span className="mt-0.5 inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-primary-100 text-xs font-semibold text-primary-800 dark:bg-primary-900/30 dark:text-primary-300">
            {index + 1}
          </span>
          <div className="min-w-0">
            <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
              {topic.title}
              {topic.is_milestone && (
                <span className="ml-1 text-xs text-yellow-600 dark:text-yellow-400" title="Milestone">
                  ★
                </span>
              )}
            </p>
            <p className="mt-0.5 text-xs text-gray-500 md:hidden dark:text-gray-400">
              {topic.category} · {topic.xp_value} XP
            </p>
            <div className="mt-2 lg:hidden">
              <BlogStatusCell
                status={blogStatus}
                onGenerate={() => onGenerateBlogs(topic.id)}
                disabled={disabled}
              />
            </div>
          </div>
        </div>
      </td>

      {/* Category */}
      <td className="hidden px-3 py-3 md:table-cell">
        <span className="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-800 dark:bg-blue-900/30 dark:text-blue-300">
          {topic.category}
        </span>
      </td>

      {/* XP */}
      <td className="hidden px-3 py-3 text-center md:table-cell">
        <span className="inline-flex items-center whitespace-nowrap rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-300">
          {topic.xp_value} XP
        </span>
      </td>

      {/* Blogs */}
      <td className="hidden px-3 py-3 lg:table-cell">
        <BlogStatusCell
          status={blogStatus}
          onGenerate={() => onGenerateBlogs(topic.id)}
          disabled={disabled}
        />
      </td>

      {/* Milestone */}
      <td className="hidden px-3 py-3 text-center sm:table-cell">
        <input
          type="checkbox"
          checked={topic.is_milestone}
          onChange={() => onToggleMilestone(topic.id)}
          disabled={disabled}
          className="h-4 w-4 rounded border-gray-300 text-yellow-600 focus:ring-yellow-500 disabled:cursor-not-allowed disabled:opacity-50 dark:border-gray-600 dark:bg-gray-700"
          title={topic.is_milestone ? 'Remove milestone' : 'Mark as milestone'}
        />
      </td>

      {/* Actions */}
      <td className="py-3 pl-0 pr-2 sm:px-3">
        <div className="flex items-center justify-end gap-1 sm:justify-start sm:gap-2">
          <button
            type="button"
            onClick={() => onEdit(topic.id)}
            disabled={disabled}
            className={actionButtonStyles.edit}
            title="Edit"
          >
            <EditIcon />
          </button>
          <button
            type="button"
            onClick={() => onGenerateContent(topic.id)}
            disabled={disabled}
            className={actionButtonStyles.generate}
            title="Generate study guide"
          >
            <GenerateIcon />
          </button>
        </div>
      </td>
    </tr>
  )
}

export function PathTopicOrganizer({ pathId }: PathTopicOrganizerProps) {
  const router = useRouter()
  const [pathTopics, setPathTopics] = useState<PathTopic[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [blogStatus, setBlogStatus] = useState<Record<string, TopicBlogStatus>>({})

  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  )

  const loadBlogStatus = useCallback(async () => {
    try {
      const res = await fetch(`/api/admin/learning-paths/${pathId}/blog-status`, {
        cache: 'no-store',
      })
      if (!res.ok) return
      const body = await res.json()
      const next: Record<string, TopicBlogStatus> = {}
      for (const t of body?.data?.topics ?? []) {
        next[t.topic_id] = t.locales
      }
      setBlogStatus(next)
    } catch {
      // Blog status is supplementary; the lesson list still works without it.
    }
  }, [pathId])

  // Load topics
  useEffect(() => {
    loadTopics()
    loadBlogStatus()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pathId])

  // Refresh while any lesson's blogs are being written.
  const anyGenerating = Object.values(blogStatus).some((s) =>
    BLOG_LOCALES.some((l) => s[l]?.generating)
  )
  useEffect(() => {
    if (!anyGenerating) return
    const timer = setInterval(loadBlogStatus, BLOG_POLL_MS)
    return () => clearInterval(timer)
  }, [anyGenerating, loadBlogStatus])

  const loadTopics = async () => {
    setIsLoading(true)
    setError(null)
    try {
      // Fetch path topics
      const response = await fetch(`/api/admin/learning-paths/${pathId}`)
      if (!response.ok) {
        const errorText = await response.text()
        throw new Error(`Failed to load path topics (${response.status}): ${errorText}`)
      }
      const pathData = await response.json()

      if (!pathData || !pathData.learning_path) {
        console.error('Invalid path data:', pathData)
        throw new Error('Invalid path data structure')
      }

      const pathTopicsList: PathTopic[] = pathData.learning_path.topics || []

      // Sort by position
      pathTopicsList.sort((a, b) => a.position - b.position)

      setPathTopics(pathTopicsList)
    } catch (err) {
      console.error('Failed to load topics:', err)
      const errorMessage = err instanceof Error ? err.message : 'Unknown error'
      setError(`Failed to load topics: ${errorMessage}. Please try again.`)
    } finally {
      setIsLoading(false)
    }
  }

  const handleDragEnd = async (event: DragEndEvent) => {
    const { active, over } = event

    if (over && active.id !== over.id) {
      const oldIndex = pathTopics.findIndex((topic) => topic.id === active.id)
      const newIndex = pathTopics.findIndex((topic) => topic.id === over.id)

      const reorderedTopics = arrayMove(pathTopics, oldIndex, newIndex).map(
        (topic, index) => ({
          ...topic,
          position: index + 1,
        })
      )

      // Optimistic update
      setPathTopics(reorderedTopics)

      // Save to backend
      setIsSaving(true)
      try {
        const reorderData = reorderedTopics.map((topic) => ({
          topic_id: topic.id,
          position: topic.position,
        }))

        await reorderPathTopics({
          learning_path_id: pathId,
          topic_orders: reorderData,
        })
      } catch (err) {
        console.error('Failed to reorder topics:', err)
        setError('Failed to save new order. Please try again.')
        // Reload to reset
        await loadTopics()
      } finally {
        setIsSaving(false)
      }
    }
  }

  const handleToggleMilestone = async (topicId: string) => {
    const topic = pathTopics.find((t) => t.id === topicId)
    if (!topic) return

    setIsSaving(true)
    setError(null)
    try {
      await toggleTopicMilestone(pathId, topicId, {
        is_milestone: !topic.is_milestone,
      })

      // Update local state
      setPathTopics(
        pathTopics.map((t) =>
          t.id === topicId ? { ...t, is_milestone: !t.is_milestone } : t
        )
      )
    } catch (err) {
      console.error('Failed to toggle milestone:', err)
      setError('Failed to update milestone. Please try again.')
    } finally {
      setIsSaving(false)
    }
  }

  const handleEdit = (topicId: string) => {
    // Navigate to dedicated edit page with path parameter for smart back navigation
    router.push(`/topics/${topicId}/edit?path=${pathId}`)
  }

  const handleGenerateContent = (topicId: string) => {
    router.push(`/study-generator?topic=${topicId}&path=${pathId}`)
  }

  const handleGenerateBlogs = async (topicId: string) => {
    try {
      const res = await fetch(
        `/api/admin/learning-paths/${pathId}/topics/${topicId}/generate-blog`,
        { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' }
      )
      const body = await res.json().catch(() => ({}))
      if (!res.ok) {
        toast.error(body.error || 'Could not start blog generation')
        return
      }
      const started: string[] = body?.data?.started ?? []
      if (started.length > 0) {
        toast.success(
          `Writing ${started.map((l) => l.toUpperCase()).join(', ')} blog${started.length > 1 ? 's' : ''}. This can take a few minutes.`
        )
      } else {
        toast.info('These blogs already exist or are being written.')
      }
      await loadBlogStatus()
    } catch {
      toast.error('Could not start blog generation')
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="text-center">
          <div className="mx-auto h-12 w-12 animate-spin rounded-full border-4 border-primary border-t-transparent"></div>
          <p className="mt-4 text-sm text-gray-600 dark:text-gray-400">Loading topics...</p>
        </div>
      </div>
    )
  }

  const lessonsMissingBlogs = pathTopics.filter((t) => {
    const s = blogStatus[t.id]
    return s && BLOG_LOCALES.some((l) => !s[l]?.slug)
  }).length

  return (
    <div className="space-y-4">
      {/* Error Message */}
      {error && (
        <div className="rounded-lg bg-red-50 p-3 dark:bg-red-900/20">
          <p className="text-sm text-red-800 dark:text-red-300">{error}</p>
          <button
            type="button"
            onClick={loadTopics}
            className="mt-2 text-sm font-medium text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300"
          >
            Try again
          </button>
        </div>
      )}

      {/* Header with Add Button */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h3 className="text-base font-semibold text-gray-900 sm:text-lg dark:text-gray-100">
            Path Topics ({pathTopics.length})
          </h3>
          <p className="mt-0.5 text-xs text-gray-600 sm:text-sm dark:text-gray-400">
            Drag to reorder. {lessonsMissingBlogs > 0
              ? `${lessonsMissingBlogs} lesson${lessonsMissingBlogs > 1 ? 's' : ''} missing blogs.`
              : 'Every lesson has its blogs.'}
          </p>
        </div>
        <button
          type="button"
          onClick={() => router.push(`/learning-paths/${pathId}/add-topic`)}
          disabled={isSaving}
          className="flex items-center justify-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:cursor-not-allowed disabled:opacity-50"
        >
          <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          Add New Study Guide
        </button>
      </div>

      {/* Topics Table */}
      {pathTopics.length === 0 ? (
        <div className="rounded-lg border border-gray-200 bg-white p-5 sm:p-8 text-center dark:border-gray-700 dark:bg-gray-800">
          <h3 className="text-base font-medium text-gray-900 dark:text-gray-100">
            No topics in this path
          </h3>
          <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
            Get started by adding a new study guide to this learning path.
          </p>
          <button
            type="button"
            onClick={() => router.push(`/learning-paths/${pathId}/add-topic`)}
            className="mt-4 inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600"
          >
            Add New Study Guide
          </button>
        </div>
      ) : (
        // DndContext renders an accessibility announcer <div>, which is invalid
        // inside <tbody> and broke hydration, so it wraps the whole table.
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragEnd={handleDragEnd}
        >
        <div className="overflow-hidden rounded-lg border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-800">
          <table className="w-full table-auto divide-y divide-gray-200 dark:divide-gray-700">
            <thead className="bg-gray-50 dark:bg-gray-800">
              <tr className="text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                <th className="w-8 py-2 pl-2 pr-0 sm:px-3" aria-label="Reorder" />
                <th className="py-2 pl-1 pr-2 text-left sm:px-3">Lesson</th>
                <th className="hidden px-3 py-2 text-left md:table-cell">Category</th>
                <th className="hidden px-3 py-2 text-center md:table-cell">XP</th>
                <th className="hidden px-3 py-2 text-left lg:table-cell">Blogs</th>
                <th className="hidden px-3 py-2 text-center sm:table-cell">Milestone</th>
                <th className="py-2 pl-0 pr-2 text-right sm:px-3 sm:text-left">
                  <span className="sr-only sm:not-sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody>
                <SortableContext
                  items={pathTopics.map((topic) => topic.id)}
                  strategy={verticalListSortingStrategy}
                >
                  {pathTopics.map((topic, index) => (
                    <SortableRow
                      key={topic.id}
                      topic={topic}
                      index={index}
                      blogStatus={blogStatus[topic.id]}
                      onToggleMilestone={handleToggleMilestone}
                      onEdit={handleEdit}
                      onGenerateContent={handleGenerateContent}
                      onGenerateBlogs={handleGenerateBlogs}
                      disabled={isSaving}
                    />
                  ))}
                </SortableContext>
            </tbody>
          </table>
        </div>
        </DndContext>
      )}

      {/* Saving Indicator */}
      {isSaving && (
        <div className="fixed bottom-4 right-4 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white shadow-lg">
          Saving changes...
        </div>
      )}
    </div>
  )
}

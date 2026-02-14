'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
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
import { listTopics, reorderPathTopics, toggleTopicMilestone } from '@/lib/api/admin'
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

function SortableRow({
  topic,
  index,
  onToggleMilestone,
  onEdit,
  onGenerateContent,
  disabled,
}: {
  topic: PathTopic
  index: number
  onToggleMilestone: (topicId: string) => void
  onEdit: (topicId: string) => void
  onGenerateContent: (topicId: string) => void
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
      className="border-b border-gray-200 bg-white hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-800 dark:hover:bg-gray-700"
    >
      {/* Drag Handle */}
      <td className="px-4 py-3 text-center">
        {!disabled && (
          <button
            type="button"
            className={actionButtonStyles.dragHandle}
            {...attributes}
            {...listeners}
          >
            <DragHandleIcon />
          </button>
        )}
      </td>

      {/* Position */}
      <td className="px-4 py-3 text-center">
        <span className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-primary-100 text-sm font-semibold text-primary-800 dark:bg-primary-900/30 dark:text-primary-300">
          {index + 1}
        </span>
      </td>

      {/* Title */}
      <td className="px-4 py-3">
        <p className="font-medium text-gray-900 dark:text-gray-100">{topic.title}</p>
      </td>

      {/* Category */}
      <td className="px-4 py-3">
        <span className="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-800 dark:bg-blue-900/30 dark:text-blue-300">
          {topic.category}
        </span>
      </td>

      {/* XP */}
      <td className="px-4 py-3 text-center">
        <span className="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-300">
          {topic.xp_value} XP
        </span>
      </td>

      {/* Milestone */}
      <td className="px-4 py-3 text-center">
        <input
          type="checkbox"
          checked={topic.is_milestone}
          onChange={() => onToggleMilestone(topic.id)}
          disabled={disabled}
          className="h-4 w-4 rounded border-gray-300 text-yellow-600 focus:ring-yellow-500 disabled:cursor-not-allowed disabled:opacity-50 dark:border-gray-600 dark:bg-gray-700"
          title={topic.is_milestone ? 'Remove milestone' : 'Mark as milestone'}
        />
        {topic.is_milestone && (
          <span className="ml-1 text-xs text-yellow-600 dark:text-yellow-400">★</span>
        )}
      </td>

      {/* Actions */}
      <td className="px-4 py-3">
        <div className="flex items-center gap-2">
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
            title="Generate Content"
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

  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  )

  // Load topics
  useEffect(() => {
    loadTopics()
  }, [pathId])

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

  return (
    <div className="space-y-6">
      {/* Error Message */}
      {error && (
        <div className="rounded-lg bg-red-50 p-4 dark:bg-red-900/20">
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
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
            Path Topics ({pathTopics.length})
          </h3>
          <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
            Drag to reorder topics and mark milestones
          </p>
        </div>
        <button
          type="button"
          onClick={() => router.push(`/learning-paths/${pathId}/add-topic`)}
          disabled={isSaving}
          className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-50"
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
          Add New Study Guide
        </button>
      </div>

      {/* Topics Table */}
      {pathTopics.length === 0 ? (
        <div className="rounded-lg border border-gray-200 bg-white p-12 text-center dark:border-gray-700 dark:bg-gray-800">
          <svg
            className="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500"
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
          <h3 className="mt-4 text-lg font-medium text-gray-900 dark:text-gray-100">
            No topics in this path
          </h3>
          <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">
            Get started by adding a new study guide to this learning path.
          </p>
          <button
            type="button"
            onClick={() => router.push(`/learning-paths/${pathId}/add-topic`)}
            className="mt-4 inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-dark"
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
            Add New Study Guide
          </button>
        </div>
      ) : (
        <div className="overflow-hidden rounded-lg border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-800">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead className="bg-gray-50 dark:bg-gray-800">
                <tr>
                  <th className="w-12 px-4 py-3 text-center text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    {/* Drag handle column */}
                  </th>
                  <th className="w-16 px-4 py-3 text-center text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    #
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Title
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Category
                  </th>
                  <th className="w-24 px-4 py-3 text-center text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    XP
                  </th>
                  <th className="w-24 px-4 py-3 text-center text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Milestone
                  </th>
                  <th className="w-40 px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody>
                <DndContext
                  sensors={sensors}
                  collisionDetection={closestCenter}
                  onDragEnd={handleDragEnd}
                >
                  <SortableContext
                    items={pathTopics.map((topic) => topic.id)}
                    strategy={verticalListSortingStrategy}
                  >
                    {pathTopics.map((topic, index) => (
                      <SortableRow
                        key={topic.id}
                        topic={topic}
                        index={index}
                        onToggleMilestone={handleToggleMilestone}
                        onEdit={handleEdit}
                        onGenerateContent={handleGenerateContent}
                        disabled={isSaving}
                      />
                    ))}
                  </SortableContext>
                </DndContext>
              </tbody>
            </table>
          </div>

          {/* Hint */}
          {pathTopics.length > 1 && (
            <div className="border-t border-gray-200 bg-gray-50 px-4 py-3 dark:border-gray-700 dark:bg-gray-800">
              <p className="text-xs text-gray-500 dark:text-gray-400">
                💡 <strong>Tip:</strong> Drag rows to reorder topics. Check the
                Milestone box to mark important progress checkpoints.
              </p>
            </div>
          )}
        </div>
      )}

      {/* Summary */}
      {pathTopics.length > 0 && (
        <div className="rounded-lg border border-gray-200 bg-blue-50 p-4 dark:border-blue-900/30 dark:bg-blue-900/20">
          <div className="flex items-start gap-3">
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
              <p className="text-sm font-medium text-blue-900 dark:text-blue-200">Path Summary</p>
              <ul className="mt-2 space-y-1 text-sm text-blue-800 dark:text-blue-300">
                <li>• {pathTopics.length} topics in this path</li>
                <li>
                  • {pathTopics.filter((t) => t.is_milestone).length} milestone
                  checkpoints
                </li>
                <li>
                  • Total XP:{' '}
                  {pathTopics.reduce((sum, t) => sum + t.xp_value, 0)}
                </li>
              </ul>
            </div>
          </div>
        </div>
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

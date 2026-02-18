'use client'

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
import type { LearningPath } from '@/types/admin'
import { EditIcon, DeleteIcon, ManageIcon, DragHandleIcon, actionButtonStyles } from '@/components/ui/action-icons'

// Map icon names to emojis
const iconMap: Record<string, string> = {
  auto_stories: '📖',
  trending_up: '📈',
  volunteer_activism: '🤝',
  shield: '🛡️',
  family_restroom: '👨‍👩‍👧‍👦',
  psychology: '🧠',
  spa: '🕊️',
  favorite: '❤️',
  lightbulb: '💡',
  school: '🎓',
}

interface LearningPathsTableProps {
  paths: LearningPath[]
  onEdit: (path: LearningPath) => void
  onDelete: (pathId: string) => void
  onToggle: (pathId: string, isActive: boolean) => void
  onReorder: (paths: LearningPath[]) => void
  disabled?: boolean
}

function SortableRow({
  path,
  onEdit,
  onDelete,
  onToggle,
  router,
  disabled,
}: {
  path: LearningPath
  onEdit: (path: LearningPath) => void
  onDelete: (pathId: string) => void
  onToggle: (pathId: string, isActive: boolean) => void
  router: any
  disabled?: boolean
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: path.id })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  }

  return (
    <>
      <tr
        ref={setNodeRef}
        style={style}
        className="border-b border-gray-200 bg-white hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-800 dark:hover:bg-gray-700"
      >
      {/* Drag Handle */}
      <td className="px-4 py-3">
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

      {/* Icon & Color */}
      <td className="px-4 py-3">
        <div
          className="flex h-10 w-10 items-center justify-center rounded-lg text-2xl"
          style={{ backgroundColor: `${path.color}20` }}
        >
          {iconMap[path.icon_name] || '📚'}
        </div>
      </td>

      {/* Title */}
      <td className="px-4 py-3">
        <div>
          <p className="font-medium text-gray-900 dark:text-gray-100">{path.title}</p>
          <p className="text-sm text-gray-500 dark:text-gray-400">{path.slug}</p>
        </div>
      </td>

      {/* Topics Count */}
      <td className="px-4 py-3 text-center">
        <span className="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-800 dark:bg-blue-900/30 dark:text-blue-300">
          {path.topics_count || 0}
        </span>
      </td>

      {/* Enrolled Users */}
      <td className="px-4 py-3 text-center">
        <span className="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-300">
          {path.enrolled_count || 0}
        </span>
      </td>

      {/* Total XP */}
      <td className="px-4 py-3 text-center">
        <span className="text-sm font-medium text-gray-900 dark:text-gray-100">
          {path.total_xp}
        </span>
      </td>

      {/* Disciple Level */}
      <td className="px-4 py-3">
        <span
          className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
            path.disciple_level === 'seeker'
              ? 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300'
              : path.disciple_level === 'follower'
                ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300'
                : path.disciple_level === 'disciple'
                  ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300'
                  : 'bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-300'
          }`}
        >
          {path.disciple_level}
        </span>
      </td>

      {/* Status Toggle */}
      <td className="px-4 py-3">
        <button
          type="button"
          onClick={() => onToggle(path.id, !path.is_active)}
          disabled={disabled}
          className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
            path.is_active ? 'bg-primary' : 'bg-gray-300'
          } ${disabled ? 'cursor-not-allowed opacity-50' : ''}`}
        >
          <span
            className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
              path.is_active ? 'translate-x-6' : 'translate-x-1'
            }`}
          />
        </button>
      </td>

      {/* Actions */}
      <td className="px-4 py-3">
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => router.push(`/learning-paths/${path.id}`)}
            disabled={disabled}
            className={actionButtonStyles.manage}
            title="Manage Topics"
          >
            <ManageIcon />
          </button>
          <button
            type="button"
            onClick={() => onEdit(path)}
            disabled={disabled}
            className={actionButtonStyles.edit}
            title="Edit"
          >
            <EditIcon />
          </button>
          <button
            type="button"
            onClick={() => onDelete(path.id)}
            disabled={disabled}
            className={actionButtonStyles.delete}
            title="Delete"
          >
            <DeleteIcon />
          </button>
        </div>
      </td>
    </tr>
    </>
  )
}

export function LearningPathsTable({
  paths,
  onEdit,
  onDelete,
  onToggle,
  onReorder,
  disabled = false,
}: LearningPathsTableProps) {
  const router = useRouter()

  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  )

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event

    if (over && active.id !== over.id) {
      const oldIndex = paths.findIndex((path) => path.id === active.id)
      const newIndex = paths.findIndex((path) => path.id === over.id)

      const reorderedPaths = arrayMove(paths, oldIndex, newIndex).map(
        (path, index) => ({
          ...path,
          display_order: index + 1,
        })
      )

      onReorder(reorderedPaths)
    }
  }

  if (paths.length === 0) {
    return (
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
          No learning paths
        </h3>
        <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">
          Get started by creating a new learning path.
        </p>
      </div>
    )
  }

  return (
    <div className="overflow-hidden rounded-lg border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-800">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
          <thead className="bg-gray-50 dark:bg-gray-800">
            <tr>
              <th className="w-12 px-4 py-3 text-left">
                {/* Drag handle column */}
              </th>
              <th className="w-16 px-4 py-3 text-left">
                {/* Icon column */}
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Title
              </th>
              <th className="px-4 py-3 text-center text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Topics
              </th>
              <th className="px-4 py-3 text-center text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Enrolled
              </th>
              <th className="px-4 py-3 text-center text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Total XP
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Disciple Level
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                Status
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
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
                items={paths.map((path) => path.id)}
                strategy={verticalListSortingStrategy}
              >
                {paths.map((path) => (
                  <SortableRow
                    key={path.id}
                    path={path}
                    onEdit={onEdit}
                    onDelete={onDelete}
                    onToggle={onToggle}
                    router={router}
                    disabled={disabled}
                  />
                ))}
              </SortableContext>
            </DndContext>
          </tbody>
        </table>
      </div>

      {/* Hint */}
      {!disabled && paths.length > 1 && (
        <div className="border-t border-gray-200 bg-gray-50 px-4 py-3 dark:border-gray-700 dark:bg-gray-800">
          <p className="text-xs text-gray-500 dark:text-gray-400">
            💡 <strong>Tip:</strong> Drag rows to reorder learning paths. The
            order determines how they appear to users.
          </p>
        </div>
      )}
    </div>
  )
}

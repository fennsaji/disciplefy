/**
 * Standardized Action Icons for Admin Tables
 *
 * These icons maintain consistent styling across all admin tables.
 * Usage: Import and use as components for action buttons.
 */

interface ActionIconProps {
  disabled?: boolean
  className?: string
}

/**
 * Edit Icon - Purple/Primary color
 * Use for: Editing any resource (topics, paths, etc.)
 */
export function EditIcon({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <svg
      className={className}
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
  )
}

/**
 * Delete Icon - Red color
 * Use for: Deleting/removing any resource
 */
export function DeleteIcon({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <svg
      className={className}
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
  )
}

/**
 * Manage/View Icon - Blue color
 * Use for: Managing topics, viewing details, accessing sub-resources
 */
export function ManageIcon({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"
      />
    </svg>
  )
}

/**
 * Generate Icon - Green color
 * Use for: Generating content, creating study guides, AI operations
 */
export function GenerateIcon({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M13 10V3L4 14h7v7l9-11h-7z"
      />
    </svg>
  )
}

/**
 * View Icon - Indigo color
 * Use for: Viewing generated content, viewing study guides
 */
export function ViewIcon({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <svg
      className={className}
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
  )
}

/**
 * Drag Handle Icon - Gray color
 * Use for: Drag-and-drop reordering
 */
export function DragHandleIcon({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M4 6h16M4 12h16M4 18h16"
      />
    </svg>
  )
}

/**
 * Toggle/Power Icon - Color varies by state
 * Use for: Activating/deactivating resources (promo codes, features, etc.)
 */
export function ToggleIcon({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M13 10V3L4 14h7v7l9-11h-7z"
      />
    </svg>
  )
}

/**
 * Standard Action Button Styles
 * Use these className strings for consistent button styling
 */
export const actionButtonStyles = {
  edit: "text-primary hover:text-primary-dark disabled:cursor-not-allowed disabled:opacity-50",
  delete: "text-red-600 hover:text-red-800 disabled:cursor-not-allowed disabled:opacity-50",
  manage: "text-blue-600 hover:text-blue-800 disabled:cursor-not-allowed disabled:opacity-50",
  generate: "text-green-600 hover:text-green-800 disabled:cursor-not-allowed disabled:opacity-50",
  view: "text-indigo-600 hover:text-indigo-800 disabled:cursor-not-allowed disabled:opacity-50",
  dragHandle: "cursor-grab text-gray-400 hover:text-gray-600 active:cursor-grabbing",
  toggleActive: "text-green-600 hover:text-green-800 disabled:cursor-not-allowed disabled:opacity-50",
  toggleInactive: "text-orange-600 hover:text-orange-800 disabled:cursor-not-allowed disabled:opacity-50",
} as const

/**
 * Example Usage:
 *
 * import { EditIcon, DeleteIcon, actionButtonStyles } from '@/components/ui/action-icons'
 *
 * <button
 *   onClick={() => onEdit(item)}
 *   className={actionButtonStyles.edit}
 *   title="Edit"
 * >
 *   <EditIcon />
 * </button>
 */

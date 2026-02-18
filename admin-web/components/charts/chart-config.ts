/**
 * Shared Recharts configuration helpers.
 * Provides theme-aware tooltip and axis styles.
 */

export const CHART_COLORS = [
  '#6A4FB6', // primary
  '#3B82F6', // blue
  '#10B981', // green
  '#F59E0B', // amber
  '#EF4444', // red
  '#EC4899', // pink
  '#6366F1', // indigo
]

export function getTooltipStyle(isDark: boolean) {
  return {
    backgroundColor: isDark ? '#1F2937' : '#FFFFFF',
    border: `1px solid ${isDark ? '#374151' : '#E5E7EB'}`,
    borderRadius: '8px',
    color: isDark ? '#F9FAFB' : '#111827',
    boxShadow: '0 4px 6px -1px rgba(0,0,0,0.1)',
  }
}

export function getAxisStroke(isDark: boolean) {
  return isDark ? '#6B7280' : '#9CA3AF'
}

export function getGridStroke(isDark: boolean) {
  return isDark ? '#374151' : '#E5E7EB'
}

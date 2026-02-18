import { format, subDays, startOfDay, endOfDay } from 'date-fns'

export type DateRangePreset = 'today' | '7days' | '30days' | 'custom'

export interface DateRange {
  from: Date
  to: Date
}

export function getDateRangePreset(preset: DateRangePreset): DateRange {
  const now = new Date()

  switch (preset) {
    case 'today':
      return {
        from: startOfDay(now),
        to: endOfDay(now),
      }
    case '7days':
      return {
        from: startOfDay(subDays(now, 7)),
        to: endOfDay(now),
      }
    case '30days':
      return {
        from: startOfDay(subDays(now, 30)),
        to: endOfDay(now),
      }
    default:
      return {
        from: startOfDay(subDays(now, 7)),
        to: endOfDay(now),
      }
  }
}

export function formatDateForAPI(date: Date): string {
  return format(date, 'yyyy-MM-dd')
}

export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 4,
  }).format(amount)
}

export function formatNumber(num: number): string {
  return new Intl.NumberFormat('en-US').format(num)
}

export function formatCompactNumber(num: number): string {
  return new Intl.NumberFormat('en-US', {
    notation: 'compact',
    maximumFractionDigits: 1,
  }).format(num)
}

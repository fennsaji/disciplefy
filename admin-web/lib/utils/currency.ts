/**
 * One currency for the dashboard: US dollars.
 *
 * The app charges in rupees through Razorpay and pays Anthropic in dollars, so
 * figures used to arrive in whichever currency their source happened to use.
 * Reading a page that mixed the two meant converting in your head before you
 * could compare anything, which is how a cost gets misread.
 *
 * Everything shown to an admin is therefore in dollars. Amounts that are
 * genuinely rupees — plan prices, Razorpay payments, token purchases — are
 * converted here, and anywhere the exact charged amount matters the rupee
 * figure is shown beside it rather than instead of it.
 */

/**
 * Fallback rate, matching USD_TO_INR_RATE in the backend's cost-tracking
 * service so both sides of the system agree. Pages that have a live rate should
 * pass it in.
 */
export const USD_TO_INR_FALLBACK = 83.5

/** Dollars for an amount held in rupees. */
export function inrToUsd(amountInr: number | null | undefined, rate: number = USD_TO_INR_FALLBACK): number {
  const amount = Number(amountInr ?? 0)
  if (!Number.isFinite(amount) || rate <= 0) return 0
  return amount / rate
}

/**
 * An amount in dollars, written the way money should be read.
 *
 * Small figures keep more decimals: a per-call model cost of $0.0004 is
 * meaningless rounded to two places, while a monthly total is noise beyond
 * them.
 */
export function formatUsd(amountUsd: number | null | undefined): string {
  const amount = Number(amountUsd ?? 0)
  if (!Number.isFinite(amount)) return '$0.00'

  const magnitude = Math.abs(amount)
  const decimals = magnitude === 0 ? 2 : magnitude < 0.01 ? 4 : 2

  return `$${amount.toLocaleString('en-US', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  })}`
}

/** A rupee amount, shown in dollars. */
export function formatInrAsUsd(
  amountInr: number | null | undefined,
  rate: number = USD_TO_INR_FALLBACK,
): string {
  return formatUsd(inrToUsd(amountInr, rate))
}

/**
 * The rupee figure, for the few places where the exact charged amount matters:
 * a Razorpay receipt, a plan's listed price. Always shown alongside dollars,
 * never on its own.
 */
export function formatInrDetail(amountInr: number | null | undefined): string {
  const amount = Number(amountInr ?? 0)
  return `₹${amount.toLocaleString('en-IN', { maximumFractionDigits: 2 })} charged`
}

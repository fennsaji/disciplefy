/**
 * Compares what we think we spent against what Anthropic actually billed.
 *
 * Every cost figure in this app is our own arithmetic: token counts from the
 * API response multiplied by a price table we maintain by hand. That is fine
 * until a price changes, a model appears that the table does not know, or the
 * cache accounting drifts — all of which have already happened once. Nothing in
 * the app would notice, because the same wrong number feeds the budgets, the
 * ceiling and the admin dashboard.
 *
 * Anthropic's Cost Admin API reports the real figure. Pulling it daily and
 * comparing turns a silent error into a visible one.
 *
 * Two things are needed, neither of which the app has by default:
 *
 *   ANTHROPIC_ADMIN_KEY    an Admin API key (sk-ant-admin...), which a
 *                          workspace-scoped key cannot substitute for
 *   ANTHROPIC_WORKSPACE_ID the workspace Disciplefy runs in
 *
 * The workspace matters: the cost report covers the whole organisation, and an
 * account with several projects would otherwise reconcile Disciplefy against
 * everything else's bill too. Without both set, reconciliation reports that it
 * is unconfigured and does nothing.
 */

const COST_REPORT_URL = 'https://api.anthropic.com/v1/organizations/cost_report'
const API_VERSION = '2023-06-01'

/** Anthropic reports money as decimal strings in cents. */
const CENTS_PER_DOLLAR = 100

export interface ReconciliationResult {
  readonly configured: boolean
  readonly day: string
  readonly ourUsd: number
  readonly anthropicUsd: number
  readonly gapUsd: number
  /** Positive when Anthropic billed more than we recorded. */
  readonly gapPercent: number
  readonly reason?: string
}

/** Midnight UTC on [day] and on the day after, as the API wants them. */
function dayBounds(day: string): { startingAt: string; endingAt: string } {
  const start = new Date(`${day}T00:00:00Z`)
  const end = new Date(start)
  end.setUTCDate(end.getUTCDate() + 1)
  return { startingAt: start.toISOString(), endingAt: end.toISOString() }
}

/**
 * Dollars Anthropic billed for [day], for our workspace only.
 *
 * The report is grouped by workspace so an organisation running several
 * projects can be told apart. Anything outside our workspace is ignored.
 */
export async function anthropicSpendForDay(
  day: string,
  adminKey: string,
  workspaceId: string,
): Promise<number> {
  const { startingAt, endingAt } = dayBounds(day)
  const url = new URL(COST_REPORT_URL)
  url.searchParams.set('starting_at', startingAt)
  url.searchParams.set('ending_at', endingAt)
  url.searchParams.append('group_by[]', 'workspace_id')

  let page: string | undefined
  let cents = 0

  do {
    if (page) url.searchParams.set('page', page)

    const response = await fetch(url, {
      headers: {
        'x-api-key': adminKey,
        'anthropic-version': API_VERSION,
        'user-agent': 'Disciplefy/1.0 (https://www.disciplefy.in)',
      },
    })

    if (!response.ok) {
      throw new Error(`Cost report failed (${response.status}): ${await response.text()}`)
    }

    const body = await response.json()

    for (const bucket of body.data ?? []) {
      for (const item of bucket.results ?? []) {
        if (item.workspace_id !== workspaceId) continue
        cents += Number(item.amount ?? 0)
      }
    }

    page = body.has_more ? body.next_page : undefined
  } while (page)

  return cents / CENTS_PER_DOLLAR
}

/**
 * Our own recorded spend for [day], from usage_logs.
 *
 * This is the number the budgets and the admin dashboard read, so it is the one
 * worth checking.
 */
export async function ourSpendForDay(
  // deno-lint-ignore no-explicit-any -- the generated database types are not wired into functions
  db: any,
  day: string,
): Promise<number> {
  const { startingAt, endingAt } = dayBounds(day)

  const { data, error } = await db
    .from('usage_logs')
    .select('llm_cost_usd')
    .gte('created_at', startingAt)
    .lt('created_at', endingAt)
    .not('llm_cost_usd', 'is', null)

  if (error) throw new Error(`Could not read our own spend: ${error.message}`)

  return (data ?? []).reduce(
    (total: number, row: { llm_cost_usd: number | string | null }) => total + Number(row.llm_cost_usd ?? 0),
    0,
  )
}

/** Yesterday in UTC — the most recent day whose billing has settled. */
export function yesterdayUtc(now: Date = new Date()): string {
  const day = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()))
  day.setUTCDate(day.getUTCDate() - 1)
  return day.toISOString().slice(0, 10)
}

export async function reconcileDay(
  // deno-lint-ignore no-explicit-any -- see ourSpendForDay
  db: any,
  day: string,
): Promise<ReconciliationResult> {
  const adminKey = Deno.env.get('ANTHROPIC_ADMIN_KEY')
  const workspaceId = Deno.env.get('ANTHROPIC_WORKSPACE_ID')

  const ourUsd = await ourSpendForDay(db, day)

  if (!adminKey || !workspaceId) {
    return {
      configured: false,
      day,
      ourUsd,
      anthropicUsd: 0,
      gapUsd: 0,
      gapPercent: 0,
      reason: 'ANTHROPIC_ADMIN_KEY and ANTHROPIC_WORKSPACE_ID are not both set',
    }
  }

  const anthropicUsd = await anthropicSpendForDay(day, adminKey, workspaceId)
  const gapUsd = anthropicUsd - ourUsd
  // Against Anthropic's figure, since theirs is the one that is true.
  const gapPercent = anthropicUsd > 0 ? (gapUsd / anthropicUsd) * 100 : 0

  return { configured: true, day, ourUsd, anthropicUsd, gapUsd, gapPercent }
}

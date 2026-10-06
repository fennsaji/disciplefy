/**
 * Rebuilds a plan's marketing copy (English + Hindi + Malayalam) from the
 * limits the app actually enforces, so an admin save can't leave the pricing
 * page quoting numbers the backend doesn't apply, or the locales out of step.
 *
 * Sources of each number:
 * - credits a day: subscription_plans.features.daily_tokens
 * - Discipler conversations: subscription_plans.features.voice_conversations_monthly
 * - memory verses reviewed a day: system_config `<plan>_memory_verses_limit`
 * - practice modes: system_config `free_available_practice_modes` / `paid_available_practice_modes`
 * - follow-ups per study: FOLLOW_UP_LIMITS below (mirrors
 *   backend/supabase/functions/study-followup/follow-up-limits.ts)
 * - study modes and fellowships: fixed per plan by feature flags
 *
 * The order matches migration 20261006100000_plan_marketing_copy_credits.sql.
 */

export type PlanCode = 'free' | 'standard' | 'plus' | 'premium'

export interface PlanMarketingCopy {
  en: string[]
  hi: string[]
  ml: string[]
}

export interface PlanLimits {
  /** Memory verses reviewed a day; -1 = unlimited. */
  memoryVersesLimit: number
  /** Number of memory practice modes available on this plan. */
  practiceModes: number
}

/** Mirrors study-followup/follow-up-limits.ts. Free has no follow-ups (study_chat flag off). */
export const FOLLOW_UP_LIMITS: Record<PlanCode, number> = {
  free: 0,
  standard: 10,
  plus: 15,
  premium: 20,
}

const DEFAULT_LIMITS: Record<PlanCode, PlanLimits> = {
  free: { memoryVersesLimit: 3, practiceModes: 2 },
  standard: { memoryVersesLimit: 5, practiceModes: 8 },
  plus: { memoryVersesLimit: 10, practiceModes: 8 },
  premium: { memoryVersesLimit: -1, practiceModes: 8 },
}

export function isPlanCode(value: unknown): value is PlanCode {
  return value === 'free' || value === 'standard' || value === 'plus' || value === 'premium'
}

function num(value: unknown, fallback: number): number {
  const n = typeof value === 'string' ? Number(value) : value
  return typeof n === 'number' && Number.isFinite(n) ? n : fallback
}

export function buildMarketingFeatures(
  planCode: PlanCode,
  features: Record<string, unknown>,
  limits: Partial<PlanLimits> = {}
): PlanMarketingCopy {
  const credits = num(features.daily_tokens, 0)
  const discipler = num(features.voice_conversations_monthly, 0)
  const memory = num(limits.memoryVersesLimit, DEFAULT_LIMITS[planCode].memoryVersesLimit)
  const practice = num(limits.practiceModes, DEFAULT_LIMITS[planCode].practiceModes)
  const followUps = FOLLOW_UP_LIMITS[planCode]
  const leads = planCode === 'plus' || planCode === 'premium'

  const en: string[] = []
  const hi: string[] = []
  const ml: string[] = []
  const add = (e: string, h: string, m: string) => {
    en.push(e)
    hi.push(h)
    ml.push(m)
  }

  add('Daily Bible verse', 'रोज़ का बाइबल वचन', 'ദിവസ വചനം')

  if (credits === -1) {
    add('Unlimited credits', 'असीमित क्रेडिट', 'പരിധിയില്ലാത്ത ക്രെഡിറ്റ്')
  } else {
    add(`${credits} credits a day`, `${credits} क्रेडिट/दिन`, `ദിവസം ${credits} ക്രെഡിറ്റ്`)
  }

  if (planCode === 'free') {
    add('Quick Read and Standard studies', 'क्विक और स्टैंडर्ड अध्ययन', 'ക്വിക്ക്, സ്റ്റാൻഡേർഡ് പഠനം')
  } else if (planCode === 'standard') {
    add(
      'Quick Read, Standard, Deep Dive and Lectio Divina',
      'क्विक, स्टैंडर्ड, डीप डाइव, लेक्टियो',
      'ക്വിക്ക്, സ്റ്റാൻഡേർഡ്, ഡീപ്പ്, ലെക്റ്റിയോ'
    )
  } else {
    add('All study modes', 'सभी अध्ययन तरीके', 'എല്ലാ പഠന രീതികളും')
  }

  add('Guided learning paths', 'सीखने के पथ', 'പഠന പാതകൾ')

  if (memory === -1) {
    add('Unlimited memory reviews', 'असीमित वचन अभ्यास', 'പരിധിയില്ലാത്ത പരിശീലനം')
  } else if (planCode === 'free') {
    add(`Review ${memory} memory verses a day`, `रोज़ ${memory} वचन दोहराएँ`, `ദിവസം ${memory} വാക്യം`)
    add(`${practice} practice modes`, `${practice} अभ्यास तरीके`, `${practice} പരിശീലന രീതി`)
  } else {
    add(
      `Review ${memory} memory verses a day · all ${practice} practice modes`,
      `रोज़ ${memory} वचन · सभी ${practice} अभ्यास`,
      `ദിവസം ${memory} വാക്യം · ${practice} രീതികൾ`
    )
  }

  if (followUps > 0) {
    add(
      `${followUps} follow-ups per study`,
      `हर अध्ययन पर ${followUps} प्रश्न`,
      `ഓരോ പഠനത്തിനും ${followUps} ചോദ്യം`
    )
  }

  if (discipler === -1) {
    add('Unlimited Discipler conversations', 'असीमित Discipler', 'പരിധിയില്ലാത്ത Discipler')
  } else if (discipler > 0) {
    add(
      `Discipler · ${discipler} conversations a month`,
      `Discipler · ${discipler} बातचीत/माह`,
      `Discipler · മാസം ${discipler}`
    )
  }

  if (leads) {
    add('Create and lead fellowships', 'फ़ेलोशिप बनाएँ', 'ഫെലോഷിപ്പ് തുടങ്ങാം')
  } else {
    add('Join fellowships', 'फ़ेलोशिप से जुड़ें', 'ഫെലോഷിപ്പിൽ ചേരാം')
  }

  return { en, hi, ml }
}

/** Minimal shape of the Supabase admin client calls used here. */
interface AdminClient {
  from(table: string): unknown
}

/** The query this file runs, typed loosely so the full Supabase types aren't instantiated. */
interface ConfigQuery {
  select(columns: string): {
    in(column: string, values: string[]): PromiseLike<{ data: unknown[] | null }>
  }
}

/**
 * Reads the limits that live in system_config and returns the columns to
 * write: English copy plus hi/ml merged into the existing translations, so
 * other locales already stored are kept.
 */
export async function planMarketingUpdate(
  supabaseAdmin: AdminClient,
  planCode: string,
  features: Record<string, unknown>,
  existingI18n: Record<string, unknown> | null | undefined
): Promise<{ marketing_features: string[]; marketing_features_i18n: Record<string, unknown> } | null> {
  if (!isPlanCode(planCode)) return null

  const tier = planCode === 'free' ? 'free' : 'paid'
  const { data } = await (supabaseAdmin.from('system_config') as ConfigQuery)
    .select('key, value')
    .in('key', [`${planCode}_memory_verses_limit`, `${tier}_available_practice_modes`])

  const limits: Partial<PlanLimits> = {}
  for (const row of (data ?? []) as Array<{ key: string; value: unknown }>) {
    if (row.key.endsWith('_memory_verses_limit')) {
      limits.memoryVersesLimit = num(row.value, DEFAULT_LIMITS[planCode].memoryVersesLimit)
    } else {
      const modes = parseModes(row.value)
      if (modes !== null) limits.practiceModes = modes
    }
  }

  const copy = buildMarketingFeatures(planCode, features, limits)
  return {
    marketing_features: copy.en,
    marketing_features_i18n: { ...(existingI18n ?? {}), hi: copy.hi, ml: copy.ml },
  }
}

function parseModes(value: unknown): number | null {
  try {
    const parsed = typeof value === 'string' ? JSON.parse(value) : value
    return Array.isArray(parsed) ? parsed.length : null
  } catch {
    return null
  }
}

/**
 * Mentor controls for the Discipler daily post.
 *
 *   POST /fellowship-study/daily/status   { fellowship_id }
 *   POST /fellowship-study/daily/update   { fellowship_id, skip_next?, paused_until?, time?, next_learning_path_topic_id? }
 *   POST /fellowship-study/daily/request  { fellowship_id, kind: 'preview' | 'regenerate' | 'post_now' }
 *
 * Status, schedule and the next-lesson choice are read and written here. The
 * three actions that cost an LLM call are only recorded as requests: the
 * rs-backend fellowship_daily_post job (every minute) carries them out, and
 * status reports their progress. Each of those actions needs its own admin flag.
 *
 * The schedule rules mirror rs-backend `models/fellowship_daily.rs`
 * (`effective_last_post`, `next_post_date`); change both together.
 */
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'

type Db = ServiceContainer['supabaseServiceClient']

export const POST_TIMES = ['06:30', '08:00', '12:00', '18:00', '20:00'] as const
export const REGENERATE_DAILY_CAP = 3
const UPCOMING_LIMIT = 5
const HISTORY_LIMIT = 10
const REQUEST_KINDS = ['preview', 'regenerate', 'post_now', 'repost'] as const
type RequestKind = typeof REQUEST_KINDS[number]

// "Post again" publishes immediately, so it sits under the Post now switch.
const FLAG_FOR_KIND: Record<RequestKind, string> = {
  preview: 'daily_post_preview_allowed',
  regenerate: 'daily_post_regenerate_allowed',
  post_now: 'daily_post_post_now_allowed',
  repost: 'daily_post_post_now_allowed',
}

export const REPOST_DAILY_CAP = 3

// ---------------------------------------------------------------------------
// Schedule rules (mirror rs-backend models/fellowship_daily.rs)
// ---------------------------------------------------------------------------

export function addDays(date: string, days: number): string {
  const d = new Date(`${date}T00:00:00Z`)
  d.setUTCDate(d.getUTCDate() + days)
  return d.toISOString().slice(0, 10)
}

/** A skipped date that has arrived counts as a posting day. */
export function effectiveLastPost(last: string | null, skip: string | null, today: string): string | null {
  const arrived = skip && skip <= today ? skip : null
  if (last && arrived) return last > arrived ? last : arrived
  return last ?? arrived
}

export function nextPostDate(
  last: string | null, today: string, freq: number, skip: string | null, pausedUntil: string | null,
): string {
  const step = Math.max(freq, 1)
  const effective = effectiveLastPost(last, skip, today)
  let date = today
  if (effective) {
    const due = addDays(effective, step)
    date = due > today ? due : today
  }
  if (pausedUntil && date <= pausedUntil) date = addDays(pausedUntil, 1)
  if (skip === date) date = addDays(date, step)
  return date
}

/** The job keys posts on the UTC date; every posting time is after 05:30 IST. */
function utcToday(): string {
  return new Date().toISOString().slice(0, 10)
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

async function authenticate(req: Request, services: ServiceContainer): Promise<string> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', ''),
  )
  if (error || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)
  return user.id
}

async function readBody<T>(req: Request): Promise<T & { fellowship_id: string }> {
  let body: T & { fellowship_id?: string }
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body || typeof body.fellowship_id !== 'string' || !body.fellowship_id) {
    throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  }
  return body as T & { fellowship_id: string }
}

async function requireMentor(db: Db, fellowshipId: string, userId: string): Promise<void> {
  const { data: isMentor, error } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: fellowshipId,
    p_user_id: userId,
  })
  if (error) {
    console.error('[fellowship-study/daily] mentor check error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  }
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)
}

const FELLOWSHIP_COLUMNS = [
  'id', 'language', 'is_official', 'daily_post_allowed', 'daily_post_on', 'daily_post_frequency_days',
  'daily_post_auto_advance', 'daily_post_time', 'daily_post_skip_date', 'daily_post_paused_until',
  'daily_post_preview_allowed', 'daily_post_regenerate_allowed', 'daily_post_post_now_allowed',
].join(', ')

// deno-lint-ignore no-explicit-any
async function loadDailyFellowship(db: Db, fellowshipId: string): Promise<any> {
  const { data: row, error } = await db.from('fellowships').select(FELLOWSHIP_COLUMNS)
    .eq('id', fellowshipId).maybeSingle()
  // A column list built at runtime leaves supabase-js unable to type the row.
  // deno-lint-ignore no-explicit-any
  const data = row as any
  if (error) {
    console.error('[fellowship-study/daily] fellowship load error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to load fellowship', 500)
  }
  if (!data) throw new AppError('NOT_FOUND', 'Fellowship not found', 404)
  if (!data.daily_post_allowed) {
    throw new AppError('PERMISSION_DENIED', 'Daily posts are not enabled for this fellowship', 403)
  }
  return data
}

async function lastDailyPost(db: Db, fellowshipId: string) {
  const { data } = await db.from('discipler_daily_posts')
    .select('post_date, learning_path_topic_id, created_at, post_id, study_guide_id')
    .eq('fellowship_id', fellowshipId)
    .order('post_date', { ascending: false })
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle()
  return data as {
    post_date: string; learning_path_topic_id: string; created_at: string
    post_id: string | null; study_guide_id: string | null
  } | null
}

interface LessonRow { id: string; position: number; topic_id: string; title: string }

/** Visible lessons of a path from `fromPosition`, localized to `language`. */
async function visibleLessons(
  db: Db, pathId: string, fromPosition: number, language: string, limit: number,
): Promise<LessonRow[]> {
  const { data: rows } = await db.from('learning_path_topics')
    .select('id, position, topic_id')
    .eq('learning_path_id', pathId)
    .eq('is_active', true)
    .gte('position', fromPosition)
    .order('position', { ascending: true })
    .limit(limit * 3)
  const candidates = (rows ?? []) as { id: string; position: number; topic_id: string }[]
  if (candidates.length === 0) return []

  const topicIds = candidates.map((r) => r.topic_id)
  const { data: topics } = await db.from('recommended_topics')
    .select('id, title, is_active').in('id', topicIds)
  const topicById = new Map((topics ?? []).map((t: { id: string; title: string; is_active: boolean | null }) => [t.id, t]))

  const titles = new Map<string, string>()
  if (language !== 'en') {
    const { data: translations } = await db.from('recommended_topics_translations')
      .select('topic_id, title').eq('language_code', language).in('topic_id', topicIds)
    for (const t of (translations ?? []) as { topic_id: string; title: string | null }[]) {
      if (t.title?.trim()) titles.set(t.topic_id, t.title)
    }
  }

  return candidates
    .filter((r) => topicById.get(r.topic_id)?.is_active === true)
    .slice(0, limit)
    .map((r) => ({
      id: r.id,
      position: r.position,
      topic_id: r.topic_id,
      title: titles.get(r.topic_id) ?? topicById.get(r.topic_id)!.title,
    }))
}

// ---------------------------------------------------------------------------
// POST /daily/status
// ---------------------------------------------------------------------------

export async function handleDailyStatus(req: Request, services: ServiceContainer): Promise<Response> {
  const userId = await authenticate(req, services)
  const body = await readBody<Record<string, never>>(req)
  const db = services.supabaseServiceClient
  await requireMentor(db, body.fellowship_id, userId)
  const f = await loadDailyFellowship(db, body.fellowship_id)

  const today = utcToday()
  const last = await lastDailyPost(db, f.id)

  const { data: study } = await db.from('fellowship_study')
    .select('learning_path_id, current_guide_index, started_at, completed_at, learning_paths(title)')
    .eq('fellowship_id', f.id).maybeSingle()

  // The lesson the job posts next. Mirrors resolve_post_plan for the common
  // case; when the path is exhausted the job picks the next path itself.
  let upcoming: LessonRow[] = []
  let pathTitle: string | null = null
  let pathTotal = 0
  if (study && !study.completed_at) {
    pathTitle = (study.learning_paths as { title?: string } | null)?.title ?? null
    if (f.language !== 'en') {
      const { data: t } = await db.from('learning_path_translations').select('title')
        .eq('learning_path_id', study.learning_path_id).eq('lang_code', f.language).maybeSingle()
      if (t?.title?.trim()) pathTitle = t.title
    }
    const { count } = await db.from('learning_path_topics').select('id', { count: 'exact', head: true })
      .eq('learning_path_id', study.learning_path_id).eq('is_active', true)
    pathTotal = count ?? 0

    const fromCurrent = await visibleLessons(db, study.learning_path_id, study.current_guide_index, f.language, UPCOMING_LIMIT + 1)
    const current = fromCurrent[0]
    const alreadyPosted = !!(current && last && last.learning_path_topic_id === current.id
      && last.created_at >= study.started_at)
    upcoming = alreadyPosted
      ? (f.daily_post_auto_advance ? fromCurrent.slice(1) : [])
      : fromCurrent
    upcoming = upcoming.slice(0, UPCOMING_LIMIT)
  }

  const scheduleOn = f.daily_post_on === true
  const nextDate = nextPostDate(
    last?.post_date ?? null, today, f.daily_post_frequency_days ?? 1,
    f.daily_post_skip_date, f.daily_post_paused_until,
  )

  // Preview (only when the admin allows it)
  let preview = null
  if (f.daily_post_preview_allowed) {
    const { data: p } = await db.from('discipler_daily_post_previews')
      .select('post_date, learning_path_topic_id, topic_title, content, teaser_hook, teaser_body, regenerate_date, regenerate_count, updated_at')
      .eq('fellowship_id', f.id).maybeSingle()
    if (p) {
      const used = p.regenerate_date === today ? p.regenerate_count : 0
      preview = {
        post_date: p.post_date,
        topic_title: p.topic_title,
        content: p.content,
        teaser_hook: p.teaser_hook,
        teaser_body: p.teaser_body,
        updated_at: p.updated_at,
        regenerations_left: f.daily_post_regenerate_allowed ? Math.max(REGENERATE_DAILY_CAP - used, 0) : 0,
        // The job ignores a preview made for another lesson or an earlier date.
        is_current: p.post_date >= today && upcoming[0]?.id === p.learning_path_topic_id,
      }
    }
  }

  // Latest request of each kind, so the app can show progress and errors.
  const { data: requestRows } = await db.from('discipler_daily_post_requests')
    .select('kind, status, error, created_at, processed_at, target_daily_post_id')
    .eq('fellowship_id', f.id)
    .order('created_at', { ascending: false })
    .limit(20)
  const requests: Record<string, unknown> = {}
  for (const r of (requestRows ?? []) as { kind: string }[]) {
    if (!(r.kind in requests)) requests[r.kind] = r
  }

  // History with how many members completed each guide.
  const { data: historyRows } = await db.from('discipler_daily_posts')
    .select('id, post_date, post_id, study_guide_id, learning_path_topic_id, topic_id, created_at')
    .eq('fellowship_id', f.id)
    .order('post_date', { ascending: false })
    .limit(HISTORY_LIMIT)
  const history = (historyRows ?? []) as {
    id: string; post_date: string; post_id: string | null; study_guide_id: string | null
    topic_id: string; created_at: string
  }[]
  const postIds = history.map((h) => h.post_id).filter(Boolean) as string[]
  const guideIds = history.map((h) => h.study_guide_id).filter(Boolean) as string[]
  const titleByPost = new Map<string, string>()
  const deletedPosts = new Set<string>()
  if (postIds.length) {
    const { data: posts } = await db.from('fellowship_posts').select('id, topic_title, is_deleted').in('id', postIds)
    for (const p of (posts ?? []) as { id: string; topic_title: string | null; is_deleted: boolean }[]) {
      if (p.topic_title) titleByPost.set(p.id, p.topic_title)
      if (p.is_deleted) deletedPosts.add(p.id)
    }
  }
  // A post removed outright leaves no title to show; fall back to the lesson's.
  const titleByTopic = new Map<string, string>()
  const untitled = history.filter((h) => !h.post_id || !titleByPost.has(h.post_id)).map((h) => h.topic_id)
  if (untitled.length) {
    const { data: topics } = await db.from('recommended_topics').select('id, title').in('id', untitled)
    for (const t of (topics ?? []) as { id: string; title: string }[]) titleByTopic.set(t.id, t.title)
    if (f.language !== 'en') {
      const { data: translations } = await db.from('recommended_topics_translations')
        .select('topic_id, title').eq('language_code', f.language).in('topic_id', untitled)
      for (const t of (translations ?? []) as { topic_id: string; title: string | null }[]) {
        if (t.title?.trim()) titleByTopic.set(t.topic_id, t.title)
      }
    }
  }
  const completedByGuide = new Map<string, number>()
  if (guideIds.length) {
    const { data: members } = await db.from('fellowship_members').select('user_id')
      .eq('fellowship_id', f.id).eq('is_active', true)
    const memberIds = ((members ?? []) as { user_id: string }[]).map((m) => m.user_id)
    if (memberIds.length) {
      const { data: done } = await db.from('user_study_guides').select('study_guide_id')
        .in('study_guide_id', guideIds).in('user_id', memberIds).not('completed_at', 'is', null)
      for (const d of (done ?? []) as { study_guide_id: string }[]) {
        completedByGuide.set(d.study_guide_id, (completedByGuide.get(d.study_guide_id) ?? 0) + 1)
      }
    }
  }

  const data = {
    settings: {
      daily_post_on: scheduleOn,
      frequency_days: f.daily_post_frequency_days ?? 1,
      auto_advance: f.daily_post_auto_advance ?? true,
      time: f.daily_post_time ?? '06:30',
      skip_date: f.daily_post_skip_date,
      paused_until: f.daily_post_paused_until,
      preview_allowed: f.daily_post_preview_allowed === true,
      regenerate_allowed: f.daily_post_regenerate_allowed === true,
      post_now_allowed: f.daily_post_post_now_allowed === true,
      // Official groups have no daily caps and no pause length limit.
      no_limits: f.is_official === true,
      times: POST_TIMES,
    },
    today,
    last_post: last
      ? { post_date: last.post_date, post_id: last.post_id, topic_title: last.post_id ? titleByPost.get(last.post_id) ?? null : null }
      : null,
    posted_today: last?.post_date === today,
    next_post: scheduleOn ? { date: nextDate, time: f.daily_post_time ?? '06:30' } : null,
    path: study && !study.completed_at
      ? { learning_path_id: study.learning_path_id, title: pathTitle, total_lessons: pathTotal }
      : null,
    upcoming: upcoming.map((l) => ({ learning_path_topic_id: l.id, position: l.position, title: l.title })),
    preview,
    requests,
    history: history.map((h) => ({
      daily_post_id: h.id,
      post_date: h.post_date,
      post_id: h.post_id,
      // Deleted by a mentor, or removed outright: "Post again" still works.
      post_deleted: !h.post_id || deletedPosts.has(h.post_id),
      topic_title: (h.post_id ? titleByPost.get(h.post_id) : undefined) ?? titleByTopic.get(h.topic_id) ?? null,
      completed_count: h.study_guide_id ? completedByGuide.get(h.study_guide_id) ?? 0 : 0,
    })),
    reposts_left_today: f.daily_post_post_now_allowed === true
      ? Math.max(REPOST_DAILY_CAP - (await repostsToday(db, f.id, today)), 0)
      : 0,
  }

  return json({ success: true, data })
}

// ---------------------------------------------------------------------------
// POST /daily/update
// ---------------------------------------------------------------------------

export async function handleDailyUpdate(req: Request, services: ServiceContainer): Promise<Response> {
  const userId = await authenticate(req, services)
  const body = await readBody<{
    skip_next?: boolean; paused_until?: string | null; time?: string; next_learning_path_topic_id?: string
  }>(req)
  const db = services.supabaseServiceClient
  await requireMentor(db, body.fellowship_id, userId)
  const f = await loadDailyFellowship(db, body.fellowship_id)

  const today = utcToday()
  const updates: Record<string, unknown> = {}

  if (body.time !== undefined) {
    if (!POST_TIMES.includes(body.time as typeof POST_TIMES[number])) {
      throw new AppError('VALIDATION_ERROR', `time must be one of ${POST_TIMES.join(', ')}`, 400)
    }
    updates.daily_post_time = body.time
  }

  if (body.paused_until !== undefined) {
    if (body.paused_until === null) {
      updates.daily_post_paused_until = null
    } else {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(body.paused_until) || body.paused_until < today) {
        throw new AppError('VALIDATION_ERROR', 'paused_until must be a date from today onwards (YYYY-MM-DD)', 400)
      }
      if (f.is_official !== true && body.paused_until > addDays(today, 90)) {
        throw new AppError('VALIDATION_ERROR', 'Daily posts can be paused for up to 90 days', 400)
      }
      updates.daily_post_paused_until = body.paused_until
    }
  }

  if (typeof body.skip_next === 'boolean') {
    if (body.skip_next) {
      const last = await lastDailyPost(db, f.id)
      // Compute from the schedule without any existing skip, so pressing
      // "skip" again does not move further out.
      updates.daily_post_skip_date = nextPostDate(
        last?.post_date ?? null, today, f.daily_post_frequency_days ?? 1, null,
        (updates.daily_post_paused_until as string | null | undefined) ?? f.daily_post_paused_until,
      )
    } else {
      updates.daily_post_skip_date = null
    }
  }

  if (body.next_learning_path_topic_id !== undefined) {
    await setNextLesson(db, f.id, body.next_learning_path_topic_id)
  }

  if (Object.keys(updates).length > 0) {
    const { error } = await db.from('fellowships').update(updates).eq('id', f.id)
    if (error) {
      console.error('[fellowship-study/daily/update] update error:', error)
      throw new AppError('DATABASE_ERROR', 'Failed to update the daily post schedule', 500)
    }
  } else if (body.next_learning_path_topic_id === undefined) {
    throw new AppError('VALIDATION_ERROR', 'No valid fields provided to update', 400)
  }

  return json({ success: true })
}

/** Points the group's study at a lesson on its current path, for the next post. */
async function setNextLesson(db: Db, fellowshipId: string, learningPathTopicId: string): Promise<void> {
  const { data: study } = await db.from('fellowship_study')
    .select('id, learning_path_id, completed_at').eq('fellowship_id', fellowshipId).maybeSingle()
  if (!study || study.completed_at) {
    throw new AppError('VALIDATION_ERROR', 'The group has no study in progress', 400)
  }
  const { data: lesson } = await db.from('learning_path_topics')
    .select('id, position, topic_id, is_active')
    .eq('id', learningPathTopicId).eq('learning_path_id', study.learning_path_id).maybeSingle()
  if (!lesson || !lesson.is_active) {
    throw new AppError('NOT_FOUND', 'That lesson is not part of the current learning path', 404)
  }
  const last = await lastDailyPost(db, fellowshipId)
  if (last?.learning_path_topic_id === lesson.id) {
    throw new AppError('VALIDATION_ERROR', 'That lesson was the last one posted', 400)
  }
  const { error } = await db.from('fellowship_study')
    .update({ current_guide_index: lesson.position, updated_at: new Date().toISOString() })
    .eq('id', study.id)
  if (error) {
    console.error('[fellowship-study/daily/update] next lesson error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to set the next lesson', 500)
  }
}

// ---------------------------------------------------------------------------
// POST /daily/request
// ---------------------------------------------------------------------------

/** Reposts requested today that did not fail (open ones count too). */
async function repostsToday(db: Db, fellowshipId: string, today: string): Promise<number> {
  const { count } = await db.from('discipler_daily_post_requests')
    .select('id', { count: 'exact', head: true })
    .eq('fellowship_id', fellowshipId)
    .eq('kind', 'repost')
    .neq('status', 'failed')
    .gte('created_at', `${today}T00:00:00Z`)
  return count ?? 0
}

export async function handleDailyRequest(req: Request, services: ServiceContainer): Promise<Response> {
  const userId = await authenticate(req, services)
  const body = await readBody<{ kind?: string; daily_post_id?: string }>(req)
  if (!REQUEST_KINDS.includes(body.kind as RequestKind)) {
    throw new AppError('VALIDATION_ERROR', `kind must be one of ${REQUEST_KINDS.join(', ')}`, 400)
  }
  const kind = body.kind as RequestKind
  const db = services.supabaseServiceClient
  await requireMentor(db, body.fellowship_id, userId)
  const f = await loadDailyFellowship(db, body.fellowship_id)

  if (f[FLAG_FOR_KIND[kind]] !== true) {
    throw new AppError('PERMISSION_DENIED', 'This control is not enabled for this fellowship', 403)
  }

  const today = utcToday()
  if (kind === 'regenerate') {
    const { data: p } = await db.from('discipler_daily_post_previews')
      .select('regenerate_date, regenerate_count').eq('fellowship_id', f.id).maybeSingle()
    if (!p) throw new AppError('VALIDATION_ERROR', 'Preview the next post first', 400)
    const used = p.regenerate_date === today ? p.regenerate_count : 0
    if (f.is_official !== true && used >= REGENERATE_DAILY_CAP) {
      throw new AppError('RATE_LIMIT_EXCEEDED', 'You have used all new teasers for today', 429)
    }
  }
  if (kind === 'post_now') {
    const last = await lastDailyPost(db, f.id)
    if (last?.post_date === today) {
      throw new AppError('VALIDATION_ERROR', 'The post for today has already gone out', 400)
    }
  }

  let targetDailyPostId: string | null = null
  if (kind === 'repost') {
    if (typeof body.daily_post_id !== 'string' || !body.daily_post_id) {
      throw new AppError('VALIDATION_ERROR', 'daily_post_id is required to post again', 400)
    }
    const { data: dailyPost } = await db.from('discipler_daily_posts')
      .select('id').eq('id', body.daily_post_id).eq('fellowship_id', f.id).maybeSingle()
    if (!dailyPost) throw new AppError('NOT_FOUND', 'That post is no longer available', 404)
    if (f.is_official !== true && await repostsToday(db, f.id, today) >= REPOST_DAILY_CAP) {
      throw new AppError('RATE_LIMIT_EXCEEDED', "You have posted again the most times allowed today", 429)
    }
    targetDailyPostId = dailyPost.id
  }

  const { error } = await db.from('discipler_daily_post_requests').insert({
    fellowship_id: f.id, kind, requested_by: userId, target_daily_post_id: targetDailyPostId,
  })
  if (error && error.code === '23505' && kind === 'repost') {
    // Only one repost runs at a time, and it may be for a different post.
    throw new AppError('VALIDATION_ERROR', 'Another post is being posted again. Try again in a minute', 409)
  }
  // 23505 otherwise: the same request is already waiting — nothing more to do.
  if (error && error.code !== '23505') {
    console.error('[fellowship-study/daily/request] insert error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to record the request', 500)
  }

  return json({ success: true, data: { kind, status: 'pending' } })
}

function json(data: unknown): Response {
  return new Response(JSON.stringify(data), { status: 200, headers: { 'Content-Type': 'application/json' } })
}

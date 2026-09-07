// backend/supabase/functions/fellowship-posts/notify.ts
/**
 * POST /fellowship-posts/notify  (service-role bearer only; called by rs-backend)
 *   { kind: 'daily_post', post_id }             → push members about a Discipler daily post, push mentors
 *   { kind: 'activity_digest', fellowship_id }  → one push to mentors for unpushed react/daily rows
 */
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { pushMentors, pushUsers, recordActivity } from '../_shared/services/discipler-service.ts'
import { DISCIPLER_USER_ID } from '../_shared/utils/discipler.ts'

export async function handleNotify(req: Request, services: ServiceContainer): Promise<Response> {
  const srk = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!srk || req.headers.get('Authorization') !== `Bearer ${srk}`) throw new AppError('PERMISSION_DENIED', 'Service role required', 403)
  let body: { kind: string; post_id?: string; fellowship_id?: string }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  const db = services.supabaseServiceClient

  if (body.kind === 'daily_post') {
    if (!body.post_id) throw new AppError('VALIDATION_ERROR', 'post_id is required', 400)
    const { data: post } = await db.from('fellowship_posts').select('id, fellowship_id, content, topic_title').eq('id', body.post_id).maybeSingle()
    if (!post) throw new AppError('NOT_FOUND', 'Post not found', 404)
    const { data: f } = await db.from('fellowships').select('name').eq('id', post.fellowship_id).maybeSingle()
    const { data: members } = await db.from('fellowship_members').select('user_id').eq('fellowship_id', post.fellowship_id).eq('is_active', true)
    const ids = ((members ?? []) as { user_id: string }[]).map((m) => m.user_id).filter((id) => id !== DISCIPLER_USER_ID)
    const title = `📖 Today's study in ${f?.name ?? 'your fellowship'}`
    const bodyText = post.topic_title ?? post.content.slice(0, 80)
    await pushUsers(db, ids, { title, body: bodyText }, { type: 'fellowship_daily_post', fellowship_id: post.fellowship_id, post_id: post.id })
    await recordActivity(db, { fellowshipId: post.fellowship_id, kind: 'daily_post', postId: post.id, summary: `Posted today's study: ${bodyText}`, pushNow: false })
    return ok({ sent: ids.length })
  }

  if (body.kind === 'activity_digest') {
    if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
    const { data: rows } = await db.from('discipler_activity').select('id, kind').eq('fellowship_id', body.fellowship_id).is('pushed_at', null)
    const list = (rows ?? []) as { id: string; kind: string }[]
    if (list.length === 0) return ok({ sent: 0 })
    const reacts = list.filter((r) => r.kind === 'react').length
    const daily = list.filter((r) => r.kind === 'daily_post').length
    const parts = [reacts ? `${reacts} reaction${reacts === 1 ? '' : 's'}` : '', daily ? `${daily} daily post${daily === 1 ? '' : 's'}` : ''].filter(Boolean)
    const { data: f } = await db.from('fellowships').select('name').eq('id', body.fellowship_id).maybeSingle()
    await pushMentors(db, body.fellowship_id,
      { title: `✨ Discipler activity in ${f?.name ?? 'your fellowship'}`, body: parts.join(' · ') },
      { type: 'fellowship_discipler_activity', fellowship_id: body.fellowship_id }, { respectMute: true })
    await db.from('discipler_activity').update({ pushed_at: new Date().toISOString() }).in('id', list.map((r) => r.id))
    return ok({ sent: list.length })
  }

  throw new AppError('VALIDATION_ERROR', "kind must be 'daily_post' or 'activity_digest'", 400)
}

function ok(data: Record<string, unknown>): Response {
  return new Response(JSON.stringify({ success: true, data }), { status: 200, headers: { 'Content-Type': 'application/json' } })
}

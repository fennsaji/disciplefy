import type { SupabaseClient } from '@supabase/supabase-js'
import { FCMService } from '../fcm-service.ts'
import { DISCIPLER_USER_ID, type DisciplerReaction, type FellowshipDisciplerSettings } from '../utils/discipler.ts'

export interface DisciplerFellowshipRow extends FellowshipDisciplerSettings {
  id: string
  name: string
  language: 'en' | 'hi' | 'ml'
  daily_post_allowed: boolean
  daily_post_on: boolean
}

export const DISCIPLER_SETTINGS_COLUMNS =
  'id, name, language, discipler_allowed, discipler_reply_mode, discipler_reply_scope, discipler_reply_delay_min, discipler_react_enabled, daily_post_allowed, daily_post_on'

export async function loadFellowshipDiscipler(db: SupabaseClient, fellowshipId: string): Promise<DisciplerFellowshipRow | null> {
  const { data, error } = await db.from('fellowships').select(DISCIPLER_SETTINGS_COLUMNS).eq('id', fellowshipId).maybeSingle()
  if (error) { console.error('[discipler] settings load error:', error); return null }
  return (data as DisciplerFellowshipRow | null) ?? null
}

export async function isDisciplerGloballyEnabled(db: SupabaseClient): Promise<boolean> {
  const { data } = await db.from('system_config').select('value').eq('key', 'discipler_global_enabled').maybeSingle()
  return data?.value === 'true'
}

export async function enqueueReply(db: SupabaseClient, args: {
  postId: string; commentId?: string | null; fellowshipId: string; trigger: 'mention' | 'question'; runAfter: string
}): Promise<void> {
  const { error } = await db.from('discipler_reply_queue').upsert({
    post_id: args.postId,
    comment_id: args.commentId ?? null,
    fellowship_id: args.fellowshipId,
    trigger: args.trigger,
    run_after: args.runAfter,
    status: 'pending',
  }, { onConflict: 'post_id,comment_id', ignoreDuplicates: true })
  if (error) console.error('[discipler] enqueue error (non-fatal):', error)
}

export async function reactAsDiscipler(db: SupabaseClient, args: {
  postId: string; fellowshipId: string; reaction: DisciplerReaction; currentCounts: Record<string, number>
}): Promise<Record<string, number>> {
  const { error: insertError } = await db.from('fellowship_reactions').insert({
    post_id: args.postId, fellowship_id: args.fellowshipId, user_id: DISCIPLER_USER_ID, reaction_type: args.reaction,
  })
  if (insertError) { console.error('[discipler] reaction insert error:', insertError); return args.currentCounts }
  const counts = { ...args.currentCounts }
  counts[args.reaction] = (counts[args.reaction] || 0) + 1
  const { error: updateError } = await db.from('fellowship_posts').update({ reaction_counts: counts }).eq('id', args.postId)
  if (updateError) console.error('[discipler] reaction count update error (non-fatal):', updateError)
  return counts
}

export async function recordActivity(db: SupabaseClient, args: {
  fellowshipId: string; kind: 'reply' | 'react' | 'draft' | 'daily_post'
  postId?: string | null; commentId?: string | null; reaction?: string | null; language?: string | null
  summary: string; pushNow: boolean
}): Promise<void> {
  const { error } = await db.from('discipler_activity').insert({
    fellowship_id: args.fellowshipId, kind: args.kind, post_id: args.postId ?? null, comment_id: args.commentId ?? null,
    reaction: args.reaction ?? null, language: args.language ?? null, summary: args.summary.slice(0, 200),
    pushed_at: args.pushNow ? new Date().toISOString() : null,
  })
  if (error) console.error('[discipler] activity insert error (non-fatal):', error)
}

export async function pushUsers(db: SupabaseClient, userIds: string[], notification: { title: string; body: string }, data: Record<string, string>): Promise<void> {
  if (userIds.length === 0) return
  try {
    const { data: tokenRows } = await db.from('user_notification_tokens').select('fcm_token').in('user_id', userIds)
    const tokens = (tokenRows ?? []).map((r: { fcm_token: string }) => r.fcm_token).filter(Boolean)
    if (tokens.length === 0) return
    await new FCMService().sendBatchNotifications(tokens, notification, data)
  } catch (err) {
    console.error('[discipler] push error (non-fatal):', err)
  }
}

export async function pushMentors(db: SupabaseClient, fellowshipId: string, notification: { title: string; body: string }, data: Record<string, string>, opts: { excludeUserId?: string; respectMute?: boolean } = {}): Promise<void> {
  try {
    const { data: rows } = await db.rpc('fellowship_mentor_ids', { p_fellowship_id: fellowshipId })
    const ids = ((rows ?? []) as { user_id: string; discipler_activity_push: boolean }[])
      .filter((r) => !opts.respectMute || r.discipler_activity_push)
      .map((r) => r.user_id)
      .filter((id) => id !== opts.excludeUserId)
    await pushUsers(db, ids, notification, data)
  } catch (err) {
    console.error('[discipler] pushMentors error (non-fatal):', err)
  }
}

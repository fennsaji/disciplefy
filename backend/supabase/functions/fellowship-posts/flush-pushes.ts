// backend/supabase/functions/fellowship-posts/flush-pushes.ts
/**
 * POST /fellowship-posts/flush-pushes
 * Internal only (X-Internal-Api-Key or service-role bearer). Called every
 * minute by the rs-backend discipler_reply_worker after it drains its own
 * queue.
 *
 * Delivers notification_push_queue rows whose hold has expired — pushes that
 * were composed during the recipient's 22:00–07:00 local night and parked
 * until their 07:00. It lives here rather than in a new Edge Function because
 * /discipler-reply already gives the worker an internal-only route on this
 * function with the same auth shape and the same per-minute cadence.
 */
import type { SupabaseClient } from '@supabase/supabase-js'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { deliverQueuedRow } from '../_shared/services/discipler-service.ts'
import { isInternalCaller } from './discipler-reply.ts'

/**
 * Rows claimed per run. The worker ticks every minute, so this is a rate
 * limit rather than a cap on throughput: a 07:00-local spike in one timezone
 * band drains over the following minutes instead of firing thousands of FCM
 * calls inside one 15-second function timeout.
 */
const BATCH_SIZE = 200

/** Give up on a row after this many failed sends. */
const MAX_ATTEMPTS = 3

interface QueueRow {
  id: string
  user_id: string
  kind: string
  title: string
  body: string
  data: Record<string, string>
}

export async function handleFlushPushes(req: Request, services: ServiceContainer): Promise<Response> {
  let ctx: { userId: string } | null = null
  try { ctx = await services.authService.getUserContext(req) as { userId: string } } catch { ctx = null }
  if (!isInternalCaller(ctx, req.headers.get('Authorization'))) {
    throw new AppError('PERMISSION_DENIED', 'Internal callers only', 403)
  }

  const db = services.supabaseServiceClient

  const { rows, error } = await claimDueRows(db)

  if (error) {
    console.error('[flush-pushes] Claim query failed:', error.message)
    throw new AppError('DATABASE_ERROR', 'Failed to read push queue', 500)
  }

  const due = (rows ?? []) as QueueRow[]
  if (due.length === 0) return json({ claimed: 0, sent: 0, failed: 0, retrying: 0 })

  let sent = 0
  let failed = 0
  let retrying = 0

  // Sequential and individually guarded: one recipient whose FCM token has
  // been revoked must not abort the rest of the batch, which would leave every
  // later row stuck behind it run after run.
  for (const row of due) {
    try {
      await deliverQueuedRow(db, row)
      await markSent(db, row.id)
      sent++
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      const terminal = await markFailure(db, row.id, message)
      if (terminal) failed++
      else retrying++
      // Log the row id and the transport error only — never the title or body.
      console.error(`[flush-pushes] Row ${row.id} (${row.kind}) failed: ${message}`)
    }
  }

  console.log(`[flush-pushes] claimed=${due.length} sent=${sent} retrying=${retrying} failed=${failed}`)
  return json({ claimed: due.length, sent, failed, retrying })
}

/** How long a claimed row stays invisible to other runs (seconds). */
const CLAIM_LEASE_SECONDS = 300

/**
 * Claims due rows atomically (FOR UPDATE SKIP LOCKED + a lease on not_before),
 * so two overlapping runs never both send the same row. Falls back to the
 * plain read only while the claim RPC is not yet deployed.
 */
async function claimDueRows(
  db: SupabaseClient,
): Promise<{ rows: QueueRow[] | null; error: { message: string } | null }> {
  const { data, error } = await db.rpc('claim_due_push_queue_rows', {
    p_limit: BATCH_SIZE,
    p_lease_seconds: CLAIM_LEASE_SECONDS,
  })
  if (!error) return { rows: (data ?? []) as QueueRow[], error: null }
  if (error.code !== 'PGRST202' && error.code !== '42883') return { rows: null, error }

  console.warn('[flush-pushes] claim RPC missing, using unclaimed read')
  const fallback = await db
    .from('notification_push_queue')
    .select('id, user_id, kind, title, body, data')
    .eq('status', 'pending')
    .lte('not_before', new Date().toISOString())
    .order('not_before', { ascending: true })
    .limit(BATCH_SIZE)
  return { rows: (fallback.data ?? null) as QueueRow[] | null, error: fallback.error }
}

async function markSent(db: SupabaseClient, id: string): Promise<void> {
  const { error } = await db
    .from('notification_push_queue')
    .update({ status: 'sent', sent_at: new Date().toISOString() })
    .eq('id', id)
  if (error) {
    // The push already went out; a status write that fails means it will be
    // re-sent next minute, so this is shouty rather than silent.
    console.error(`[flush-pushes] DUPLICATE RISK — row ${id} sent but not marked: ${error.message}`)
  }
}

/**
 * Records a failed attempt. Returns true when the row has exhausted its
 * retries and was marked `failed`.
 */
async function markFailure(db: SupabaseClient, id: string, message: string): Promise<boolean> {
  const { data: current } = await db
    .from('notification_push_queue')
    .select('attempts')
    .eq('id', id)
    .maybeSingle()

  const attempts = ((current?.attempts as number | undefined) ?? 0) + 1
  const terminal = attempts >= MAX_ATTEMPTS

  const { error } = await db
    .from('notification_push_queue')
    .update({
      attempts,
      last_error: message.slice(0, 500),
      status: terminal ? 'failed' : 'pending',
    })
    .eq('id', id)
  if (error) console.error(`[flush-pushes] Could not record failure for row ${id}: ${error.message}`)

  return terminal
}

function json(data: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify({ success: true, data }), { status, headers: { 'Content-Type': 'application/json' } })
}

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { deliverOrQueue } from './discipler-service.ts'

/**
 * Pushes "you were mentioned" to the people tagged in a post or comment.
 *
 * The client sends the ids it inserted through the @mention picker rather than
 * the backend re-parsing handles out of the text: display names are not unique
 * and contain spaces, so matching them back to accounts guesses.
 *
 * Every id is checked against active membership before anything is sent, so a
 * crafted request cannot notify someone outside the fellowship. The author is
 * dropped (tagging yourself notifies no one), as is anyone in a mutual block
 * with them. Delivery goes through deliverOrQueue, so the recipient's mention
 * preference and quiet hours both apply.
 */
export async function pushMentions(
  db: SupabaseClient,
  args: {
    fellowshipId: string
    authorUserId: string
    authorDisplayName: string
    mentionedUserIds: string[]
    content: string
    postId: string
    commentId?: string
  },
): Promise<void> {
  const requested = [...new Set(args.mentionedUserIds)].filter((id) => id !== args.authorUserId)
  if (requested.length === 0) return

  const { data: memberRows } = await db.from('fellowship_members')
    .select('user_id')
    .eq('fellowship_id', args.fellowshipId)
    .eq('is_active', true)
    .in('user_id', requested)
  const recipients = new Set<string>((memberRows ?? []).map((r: { user_id: string }) => r.user_id))
  if (recipients.size === 0) return

  const { data: blockedRows } = await db.rpc('blocked_user_ids', { p_user_id: args.authorUserId })
  for (const row of (blockedRows ?? []) as { user_id: string }[]) recipients.delete(row.user_id)
  if (recipients.size === 0) return

  const preview = args.content.length > 80 ? args.content.slice(0, 80) + '…' : args.content
  await deliverOrQueue(db, [...recipients],
    { title: `🏷️ ${args.authorDisplayName} mentioned you`, body: preview },
    {
      type: 'fellowship_mention',
      fellowship_id: args.fellowshipId,
      post_id: args.postId,
      ...(args.commentId ? { comment_id: args.commentId } : {}),
    },
    { kind: 'fellowship_mention' })
}

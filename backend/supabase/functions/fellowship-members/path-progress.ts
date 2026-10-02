/**
 * Member progress on a fellowship's learning path.
 *
 * A member's progress is the number of the path's active lessons they have
 * completed — anywhere, alone or with the group — read from
 * user_topic_progress, the same source the learning path detail uses for its
 * lesson ticks. Distinct topics are counted, so a topic listed twice or a
 * duplicate progress row never pushes a member past the path's length.
 */

// deno-lint-ignore no-explicit-any
type Db = { from: (table: string) => any }

/**
 * Counts each member's completed lessons on [pathId]. Every member gets an
 * entry (0 when nothing is completed).
 */
export async function countPathTopicsCompleted(
  db: Db,
  pathId: string,
  userIds: string[],
): Promise<Map<string, number>> {
  const counts = new Map<string, number>(userIds.map((id) => [id, 0]))
  if (userIds.length === 0) return counts

  const { data: pathTopics } = await db
    .from('learning_path_topics')
    .select('topic_id')
    .eq('learning_path_id', pathId)
    .eq('is_active', true)
  const topicIds = [...new Set((pathTopics ?? []).map((r: { topic_id: string }) => r.topic_id))]
  if (topicIds.length === 0) return counts

  const { data: completedRows } = await db
    .from('user_topic_progress')
    .select('user_id, topic_id')
    .in('user_id', userIds)
    .in('topic_id', topicIds)
    .not('completed_at', 'is', null)

  const seen = new Set<string>()
  for (const row of (completedRows ?? []) as { user_id: string; topic_id: string }[]) {
    const key = `${row.user_id}:${row.topic_id}`
    if (seen.has(key) || !counts.has(row.user_id)) continue
    seen.add(key)
    counts.set(row.user_id, counts.get(row.user_id)! + 1)
  }
  return counts
}

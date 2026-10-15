/**
 * Curriculum order for the fellowship path picker: seeker, follower,
 * disciple, leader, then the admin-set display order within a level.
 *
 * The flat listing otherwise comes back in the user's personal order (their
 * in-progress and enrolled paths first), a page at a time. The picker groups
 * paths by level, so a later page's seeker paths landed in the seeker section
 * above the place the mentor had already scrolled past. Ordering the whole
 * list on the server makes every page append below the last one.
 */

const LEVEL_ORDER = ['seeker', 'follower', 'disciple', 'leader']

/** Rank of a disciple level; "believer" is the old name for follower, unknown levels go last. */
export function discipleLevelRank(level: unknown): number {
  const normalised = String(level ?? '').toLowerCase().trim()
  const index = LEVEL_ORDER.indexOf(normalised === 'believer' ? 'follower' : normalised)
  return index === -1 ? LEVEL_ORDER.length : index
}

/** Rows sorted into curriculum order; the incoming (personal) order breaks ties. */
export function inCurriculumOrder<T extends Record<string, unknown>>(rows: readonly T[]): T[] {
  return rows
    .map((row, index) => ({ row, index }))
    .sort((a, b) =>
      discipleLevelRank(a.row.disciple_level) - discipleLevelRank(b.row.disciple_level) ||
      orderOf(a.row) - orderOf(b.row) ||
      a.index - b.index)
    .map(({ row }) => row)
}

/** Paths without a display order go after ordered ones within their level. */
function orderOf(row: Record<string, unknown>): number {
  return typeof row.display_order === 'number' ? row.display_order : Number.MAX_SAFE_INTEGER
}

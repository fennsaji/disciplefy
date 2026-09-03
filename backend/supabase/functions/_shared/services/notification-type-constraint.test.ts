// ============================================================================
// Notification Type / DB Constraint Drift Test
// ============================================================================
// Guards the coupling between the NotificationType union and the CHECK
// constraint on notification_logs.notification_type.
//
// These two drifted in production: the constraint was missing
// 'continue_learning', 'streak_milestone', 'streak_lost' and
// 'memory_verse_overdue'. logNotification() swallows insert errors so a push is
// never failed by a logging problem, which meant the rejected rows were
// invisible — but per-day dedup reads that table, so those notifications were
// never recorded and therefore re-sent on every subsequent run. A user received
// both "Continue Your Study" and "Recommended Topic" from two runs six minutes
// apart before this was caught.
//
// Run with: deno test --allow-read notification-type-constraint.test.ts

import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';

/** Every value the application may pass as a notification type. */
const APPLICATION_TYPES = [
  'daily_verse',
  'recommended_topic',
  'continue_learning',
  'streak_reminder',
  'streak_milestone',
  'streak_lost',
  'memory_verse_reminder',
  'memory_verse_overdue',
] as const;

const HELPER_PATH = new URL('./notification-helper-service.ts', import.meta.url);
const MIGRATIONS_DIR = new URL('../../../migrations/', import.meta.url);

/** Parses the NotificationType union members out of the helper source. */
function readUnionMembers(source: string): string[] {
  const match = source.match(/export type NotificationType\s*=([\s\S]*?)(?:\n\n|\n\/\*\*)/);
  if (!match) throw new Error('Could not locate the NotificationType union');
  return [...match[1].matchAll(/'([a-z_]+)'/g)].map((m) => m[1]).sort();
}

/**
 * Returns the allowed values from the most recent migration that (re)defines
 * the notification_logs type constraint.
 */
async function readConstraintValues(): Promise<string[]> {
  const files: string[] = [];
  for await (const entry of Deno.readDir(MIGRATIONS_DIR)) {
    if (entry.isFile && entry.name.endsWith('.sql')) files.push(entry.name);
  }
  files.sort(); // migration filenames are timestamp-prefixed, so this is chronological

  let latest: string[] | null = null;
  for (const name of files) {
    const sql = await Deno.readTextFile(new URL(name, MIGRATIONS_DIR));
    // Only consider statements that constrain notification_logs' type column.
    if (!/notification_logs/.test(sql)) continue;
    const match = sql.match(/CHECK\s*\(\s*notification_type\s+IN\s*\(([\s\S]*?)\)\s*\)/);
    if (match) {
      latest = [...match[1].matchAll(/'([a-z_]+)'/g)].map((m) => m[1]).sort();
    }
  }
  if (!latest) throw new Error('Could not locate the notification_type CHECK constraint');
  return latest;
}

Deno.test({
  name: 'NotificationType union covers every type the application sends',
  fn: async () => {
    const union = readUnionMembers(await Deno.readTextFile(HELPER_PATH));
    for (const type of APPLICATION_TYPES) {
      assertEquals(
        union.includes(type),
        true,
        `NotificationType union is missing '${type}'`
      );
    }
  },
});

Deno.test({
  name: 'notification_logs CHECK constraint accepts every NotificationType',
  fn: async () => {
    const union = readUnionMembers(await Deno.readTextFile(HELPER_PATH));
    const allowed = await readConstraintValues();

    const missing = union.filter((t) => !allowed.includes(t));
    assertEquals(
      missing,
      [],
      `notification_logs CHECK constraint rejects ${missing.join(', ')} — ` +
        `logNotification() swallows the error, so dedup goes blind and these ` +
        `notifications get re-sent every run. Add them in a new migration.`
    );
  },
});

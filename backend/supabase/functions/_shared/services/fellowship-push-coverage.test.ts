// ============================================================================
// Fellowship Push Coverage Test
// ============================================================================
// Every fellowship push must be two things:
//
//   1. Switchable off  — its type has a PREFERENCE_COLUMN entry, which is what
//      deliverOrQueue consults before sending.
//   2. Quiet-hours aware — it is sent through deliverOrQueue /
//      pushUsersOrQueue / pushMentorsOrQueue, not the raw pushUsers /
//      pushMentors, which go straight to FCM at any hour.
//
// A push that skips either one cannot be silenced by the user and can wake
// them at 3am. This test reads the Edge Function sources so a new push type
// or a call site that reaches for the raw helper fails here rather than in
// someone's night.
//
// Run with: deno test --allow-read fellowship-push-coverage.test.ts

import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';

const FUNCTIONS_DIR = new URL('../../', import.meta.url);

/** Edge Functions that send fellowship pushes. */
const FELLOWSHIP_FUNCTIONS = [
  'fellowship/index.ts',
  'fellowship-posts/index.ts',
  'fellowship-posts/notify.ts',
  'fellowship-posts/discipler-reply.ts',
  'fellowship-comments/index.ts',
  'fellowship-invites/index.ts',
  'fellowship-meetings/index.ts',
  'fellowship-members/index.ts',
  '_shared/services/mention-service.ts',
];

/** The raw helpers, which send immediately and consult no preference. */
const RAW_SENDERS = ['pushUsers', 'pushMentors'];

async function read(relative: string): Promise<string> {
  return await Deno.readTextFile(new URL(relative, FUNCTIONS_DIR));
}

/** Parses the PREFERENCE_COLUMN map's keys out of the service. */
function readPreferenceTypes(source: string): Set<string> {
  const match = source.match(
    /const PREFERENCE_COLUMN: Record<string, string> = \{([\s\S]*?)\n\}/,
  );
  if (!match) throw new Error('Could not locate PREFERENCE_COLUMN in discipler-service.ts');
  return new Set([...match[1].matchAll(/^\s*([a-z_]+):/gm)].map((m) => m[1]));
}

/** Collects `type: 'fellowship_x'` values out of FCM data payloads. */
function readEmittedTypes(source: string): string[] {
  const found = new Set<string>();
  for (const m of source.matchAll(/(?<!notification_)\btype:\s*'(fellowship_[a-z_]+)'/g)) {
    found.add(m[1]);
  }
  return [...found];
}

/**
 * Finds calls to a raw sender. The `OrQueue` variants share the prefix, so the
 * next character has to be `(` for it to be the raw one.
 */
function rawSenderCalls(source: string): string[] {
  const found: string[] = [];
  for (const name of RAW_SENDERS) {
    for (const m of source.matchAll(new RegExp(`\\b${name}\\(`, 'g'))) {
      // Skip the definitions and re-exports inside the service itself.
      const before = source.slice(Math.max(0, m.index! - 30), m.index!);
      if (before.includes('function ') || before.includes('import')) continue;
      found.push(name);
    }
  }
  return found;
}

Deno.test('every fellowship push type can be switched off', async () => {
  const preferenceTypes = readPreferenceTypes(
    await read('_shared/services/discipler-service.ts'),
  );

  const missing: string[] = [];
  for (const file of FELLOWSHIP_FUNCTIONS) {
    for (const type of readEmittedTypes(await read(file))) {
      if (!preferenceTypes.has(type)) missing.push(`${type} (${file})`);
    }
  }

  assertEquals(
    missing,
    [],
    `These fellowship pushes have no preference column, so a user cannot turn ` +
      `them off. Add the column to user_notification_preferences and an entry ` +
      `to PREFERENCE_COLUMN:\n  ${missing.join('\n  ')}`,
  );
});

Deno.test('no fellowship push bypasses quiet hours', async () => {
  const offenders: string[] = [];
  for (const file of FELLOWSHIP_FUNCTIONS) {
    for (const name of rawSenderCalls(await read(file))) {
      offenders.push(`${name} in ${file}`);
    }
  }

  assertEquals(
    offenders,
    [],
    `These call sites send straight to FCM, skipping both the user's ` +
      `preference and their quiet hours. Use the OrQueue variant:\n  ` +
      offenders.join('\n  '),
  );
});

// ============================================================================
// Push Type / Client Routing Drift Test
// ============================================================================
// Guards the coupling between the `type` values the fellowship Edge Functions
// put in their FCM data payloads and the `validTypes` allowlist in the Flutter
// client's _navigateFromNotification.
//
// These drifted: the client only knew 'fellowship_meeting_reminder', so every
// other community push (new post, comment, reaction, question, member joined,
// meeting invite) hit the "unknown notification type" branch and force
// navigated to '/'. The push arrived, the user tapped it, and landed on the
// home screen instead of the thread it was about.
//
// This is the same failure shape as notification-type-constraint.test.ts: a
// producer emitting a value some consumer's allowlist has never heard of.
//
// Run with: deno test --allow-read push-type-routing-drift.test.ts

import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';

const FUNCTIONS_DIR = new URL('../../', import.meta.url);
const CLIENT_NOTIFICATION_SERVICE = new URL(
  '../../../../../frontend/lib/core/services/notification_service.dart',
  import.meta.url,
);

/** Edge Functions that send community pushes straight through FCMService. */
const FELLOWSHIP_FUNCTIONS = [
  'fellowship/index.ts',
  'fellowship-posts/index.ts',
  'fellowship-comments/index.ts',
  'fellowship-invites/index.ts',
  'fellowship-meetings/index.ts',
];

/**
 * Collects the `type: 'x'` values out of FCM data payloads.
 *
 * The data payload is an object literal whose first key is `type`, e.g.
 *   { type: 'fellowship_new_post', fellowship_id: ..., post_id: ... }
 *
 * `notification_type` is deliberately NOT collected: that is the
 * notification_logs column (guarded by notification-type-constraint.test.ts),
 * a different namespace from the FCM data payload the client routes on. They
 * genuinely differ — the meeting invite logs 'meeting_invite' while sending
 * 'fellowship_meeting_invite'.
 */
function readEmittedTypes(source: string): string[] {
  const found = new Set<string>();
  for (const m of source.matchAll(/(?<!notification_)\btype:\s*'([a-z_]+)'/g)) {
    found.add(m[1]);
  }
  return [...found];
}

/** Parses the validTypes set literal out of the Dart client. */
function readClientValidTypes(source: string): string[] {
  const match = source.match(/const validTypes = \{([\s\S]*?)\};/);
  if (!match) throw new Error('Could not locate the validTypes set in notification_service.dart');
  return [...match[1].matchAll(/'([a-z_]+)'/g)].map((m) => m[1]).sort();
}

Deno.test('every fellowship push type is routable by the client', async () => {
  const clientSource = await Deno.readTextFile(CLIENT_NOTIFICATION_SERVICE);
  const validTypes = new Set(readClientValidTypes(clientSource));

  const emitted = new Set<string>();
  for (const relative of FELLOWSHIP_FUNCTIONS) {
    const source = await Deno.readTextFile(new URL(relative, FUNCTIONS_DIR));
    for (const type of readEmittedTypes(source)) emitted.add(type);
  }

  // Sanity: the parser must actually be finding something, otherwise this test
  // passes vacuously the moment the payload shape changes.
  const communityTypes = [...emitted].filter(
    (t) => t.startsWith('fellowship_') || t === 'meeting_invite',
  );
  if (communityTypes.length === 0) {
    throw new Error('Parsed no community push types — the payload shape likely changed');
  }

  const unroutable = communityTypes.filter((t) => !validTypes.has(t)).sort();
  assertEquals(
    unroutable,
    [],
    `These push types are sent by the backend but are not in the client's validTypes, ` +
      `so tapping them navigates to '/' instead of the fellowship: ${unroutable.join(', ')}`,
  );
});

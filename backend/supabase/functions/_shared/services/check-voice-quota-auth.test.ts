// ============================================================================
// check_voice_quota must not answer an unauthenticated call with an allowance
// ============================================================================
// It used to return { quota_limit: 0, quota_remaining: 0, tier: 'free',
// error: ... } for a call with no user, which the app showed as
// "0 of 0 left this month" and treated as "cannot start". The latest
// definition must raise instead.
//
// Run with: deno test --allow-read check-voice-quota-auth.test.ts

import { assert, assertMatch } from 'https://deno.land/std@0.208.0/assert/mod.ts';

const MIGRATIONS_DIR = new URL('../../../migrations/', import.meta.url);

/** Body of the most recent migration that (re)defines check_voice_quota(). */
async function latestDefinition(): Promise<{ file: string; body: string }> {
  const files: string[] = [];
  for await (const entry of Deno.readDir(MIGRATIONS_DIR)) {
    if (entry.isFile && entry.name.endsWith('.sql')) files.push(entry.name);
  }
  files.sort();
  let latest: { file: string; body: string } | null = null;
  for (const file of files) {
    const sql = await Deno.readTextFile(new URL(file, MIGRATIONS_DIR));
    const match = sql.match(
      /CREATE OR REPLACE FUNCTION\s+(?:public\.)?check_voice_quota\(\)[\s\S]*?\$\$([\s\S]*?)\$\$/i,
    );
    if (match) latest = { file, body: match[1] };
  }
  assert(latest, 'no migration defines check_voice_quota()');
  return latest;
}

Deno.test('check_voice_quota raises when there is no user', async () => {
  const { file, body } = await latestDefinition();
  const guard = body.match(/IF v_user_id IS NULL THEN([\s\S]*?)END IF;/);
  assert(guard, `${file}: no unauthenticated guard`);
  assertMatch(guard[1], /RAISE EXCEPTION/, `${file}: guard must raise`);
  assert(
    !/RETURN\s+jsonb_build_object/i.test(guard[1]),
    `${file}: guard must not return a 0-of-0 payload`,
  );
});

Deno.test('check_voice_quota still reports unlimited and the plan limit', async () => {
  const { file, body } = await latestDefinition();
  assertMatch(body, /voice_conversations_monthly/, `${file}: limit source`);
  assertMatch(body, /999999/, `${file}: unlimited marker`);
});

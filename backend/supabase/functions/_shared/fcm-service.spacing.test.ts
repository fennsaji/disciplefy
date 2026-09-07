// ============================================================================
// Cross-Category Notification Spacing Tests (live local Supabase)
// ============================================================================
// getRecentlyNotifiedUserIds() backs excludeRecentlyNotified(), which the four
// scheduled senders (daily verse, recommended topic / continue learning,
// streak reminder / lost / milestone, memory verse reminder / overdue) use to
// avoid bursting several categories at the same user within
// MIN_MINUTES_BETWEEN_NOTIFICATIONS.
//
// Regression: fellowship pushes started writing to notification_logs for
// observability (quiet-hours change), which meant they were unintentionally
// picked up by this same spacing check — a fellowship reply 20 minutes before
// the daily verse would suppress that day's daily verse for an active member.
// Fellowship/Discipler types must be logged but excluded from spacing.
//
// These tests hit the real local Supabase instance (127.0.0.1:54321) and are
// skipped when SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are not set, matching
// the pattern used by fcm-service.integration.test.ts.
//
// Run with:
//   SUPABASE_URL=http://127.0.0.1:54321 \
//   SUPABASE_SERVICE_ROLE_KEY=<service role key> \
//   deno test --allow-env --allow-net fcm-service.spacing.test.ts

import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { getRecentlyNotifiedUserIds } from './fcm-service.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const SKIP = !SUPABASE_URL || !SERVICE_ROLE_KEY;

if (SKIP) {
  console.log('\n' + '='.repeat(60));
  console.log('SKIPPED: fcm-service.spacing.test.ts requires a live local Supabase');
  console.log('  Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (see backend/.env.local)');
  console.log('='.repeat(60) + '\n');
}

const TEST_USER_ID = '99999999-0000-0000-0000-000000000001';

/**
 * notification_logs.user_id has a FK to auth.users, so each test creates and
 * tears down its own throwaway auth user via the admin API rather than
 * depending on a pre-seeded fixture.
 */
async function ensureTestUser(): Promise<void> {
  const supabase = createClient(SUPABASE_URL!, SERVICE_ROLE_KEY!);
  const { error } = await supabase.auth.admin.createUser({
    email: 'spacing-test@test.local',
    email_confirm: true,
    user_metadata: {},
    app_metadata: {},
    id: TEST_USER_ID,
  } as never);
  // Ignore "already exists" from a prior interrupted run.
  if (error && !/already been registered|already exists/i.test(error.message)) {
    throw new Error(`Failed to create test user: ${error.message}`);
  }
}

async function deleteTestUser(): Promise<void> {
  const supabase = createClient(SUPABASE_URL!, SERVICE_ROLE_KEY!);
  await supabase.auth.admin.deleteUser(TEST_USER_ID).catch(() => {});
}

async function insertLog(
  notificationType: string,
  sentAt: Date
): Promise<void> {
  const supabase = createClient(SUPABASE_URL!, SERVICE_ROLE_KEY!);
  const { error } = await supabase.from('notification_logs').insert({
    user_id: TEST_USER_ID,
    notification_type: notificationType,
    title: 'spacing-test',
    body: 'spacing-test',
    language: 'en',
    delivery_status: 'sent',
    sent_at: sentAt.toISOString(),
  });
  if (error) throw new Error(`Failed to insert test log: ${error.message}`);
}

async function cleanup(): Promise<void> {
  const supabase = createClient(SUPABASE_URL!, SERVICE_ROLE_KEY!);
  await supabase.from('notification_logs').delete().eq('user_id', TEST_USER_ID);
}

Deno.test({
  name: 'a recent fellowship_new_post does NOT suppress a due daily_verse',
  ignore: SKIP,
  // supabase-js schedules internal timers (e.g. realtime heartbeats) that
  // outlive a single createClient() call; irrelevant to what these tests
  // verify, so resource/op sanitizers are disabled like the existing
  // fcm-service.integration.test.ts does implicitly via its short-lived client.
  sanitizeOps: false,
  sanitizeResources: false,
  fn: async () => {
    await ensureTestUser();
    await cleanup();
    try {
      // Fellowship push 20 minutes ago — well within the 60-minute spacing
      // window if it were (wrongly) counted.
      await insertLog('fellowship_new_post', new Date(Date.now() - 20 * 60 * 1000));

      const recentlyNotified = await getRecentlyNotifiedUserIds(
        SUPABASE_URL!,
        SERVICE_ROLE_KEY!,
        [TEST_USER_ID],
        60
      );

      assertEquals(
        recentlyNotified.has(TEST_USER_ID),
        false,
        'fellowship_new_post must not count toward cross-category spacing — ' +
          'the daily verse should still be eligible to send'
      );
    } finally {
      await cleanup();
      await deleteTestUser();
    }
  },
});

Deno.test({
  name: 'a recent daily_verse still suppresses a recommended_topic',
  ignore: SKIP,
  // supabase-js schedules internal timers (e.g. realtime heartbeats) that
  // outlive a single createClient() call; irrelevant to what these tests
  // verify, so resource/op sanitizers are disabled like the existing
  // fcm-service.integration.test.ts does implicitly via its short-lived client.
  sanitizeOps: false,
  sanitizeResources: false,
  fn: async () => {
    await ensureTestUser();
    await cleanup();
    try {
      // Scheduled push 20 minutes ago — inside the 60-minute spacing window.
      await insertLog('daily_verse', new Date(Date.now() - 20 * 60 * 1000));

      const recentlyNotified = await getRecentlyNotifiedUserIds(
        SUPABASE_URL!,
        SERVICE_ROLE_KEY!,
        [TEST_USER_ID],
        60
      );

      assertEquals(
        recentlyNotified.has(TEST_USER_ID),
        true,
        'a scheduled daily_verse sent 20 minutes ago should still suppress ' +
          'another scheduled category (recommended_topic) within the 60-minute window'
      );
    } finally {
      await cleanup();
      await deleteTestUser();
    }
  },
});

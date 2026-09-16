// ============================================================================
// Notification Channel Drift Test
// ============================================================================
// Android shows one switch per notification channel. A push whose channel id
// the app never created is shown in the manifest's default channel, so it
// disappears into another category's switch — which is how every fellowship,
// meeting and memory verse push ended up under "Daily Verse".
//
// This guards both halves: every push type the backend can send has a channel,
// and every channel the backend names is one the Flutter app actually creates.
//
// Run with: deno test --allow-read notification-channel-drift.test.ts

import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';
import { CHANNEL_FOR_TYPE, channelIdForType } from '../utils/notification-channels.ts';

const HELPER = new URL('./notification-helper-service.ts', import.meta.url);
const CLIENT_NOTIFICATION_SERVICE = new URL(
  '../../../../../frontend/lib/core/services/notification_service.dart',
  import.meta.url,
);

/** The NotificationType union members the backend can log and send. */
function readNotificationTypes(source: string): string[] {
  const match = source.match(/export type NotificationType =([\s\S]*?)\n\n/);
  if (!match) throw new Error('Could not locate the NotificationType union');
  return [...match[1].matchAll(/'([a-z_]+)'/g)].map((m) => m[1]);
}

/** Channel ids the Dart client registers with Android. */
function readClientChannelIds(source: string): Set<string> {
  const match = source.match(/static const _allAndroidChannels = \[([\s\S]*?)\n  \];/);
  if (!match) throw new Error('Could not locate _allAndroidChannels in notification_service.dart');
  return new Set([...match[1].matchAll(/AndroidNotificationChannel\(\s*'([a-z_]+)'/g)].map((m) => m[1]));
}

Deno.test('every push type has a channel', async () => {
  const types = readNotificationTypes(await Deno.readTextFile(HELPER));
  if (types.length === 0) throw new Error('Parsed no notification types');

  const unmapped = types.filter((t) => !CHANNEL_FOR_TYPE[t]).sort();
  assertEquals(
    unmapped,
    [],
    `These push types have no Android channel, so they land in the default one: ${unmapped.join(', ')}`,
  );
});

Deno.test('every channel the backend names exists in the app', async () => {
  const clientChannels = readClientChannelIds(
    await Deno.readTextFile(CLIENT_NOTIFICATION_SERVICE),
  );
  if (clientChannels.size === 0) throw new Error('Parsed no client channels');

  const backendChannels = new Set([...Object.values(CHANNEL_FOR_TYPE), channelIdForType(undefined)]);
  const missing = [...backendChannels].filter((c) => !clientChannels.has(c)).sort();
  assertEquals(
    missing,
    [],
    `The backend sends these channel ids but the app never creates them: ${missing.join(', ')}`,
  );
});

Deno.test('an unknown type falls back to the general channel', () => {
  assertEquals(channelIdForType(undefined), 'general');
  assertEquals(channelIdForType('something_new'), 'general');
});

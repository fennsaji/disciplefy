// ============================================================================
// Android notification channels
// ============================================================================
// Android groups notifications by channel, and Settings > Notifications lists
// one switch per channel. A push that names no channel is shown in the app
// manifest's default one, so every fellowship, meeting and memory verse push
// used to appear under "Daily Verse" — and turning that off silenced them all.
//
// The ids here must match the channels the Flutter app creates in
// notification_service.dart; notification-channel-drift.test.ts checks that.

/** Channel id for each push type. Keep in step with the app's channel list. */
export const CHANNEL_FOR_TYPE: Record<string, string> = {
  daily_verse: 'daily_verse',

  recommended_topic: 'recommended_topics',
  for_you: 'recommended_topics',
  continue_learning: 'recommended_topics',

  streak_reminder: 'streak_reminders',
  streak_milestone: 'streak_milestones',
  streak_lost: 'streak_reset_motivation',
  achievement_unlocked: 'streak_milestones',

  memory_verse_reminder: 'memory_verse_reminders',
  memory_verse_overdue: 'memory_verse_reminders',

  fellowship_daily_post: 'fellowship_posts',
  fellowship_new_post: 'fellowship_posts',
  fellowship_new_comment: 'fellowship_posts',
  fellowship_reaction: 'fellowship_posts',
  fellowship_question: 'fellowship_posts',

  fellowship_mention: 'fellowship_mentions',

  fellowship_discipler_reply: 'fellowship_discipler',
  fellowship_discipler_activity: 'fellowship_discipler',

  fellowship_meeting: 'fellowship_meetings',
  fellowship_meeting_reminder: 'fellowship_meetings',
  fellowship_meeting_cancelled: 'fellowship_meetings',
  fellowship_meeting_invite: 'fellowship_meetings',
  meeting_invite: 'fellowship_meetings',

  fellowship_member_joined: 'fellowship_updates',
  fellowship_mentor_promoted: 'fellowship_updates',
}

/** The channel a push of this type belongs in; 'general' when unrecognised. */
export function channelIdForType(type: string | undefined): string {
  return (type && CHANNEL_FOR_TYPE[type]) || 'general'
}

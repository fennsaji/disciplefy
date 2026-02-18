/**
 * Rebuilds the marketing_features array for a subscription plan
 * based on the plan's features JSONB.
 *
 * This produces the same 8-item list shown on pricing pages and upgrade screens.
 * Order: Daily Verse → Tokens → Study Modes → Learning Paths →
 *        Memory Verses → Practice Modes → Follow-Up → Disciple AI
 */
export function buildMarketingFeatures(
  features: Record<string, any>
): string[] {
  const items: string[] = []

  // 1. Daily Bible Verse — always available
  items.push('Daily Bible Verse')

  // 2. Study Tokens
  const dailyTokens: number = features.daily_tokens ?? 0
  if (dailyTokens === -1) {
    items.push('Unlimited Study Tokens')
  } else {
    items.push(`${dailyTokens} Study Tokens/Day`)
  }

  // 3. Study Modes — unlimited tokens = full access, limited = limited token note
  if (dailyTokens === -1 || dailyTokens >= 50) {
    items.push('All Study Modes')
  } else {
    items.push('All Study Modes (Limited Tokens)')
  }

  // 4. Guided Learning Paths — always available
  items.push('Guided Learning Paths')

  // 5. Memory Verses
  const memoryVerses: number = features.memory_verses ?? 0
  if (memoryVerses === -1) {
    items.push('Memorize Unlimited Verses')
  } else {
    items.push(`Memorize up to ${memoryVerses} Verses`)
  }

  // 6. Memory Verse Practice Modes
  const practiceModes: number = features.practice_modes ?? 2
  if (practiceModes >= 8) {
    items.push('All 8 Memory Verse Practice Modes')
  } else {
    items.push(`${practiceModes} Memory Verse Practice Modes`)
  }

  // 7. Follow-up questions (second to last)
  const followups: number = features.followups ?? 0
  if (followups === -1) {
    items.push('Unlimited Follow-Up per Study Guide')
  } else if (followups > 0) {
    items.push(`${followups} Follow-Up per Study Guide`)
  } else {
    items.push('Follow-Up on Study Guides — Not Included')
  }

  // 8. Disciple AI — uses voice_conversations_monthly as the session count
  const voiceConversations: number = features.voice_conversations_monthly ?? 0
  if (voiceConversations === -1) {
    items.push('Disciple AI — Unlimited')
  } else if (voiceConversations > 0) {
    items.push(`Disciple AI — ${voiceConversations} Sessions/Month`)
  } else {
    items.push('Disciple AI — Not Included')
  }

  return items
}

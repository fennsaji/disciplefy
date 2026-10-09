/**
 * Follow-up questions allowed per study guide, by plan.
 *
 * Free has no follow-ups (the study_chat flag is off for free); its entry only
 * matters if that flag is turned on. The plan copy in subscription_plans and
 * the admin marketing builder (admin-web/lib/utils/plan-marketing-features.ts)
 * quote these numbers — change them together.
 */
export const FOLLOW_UP_LIMITS: Readonly<Record<string, number>> = {
  free: 3,
  standard: 10,
  plus: 15,
  premium: 20,
}

/** Limit for [plan]; unknown plans get the free limit. */
export function getFollowUpLimit(plan: string): number {
  return FOLLOW_UP_LIMITS[plan] ?? FOLLOW_UP_LIMITS.free
}

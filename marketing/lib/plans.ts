// marketing/lib/plans.ts
// Static plan data — update this when plans change in the DB.

export interface PlanConfig {
  plan_code: string;
  display_name: string;
  price_inr: number;
  credits_label: string;
  marketing_features: string[];
  is_highlighted: boolean;
  badge?: string;
}

export const PLANS: PlanConfig[] = [
  {
    plan_code: "free",
    display_name: "Free",
    price_inr: 0,
    credits_label: "15 credits/day",
    is_highlighted: false,
    marketing_features: [
      "Daily Bible Verse",
      "15 Study Credits/Day",
      "Study Modes (excl. Sermon Outline)",
      "Guided Learning Paths",
      "Memorize up to 3 Verses",
      "2 Practice Modes (1 mode/day per verse)",
      "Join Fellowship Groups",
    ],
  },
  {
    plan_code: "standard",
    display_name: "Standard",
    price_inr: 79,
    credits_label: "40 credits/day",
    is_highlighted: false,
    badge: "Best Value",
    marketing_features: [
      "Daily Bible Verse",
      "40 Study Credits/Day",
      "Voice Discipler — 3 Sessions/Month",
      "Study Modes (excl. Sermon Outline)",
      "5 Follow-Up per Study Guide",
      "Memorize up to 5 Verses",
      "All 8 Practice Modes (2 modes/day per verse)",
      "Join Fellowship Groups",
    ],
  },
  {
    plan_code: "plus",
    display_name: "Plus",
    price_inr: 149,
    credits_label: "60 credits/day",
    is_highlighted: true,
    marketing_features: [
      "Daily Bible Verse",
      "60 Study Credits/Day",
      "Voice Discipler — 10 Sessions/Month",
      "All Study Modes incl. Sermon Outline",
      "10 Follow-Up per Study Guide",
      "Memorize up to 10 Verses",
      "All 8 Practice Modes (3 modes/day per verse)",
      "Create & Lead Fellowship Groups",
    ],
  },
  {
    plan_code: "premium",
    display_name: "Premium",
    price_inr: 499,
    credits_label: "Unlimited credits",
    is_highlighted: false,
    marketing_features: [
      "Daily Bible Verse",
      "Unlimited Study Credits",
      "Voice Discipler — Unlimited",
      "All Study Modes incl. Sermon Outline",
      "Unlimited Follow-Up per Study Guide",
      "Memorize Unlimited Verses",
      "All 8 Practice Modes — Unlimited modes/day",
      "Unlimited Fellowship Groups",

      "Priority Support",
      "Early Access to New Features",
    ],
  },
];

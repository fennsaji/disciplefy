# Tab simplification review (real app, local web build)

Date: 2026-10-07. Walked the local web build at 390×844 as an existing user (gen.check@local.test) and a brand-new account (Ruth New). Screenshots: `docs/ux/audit-screenshots/real-app-*.png`.

## Verdicts

| Page | Verdict | Top reasons | Screens |
|---|---|---|---|
| Generate | Needs simplification | 4 choices before value (Scripture/Topic/Question tabs, language, 5 depth cards, button); credit costs on every card and in the header; "Continue reading" mixes path lessons with own studies | real-app-02-generate, -03-all5, -09-back, -46-new-generate |
| Generate → study guide | Good enough | Opens straight into the guide and streams sections in; clear header (type · mode · time), progress segments, Listen / Ask Discipler | real-app-06-after-tap, -08-streamed |
| Your library (See all) | Minor tweaks | "Your library" with Saved / Recent is a third name for the same guides (Recent Studies, Continue reading); long loading state | real-app-10-see-all |
| Discipler | Good enough | Clear title, Start talking / Type, three example questions. Minor: "3 of 3 left this month" quota chip is the first thing seen | real-app-20-discipler, -49-new-discipler |
| Topics (paths list) | Needs simplification | Streak + Leaderboard, "For you", search, 6 level filters and 6 category rows on one screen; Seeker/Follower/Disciple/Leader jargon and XP on every row; tab says "Topics" but lists Learning Paths of "Topics" | real-app-22-topics, -47-new-topics |
| Path detail | Minor tweaks | Clear list and one "Start Path" button. Minor: "+50 XP" and category on every lesson row; lessons are called Topics | real-app-23-path-detail |
| Lesson (study guide) | Good enough | Same guide screen as Generate; follow-up chips at the end are useful | real-app-24b-lesson-guide |
| Community (list) | Minor tweaks | Cards are clear. Header icons (key = join by code, + with lock = create) are cryptic; floating "Join a Fellowship" duplicates the key icon and covers content | real-app-25-community |
| Community (new user) | Minor tweaks | Empty state is clear with one action, but Home already offers "Disciplefy Official · Join" while Community says "You haven't joined"; the public fellowship should be suggested right here | real-app-48-new-community |
| Fellowship home | Good enough | Studying together card, Meetings, Recent Activity, New Post. Minor: empty "Meetings" row takes space when there are none | real-app-26-group-home, -28-meetings |
| Group lessons | Good enough | Clear "Group is here / Now" marker; "Group moved on" tag repeated on every past lesson is noisy | real-app-27-group-lessons |
| New post | Good enough | Four post types and a text box; simple | real-app-29-new-post |
| Memory Verses (with verses) | Needs simplification | Stats row, Champions/Statistics, language filters, then a long list where every card says "Review" and "x days overdue" in red, which reads as guilt; no single "Review now" action | real-app-30-memory |
| Memory Verses (zero verses) | Minor tweaks | "No Verses Yet" + "Add Your First Verse" is clear, but it opens a 3-way sheet (Daily verse / Suggested / Custom) with category chips; the obvious first action "Save today's verse (John 3:16)" is one level down | real-app-44b-memory-empty-clean, -45-add-verse |
| Settings | Minor tweaks | Long single list (5 sections, ~25 rows). Study-mode preferences, Retake Questionnaire, Replay walkthrough and three policy rows could move under "More"; "Verify your email" banner is useful | real-app-31-settings, -31b-settings-scroll |
| My Plan | Needs simplification | Contradicts reality: says "15 Study Tokens/Day" while Credits says 40, "Memorize up to 3 verses" while the user has 7, "Talk to Discipler — Not included" while it works, "Paid with App Store" on web, "Trial" with "Cancel plan" | real-app-32-my-plan |
| Credits | Minor tweaks | Clear "30 of 40, resets at 5:30 AM". Too many numbers and CTAs at once (used/purchased/total, Get credits, Upgrade, Manage, plan table); "Standard plan" vs "Free until March 31, 2027" is confusing | real-app-33-credits |

## Cross-cutting notes

- Tours still appear on every tab for a new user ("Got it → / Watch video / Skip"), and the notification sheet blocks the first tab visits.
- The same guides have three names: Recent Studies, Continue reading, Your library.
- Credits are shown in four places (Generate header, depth cards, button, Credits page); Discipler has its own separate quota.

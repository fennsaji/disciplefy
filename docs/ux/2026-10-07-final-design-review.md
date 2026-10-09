# Final design review — Disciplefy redesign (13 flows)

Reviewed: `docs/ux/design-final/*.png`. The boards are exported at about 0.5x (phone frames are about 195px wide), so a sizing note of "≈Xpt" means the size on the device.

## Overall verdict

**The core is simple. The outer flows are not, and the boards contradict each other.** Home is good: a verse hero, one path strip and one "Start lesson N" button. The "New for you" banner is also good. The first-run flow, though, has a logic break, and both Memory verses and Account bring back exactly the overload the product goal forbids: 8 practice modes, XP, levels, a leaderboard, "Champions", per-language credit tables and "Study Tokens". The bigger problem is data consistency. Lesson numbers, credit balances, verse limits and topic counts contradict each other from screen to screen, and sometimes inside one screen. Readability is acceptable for headings and buttons. Secondary meta text (≈9–10pt muted grey), dock labels, table column labels and footnotes fall below 12pt across the boards. **No Hindi or Malayalam screen exists beyond the pickers,** so text fit in those scripts is unverified, and that is the largest readability risk.

## Per-flow verdicts

| Flow | Verdict | Top issues (screen) |
|---|---|---|
| First run | **Needs work** | (1) "Home" after signing up at lesson 1 shows 3 done and "Start lesson 4". It should be lesson 2, marked Tomorrow (5 Home). (2) "Choose your first path" appears after sign-up even though the goal was already picked on screen 2 (9 Home). (3) Screen 2 is light theme between two dark screens. The path card says "3 topics · 400 XP" but the path has 8 topics (2, 9). |
| Guest mode | Minor issues | (1) After lesson 3, the dismissible save card offers 3 sign-in buttons, so it competes with "Back to Today" (2 Lesson 3 complete). (2) The "Sign up to start" pills on the next paths are small and tightly packed (3 Path finished). |
| Home | **Good** | (1) The "Memory Verses" header chip and "Reflect on this verse" are a second and third action above the primary one, which is fine but busy. (2) The day labels and meta under the dots are ≈9pt (all). |
| New for you | Minor issues | (1) The Memory banner and the red dot on the Memory Verses chip promote the same thing twice (1). (2) Subtext on the photo banners is low-contrast grey on a dark image, ≈9pt (4, 6). |
| Feature introductions | Minor issues | (1) A designer note ("Opened from the New for you card. Also in Explore all features…") is rendered as UI text on every screen. (2) No board shows "Explore all features", so the reference leads nowhere. (3) XP appears on the path cards (1). |
| Study (Generate) | **Needs work** | (1) The header says 40 credits while the sheet says "only 5 remaining today" (6 Out of credits). (2) The stream is labelled "Quick read · 3 min" but shows 8 progress segments and a Context section that Quick Read doesn't include (3). (3) Gold focus outlines sit flush on the "Choose depth" and "Continue reading" rows and look like layout bugs (4, 7). The all-depths sheet exposes "Lectio Divina" and "Sermon Outline (2x credits)". |
| Learning paths | Minor issues | (1) The Topics tab is titled "Study Topics", the list "Learning Paths" and the items are called "topics", while Home calls them "lessons". (2) The leaderboard ("Join at 200 XP") is gamification jargon for a new believer (8). (3) "250 XP" is shown for paths of both 5 and 8 topics. |
| Lesson / study guide | Minor issues | (1) Home says "Full guide · 10 min" but the guide header says "Standard · 8 min". (2) The guide end stacks three inputs: a post composer, a follow-up chat and Mark complete (2). (3) The "Topic 1 complete" screen here differs from the "Lesson 1 complete" screen in first run. |
| Memory verses | **Needs work** | (1) The test account has 7 verses on Standard, but the plan allows "up to 5 verses" (2 vs Account 1). (2) The empty state's verse of the day is John 3:16 while Home shows Psalm 23:1 (1). (3) "Choose a practice" lists 8 modes with difficulty tags, and Statistics and Champions use "mastered" and a ranking, which is too much (3, 14, 15). |
| Community & fellowships | **Needs work** | (1) The Disciplefy group shows "Lesson 1 · 0 of 8", then "0 of 5", then "Lesson 3 of 8 · 2 done" across screens 1–3. (2) The mentor Lessons header says Lesson 4 while the list highlights 3 as "Now" (11). (3) The daily study post belongs to "Grace Church Fellowship" and shows Matthew 4, but the group studies New Believer Essentials (10). XP also appears in the lesson lists. |
| Discipler | Minor issues | (1) The end-of-conversation sheet asks for stars and Yes/No and a text box, which is three feedback asks (3). (2) The sheets and empty states sit on a blank black background instead of a dimmed chat (3, 6, 7, 8). (3) The "3 of 3 left this month" chip is ≈9pt. |
| Account, plans & credits | **Needs work** | (1) The same allowance is called "40 Study Tokens/Day" in one place and "40 credits" in another (1, 2). (2) The "What a study costs" table has unlabelled EN/HI/ML columns at ≈7pt, and costs that vary by language will confuse users (5). (3) Three badges compete: Most popular, Recommended and Best value (2). |
| Settings | Minor issues | (1) The profile is "Sarah Mathew" while Home greets "Anu" and Community uses "Fenn". (2) "My progress" shows Seeker / Level 1 / 100 XP / achievements, which is jargon (6). (3) The Theme sheet sits on a blank black background (2). |

## Prioritized fixes

**P0, blocks sign-off (logic and data contradictions)**
1. First run: Home after sign-up must show lesson 1 done and lesson 2 as Tomorrow. Remove or skip "Choose your first path" when a goal was already chosen.
2. Pick one test persona (name, current lesson, credits, verse count, verse of the day) and apply it to every board: Anu/Sarah/Fenn, lesson 4 vs 1 vs 3, 40 vs 30 vs 5 credits, Psalm 23 vs John 3:16.
3. Out of credits: the header balance must match the sheet ("5 left").
4. Fix the community lesson state between My fellowships, Fellowship home and Lessons. Fix the mentor screen where the header says 4 and the list says 3. Give the daily post the right group and path.
5. Memory verse count vs plan limit: either raise the Standard limit or show 5 verses.
6. Quick Read streaming should show only Quick Read sections and segment count.

**P1, simplicity and terminology**
7. Use one noun: "lesson" everywhere (Home, path detail, completion, Mark complete, fellowship). Use "credits" and never "Study Tokens". Name the tab and screen the same ("Paths" or "Topics").
8. Remove XP, levels, Seeker, leaderboard and Champions from the new-user surfaces (path cards, lesson lists, intros). Keep them behind My progress, or hide them until opted in.
9. Memory: "Practise now" should pick the mode automatically. Collapse the 8-mode chooser behind "Change mode" and drop the Easy/Medium/Hard tags from the main list.
10. Remove the designer-note footers from the feature intros, or design the "Explore all features" screen they point to.
11. Guide end: keep "Mark complete" primary. Collapse the fellowship post composer and the follow-up chat into secondary buttons.
12. Credits: replace the per-language cost table with one line ("Quick Read 10 · Standard 20"), and show language surcharges only at generation time.

**P2, readability and polish**
13. Raise all meta, caption, dock-label and footnote text to at least 12pt. Lift muted grey on dark to at least 4.5:1, especially the banner subtext over photos.
14. Use one bottom-sheet backdrop (a dimmed real screen) for Theme, Share, Choose path, Discipler sheets and Cancel plan. Render flow-annotation highlights outside the UI (dashed, offset) so they are not read as focus bugs.
15. Add a Hindi and a Malayalam variant of Home, the lesson guide and a banner to check line height, wrapping and button fit. Keep first-run screen 2 in the dark theme.

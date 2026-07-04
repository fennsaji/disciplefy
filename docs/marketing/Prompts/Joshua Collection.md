# Joshua Collection — Google Flow / Veo Video Prompts

Asset library of Google Flow / Veo video-generation prompts featuring **Joshua**, a recurring Disciplefy 3D-animated character, and (starting at Part 2) **Grace**, his female counterpart. Every asset instructs the generator to keep the character's appearance identical to what was "established previously" and to never redesign him/her — the actual appearance spec (hair, exact clothing, age, etc.) lives outside this document (presumably a character model sheet), so this file only carries the *reminder* instruction, not the reference itself.

The source document numbers assets in **two separate sequences that both restart at 001** — see Finding 1 below. This conversion keeps the original numbering but disambiguates the two runs as **Part 1 (Solo Joshua, 001–023)** and **Part 2 (Joshua & Grace, 001–017)**, matching the order they appear in the source file.

## Consistency & Structural Findings

> **Note — two visual systems, not obviously reconciled.** This library's `Style` field is "Premium stylized 3D animation" (Apple-quality rendering, Material 3–inspired colours, semi-realistic proportions) on every single asset. Nothing else in the marketing library uses 3D animation: the Visual Bible (`Strategy/03 Disciplefy Visual Bible.md`) only ever describes photography/live-action guidance (Photography Style, Video Language, Google Flow/Veo Guidelines all reference real light, real locations, real props — animation is never mentioned), the `Daily Devotions.md` prompt generator explicitly requires **"Photorealistic live action... No CGI... No fantasy"**, and `Content_Playbook_Season1_Week2.md` uses **Daniel**, a live-action recurring character, for the same "modern apartment, morning sunlight, open Bible, coffee, notebook" scenario Joshua occupies here almost beat-for-beat (compare Week 2 Monday's visual style to Asset 001/006 below). Joshua/Grace and Daniel appear to be **two unreconciled character tracks for near-identical scenes** — either this is a deliberate second (animated) visual system that the Visual Bible hasn't caught up to documenting yet, or Joshua/Grace should have been unified with Daniel and weren't. Flagging rather than resolving.
>
> **Note — Joshua and Grace are a matched pair, confirmed in this same file.** Part 2 of this document (originally still inside "Joshua Collection.docx") is a set of 17 assets starring "Joshua and Grace, the official Disciplefy animated characters" together, with the same "never redesign" boilerplate applied to both. So the pairing isn't speculative — it's explicit in the source. A standalone `Grace Collection.md` doesn't exist in `docs/marketing/Prompts/` yet (only `Grace Collection.docx`), so cross-checking Grace's solo asset set for drift against her appearance here wasn't possible in this pass.

**Finding 1 — duplicate asset numbering (structural, not fixed).** The source restarts numbering at "Asset 001" partway through the file: Solo Joshua assets run 001–023 sequentially with no gaps or duplicates, then a new "Asset 001 — Studying Scripture Together" begins the Joshua & Grace duo set, which itself runs 001–017 sequentially with no gaps or duplicates. Within each of the two runs the numbering is clean; across the whole document, asset numbers 001–017 each occur **twice** referring to entirely different videos. Kept as two labeled parts here rather than renumbered, since renumbering would break any existing references to "Asset 00X" elsewhere.

**Finding 2 — the "never redesign the character" boilerplate itself drifts in wording.** Five different phrasings of the same continuity instruction appear across the file (list, not just word order, changes each time):
- Asset 001 (Solo): "Maintain the exact same appearance, **hairstyle, facial features, clothing, body proportions** and animation style established previously... Never redesign the character."
- Asset 006 (Solo): same idea, but drops "facial features" and "established previously."
- Asset 011 (Solo) and Asset 019 (Solo): drops "facial features" and shortens "body proportions" to "proportions"; **both also drop the "Never redesign the character" sentence entirely.**
- Asset 001 (Duo): "appearance, clothing, body proportions, **hairstyles** (plural), facial features and animation style established previously... Never redesign the **characters**."
- Asset 009 (Duo): same list as Duo-001 but drops "established previously."

None of this changes what the character actually looks like (no hair colour, clothing colour, or age is ever specified in this document), but the safeguard sentence meant to *prevent* redesign is itself inconsistently copy-pasted — including two assets (011, 019) that quietly drop the explicit "never redesign" instruction altogether. Flagging as a real drift, fixed only cosmetically here (original wording preserved verbatim per asset, not harmonized).

**Finding 3 — formatting collapses in the back half of Part 2.** Duo Assets 001–009 use full labeled fields (Characters/Scene/Camera/Lighting/Style/Mood, plus an implicit Output line). Starting at **Duo Asset 010** through **Duo Asset 017**, the source drops all field labels, the "Create a premium 10-second cinematic animated video" opener, and — inconsistently — the Mood and Output fields (some of 010–017 keep a "No dialogue" line, most don't; none have a Mood line). This reads as the source document getting terser over time rather than a deliberate format. Reconstructed field labels for 010–017 below from context; fields absent in the source are marked *(not specified in source)*.

**Finding 4 — camera/lens language is uniform but photographic.** Every asset (both parts) pairs "Premium stylized 3D animation" with live-action camera vocabulary — 35mm/50mm/85mm lens, "natural handheld feel" (Asset 001, Solo), dolly/orbit/slider/crane moves. This is consistent throughout (not a drift — no asset breaks from stylized-3D to describe photoreal skin/material detail), so it isn't a contradiction between assets, but it is worth noting as a house convention: this whole library speaks in cinematographer's terms about a rendered/animated character, which is unusual and should be intentional rather than a copy-paste leftover from a live-action prompt template.

**Finding 5 — redundant/near-duplicate scenes worth consolidating.** Given the volume, several clusters cover almost the same beat:
- Solo prayer set (Assets 011, 012, 013, 014, 015, 016, 017) — seven variations on "Joshua prays quietly" distinguished mainly by location (desk, balcony, park, kneeling, evening chair, church). Could likely be trimmed to 3–4 without losing coverage.
- Solo Assets 001 and 006 ("Joshua Reading the Bible" / "Joshua Studying with a Notebook") describe essentially the same desk scene and beat sequence (read → write note → pause → continue).
- Duo "Grace points at something in the Bible" motif recurs four times (Assets 009, 011, 014, 016 — context, cross-reference, Joshua's observation, a question) with very similar staging.
- Duo Asset 012 ("Looking at the Same Bible") largely restates Duo Asset 001 ("Studying Scripture Together").

No content was deleted for this — all assets are preserved below — this is a flag for a future editorial pass, not an action taken here.

**Minor fixes made during conversion:** merged fragmented one-sentence-per-line prose into readable paragraphs per field (no wording changed or removed); labeled previously-unlabeled trailing "No dialogue / no text" lines as an **Output** field for consistency with the assets that do label it; normalized field order (Character → Scene → Camera → Lighting → Style → Mood → Output) where the source had it reordered (e.g. Duo Asset 017).

---

## Table of Contents

### Part 1 — Solo Joshua (Assets 001–023)
- [001 — Joshua Reading the Bible](#asset-001--joshua-reading-the-bible)
- [002 — Joshua Writing Notes](#asset-002--joshua-writing-notes)
- [003 — Joshua Turning Bible Pages](#asset-003--joshua-turning-bible-pages)
- [004 — Joshua Highlighting Scripture](#asset-004--joshua-highlighting-scripture)
- [005 — Joshua Reflecting](#asset-005--joshua-reflecting)
- [006 — Joshua Studying with a Notebook](#asset-006--joshua-studying-with-a-notebook)
- [007 — Joshua Comparing Scripture](#asset-007--joshua-comparing-scripture)
- [008 — Joshua Reading by the Window](#asset-008--joshua-reading-by-the-window)
- [009 — Joshua Beginning His Devotion](#asset-009--joshua-beginning-his-devotion)
- [010 — Joshua Ending His Devotion](#asset-010--joshua-ending-his-devotion)
- [011 — Joshua Beginning Prayer](#asset-011--joshua-beginning-prayer)
- [012 — Joshua Prayer Before Bible Study](#asset-012--joshua-prayer-before-bible-study)
- [013 — Joshua Balcony Prayer](#asset-013--joshua-balcony-prayer)
- [014 — Joshua Silent Prayer Walk](#asset-014--joshua-silent-prayer-walk)
- [015 — Joshua Kneeling in Prayer](#asset-015--joshua-kneeling-in-prayer)
- [016 — Joshua Evening Prayer](#asset-016--joshua-evening-prayer)
- [017 — Joshua Praying in Church](#asset-017--joshua-praying-in-church)
- [018 — Joshua Looking Up in Gratitude](#asset-018--joshua-looking-up-in-gratitude)
- [019 — Joshua Holding the Door](#asset-019--joshua-holding-the-door)
- [020 — Joshua Giving His Seat](#asset-020--joshua-giving-his-seat)
- [021 — Joshua Helping Carry Groceries](#asset-021--joshua-helping-carry-groceries)
- [022 — Joshua Listening Attentively](#asset-022--joshua-listening-attentively)
- [023 — Joshua Returning a Lost Wallet](#asset-023--joshua-returning-a-lost-wallet)

### Part 2 — Joshua & Grace (Assets 001–017)
- [001 — Studying Scripture Together](#asset-001--studying-scripture-together)
- [002 — Discussing Scripture](#asset-002--discussing-scripture)
- [003 — Writing Notes Together](#asset-003--writing-notes-together)
- [004 — Walking After Bible Study](#asset-004--walking-after-bible-study)
- [005 — Praying Together](#asset-005--praying-together)
- [006 — Walking Into Church](#asset-006--walking-into-church)
- [007 — Listening During a Bible Study](#asset-007--listening-during-a-bible-study)
- [008 — Serving Together](#asset-008--serving-together)
- [009 — Grace Points to the Context](#asset-009--grace-points-to-the-context)
- [010 — Comparing Notes](#asset-010--comparing-notes)
- [011 — Grace Finds a Cross Reference](#asset-011--grace-finds-a-cross-reference)
- [012 — Looking at the Same Bible](#asset-012--looking-at-the-same-bible)
- [013 — Grace Encourages Joshua to Keep Reading](#asset-013--grace-encourages-joshua-to-keep-reading)
- [014 — Joshua Explains His Observation](#asset-014--joshua-explains-his-observation)
- [015 — Discovering Something Together](#asset-015--discovering-something-together)
- [016 — Grace Asks a Question](#asset-016--grace-asks-a-question)
- [017 — Studying Different Passages Together](#asset-017--studying-different-passages-together)

---

# Part 1 — Solo Joshua Assets

Create a premium 10-second cinematic animated video for each asset below unless noted otherwise.

## Asset 001 — Joshua Reading the Bible

**Character:** Joshua, the official Disciplefy animated character. Maintain the exact same appearance, hairstyle, facial features, clothing, body proportions and animation style established previously. Never redesign the character.

**Scene:** Joshua is sitting alone at his wooden Bible study desk inside his modern apartment during early morning. An open Bible rests naturally on the table beside a leather notebook, fountain pen and ceramic coffee mug. Warm golden sunlight softly enters through the nearby window. Joshua quietly reads Scripture with complete focus. He slowly turns a page, pauses naturally, then continues reading. No exaggerated expressions, no dramatic acting — his body language is peaceful, relaxed and thoughtful.

**Camera:** Single slow push-in. 35mm lens. Natural handheld feel.

**Lighting:** Golden sunrise. Soft warm shadows. Cinematic.

**Style:** Premium stylized 3D animation. Semi-realistic proportions. Apple-quality rendering. Material 3 inspired colours. Warm colour grading. Natural movement.

**Mood:** Peaceful, reflective, hopeful.

**Output:** No dialogue, no lip movement, no subtitles, no logos, no text.

## Asset 002 — Joshua Writing Notes

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua is seated at the same Bible study desk. His Bible remains open. He quietly writes observations inside a leather notebook while occasionally looking back at the Bible. He underlines a sentence, thinks briefly, then continues writing naturally. The scene should feel calm and intentional.

**Camera:** Single slow side slider movement. 50mm lens.

**Lighting:** Warm morning sunlight.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Warm cinematic lighting. Material 3 inspired colours.

**Mood:** Focused, peaceful, reflective.

**Output:** No dialogue, no subtitles, no text.

## Asset 003 — Joshua Turning Bible Pages

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua slowly turns multiple pages of his Bible while searching for another passage. He carefully places one finger on the page before turning it. His movements are slow, intentional and natural. The Bible remains the visual hero.

**Camera:** Close-up. Very slow push-in. 85mm lens.

**Lighting:** Warm natural sunlight. Soft cinematic shadows.

**Style:** Premium stylized 3D animation. Apple-quality rendering. Minimal. Warm. Material 3 inspired.

**Mood:** Quiet, thoughtful, natural.

**Output:** No dialogue, no subtitles, no text.

## Asset 004 — Joshua Highlighting Scripture

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua quietly highlights a Bible passage using a yellow highlighter. He reads the verse once more before gently closing the highlighter. Everything feels slow and intentional.

**Camera:** Top-down cinematic shot. Very subtle movement.

**Lighting:** Warm morning light.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality. Warm cinematic colour grading. Material 3 inspired colours.

**Mood:** Focused, intentional, peaceful.

**Output:** No dialogue, no subtitles, no text.

## Asset 005 — Joshua Reflecting

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua quietly sits beside the open Bible. His notebook remains open. He simply reflects in silence while looking toward the nearby window. His breathing is calm. His expression is peaceful and thoughtful. Avoid dramatic emotions.

**Camera:** Slow orbit. 50mm lens.

**Lighting:** Golden morning sunlight. Soft shadows.

**Style:** Premium stylized 3D animation. Apple-quality rendering. Material 3 inspired colours. Warm cinematic grading.

**Mood:** Stillness, peace, reflection.

**Output:** No dialogue, no subtitles, no text.

## Asset 006 — Joshua Studying with a Notebook

> **Note:** this asset's Character block drops "facial features" and "established previously" relative to Asset 001 — see Finding 2.

**Character:** Joshua, the official Disciplefy animated character. Maintain the exact same appearance, hairstyle, clothing, body proportions and animation style. Never redesign the character.

**Scene:** Joshua sits at his Bible study desk during early morning. An open Bible rests beside a leather notebook. Joshua slowly reads a passage, writes a short note in the notebook, pauses to think, then continues writing. His movements are calm, deliberate and natural. The notebook gradually fills with handwritten observations. The atmosphere feels peaceful and focused.

**Camera:** Single slow push-in. 50mm lens.

**Lighting:** Warm golden sunrise entering through a nearby window. Soft natural shadows.

**Style:** Premium stylized 3D animation. Semi-realistic proportions. Apple-quality rendering. Material 3 inspired colours. Warm cinematic colour grading.

**Mood:** Peaceful, focused, intentional.

**Output:** No dialogue, no lip movement, no subtitles, no logos, no text.

## Asset 007 — Joshua Comparing Scripture

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua studies an open Bible while comparing different passages. He gently flips between bookmarked pages. He occasionally glances at handwritten notes before returning to Scripture. His actions are patient and thoughtful. Avoid dramatic emotions.

**Camera:** Single over-the-shoulder shot with a slow cinematic push-in. 35mm lens.

**Lighting:** Warm morning sunlight. Soft cinematic shadows.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Warm colour grading. Material 3 inspired colours.

**Mood:** Curious, reflective, natural.

**Output:** No dialogue, no subtitles, no text.

## Asset 008 — Joshua Reading by the Window

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua stands quietly beside a large apartment window during sunrise. He holds an open Bible with both hands and slowly reads. After reading, he pauses briefly while looking outside before continuing. Warm sunlight gently illuminates the pages. The room is minimal, modern and peaceful.

**Camera:** Single slow side tracking shot. 50mm lens.

**Lighting:** Golden sunrise. Warm natural light.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Material 3 inspired colours. Warm cinematic colour grading.

**Mood:** Peaceful, hopeful, reflective.

**Output:** No dialogue, no subtitles, no text.

## Asset 009 — Joshua Beginning His Devotion

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua arrives at his Bible study desk carrying his Bible and notebook. He gently places them on the table, sits down comfortably, opens the Bible, and prepares to begin studying. Everything feels calm and intentional. Avoid exaggerated acting.

**Camera:** Wide shot with a slow push-in. 35mm lens.

**Lighting:** Warm early morning sunlight. Soft shadows.

**Style:** Premium stylized 3D animation. Apple-quality rendering. Material 3 inspired colours. Warm cinematic lighting.

**Mood:** Fresh beginning, peaceful, calm.

**Output:** No dialogue, no subtitles, no text.

## Asset 010 — Joshua Ending His Devotion

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua gently closes his Bible after finishing his study. He closes his notebook, takes a quiet moment of reflection, smiles softly, then stands up carrying both the Bible and notebook as he leaves the room. The study desk remains neat and peaceful.

**Camera:** Single slow pull-back. 50mm lens.

**Lighting:** Golden morning sunlight. Warm soft shadows.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Material 3 inspired colours. Warm cinematic colour grading.

**Mood:** Peace, completion, hope.

**Output:** No dialogue, no lip movement, no subtitles, no logos, no text.

## Asset 011 — Joshua Beginning Prayer

> **Note:** this asset's Character block drops "facial features" and shortens "body proportions" to "proportions" — and is the first asset to drop the "Never redesign the character" sentence entirely. See Finding 2.

**Character:** Joshua, the official Disciplefy animated character. Maintain the exact same appearance, clothing, hairstyle, proportions and animation style.

**Scene:** Joshua sits quietly at his Bible study desk during early morning. An open Bible rests on the wooden table beside a leather notebook, fountain pen and ceramic coffee mug. Joshua gently closes his eyes. He slowly folds both hands together. He remains still in silent prayer. The scene should feel peaceful and intimate. Avoid dramatic emotions.

**Camera:** Single slow push-in. 50mm lens.

**Lighting:** Warm golden sunrise entering through a nearby window. Soft natural shadows.

**Style:** Premium stylized 3D animation. Semi-realistic proportions. Apple-quality rendering. Warm cinematic colour grading. Material 3 inspired colours.

**Mood:** Peaceful, prayerful, hopeful.

**Output:** No dialogue, no lip movement, no subtitles, no text, no logos.

## Asset 012 — Joshua Prayer Before Bible Study

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua opens his Bible on the desk. Before reading, he gently places one hand on the Bible while quietly bowing his head in prayer. After a few peaceful moments, he slowly opens his eyes and begins reading. Everything feels natural and unhurried.

**Camera:** Slow side slider. 35mm lens.

**Lighting:** Warm early morning sunlight.

**Style:** Premium stylized 3D animation. Apple-quality rendering. Material 3 inspired colours. Warm cinematic lighting.

**Mood:** Quiet, focused, peaceful.

**Output:** No dialogue, no subtitles, no text.

## Asset 013 — Joshua Balcony Prayer

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua stands alone on the balcony of his apartment during sunrise. He looks toward the horizon. After a few seconds he gently folds his hands and quietly prays. The wind softly moves his shirt. Trees sway gently in the distance. The city slowly wakes up below.

**Camera:** Single slow orbit. 50mm lens.

**Lighting:** Golden sunrise. Warm natural light.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Warm cinematic colour grading. Material 3 inspired colours.

**Mood:** Hope, peace, reflection.

**Output:** No dialogue, no subtitles, no text.

## Asset 014 — Joshua Silent Prayer Walk

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua walks slowly through a peaceful park during golden hour. He carries a closed Bible in one hand. His head is slightly lowered in quiet prayer and reflection. He occasionally looks toward the trees and sky before continuing his walk. The atmosphere is calm and restorative.

**Camera:** Single tracking shot. 35mm lens.

**Lighting:** Golden morning light.

**Style:** Premium stylized 3D animation. Apple-quality rendering. Warm cinematic colour grading. Material 3 inspired colours.

**Mood:** Quiet, hopeful, reflective.

**Output:** No dialogue, no subtitles, no text.

## Asset 015 — Joshua Kneeling in Prayer

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Inside his apartment beside the study desk, Joshua kneels quietly beside a chair. His Bible rests open on the seat. He remains still in silent prayer. The room is peaceful. Nothing dramatic happens. The scene communicates humility and dependence on God.

**Camera:** Single slow push-in. 85mm lens.

**Lighting:** Warm window light. Soft shadows.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Material 3 inspired colours. Warm cinematic lighting.

**Mood:** Reverent, peaceful, still.

**Output:** No dialogue, no subtitles, no text.

## Asset 016 — Joshua Evening Prayer

> **Note:** first asset to depart from the recurring golden-morning-sunrise lighting for an evening/lamp setting — an intentional variation, not a contradiction, but flagged since it breaks the otherwise-uniform time-of-day across the collection.

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua sits in a comfortable chair beside a softly lit lamp after sunset. His Bible is open on his lap. He quietly closes the Bible, folds his hands, and spends a few peaceful moments in silent evening prayer. The room feels warm and restful.

**Camera:** Single slow push-in. 50mm lens.

**Lighting:** Warm table lamp. Soft ambient evening light.

**Style:** Premium stylized 3D animation. Apple-quality rendering. Warm cinematic colour grading. Material 3 inspired colours.

**Mood:** Peace, rest, gratitude.

**Output:** No dialogue, no subtitles, no text.

## Asset 017 — Joshua Praying in Church

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua sits quietly alone on a wooden church pew. An open Bible rests beside him. He bows his head in silent prayer. Warm sunlight shines through stained-glass windows, creating soft patterns of light across the floor. The church is empty, peaceful, and reverent.

**Camera:** Single slow dolly-in. 50mm lens.

**Lighting:** Natural sunlight through church windows. Warm cinematic tones.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Material 3 inspired colours.

**Mood:** Worship, peace, reverence.

**Output:** No dialogue, no subtitles, no text.

## Asset 018 — Joshua Looking Up in Gratitude

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua stands outdoors during sunrise in a quiet open field. He closes his eyes briefly, takes a deep breath, then slowly looks toward the bright morning sky with a gentle smile of gratitude. His Bible remains tucked under one arm. The scene communicates thankfulness without dramatic emotion.

**Camera:** Single slow crane movement. 35mm lens.

**Lighting:** Golden sunrise. Warm natural light.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Warm cinematic colour grading. Material 3 inspired colours.

**Mood:** Gratitude, hope, joy.

**Output:** No dialogue, no subtitles, no text.

## Asset 019 — Joshua Holding the Door

> **Note:** like Asset 011, this Character block drops "facial features," shortens "body proportions" to "proportions," and omits "Never redesign the character." This asset also opens a new "everyday discipleship" mini-arc (019–023) that steps away from the apartment desk into public settings (office lobby, metro, neighbourhood, coffee shop, park) — a deliberate location expansion, not an appearance drift, but noted since it's the first clear departure from the established desk/apartment setting.

**Character:** Joshua, the official Disciplefy animated character. Maintain the exact same appearance, clothing, hairstyle, proportions and animation style.

**Scene:** Joshua stands outside the entrance of a modern office building. As another person approaches carrying several books, Joshua notices them and naturally holds the glass door open. He smiles politely while waiting. The other person walks through. Joshua then quietly follows. The interaction feels natural and unforced.

**Camera:** Single medium-wide shot. Slow cinematic push-in. 35mm lens.

**Lighting:** Warm morning sunlight. Soft natural shadows.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Material 3 inspired colours. Warm cinematic colour grading.

**Mood:** Kindness, humility, everyday discipleship.

**Output:** No dialogue, no lip movement, no subtitles, no text, no logos.

## Asset 020 — Joshua Giving His Seat

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua sits on a metro train. He notices an elderly passenger entering. Without hesitation, Joshua stands up and respectfully offers his seat. He remains standing quietly while the elderly person sits down. The atmosphere feels calm and genuine.

**Camera:** Single side shot. Slow tracking movement. 50mm lens.

**Lighting:** Natural daylight through train windows.

**Style:** Premium stylized 3D animation. Warm cinematic rendering. Material 3 inspired colours.

**Mood:** Respect, kindness, humility.

**Output:** No dialogue, no subtitles, no text.

## Asset 021 — Joshua Helping Carry Groceries

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua notices an elderly neighbour carrying several grocery bags. He politely offers to carry one of the bags. They walk together naturally for a few steps. Joshua hands the bag back near the apartment entrance. The interaction feels authentic and respectful.

**Camera:** Single slow tracking shot. 35mm lens.

**Lighting:** Golden evening sunlight.

**Style:** Premium stylized 3D animation. Apple-quality rendering. Warm cinematic colour grading. Material 3 inspired colours.

**Mood:** Service, compassion, kindness.

**Output:** No dialogue, no subtitles, no text.

## Asset 022 — Joshua Listening Attentively

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua sits across from a friend in a quiet coffee shop. While the friend speaks, Joshua listens attentively without interrupting. He maintains eye contact, nods gently, and gives the speaker his full attention. The scene communicates care through listening rather than speaking.

**Camera:** Single medium shot. Slow push-in. 50mm lens.

**Lighting:** Warm café lighting.

**Style:** Premium stylized 3D animation. Apple-quality rendering. Warm colour grading. Material 3 inspired colours.

**Mood:** Compassion, presence, friendship.

**Output:** No dialogue, no lip movement, no subtitles, no text.

## Asset 023 — Joshua Returning a Lost Wallet

**Character:** Use the official Disciplefy Joshua character.

**Scene:** Joshua notices a wallet lying on a park bench. He picks it up, looks around, notices its owner nearby, and respectfully returns it. The owner smiles gratefully. Joshua smiles politely before continuing his walk. The interaction feels simple and honest.

**Camera:** Single tracking shot. 35mm lens.

**Lighting:** Warm afternoon sunlight.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Material 3 inspired colours. Warm cinematic grading.

**Mood:** Integrity, honesty, kindness.

**Output:** No dialogue, no subtitles, no text.

---

# Part 2 — Joshua & Grace Duo Assets

> **Note:** numbering restarts at 001 here in the source document — see Finding 1. Create a premium 10-second cinematic animated video for each asset below unless noted otherwise.

## Asset 001 — Studying Scripture Together

**Characters:** Joshua and Grace, the official Disciplefy animated characters. Maintain the exact same appearance, clothing, body proportions, hairstyles, facial features and animation style established previously. Never redesign the characters.

**Scene:** Joshua and Grace sit across from each other at a wooden table inside a modern apartment during early morning. An open Bible rests between them beside a leather notebook, fountain pen and ceramic coffee mugs. Both quietly read the same Bible passage together. Joshua slowly turns one page while Grace follows along attentively. Neither character speaks. The interaction feels peaceful, natural and focused on God's Word.

**Camera:** Single slow push-in. 35mm lens.

**Lighting:** Warm golden sunrise entering through a nearby window. Soft natural shadows.

**Style:** Premium stylized 3D animation. Semi-realistic proportions. Apple-quality rendering. Material 3 inspired colours. Warm cinematic colour grading.

**Mood:** Peaceful, focused, hopeful.

**Output:** No dialogue, no lip movement, no subtitles, no text, no logos.

## Asset 002 — Discussing Scripture

**Characters:** Use the official Disciplefy Joshua and Grace characters.

**Scene:** Joshua and Grace sit together at a wooden Bible study table. An open Bible lies between them. Grace gently gestures toward a passage while Joshua listens attentively with a thoughtful expression. Joshua nods naturally before both return their attention to the Bible. The interaction is quiet and respectful.

**Camera:** Single medium shot. Slow cinematic push-in. 50mm lens.

**Lighting:** Warm morning sunlight.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Warm cinematic lighting. Material 3 inspired colours.

**Mood:** Learning, friendship, reflection.

**Output:** No dialogue, no subtitles, no text.

## Asset 003 — Writing Notes Together

**Characters:** Use the official Disciplefy Joshua and Grace characters.

**Scene:** Joshua and Grace sit side by side at a wooden study table. Both quietly write notes in separate journals while occasionally looking back at the same open Bible. Everything feels calm and intentional.

**Camera:** Single side tracking shot. 50mm lens.

**Lighting:** Warm natural morning light.

**Style:** Premium stylized 3D animation. Apple-quality rendering. Material 3 inspired colours. Warm cinematic grading.

**Mood:** Wisdom, reflection, peace.

**Output:** No dialogue, no subtitles, no text.

## Asset 004 — Walking After Bible Study

**Characters:** Use the official Disciplefy Joshua and Grace characters.

**Scene:** Joshua and Grace walk together through a peaceful park after finishing Bible study. Each carries a closed Bible naturally. They enjoy the quiet morning together without speaking. The atmosphere feels calm and encouraging.

**Camera:** Single tracking shot. 35mm lens.

**Lighting:** Golden morning sunlight filtering through trees.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Warm cinematic colour grading.

**Mood:** Peace, friendship, hope.

**Output:** No dialogue, no subtitles, no text.

## Asset 005 — Praying Together

**Characters:** Use the official Disciplefy Joshua and Grace characters.

**Scene:** Joshua and Grace sit beside each other at a wooden Bible study table. Their open Bibles remain on the table. Both quietly bow their heads in silent prayer. The room is peaceful and still.

**Camera:** Single slow push-in. 50mm lens.

**Lighting:** Warm sunrise. Soft natural shadows.

**Style:** Premium stylized 3D animation. Apple-quality rendering. Material 3 inspired colours. Warm cinematic lighting.

**Mood:** Prayer, peace, reverence.

**Output:** No dialogue, no lip movement, no subtitles, no text.

## Asset 006 — Walking Into Church

**Characters:** Use the official Disciplefy Joshua and Grace characters.

**Scene:** Joshua and Grace walk side by side toward the entrance of a modern church on a bright Sunday morning. Each carries a Bible naturally. They smile warmly as they approach the church doors. The atmosphere feels welcoming and peaceful.

**Camera:** Single wide tracking shot. 35mm lens.

**Lighting:** Warm morning sunlight.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Material 3 inspired colours. Warm cinematic colour grading.

**Mood:** Joy, community, hope.

**Output:** No dialogue, no subtitles, no text.

## Asset 007 — Listening During a Bible Study

**Characters:** Use the official Disciplefy Joshua and Grace characters.

**Scene:** Joshua and Grace sit together in a small group Bible study. An open Bible rests on each of their laps. They listen attentively to someone speaking off-camera. Joshua occasionally nods while Grace quietly follows a passage in her Bible.

**Camera:** Single medium shot. Slow cinematic push-in. 50mm lens.

**Lighting:** Warm indoor lighting.

**Style:** Premium stylized 3D animation. Apple-quality rendering. Material 3 inspired colours. Warm cinematic grading.

**Mood:** Learning, community, peace.

**Output:** No dialogue, no subtitles, no text.

## Asset 008 — Serving Together

**Characters:** Use the official Disciplefy Joshua and Grace characters.

**Scene:** Joshua and Grace arrange chairs inside a church hall before a Bible study gathering. They work together quietly and naturally. They occasionally exchange warm smiles while continuing to serve. The atmosphere feels peaceful and joyful.

**Camera:** Single wide shot. Slow side slider. 35mm lens.

**Lighting:** Warm natural daylight entering through church windows.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Material 3 inspired colours. Warm cinematic colour grading.

**Mood:** Service, humility, community.

**Output:** No dialogue, no subtitles, no text.

## Asset 009 — Grace Points to the Context

> **Note:** Output field here reads "No dialogue, no lip movement, no text" — omitting "no subtitles," present in most other assets' Output fields. Preserved as-is (not fabricated).

**Characters:** Joshua and Grace, the official Disciplefy animated characters. Maintain the exact same appearance, clothing, hairstyles, body proportions, facial features and animation style.

**Scene:** Joshua and Grace sit together at a wooden Bible study table. An open Bible lies between them. Joshua carefully reads a single verse while thinking quietly. Grace gently points to the surrounding verses on the same page, encouraging Joshua to continue reading the passage. Joshua smiles slightly and continues reading further down the page. The interaction feels natural, respectful and collaborative.

**Camera:** Single over-the-shoulder shot. Slow cinematic push-in. 50mm lens.

**Lighting:** Warm morning sunlight.

**Style:** Premium stylized 3D animation. Semi-realistic. Apple-quality rendering. Warm cinematic colour grading.

**Mood:** Discovery, learning, friendship.

**Output:** No dialogue, no lip movement, no text.

## Asset 010 — Comparing Notes

> **Note:** from here through Asset 017, the source drops field labels, the "Create a premium 10-second..." opener, and the Mood field entirely — see Finding 3. Fields below are reconstructed from context; anything the source truly omitted is marked *(not specified in source)*.

**Scene:** Joshua and Grace sit beside each other after reading Scripture. Each has a leather journal. Grace quietly slides her notebook toward Joshua. Joshua reads one observation, smiles with appreciation, then returns to his own notebook and continues writing. The interaction communicates learning from one another.

**Camera:** Single slow push-in.

**Lighting:** Warm sunrise.

**Style:** Premium stylized 3D animation.

**Mood:** *(not specified in source)*

**Output:** No dialogue, no text.

## Asset 011 — Grace Finds a Cross Reference

**Scene:** Joshua studies an open Bible while looking thoughtful. Grace quietly notices a cross-reference in the margin. She gently points to it. Joshua follows her finger, turns a few pages, and begins reading the referenced passage. Both continue studying together peacefully.

**Camera:** Single slow side slider.

**Lighting:** Warm morning light.

**Style:** Premium stylized 3D animation.

**Mood:** *(not specified in source)*

**Output:** No dialogue, no subtitles.

## Asset 012 — Looking at the Same Bible

**Scene:** Joshua and Grace stand together beside a wooden table. Both lean slightly toward the same open Bible. Joshua slowly turns the page while Grace follows along attentively. Neither speaks. The focus remains entirely on God's Word.

**Camera:** Single slow push-in.

**Lighting:** Warm cinematic lighting.

**Style:** Premium stylized 3D animation.

**Mood:** *(not specified in source)*

**Output:** *(not specified in source)*

## Asset 013 — Grace Encourages Joshua to Keep Reading

**Scene:** Joshua pauses after reading a short passage. Grace gently smiles and lightly gestures toward the next section of Scripture. Joshua nods naturally and continues reading. The interaction feels encouraging rather than instructional.

**Camera:** Single medium shot.

**Lighting:** Warm sunrise.

**Style:** Premium stylized 3D animation.

**Mood:** *(not specified in source)*

**Output:** *(not specified in source)*

## Asset 014 — Joshua Explains His Observation

**Scene:** Joshua quietly points to a verse in the Bible while Grace listens attentively. Grace looks thoughtfully at the passage before nodding in agreement. Both continue reading together. The interaction feels like two friends studying Scripture together.

**Camera:** Single slow push-in.

**Lighting:** Warm cinematic lighting.

**Style:** Premium stylized 3D animation.

**Mood:** *(not specified in source)*

**Output:** *(not specified in source)*

## Asset 015 — Discovering Something Together

**Scene:** Joshua and Grace both read an open Bible. After a few moments they naturally look at each other with quiet smiles before returning their attention to the Bible. The moment communicates shared understanding without exaggeration.

**Camera:** Single cinematic push-in.

**Lighting:** Golden morning sunlight.

**Style:** Premium stylized 3D animation.

**Mood:** *(not specified in source)*

**Output:** No dialogue, no subtitles.

## Asset 016 — Grace Asks a Question

**Scene:** Joshua reads Scripture quietly. Grace gently points toward a verse with a curious expression, as though asking a thoughtful question. Joshua looks back at the passage and begins reading the surrounding verses. Both remain focused on Scripture.

**Camera:** Single over-the-shoulder shot.

**Lighting:** Warm cinematic morning light.

**Style:** Premium stylized 3D animation.

**Mood:** *(not specified in source)*

**Output:** *(not specified in source)*

## Asset 017 — Studying Different Passages Together

> **Note:** the source lists Style ("Premium stylized 3D animation") before what looks like a Lighting descriptor ("Warm cinematic colour grading"), and never gives a Lighting field at all. Reordered here for consistency; content unchanged. Also has no Mood or Output field.

**Scene:** Joshua and Grace each have an open Bible. Joshua reads one passage while Grace reads another. After a few moments they exchange Bibles briefly to compare passages before continuing to study. Everything feels calm, natural and intentional.

**Camera:** Single slow tracking shot.

**Lighting:** *(not specified in source)*

**Style:** Premium stylized 3D animation. Warm cinematic colour grading.

**Mood:** *(not specified in source)*

**Output:** *(not specified in source)*

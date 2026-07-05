# Disciplefy Content Playbook — Season 1: Foundations of Faith
## Week 1 — Launch Week
Version: 4.3 *(rewritten — see Changelog)*

## Mission of the Week
Get the app in front of people and prove it works — before teaching the deeper "reading vs. studying" theme that Weeks 2-4 build on. Week 1 is 5 screen-recording Reels — Monday's app-intro (Play Store → open → onboarding → login) plus 4 How-To Reels Tue-Fri (the Launch post itself already went out Friday before this formal week) — not the regular Bible Explained/Bible Tips rhythm, which starts fresh in Week 2 (see `Content_Playbook_Season1_Week2.md`).

## Why Week 1 looks different from the rest of the season
The 4 core features (Generate Study Guide, Learning Paths, Memory Verses, Discipler) needed to be visible in the channel fast, and screen-recording Reels beat Carousels for that specific job this week: Reels get ~2.35x more reach than static posts and ~1.4x more than Carousels, and showing the app actually working in motion builds more install-driving trust than static screenshots. So Mon-Fri are now Reels (real screen recording + Founder voice-over), not Carousels — Monday introduces the app itself (Play Store install through login), then Tue-Fri are the 4 How-To Reels.

**This also folds in what used to be a separate Saturday-series reel:** Tuesday's Generate Study Guide Reel already covers that feature in tutorial form, so Episode 1 of the `Daily Devotion/Saturday — Disciplefy Stories.md` arc isn't needed this week — the story arc picks up cleanly at Episode 2 (Learning Paths) in Week 2 as already planned, nothing lost. That leaves Saturday open this week — acceptable for a one-off launch week (no day is hardcoded off; this is the natural gap from compressing 5 pieces of content into a Mon-Fri run). Fill it with community/reply work, or leave as slack if anything above slips.

## Content Funnel
Instagram Reel / Carousel → Profile Visit → disciplefy.in → App Install → Bible Study → Spiritual Growth

---

## 🎬 Video Generation Prompts — Intro / Outro (Google Flow / Veo)
Reusable across all 5 Monday-Friday Reels — the same two generated clips bookend every video; only the real Disciplefy screen-recording in the middle changes per day. Full detail also kept standalone at `Week1_Reel_Intro_Outro_Google_Flow_Prompts.md` — this section embeds the same prompts directly so this file is self-contained.

**STYLE BLOCK (prepend to both prompts below):**
> Premium, warm, cinematic short video clip for a Christian discipleship app called **Disciplefy**, used as an Instagram Reel intro/outro segment. Portrait **9:16**. Warm, golden-hour or soft window lighting — reverent, peaceful, hopeful, premium. **Slow, intentional pacing**: fade, slow zoom, soft dissolve, gentle light bloom. **No** fast cuts, whip pans, spinning, or aggressive animation. Setting: a quiet home or coffee-shop workspace, warm wood tones, soft natural light, subtle film grain, organic feel — never overly sharp or artificial. **No other apps, phone UI, or on-screen branding besides Disciplefy's own logo where explicitly noted.** Avoid: cheesy stock-photo feel, clip-art crosses, corporate look, garbled text.

**Intro prompt (reusable, ~3-5s):**
> No people in frame — a still-life scene on a warm wooden desk in soft morning window light: an open physical Bible, a ceramic coffee mug with gentle steam, a small potted plant, a leather journal with a pen resting on it. Slow, gentle camera push-in or soft pan across the desk. Warm, cinematic, reverent, quiet mood. No text rendered in-clip — each day's specific hook line (see that day's Script/Timeline) is added as a text overlay in edit.

**Outro prompt (reusable, ~3-4s):**
> Warm, premium closing card for Disciplefy. Soft cream/warm-gold gradient background with gentle light bloom. **Use the attached logo image** (gold open-book-with-cross icon + "Disciplefy" wordmark) — it gently fades and rises into the center of frame with a soft glow, no harsh motion, keeping the logo's real shape and type intact (don't regenerate or redraw it). Logo only — no additional text; the caption already carries "link in bio."

*Attach the actual logo file as a reference image in Google Flow when generating the Outro — don't let the model invent its own logo, AI-drawn logos/text are unreliable. If it distorts when animated, generate the empty gradient card instead and composite the real static logo on top in edit.*

## 🖼️ Thumbnail Image Generation — STYLE BLOCK (prepend to each day's thumbnail prompt below)
> Premium, warm thumbnail frame for a Disciplefy Instagram Reel. Portrait **9:16 (1080×1920)**, safe-zone aware — keep the headline and focal object clear of the top ~250px and bottom ~250px (reserved for Instagram's own UI overlays). Soft cream background (`#FAF8F5`) bathed in natural window light. Bold near-black charcoal (`#1E1E1E`) headline, Poppins 700, **maximum five words**. One clear focal object only — no busy collage, no clutter. One small gold (`#B8860B`) accent only (icon, divider, or bookmark ribbon) — gold should never dominate. Brand frame: small gold Disciplefy logo top-left with a thin gold divider beneath; small gold globe icon + "disciplefy.in" bottom-left. **Never:** red arrows, shock faces, clickbait expressions, clip-art crosses, busy collages.

## 📖 Daily Verse — Morning Story Image Generation
Adapted from `Prompts/Daily Bible Verse v2.md` (issues resolved: no Material 3/indigo, AI-imagery contradiction reworded, typography in the documented 600-700 range, IG safe-zone added) — but **not one fixed layout every day**. Instead, 7 distinct layout variants, one locked to each weekday, so the series stays visually fresh day-to-day while each weekday builds its own recognizable sub-identity (canonical set — reused across all 4 weeks, only Verse/Reference/Background change).

**Shared across every variant (brand consistency, never varies):**
> Christian discipleship app Disciplefy, Instagram Story, 1080×1920 (9:16). Warm, peaceful, premium, minimal, cinematic, Scripture-first. Photorealistic — must not look AI-generated, illustrated, or fantasy-styled. Color palette: cream `#FAF8F5` · gold accent `#B8860B`/`#C79A3B` · heading charcoal `#1E1E1E` · body `#4B5563`. Poppins Bold (heading/reference, 600-700 weight) · Inter Medium (verse text) — never shrink text for a long verse, grow the card/space instead. Disciplefy logo used exactly as uploaded, never regenerated. Keep logo, heading, and footer clear of the top ~250px / bottom ~250px IG Story safe zones. No people, no hands, no distracting objects — Scripture stays the visual hero. *(English-only for now — Hindi/Malayalam need a separate font pairing, not yet defined.)*

**Monday — Variant A: Classic Card**
> Realistic background scene per `{{BACKGROUND}}`, softly lit. Centered scripture card (~55% of frame), rounded 12px, warm gold background, soft shadow, large quotation-mark icon, reference at top, verse centered, generous padding. Top: logo + gold divider + "Today's Verse" heading. Bottom: "disciplefy.in" + small gold divider.

**Tuesday — Variant B: Full-Bleed Photo Overlay**
> Full-bleed photorealistic scene per `{{BACKGROUND}}` filling the entire frame — no separate card. Verse and reference overlaid directly on the photo in the bottom third, sitting on a soft gold-tinted gradient scrim (dark-to-transparent) for readability. Small logo top-left, no heading text needed. More editorial/cinematic than Monday's card style.

**Wednesday — Variant C: Split Layout**
> Frame split horizontally: top 60% is the photorealistic scene per `{{BACKGROUND}}`; bottom 40% is a solid warm-cream panel holding the verse + reference in charcoal text, with a thin gold divider marking the split. Logo small, top-left, sitting over the photo section.

**Thursday — Variant D: Minimalist Typography**
> No photo — solid warm cream background or a very soft cream-to-gold gradient. Large gold quotation mark, verse in big centered Inter Medium type, reference in gold Poppins Bold beneath, generous whitespace all around. Logo small, top-center. Words are the hero this day, a deliberate change of pace from the photo-driven variants.

**Friday — Variant E: Framed Photo**
> A single photorealistic scene per `{{BACKGROUND}}`, styled as a framed photograph or polaroid-style card, very slightly tilted, soft drop shadow, resting on a warm cream background. Verse + reference sit beneath the framed photo like a caption. Small gold pin or clip accent at the photo's top edge. Logo small, top-left of the whole frame.

**Saturday — Variant F: Side-by-Side**
> Frame split vertically down the middle: left half is a soft off-white verse card (reference top, verse centered, quotation icon) on cream; right half is the photorealistic scene per `{{BACKGROUND}}`. Thin vertical gold divider between the two halves. Logo small, top-left over the card half.

**Sunday — Variant G: Vertical Bookmark**
> A tall, narrow "bookmark"-shaped card (rounded top, tapered bottom point) centered on a softly blurred, warm photorealistic background per `{{BACKGROUND}}`. Verse + reference run down the bookmark in elegant vertical-feeling spacing. Small gold tassel or ribbon detail at the bookmark's top. Logo small, top-left of the whole frame. Reflective, quieter mood fitting Sunday.

---

## Monday — 📲 Meet Disciplefy
**Format:** Reel — real screen recording + Founder voice-over (app-intro; Tue-Fri are the How-To Reels for the 4 core features)
**Bible Verse:** Nehemiah 8:8 — "...and they gave the sense, so that the people understood the reading."

**Thumbnail:** "Meet Disciplefy"
**Thumbnail Image Prompt** *(prepend the Thumbnail STYLE BLOCK above)*:
> Headline: "Meet Disciplefy." Scene: a smartphone resting face-up on a warm wooden desk showing only a soft warm glow on its screen (no rendered app UI), an open Bible beside it, soft morning light, a small potted plant nearby.

**Script / Timeline (~42s) — Play Store → open app → onboarding walkthrough → login, outro at the end:**

| Time | Section | Screen | Voice-over |
|---|---|---|---|
| 0:00-0:03 | INTRO | On-screen text over simple b-roll (open physical Bible, no app): "Confused by what you read in the Bible?" | "Confused by what you read in the Bible?" |
| 0:03-0:07 | INTRO | B-roll: closing the Bible, picking up a phone | "That's exactly why I built Disciplefy." |
| 0:07-0:11 | STORE | Google Play Store listing for "Disciplefy - Bible Study," tap Install (or Open, if already installed) | "Free, right on the Play Store." |
| 0:11-0:14 | APP | App splash screen (cream background, logo fades in) | "Opens straight into—" |
| 0:14-0:16 | APP | Onboarding slide 1 — "Daily Inspiration & Study," tap Continue | "Start your day with a verse—" |
| 0:16-0:19 | APP | Onboarding slide 2 — "Personalized Study Guides," tap Continue | "—get a personal study guide for whatever you're facing—" |
| 0:19-0:21 | APP | Onboarding slide 3 — "Voice Discipler," tap Continue | "—talk it through with a voice companion—" |
| 0:21-0:24 | APP | Onboarding slide 4 — "Memory Verses" (real: 4 slides total, confirmed against app code) | "—and hide verses in your heart so they actually stick." |
| 0:24-0:27 | APP | Tap "Start Free" on the last onboarding slide | "Tap Start Free—" |
| 0:27-0:34 | APP | Login screen ("Welcome to Disciplefy," feature list), tap "Continue with Google" (real buttons: Google, Apple on iOS, Email — no guest/anonymous option) | "—sign in with Google, Apple, or email, and you're in." |
| 0:34-0:38 | APP | Land on the Home screen | "That's it. You're ready to actually study, not just read." |
| 0:38-0:42 | OUTRO | Gold CTA card, on-screen text: "Free — link in bio." | "Disciplefy. Free — link in bio." |

**Caption:** Confused by what you read in the Bible? Meet Disciplefy — download free from the Play Store, and this week we'll show you everything it can do. Link in bio.
**Hashtags:** #Disciplefy #BibleApp #BibleStudy #NewApp

**Stories (2x/day):**
- Morning: 📖 Verse — Nehemiah 8:8 + 💡 Tip — "This week, we're showing you everything Disciplefy can do — one feature a day."
  - **Daily Verse Image Prompt fill (Variant A — Classic Card):** VERSE: "...and they gave the sense, so that the people understood the reading." · REFERENCE: "Nehemiah 8:8" · BACKGROUND: "Morning desk with open Bible, soft window light."
- Evening: Share the Reel + 📖 Reflection — Download Disciplefy today, and follow along this week.

**CTA:** Download free → link in bio.
**KPI:** Reach · Installs · Profile Visits

**Hindi Dub (Stories share only — same screen recording, Hindi voice-over + on-screen text swapped in edit; main feed stays English):**

| Time | On-screen text (Hindi) | Voice-over (Hindi) |
|---|---|---|
| 0:00-0:03 | "बाइबल पढ़ते वक़्त कुछ समझ नहीं आता?" | "बाइबल पढ़ते वक़्त कुछ समझ नहीं आता?" |
| 0:03-0:07 | — | "इसीलिए मैंने Disciplefy बनाया।" |
| 0:07-0:11 | — | "मुफ़्त, सीधे Play Store पर।" |
| 0:11-0:14 | — | "खुलते ही दिखता है—" |
| 0:14-0:16 | — | "अपने दिन की शुरुआत एक वर्स से कीजिए—" |
| 0:16-0:19 | — | "—जो भी सामना कर रहे हैं, उसके लिए एक पर्सनल स्टडी गाइड पाइए—" |
| 0:19-0:21 | — | "—एक वॉइस साथी के साथ उस पर बात कीजिए—" |
| 0:21-0:24 | — | "—और वर्सेज़ को दिल में ऐसे बसाइए कि वो सच में याद रह जाएं।" |
| 0:24-0:27 | — | "आख़िरी स्लाइड पर Start Free दबाइए—" |
| 0:27-0:34 | — | "—Google, Apple, या ईमेल से साइन इन करें, बस हो गया।" |
| 0:34-0:38 | — | "बस इतना ही। अब आप असल में स्टडी करने के लिए तैयार हैं, सिर्फ़ पढ़ने के लिए नहीं।" |
| 0:38-0:42 | "मुफ़्त — लिंक बायो में।" | "Disciplefy। मुफ़्त — लिंक बायो में।" |

---

## Tuesday — 💡 How To: Generate a Study Guide
**Format:** Reel — real screen recording + Founder voice-over
**Bible Verse:** Psalm 119:105 — "Your word is a lamp to my feet and a light to my path."

**Thumbnail:** "A Full Study In Seconds" *(trimmed to 5 words from the original 6-word draft to meet the thumbnail rule)*
**Thumbnail Image Prompt** *(prepend the Thumbnail STYLE BLOCK above)*:
> Headline: "A Full Study In Seconds." Scene: a single open Bible resting on a warm wooden desk in soft morning light, a smartphone lying face-up beside it with only a soft warm glow on its blank screen (no rendered app UI), a gold ribbon bookmark draped across the Bible's open page, a ceramic coffee mug and small potted plant nearby.

**Script / Timeline (~40s) — intro, then straight into Disciplefy only (no other app shown), outro at the end:**

| Time | Section | Screen | Voice-over |
|---|---|---|---|
| 0:00-0:03 | INTRO | On-screen text over simple b-roll (open physical Bible, no app): "Opened to Romans 8. Had no idea where to start." | "Last week I opened to Romans 8 and just... stared at it." |
| 0:03-0:08 | INTRO | B-roll: flipping through a physical Bible, unsure | "I can read the words fine. Knowing what they actually mean? That's the hard part." |
| 0:08-0:12 | DISCIPLEFY | Open Disciplefy, tap the Generate tab (real bottom-nav label is "Generate," screen titled "Generate Study Guide") | "So I built Disciplefy's Study Guide to do exactly that." |
| 0:12-0:20 | DISCIPLEFY | Type "Romans 8:28" (or "anxiety") into the search field | "Type in the verse — or skip the reference and just type what you're carrying, like 'anxiety.'" |
| 0:20-0:24 | DISCIPLEFY | Open the study-mode picker (real modes: Quick Read, Standard Study, Deep Dive, Lectio Divina, Sermon Outline — not a 2-way toggle; chosen before generating) | "Want the five-minute version, or ready to go deep? You pick." |
| 0:24-0:28 | DISCIPLEFY | Tap Generate, loading animation | "One tap—" |
| 0:28-0:36 | DISCIPLEFY | Scroll through the generated Study Guide — summary, key verses, reflection questions | "—and you've got the context, the key verses, questions that actually make you think, and how to live it out today." |
| 0:36-0:40 | OUTRO | Gold CTA card, on-screen text: "Try it free — link in bio." | "Any verse. Any struggle. A real study, in seconds. Free — link's in bio." |

**Caption:** Open the Bible and freeze on where to start? Type any verse or topic — get a full study guide (context, key verses, reflection, application) in seconds. Free on Web & Android — link in bio.
**Hashtags:** #Disciplefy #BibleStudy #StudyGuide #BibleApp

**Stories (2x/day):**
- Morning: 📖 Verse — Psalm 119:105 + 💡 Tip — "Not sure where to start? Type whatever's on your heart, not just a reference."
  - **Daily Verse Image Prompt fill (Variant B — Full-Bleed Photo Overlay):** VERSE: "Your word is a lamp to my feet and a light to my path." · REFERENCE: "Psalm 119:105" · BACKGROUND: "Morning desk with Bible, soft lamp glow."
- Evening: Share the Reel + 📖 Reflection — Try generating a study guide for one verse today.

**CTA:** Try it free → link in bio.
**KPI:** Watch Time · Saves · App Installs

**Hindi Dub (Stories share only — same screen recording, Hindi voice-over + on-screen text swapped in edit; main feed stays English):**

| Time | On-screen text (Hindi) | Voice-over (Hindi) |
|---|---|---|
| 0:00-0:03 | "रोमियों 8 खोला। समझ नहीं आया कहाँ से शुरू करूं।" | "पिछले हफ़्ते मैंने रोमियों 8 खोला और बस... देखता रह गया।" |
| 0:03-0:08 | — | "पढ़ना तो आसान है। पर समझना कि इसका मतलब क्या है — वही मुश्किल है।" |
| 0:08-0:12 | — | "इसलिए मैंने Disciplefy की Study Guide बनाई — बिल्कुल यही करने के लिए।" |
| 0:12-0:20 | — | "कोई भी वर्स टाइप करें — या रेफरेंस छोड़कर बस वो लिखें जो मन में है, जैसे 'चिंता'।" |
| 0:20-0:24 | — | "पाँच मिनट वाला चाहिए, या गहराई से समझना है? आप चुनिए।" |
| 0:24-0:28 | — | "बस एक टैप—" |
| 0:28-0:36 | — | "—और आपके पास है संदर्भ, मुख्य वर्स, सोचने वाले सवाल, और आज इसे जीने का तरीका।" |
| 0:36-0:40 | "मुफ़्त — लिंक बायो में।" | "कोई भी वर्स। कोई भी परेशानी। सेकंडों में असली स्टडी। मुफ़्त — लिंक बायो में।" |

---

## Wednesday — 🚶 How To: Learning Paths
**Format:** Reel — real screen recording + Founder voice-over
**Bible Verse:** Hebrews 12:1 — "let us run with endurance the race that is set before us."

**Thumbnail:** "Stop Wandering. Start A Path."
**Thumbnail Image Prompt** *(prepend the Thumbnail STYLE BLOCK above)*:
> Headline: "Stop Wandering. Start A Path." Scene: an open Bible on a warm wooden desk, soft morning light. A thin gold dotted line traces a gentle winding path across the visible page like a subtle highlighted trail (elegant and abstract, not a literal map or illustration), leading toward a small potted plant at the edge of frame.

**Script / Timeline (~40s) — intro, then straight into Disciplefy only (no other app shown), outro at the end:**

| Time | Section | Screen | Voice-over |
|---|---|---|---|
| 0:00-0:03 | INTRO | On-screen text over simple b-roll (open physical Bible, no app): "Psalms one week. Romans the next. Going nowhere." | "I used to bounce between random verses every week — Psalms one day, Romans the next." |
| 0:03-0:08 | INTRO | B-roll: flipping between unrelated chapters in a physical Bible | "Felt busy. Wasn't actually growing — because none of it connected to what I'd studied before." |
| 0:08-0:12 | DISCIPLEFY | Open Disciplefy, tap the Topics tab | "That's exactly why we built Learning Paths." |
| 0:12-0:20 | DISCIPLEFY | Scroll through path options (Foundations, Prayer, Grace...) | "Pick a track — Foundations, Prayer, Grace, whatever you need right now." |
| 0:20-0:28 | DISCIPLEFY | Tap into a path, show its numbered topic list with XP per topic and a milestone badge (real: topic count is dynamic per path, e.g. 16 — not a fixed number, no literal "progress bar" on this screen) | "Every path shows you exactly what's next, so you're never guessing where to go." |
| 0:28-0:35 | DISCIPLEFY | Open topic 1, scroll content, tap Complete | "Finish one topic, and the next one builds right on it — that's what actual growth looks like." |
| 0:35-0:40 | OUTRO | On-screen text: "Free — link in bio." | "Stop wandering through verses. Start walking a path. Free — link in bio." |

**Caption:** Growth isn't random verses — it's a path. Learning Paths walk you through Scripture step by step so you always know what's next. Free — link in bio. 🌱
**Hashtags:** #Disciplefy #Discipleship #SpiritualGrowth #BibleStudy

**Stories (2x/day):**
- Morning: 📖 Verse — Hebrews 12:1 + 🙏 Prayer — "Lord, keep me from wandering — walk me step by step in Your Word."
  - **Daily Verse Image Prompt fill (Variant C — Split Layout):** VERSE: "Let us run with endurance the race that is set before us." · REFERENCE: "Hebrews 12:1" · BACKGROUND: "Mountain sunrise, a path winding through."
- Evening: Share the Reel + 📖 Reflection — Which topic would you want a guided path for?

**CTA:** Free → link in bio.
**KPI:** Watch Time · Saves

**Hindi Dub (Stories share only — same screen recording, Hindi voice-over + on-screen text swapped in edit; main feed stays English):**

| Time | On-screen text (Hindi) | Voice-over (Hindi) |
|---|---|---|
| 0:00-0:03 | "भजन संहिता आज, रोमियों कल। फिर भी कहीं नहीं पहुंच रहा।" | "मैं हर हफ़्ते इधर-उधर की वर्सेज़ पढ़ता था — कभी भजन संहिता, कभी रोमियों।" |
| 0:03-0:08 | — | "व्यस्त तो लगता था, पर असल में आगे नहीं बढ़ रहा था — क्योंकि कुछ भी आपस में जुड़ा नहीं था।" |
| 0:08-0:12 | — | "इसीलिए हमने Learning Paths बनाया।" |
| 0:12-0:20 | — | "एक रास्ता चुनिए — Foundations, Prayer, Grace, जो भी अभी आपको चाहिए।" |
| 0:20-0:28 | — | "हर पाथ आपको बताता है आगे क्या है, तो आपको कभी अंदाज़ा नहीं लगाना पड़ता।" |
| 0:28-0:35 | — | "एक टॉपिक खत्म करें, अगला उसी पर बनता है — असली growth ऐसी ही दिखती है।" |
| 0:35-0:40 | "मुफ़्त — लिंक बायो में।" | "वर्सेज़ में भटकना बंद कीजिए। एक रास्ते पर चलना शुरू कीजिए। मुफ़्त — लिंक बायो में।" |

---

## Thursday — 📚 How To: Memory Verses
**Format:** Reel — real screen recording + Founder voice-over
**Bible Verse:** Psalm 119:11 — "I have stored up your word in my heart, that I might not sin against you."

**Thumbnail:** "Make It Stick"
**Thumbnail Image Prompt** *(prepend the Thumbnail STYLE BLOCK above)*:
> Headline: "Make It Stick." Scene: a small handwritten verse card tucked between the pages of an open Bible on a warm wooden desk, a single gold paperclip holding it in place, soft morning light. A few more identical small verse cards fanned slightly beside it, implying repetition and practice.

**Script / Timeline (~42s) — intro, then straight into Disciplefy only (no other app shown), outro at the end:**

| Time | Section | Screen | Voice-over |
|---|---|---|---|
| 0:00-0:03 | INTRO | On-screen text over simple b-roll (no app): "Memorized this verse in youth group. Can't finish it now." | "I memorized Philippians 4:13 in youth group. Couldn't tell you the last three words of it now." |
| 0:03-0:08 | INTRO | B-roll: person trying to recall a verse, blank look | "Turns out cramming a verse once was never going to make it stick." |
| 0:08-0:12 | DISCIPLEFY | Open Disciplefy, tap the Memory Verses icon on the Home screen (real: reached from a Home-screen icon, not a bottom-nav tab), tap Add Verse | "So Memory Verses is built around one idea: repetition, at the right time." |
| 0:12-0:20 | DISCIPLEFY | Search and add a verse | "Add whatever verse you're working on." |
| 0:20-0:28 | DISCIPLEFY | Cycle through a few practice modes — flip cards, word bank, fill-in-the-blank (real: 3 of 8 actual modes, a representative sample, not exhaustive) | "Then drill it — flip cards, a word bank, fill-in-the-blank, whatever keeps it fresh." |
| 0:28-0:33 | DISCIPLEFY | Notification popup: review reminder | "It nudges you right before you'd actually forget it — not on some random schedule." |
| 0:33-0:38 | DISCIPLEFY | Show the green streak heat map | "And watching that streak grow is what keeps you coming back." |
| 0:38-0:42 | OUTRO | On-screen text: "Free — link in bio." | "Hide His Word in your heart — for good this time. Free, link in bio." |

**Caption:** Memorize a verse, then lose it in a week? Add a verse, practice with flip cards/word bank/cloze, get reminded right before you'd forget — and watch your streak grow. Free — link in bio. 🙌
**Hashtags:** #Disciplefy #MemoryVerse #BibleMemory #Scripture

**Stories (2x/day):**
- Morning: 📖 Verse — Psalm 119:11 + 💡 Tip — "Pick one short verse this week and practice it daily — consistency beats cramming."
  - **Daily Verse Image Prompt fill (Variant D — Minimalist Typography):** VERSE: "I have stored up your word in my heart, that I might not sin against you." · REFERENCE: "Psalm 119:11" · BACKGROUND: "Coffee and Bible, warm morning light (used for logo/mood only — Variant D has no photo)."
- Evening: Share the Reel + 📖 Reflection — Which verse are you memorizing first?

**CTA:** Free → link in bio.
**KPI:** Watch Time · Saves

**Hindi Dub (Stories share only — same screen recording, Hindi voice-over + on-screen text swapped in edit; main feed stays English):**

| Time | On-screen text (Hindi) | Voice-over (Hindi) |
|---|---|---|
| 0:00-0:03 | "यूथ ग्रुप में याद किया था। अब आख़िरी शब्द भी याद नहीं।" | "मैंने यूथ ग्रुप में फिलिप्पियों 4:13 याद किया था। अब आख़िरी तीन शब्द भी याद नहीं।" |
| 0:03-0:08 | — | "पता चला, एक बार रटने से वो कभी याद नहीं रहता।" |
| 0:08-0:12 | — | "इसलिए Memory Verses एक ही सोच पर बना है: सही समय पर दोहराना।" |
| 0:12-0:20 | — | "जो भी वर्स याद करना है, उसे जोड़िए।" |
| 0:20-0:28 | — | "फिर अभ्यास कीजिए — फ्लिप कार्ड्स, वर्ड बैंक, खाली जगह भरना — जो भी याद ताज़ा रखे।" |
| 0:28-0:33 | — | "ये आपको ठीक उसी वक़्त याद दिलाता है जब आप भूलने वाले होते हैं — किसी बेतरतीब समय पर नहीं।" |
| 0:33-0:38 | — | "और वो streak बढ़ते देखना ही आपको वापस लाता है।" |
| 0:38-0:42 | "मुफ़्त — लिंक बायो में।" | "उसके वचन को अपने दिल में बसाइए — इस बार हमेशा के लिए। मुफ़्त, लिंक बायो में।" |

---

## Friday — 🎙 How To: Voice Discipler
**Format:** Reel — real screen recording + Founder voice-over
**Bible Verse:** 1 Peter 3:15 — "always being prepared to make a defense to anyone who asks you for a reason for the hope that is in you."

**Thumbnail:** "Just Ask Out Loud"
**Thumbnail Image Prompt** *(prepend the Thumbnail STYLE BLOCK above)*:
> Headline: "Just Ask Out Loud." Scene: a smartphone resting upright on a warm wooden desk with a soft gold soundwave glow emanating gently from its screen (implying a voice moment, no rendered UI), an open Bible beside it, warm bright lamp-glow lighting — warm and inviting, not dark or moody.

**Script / Timeline (~40s) — intro, then straight into Disciplefy only (no other app shown), outro at the end:**

| Time | Section | Screen | Voice-over |
|---|---|---|---|
| 0:00-0:03 | INTRO | On-screen text over simple b-roll (no app): "Had a question at 1am. No one to call." | "Had a question at 1am once — 'how do I actually forgive someone who hurt me?' Nobody to call." |
| 0:03-0:08 | INTRO | B-roll: person alone at night, holding phone | "Some questions really can't wait until Sunday." |
| 0:08-0:12 | DISCIPLEFY | Open a generated Study Guide, tap "Ask Discipler" (real button, bottom of the Study Guide screen next to "Listen" — this is the real entry point, confirmed against actual app screenshots) | "That's why every Study Guide has a Discipler built right in." |
| 0:12-0:20 | DISCIPLEFY | Tap the mic, speak: "How do I forgive someone who hurt me?" | "Tap the mic and just ask it out loud — like you would a friend." |
| 0:20-0:30 | DISCIPLEFY | Scroll through the Scripture-grounded response | "It answers straight from Scripture — every single time." |
| 0:30-0:36 | DISCIPLEFY | On-screen text: "A companion, not a replacement." | "Think of it as a companion for the walk — never a replacement for your pastor or your church." |
| 0:36-0:40 | OUTRO | On-screen text: "Free — link in bio." | "Real questions, biblical answers, anytime. Free — link in bio. Follow for a new one every week." |

*This week's Follow-CTA slot (see Growth Additions below) — the added line is a soft ask, not a hard sell; doesn't replace the app CTA, just tacks on at the very end.*

**Caption:** Faith question, no one to ask right now? Tap the mic, ask out loud — get a Scripture-grounded answer. A companion for your walk, not a replacement for your pastor or church. Free — link in bio. Follow for more real questions, answered. 🙏
**Hashtags:** #Disciplefy #Discipleship #VoiceDiscipler #FaithQuestions

**Theology-safe note:** Discipler copy must always frame it as a companion that points back to Scripture and community — never a replacement for pastor, church, or the Bible itself.

**Stories (2x/day):**
- Morning: 📖 Verse — 1 Peter 3:15 + 🙏 Prayer — "Lord, give me courage to ask hard questions and to keep seeking You for the answers."
  - **Daily Verse Image Prompt fill (Variant E — Framed Photo):** VERSE: "Always being prepared to make a defense to anyone who asks you for a reason for the hope that is in you." · REFERENCE: "1 Peter 3:15" · BACKGROUND: "Library, quiet study corner."
- Evening: Share the Reel + 📖 Reflection — What's a faith question you've never asked out loud?

**CTA:** Free → link in bio.
**KPI:** Watch Time · Saves · Comments

**Hindi Dub (Stories share only — same screen recording, Hindi voice-over + on-screen text swapped in edit; main feed stays English):**

| Time | On-screen text (Hindi) | Voice-over (Hindi) |
|---|---|---|
| 0:00-0:03 | "रात 1 बजे एक सवाल था। किसी को फ़ोन नहीं कर सकता था।" | "एक बार रात 1 बजे एक सवाल था — 'मैं किसी को माफ़ कैसे करूं जिसने मुझे तकलीफ़ दी?' किसी को फ़ोन नहीं कर सकता था।" |
| 0:03-0:08 | — | "कुछ सवाल सच में रविवार तक रुक नहीं सकते।" |
| 0:08-0:12 | — | "इसीलिए हर Study Guide में एक Discipler पहले से मौजूद है।" |
| 0:12-0:20 | — | "माइक दबाइए और ज़ोर से पूछिए — जैसे किसी दोस्त से पूछते हैं।" |
| 0:20-0:30 | — | "ये हर बार सीधे शास्त्र से जवाब देता है।" |
| 0:30-0:36 | "साथी, विकल्प नहीं।" | "इसे अपने सफ़र का साथी समझिए — कभी अपने पास्टर या चर्च की जगह नहीं।" |
| 0:36-0:40 | "मुफ़्त — लिंक बायो में।" | "असली सवाल, बाइबिल से जवाब, कभी भी। मुफ़्त — लिंक बायो में। हर हफ़्ते नए सवाल के लिए फॉलो करें।" |

---

## Saturday — (open this week)
No scheduled post — the only open day this week, once Monday's new app-intro Reel filled what used to be Friday's slack. Use for community/reply work, or slack if anything above slips. Standing Saturday "Study With Disciplefy" slot (Episode 2: Learning Paths) resumes in Week 2.

---

## Sunday — 🙏 Sunday Reflection
**Topic:** Carry This Week's Truth Into Worship
**Format:** Carousel (recap, low production overhead — pre-built earlier in the week)
**Bible Verse:** Hebrews 10:24-25 — "...not neglecting to meet together, as is the habit of some, but encouraging one another..."

**Slides:** Cover ("Disciplefy launched this week — here's everything it can do") → recap the 4 features (Study Guide, Learning Paths, Memory Verses, Discipler) → one practical takeaway → invite to church/community → Disciplefy CTA

**🎨 STYLE BLOCK (prepend to every slide prompt below)** — same warm Marketing/Social system as `Instagram_Carousel_Image_Prompts.md`:
> Premium, warm, bright slide designed as one frame in a multi-slide, swipeable Instagram carousel for a Christian discipleship app called Disciplefy. Portrait 4:5 (1080×1350). Soft cream/off-white background (`#FAF8F5`) bathed in bright natural window light — airy, cozy, inviting. Warm wooden desk with tasteful props (open Bible, ceramic coffee mug, small potted plant, leather journal with pen), softly sunlit. Bold near-black charcoal (`#1E1E1E`) headline, Poppins, left-aligned; short subline in warm gray. Gold accents (`#B8860B` / `#C79A3B`) for logo, icons, dividers, and key words. Brand frame: gold Disciplefy logo + thin gold divider top-left; gold globe icon + "disciplefy.in" bottom-left. No dark/moody look, clutter, cheesy stock, distorted text, or clip-art crosses.

**Slide 1 — Cover:**
> Bright, cozy sunlit desk scene (as per STYLE BLOCK). Bold charcoal headline: "One Week In: Everything Disciplefy Can Do." Warm-gray subline: "A recap, in case you missed a day." Small gold accent icon (open book).

**Caption (on-slide text):** Disciplefy launched this week — here's everything it can do, swipe through in case you missed a day.

**Slide 2 — What's Inside recap:**
> Bright cream background, airy and clean. A balanced 2×2 grid of four minimalist gold line-icons, each on a soft off-white rounded card with a subtle shadow: (1) open book "Study Guides", (2) winding path "Learning Paths", (3) bookmark with heart "Memory Verses", (4) microphone with soundwave "Voice Discipler" — icons in gold, labels in charcoal. Small charcoal heading at top: "This Week's Features." Elegant, evenly spaced.

**Caption (on-slide text):** Four features, one goal: help you actually study Scripture, not just skim it — Study Guides, Learning Paths, Memory Verses, and Voice Discipler.

**Slide 3 — One practical takeaway:**
> Bright cream scene, warm window light, a single open Bible with a leather journal and pen beside it. Bold charcoal headline: "Try Just One Feature This Week." Warm-gray subline: "You don't need to use all four today — pick one." Small gold arrow accent.

**Caption (on-slide text):** Don't feel like you need to use all four today. Pick just one and start there this week.

**Slide 4 — Invite to church/community:**
> Warm, hopeful scene: soft Sunday-morning light through a window, a person's silhouette or just an empty warm room with a coat and Bible by the door (implying heading out), gentle golden glow. Bold charcoal headline: "Carry It Into Worship Today." Small warm-gray subline referencing Hebrews 10:24-25 ("...encouraging one another..."). No literal church building needed — keep it intimate and personal.

**Caption (on-slide text):** Whatever stood out to you this week, bring it into worship today — that's where it's meant to be lived out.

**Slide 5 — CTA:**
> Bright, hopeful closing scene: warm morning sunlight over a wooden desk with an open Bible and mug, soft golden glow. Bold charcoal headline: "Missed a Post This Week?" with a gold arrow →. Smaller warm-gray line beneath: "Catch up — link in bio."

**Caption (on-slide text):** If you missed a post this week, no worries — catch up any time. Link in bio.

**Caption:** This week Disciplefy went live — a study guide for any verse, a path to follow, verses that stick, and questions you can finally ask out loud. Today, carry it into worship. Send this to a friend heading to church today. 🙏
**Hashtags:** #Disciplefy #SundayReflection #Worship #BibleStudy #Discipleship

**Stories (2x/day):**
- Morning: 📖 Verse — Hebrews 10:25 + 🙏 Prayer — "Lord, thank You for this week's launch. Help me carry it into worship today."
  - **Daily Verse Image Prompt fill (Variant G — Vertical Bookmark):** VERSE: "...not neglecting to meet together, as is the habit of some, but encouraging one another..." · REFERENCE: "Hebrews 10:24-25" · BACKGROUND: "Church pew, soft morning light through a window."
- Evening: Share Carousel + 📖 Reflection — Which of this week's 4 features will you try first?

**CTA:** Missed a post this week? Catch up — link in bio.
**KPI:** Saves · Shares · Profile Visits

---

## Algorithm Notes (2026)
- Feed cadence this week is 5 Reels (Mon-Fri) + 1 Carousel (Sun), Sat open — reel-heavy on purpose, since reach + proof-of-feature was this week's actual goal, not the season's normal 4 Reel/3 Carousel balance. That balance resumes Week 2.
- Watch time (incl. replays) is the #1 ranking signal for all 5 Reels this week — each hook must land in the first ~3s, and a short loop-worthy ending helps more than a longer runtime.
- Shares (DM sends) are the strongest distribution trigger — every post above already carries a share-worthy CTA or invite line.

## Growth Additions (2026) — canonical, referenced by Weeks 2-4 and PreWeek1
Three tactics not yet baked into the plan before this update — reach (discovery) and follows (conversion) are different problems, these split across both:

**1. Follow-CTA (conversion) — once per week, not every post.** Asking to follow on every single post reads as needy and gets tuned out. One rotating slot per week, always the week's highest-reach/highest-engagement post:
- Week 1: Friday's Discipler Reel outro (done above — soft-tacked-on line, doesn't replace the app CTA)
- Week 2: Saturday's Episode 2 Reel
- Week 3: Saturday's Episode 9 ⭐ Hero Reel
- Week 4: Saturday's Episode 13 ⭐ Hero Reel
- PreWeek1: Sunday's Learning Paths carousel, CTA slide caption

**2. Trending audio (reach) — Daniel Reels only, when it actually fits.** Check Instagram's trending-audio tab weekly; layer a soft trending instrumental under the narration *only* if the mood matches (warm, reverent, unhurried) — skip the week entirely if nothing fits rather than forcing a mismatched trend for reach. Doesn't apply to Mon-Fri's screen-recording Reels this week (voice-over + real UI audio takes priority there).

**3. Stories interactive stickers (reach + engagement) — 2-3x/week, not daily.** Add a poll or question sticker to the Evening Story slot on the days it fits naturally (e.g. "Did you try this today? Yes/No," "What stood out to you?"). Stories has its own discovery mechanic separate from the main feed — currently every Evening slot is pure broadcast (share + reflection prompt), no interactivity. Don't do it daily — it dilutes and starts feeling like a survey, not a devotional.
- Real screen-recordings count as original content, same as AI-generated Reels — full distribution credit.

## Production Rhythm
Same rolling model as the rest of the season (see `Disciplefy Operating System`) — produce next week's content while this week publishes. Main remaining work: record the 5 screen-recordings + Founder voice-overs, edit, and schedule.

## Success Metrics
Track at the end of the week: Reach · Watch Time · Saves · Shares · Profile Visits · Website Clicks · App Installs.
Ignore vanity metrics. Focus on helping more believers take one step closer to becoming disciples of Jesus.

---

## Changelog
- **v2.0:** Full rewrite. Week 1 now runs the 5 already-built Launch + How-To posts as Carousels Mon-Fri instead of the standing rhythm.
- **v2.1:** Launch carousel had already posted the Friday before this formal week. Monday briefly changed to a recap/re-share.
- **v2.2:** Recap dropped — all content shifted one day earlier to fill the week from Monday instead (Study Guide Mon, Learning Paths Tue, Memory Verses Wed, Discipler Thu, Episode 1 reel Fri).
- **v3.0:** Switched the 4 How-To posts (Mon-Thu) from Carousel to real screen-recording Reel — better reach and install-driving trust than static screenshots for this specific goal. This made Friday's Episode 1 reel redundant with Monday's new Study Guide Reel, so it was dropped (the story arc still starts at Episode 2 in Week 2, nothing lost). Friday and Saturday are open this week as a result.
- **v3.1:** Replaced each Reel's one-line "Demo flow" with a full timestamped Script/Timeline (screen action + voice-over per beat) — production-ready instead of a bullet summary. On-screen text kept minimal (hook line + CTA card only, per Visual Bible's "large captions, minimal overlays") — the steps themselves are carried by voice-over + real screen action, not per-step text overlays.
- **v3.2:** Intro/problem beats no longer show a generic screen recording (was ambiguous, read like "another app") — now simple non-app b-roll (physical Bible, person) or on-screen text only. Every script is now explicitly Intro (no app) → Disciplefy screen recording only → Outro (CTA card).
- **v3.3:** Added detailed generation prompts for everything that isn't a real screen recording: a shared Google Flow/Veo Intro + Outro video prompt section (embedded here, not just linked), a Thumbnail STYLE BLOCK + one detailed thumbnail image prompt per Mon-Thu Reel (also trimmed Monday's thumbnail text from 6 to 5 words to meet the Visual Bible's thumbnail rule), and full STYLE BLOCK + 5 slide-by-slide image prompts for Sunday's Reflection Carousel (previously just a topic outline, no actual generation prompts).
- **v3.4:** Added a Daily Verse Story image-generation template (adapted from `Prompts/Daily Bible Verse v2.md` with its flagged issues resolved) plus a per-day Verse/Reference/Background fill for every Morning Story this week — previously the Morning Stories named a verse reference but had no actual image prompt to generate the card.
- **v3.5:** Replaced the single fixed Daily Verse layout with 7 distinct variants, one locked to each weekday (Classic Card, Full-Bleed Photo Overlay, Split Layout, Minimalist Typography, Framed Photo, Side-by-Side, Vertical Bookmark) — per direction, the verse card shouldn't look identical every day. Canonical set, reused by Weeks 2-4.
- **v3.6:** Added a per-slide Caption to Sunday's carousel — Instagram now supports a distinct caption per carousel image (rolled out June 2026), shown as viewers swipe. Captions add commentary/context beyond the on-image headline text, not a repeat of it.
- **v3.7:** Corrected screen-recording script assumptions against the real app UI/screenshots: "Study tab" → real label is "Generate"; "Quick/Deep mode toggle" → real UI is a 5-mode picker (Quick Read, Standard Study, Deep Dive, Lectio Divina, Sermon Outline), not a 2-way switch; Learning Paths "lessons 1→8 with progress bar" → real screen shows a dynamic-count numbered topic list with XP and milestone badges (e.g. 16 topics), no fixed count or literal progress bar; Discipler entry point corrected to "Ask Discipler" button on a generated Study Guide (confirmed via screenshot), not a generic "tap into the Discipler"; Memory Verse practice-mode line clarified as a 3-of-8 sample, not exhaustive; Memory Verse entry point clarified as a Home-screen icon, not a nav tab.
- **v3.8:** Monday's Reel had the mode picker placed *after* tapping Generate and viewing results — backwards, since you pick a mode before generating. Reordered: type verse → pick mode → tap Generate → view results.
- **v3.9:** Added "Growth Additions (2026)" — canonical section covering 3 tactics not previously in the plan: (1) Follow-CTA rotated once/week on the highest-reach post (this week: Thursday's Discipler Reel), (2) trending audio on Daniel Reels where mood fits, (3) Stories interactive stickers 2-3x/week. Weeks 2-4 and PreWeek1 reference this section rather than repeating it.
- **v4.0:** Rewrote all 4 Mon-Thu voice-over scripts — the "Ever ___? / Most of us..." formula repeated identically across all four felt generic and read like ad copy, not a person talking. Replaced with specific first-person founder anecdotes (Romans 8 freeze, random verse-hopping, a forgotten youth-group verse, a 1am question) that still hit the same beats (hook → problem → feature → demo → CTA) but sound like someone actually talking, not a script template.
- **v4.1:** Added a Hindi Dub to each of the 4 Mon-Thu Reels — same screen recording, Hindi voice-over + on-screen text swapped in edit. Posted to Stories only (not the main feed): keeps this week's carefully-tuned Reel cadence intact and tests Hindi demand before committing feed real estate, consistent with marketing content being English-only on the main feed for now (see Daily Verse Story note).
- **v4.2:** Added a new Monday Reel — "Meet Disciplefy," a real screen recording of Play Store → open app → the 4-slide onboarding walkthrough → login (Google/Apple/Email, no guest option), grounded in the actual app UI. Everything else shifted one day later: Study Guide Tue, Learning Paths Wed, Memory Verses Thu, Discipler Fri (Follow-CTA slot moved with it). Saturday is now the week's only open day. Week 1 is 5 Reels (Mon-Fri) + 1 Carousel (Sun) instead of 4+1; all cross-references (Mission, Why-Different, Algorithm Notes, Growth Additions, Production Rhythm, Daily Verse variant assignments) updated to match.
- **v4.3:** Split Monday's single "swipe through all 4 onboarding slides" beat into 4 separate beats, one voice-over line per walkthrough page (matches the actual per-slide swipe instead of one line glossing over all of them) — updated in both the English script and Hindi Dub.

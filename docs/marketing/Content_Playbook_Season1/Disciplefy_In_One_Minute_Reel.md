# Disciplefy in 1 Minute — Flagship Overview Reel
Version: 3.1

## What this is
A standalone ~54-second reel covering 6 tight beats in one continuous real screen recording — Founder voice-over (English + Hindi dub), personal testimony framing. Not tied to a specific week; a flagship/pinned post, slot it in wherever makes sense. Self-contained — nothing else needs to be open alongside this file.

**Format:** Reel — real screen recording + Founder voice-over (not Daniel — this is a personal testimony hook, has to be the real founder's voice)
**Hook:** "The one app I needed on day one — and didn't have."

**⚠️ Before recording: this hook is a real personal claim.** Only use it if it's true to your own story — record it as an actual testimony, not a generic "relatable" line. If it's not literally true, swap the VO for a version that doesn't claim personal history.

**⚠️ Runtime:** 6 content beats in ~54 seconds, ~6s under the 60s cap. There's a little breathing room now — feel free to pad Community or the Outro by a couple seconds each if a take needs it, without threatening the overall pace.

**⚠️ Real UI corrections baked into this script (verified against the app code, not assumed):**
- **No "Discipefy Global" community exists.** The real feature is **Fellowships** — small user/pastor-created groups. Community tab → "Discover" sub-tab → join a public fellowship (or join via invite code). Scripted accordingly below.
- **Study mode isn't a manual "skip" step.** Tapping Generate with no saved mode preference auto-pops the mode-picker sheet (defaults to Standard highlighted) — "generating without choosing" means accepting that default without browsing other options, not that the picker never appears.
- **No regenerate/change-mode button exists on the result screen.** "Going back" to try a different mode means literally back-navigating to the Generate screen and doing it again — scripted that way below.

## Video Generation Prompts — Intro / Outro (Google Flow / Veo)
Same bookend pattern as Week 1's screen-recording Reels — a generated Intro clip and Outro clip wrap the real screen recording in the middle.

**STYLE BLOCK (prepend to both prompts below):**
```
Premium, warm, cinematic short video clip for a Christian discipleship app called Disciplefy, used as an Instagram Reel intro/outro segment. Portrait 9:16. Warm, golden-hour or soft window lighting — reverent, peaceful, hopeful, premium. Slow, intentional pacing: fade, slow zoom, soft dissolve, gentle light bloom. No fast cuts, whip pans, spinning, or aggressive animation. Setting: a quiet home or coffee-shop workspace, warm wood tones, soft natural light, subtle film grain, organic feel — never overly sharp or artificial. No other apps, phone UI, or on-screen branding besides Disciplefy's own logo where explicitly noted. Avoid: cheesy stock-photo feel, clip-art crosses, corporate look, garbled text.
```

**Intro prompt (~3s):**
```
No people in frame — a single well-worn physical Bible resting open on a warm wooden desk in soft morning window light, its pages softened and slightly curled from years of use, a faded ribbon bookmark trailing from the spine, a few handwritten notes visible in the margins. Slow, gentle camera push-in on the worn pages. Warm, cinematic, reverent, nostalgic mood — this Bible has clearly been read for years. No text rendered in-clip — the hook line is added as a text overlay in edit.
```

**Outro prompt (~4s):**
```
Warm, premium closing card for Disciplefy. Soft cream/warm-gold gradient background with gentle light bloom. Use the attached logo image (gold open-book-with-cross icon + "Disciplefy" wordmark) — it gently fades and rises into the center of frame with a soft glow, no harsh motion, keeping the logo's real shape and type intact (don't regenerate or redraw it). Logo only — no additional text; the caption already carries "link in bio."
```
*Attach the actual logo file as a reference image in Google Flow when generating the Outro — don't let the model invent its own logo. If it distorts when animated, generate the empty gradient card instead and composite the real static logo on top in edit.*

## Thumbnail Image Prompt
```
Premium, warm thumbnail frame for a Disciplefy Instagram Reel. Portrait 9:16 (1080×1920), safe-zone aware — keep headline and focal object clear of the top ~250px and bottom ~250px (Instagram UI overlay zones). Soft cream background (#FAF8F5) bathed in natural window light. Bold near-black charcoal (#1E1E1E) headline, Poppins 700, maximum five words. One clear focal object only. One small gold (#B8860B) accent only. Brand frame: small gold Disciplefy logo top-left with thin gold divider; small gold globe + "disciplefy.in" bottom-left. Never: red arrows, shock faces, clickbait expressions, clip-art crosses, busy collages.

Headline: "Everything, In 60 Seconds." Scene: a well-worn physical Bible open beside a smartphone showing only a soft warm glow on its screen (no rendered app UI), morning light, a faded ribbon bookmark draped across the Bible's page.
```

## Script / Timeline (~54s) — Intro (no app) → Disciplefy screen recording only → Outro

| Time | Section | Screen | Voice-over (English) |
|---|---|---|---|
| 0:00-0:03 | INTRO | Generated Intro clip (worn physical Bible, no app) + on-screen text: "The App I Needed On Day One." | "The one app I needed on day one — and didn't have." *(delivered briskly, not conversationally slow — this is the hook, it needs to land fast)* |
| 0:03-0:11 | GENERATE | Open Disciplefy, tap the Generate tab. Tap the Scripture/Topic/Question toggle (leave on Scripture), type "Romans 8:28," tap Generate. The mode-picker sheet auto-pops (Standard pre-selected) — tap through without browsing other modes. Result streams in. | "Type a verse. Tap Generate. Don't even worry about picking a mode — it's got a default ready." |
| 0:11-0:20 | LEARNING PATHS | Tap the Topics tab, scroll path options quickly, tap into a path, show its numbered topic list with XP per topic and a milestone badge, tap into one topic, show its Study Guide. | "Don't know where to start at all? Learning Paths lays it out for you — pick a track, open a topic, and there's your guide." |
| 0:20-0:29 | MEMORY VERSES | Tap the Memory Verses icon on the Home screen, tap Add Verse, search and add "Romans 8:28" (same verse, ties the demo together), open it, show one practice mode (flip cards). | "Add a verse you want to remember, open it up, and practice it until it actually sticks." |
| 0:29-0:37 | DISCIPLER | Open the Romans 8:28 Study Guide from earlier, tap "Ask Discipler," tap the mic, speak a question ("How do I forgive someone who hurt me?"), scroll the Scripture-grounded response. | "Got a real question? Tap the mic, ask it out loud — grounded in Scripture, every time." |
| 0:37-0:46 | COMMUNITY | Tap the Community tab, tap the "Discover" sub-tab, scroll public fellowships, tap into one, tap Join, show the success confirmation. | "And you don't have to study alone — find a fellowship in Discover, and join real people doing this with you." |
| 0:46-0:54 | OUTRO | Generated Outro clip (logo card), on-screen text: "Free — link in bio." | "This is Disciplefy. Everything you just saw — free. Link in bio." |

**Why Romans 8:28 twice (Generate + Memory Verses):** not a mistake — it threads one real verse through the reel instead of feeling like disconnected feature demos. You generate a study on it, then add the same verse to memorize.

## Hindi Voice-Over
Meaning-matched, not word-for-word — natural spoken Hindi, feature/UI names kept in English (matches the house convention from Week 1's Hindi Dubs). Same screen actions and timing as the English table above.

| Time | Section | Voice-over (Hindi) |
|---|---|---|
| 0:00-0:03 | INTRO | "वो एक ऐप जिसकी मुझे पहले दिन ज़रूरत थी — और नहीं था।" |
| 0:03-0:11 | GENERATE | "कोई भी वर्स टाइप करें। Generate दबाएं। मोड चुनने की चिंता मत कीजिए — एक डिफ़ॉल्ट पहले से तैयार है।" |
| 0:11-0:20 | LEARNING PATHS | "बिल्कुल समझ नहीं आता कहाँ से शुरू करें? Learning Paths आपके लिए रास्ता बनाता है — एक ट्रैक चुनिए, एक टॉपिक खोलिए, और आपकी गाइड तैयार है।" |
| 0:20-0:29 | MEMORY VERSES | "जो वर्स याद रखना है उसे जोड़िए, खोलिए, और तब तक अभ्यास कीजिए जब तक वो सच में याद न हो जाए।" |
| 0:29-0:37 | DISCIPLER | "कोई सच्चा सवाल है? माइक दबाइए, ज़ोर से पूछिए — हर बार शास्त्र पर आधारित जवाब मिलेगा।" |
| 0:37-0:46 | COMMUNITY | "और अकेले स्टडी करने की ज़रूरत नहीं — Discover में एक fellowship ढूंढिए, और असली लोगों के साथ जुड़िए जो यही कर रहे हैं।" |
| 0:46-0:54 | OUTRO | "यही है Disciplefy। जो अभी देखा, सब कुछ — मुफ़्त। लिंक बायो में।" |

**Production note:** if using the ElevenLabs setup (see Week 2's "Daniel's Voice" section) to generate this, either clone the founder's real voice speaking Hindi directly, or use ElevenLabs' multilingual model on the founder's cloned English voice — don't use a different stock voice for the Hindi cut, it breaks the personal-testimony framing that makes the hook work.

## Caption
The one app I needed on day one — and didn't have. A study guide for any verse — pick your depth, or let it choose for you. A guided path when you don't know where to begin. Verses that actually stick. A place to ask the hard questions out loud. And a fellowship so you're not doing any of it alone. All of it, free — link in bio.

## Hashtags
#Disciplefy #BibleStudyApp #BibleStudy #ChristianApp #Discipleship

## CTA
Try it free → link in bio.

## KPI
Reach · Watch Time · Saves · Shares · Profile Visits · App Installs

## Production Notes
- **Still a dense reel** — 6 beats in ~54 seconds of screen recording. Rehearse every screen flow beforehand so there's zero fumbling.
- **Founder voice-over via ElevenLabs** is fine here too for consistency with the rest of the season's production pipeline — see `Content_Playbook_Season1_Week2.md`'s "Daniel's Voice — ElevenLabs Setup" section for the workflow (clone your own voice instead of picking a stock one; same settings guidance applies: Stability ~60-75%, low-medium Style Exaggeration).
- **On-screen captions strongly recommended, not optional here** — per the Week 2 format experiment, burn in a short compressed caption under each beat's VO line for muted viewers. At this density, a muted viewer who loses the thread for even one beat won't catch back up.
- **Consider pinning this to the top of the profile grid** once published — it's the single best "explain everything" asset for a new visitor.
- If the Discover tab has no public fellowships populated yet at recording time, seed at least one before filming — an empty Discover list breaks the Community beat entirely.
- **Hindi cut:** post as a separate version (same pattern as Week 1's Hindi Dubs — Stories/secondary placement, main feed stays English) unless you want to run it as the primary post for a Hindi-first audience segment.

## Changelog
- **v1.0:** Initial script — hook "The Bible app I wish existed the day I actually started reading," 60s screen recording covering all 4 core features, Founder voice-over (personal testimony, not Daniel).
- **v2.0:** Full rewrite per detailed flow request — expanded from 4 beats to 7: split Study Guide into 2 passes (generate without choosing a mode, then go back and regenerate the same verse with a deliberately different mode), added a quick Learning Paths path-open-to-study-guide sequence, added Memory Verses add-and-practice, kept Discipler, and added a new Community beat. Verified against the app code first and corrected 2 wrong assumptions: no "Disciplefy Global" community exists (real feature is Fellowships, joined via the Discover sub-tab), and there's no regenerate/change-mode button on the result screen (Generate #2 requires a real back-navigation, scripted accordingly). Kept the hard 60s runtime per direction, despite the pacing risk flagged for 7 beats in that space.
- **v3.0:** Dropped the Generate #2 (mode-comparison) beat — 6 beats now, re-timed to ~54s, ~6s of slack instead of a hard-packed 60s. Added a full Hindi Voice-Over track (meaning-matched, not literal — feature/UI names kept in English, same convention as Week 1's Hindi Dubs), with a note to keep it the same cloned founder voice, not a different stock voice, so the personal-testimony framing survives the translation.
- **v3.1:** Swapped the hook to "The one app I needed on day one — and didn't have." (was "The Bible app I wish existed the day I actually started reading.") — updated the Hook line, Intro on-screen text, English and Hindi VO, and the Caption opener to match.

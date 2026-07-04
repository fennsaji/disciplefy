# Daily Bible Verse v2 — Instagram Story Prompt Template

AI image-generation prompt for the recurring **"Today's Verse"** Instagram Story series (1080×1920, 9:16). Fill in `{{VERSE}}`, `{{REFERENCE}}`, and `{{BACKGROUND}}` each day; everything else must stay fixed so the series reads as one consistent, recognizable Disciplefy format.

> **Note — review before using as the daily production template:** this v2 draft carries several unresolved tensions with the current brand system (`docs/marketing/Strategy/03 Disciplefy Visual Bible.md`) and the approved carousel STYLE BLOCK (`docs/marketing/Instagram_Carousel_Image_Prompts.md`). See **Review Notes** at the bottom before treating this as final. The template text below is preserved exactly as written in the source doc; only formatting was cleaned up.

## Placeholders

| Placeholder | Filled with |
|---|---|
| `{{VERSE}}` | The Bible verse text for the day |
| `{{REFERENCE}}` | The Bible reference (e.g. "John 3:16") |
| `{{BACKGROUND}}` | A short description of the background scene/theme for the day |

---

## Prompt Template

You are the Lead Brand Designer for Disciplefy.

Your task is to design ONE premium Instagram Story (1080×1920, 9:16) following Disciplefy's official visual system.

This is part of the recurring "Today's Verse" series.

Every day's design should immediately be recognizable as Disciplefy.

**DO NOT redesign the layout.**
Only change:
- Bible verse
- Bible reference
- Background scene

Everything else should remain consistent.

### Verse

`{{VERSE}}`

### Reference

`{{REFERENCE}}`

### Background Theme

`{{BACKGROUND}}`

---

## Brand Identity

- Warm
- Peaceful
- Premium
- Minimal
- Cinematic
- Scripture-first

Material 3 design.

Apple-quality marketing.

Photography should be realistic.

Never use illustrations.

Never use AI-looking imagery.

Never use fantasy effects.

> **Note — "Material 3 design" + "Apple-quality marketing" appear together:** Material 3 is Google's design system (and matches the app's own Flutter/Material 3 UI per `CLAUDE.md`), while "Apple-quality" points to a different aesthetic sensibility, and the Visual Bible's Marketing/Social section doesn't reference Material Design at all. This pairing (also echoed later as "Soft Material shadow" in the Layout section) suggests this prompt may have been adapted from Product/App brief language rather than written fresh for the Marketing/Social system. Flagging for a decision: keep "Material 3" as an elevation/shadow-style cue, or drop it in favor of the Visual Bible's own photography/typography language.

> **Note — "Never use AI-looking imagery" / "Photography should be realistic" vs. this being an AI-generated (Google Flow/Veo) image:** the instruction is presumably shorthand for "the generated image shouldn't *look* AI-generated — it should read as real photography" (avoiding plastic skin, warped hands, over-saturation, etc.), which is a legitimate and common AI image-gen instruction. But as written it reads as a literal contradiction (the whole image *is* AI-generated), which could cause a model to hedge or under-deliver on realism. Worth rephrasing explicitly, e.g. "photorealistic — must not look AI-generated" or "avoid telltale AI-image artifacts," to remove the ambiguity for a daily-recurring prompt. Left as-is here pending a decision.

---

## Color Palette

| Role | Color |
|---|---|
| Background | `#FAF8F5` |
| Primary | `#B8860B` (Deep Gold) |
| Secondary | `#C79A3B` (Warm Gold) |
| Verse Card | `#FFEEC0` |
| Heading | `#1E1E1E` |
| Body | `#4B5563` |
| Footer | `#6B7280` |

Gold accents should match the Disciplefy logo (`#B8860B` / `#C79A3B`, per the Visual Bible).

> **Resolved — Primary/Secondary drift into the Product/App indigo system:** Primary/Secondary previously listed `#4F46E5` (Indigo 600) / `#6366F1` (Indigo 500) — the Product/App brand primaries per the Visual Bible's "Scope: Two Visual Systems" section, confirmed live in `frontend/lib/core/theme/app_colors.dart`. Nothing in this template's Layout section actually called for an indigo element (divider, heading, and card were all already gold/charcoal/cream), so this was a leftover copy-paste from the Product/App palette. Replaced with the two marketing gold shades above (`#B8860B` deep gold / `#C79A3B` lighter gold), matching "Color System — Marketing/Social."
>
> **Note — Footer `#6B7280`:** not one of the Visual Bible's defined neutrals (closest are Slate `#4B5563` and Soft Light `#E0E0E0`). Minor drift — likely fine as a lighter warm-gray tint for footer text, but worth confirming against the official palette rather than assuming.

---

## Typography

**Headings:** Poppins ExtraBold

**Verse:** Inter Medium

**Reference:** Poppins Bold

Large spacing.

Excellent readability.

Never reduce font size just because the verse is long.

Instead:
- Increase the card height.
- Simplify the background.
- Reduce decorative elements.

Scripture must always remain easy to read.

> **Note — "Poppins ExtraBold" vs. Visual Bible's "Poppins, 600–700":** ExtraBold is typically weight 800, heavier than the 600–700 (SemiBold–Bold) range specified for headlines in the Visual Bible. Minor drift; confirm if ExtraBold is an intentional exception for the Story heading treatment.
>
> **Note — non-English verses (Hindi/Malayalam):** Disciplefy supports English, Hindi, and Malayalam (per `CLAUDE.md`), but this template only specifies Poppins/Inter, which don't cover Devanagari or Malayalam scripts. If this daily series runs in all three languages, the template needs a font-substitution rule (or an explicit "English-only" scope) to stay visually consistent day-to-day.

---

## Layout

**Top**
- Disciplefy logo (use uploaded logo exactly)
- Gold divider
- Heading: "Today's Verse"

**Middle**
- Large premium Scripture Card
- Rounded 12px
- Soft Material shadow
- Warm gold background
- Large quotation mark icon
- Reference at top
- Verse centered
- Generous padding

**Bottom**
- disciplefy.in
- Small gold divider
- No CTA
- No marketing text
- No buttons
- No encouragement
- No hashtags

> **Note — Instagram Story safe zones not addressed:** native IG Story UI reserves roughly the top ~250px (profile/close button) and bottom ~250px (reply bar) of the 1080×1920 canvas. The template doesn't instruct the model to keep the logo, heading, or footer clear of those zones, which risks clipping/overlap in a full-bleed design — worth adding as an explicit safe-margin instruction for daily consistency.

---

## Background Photography

Create ONE realistic premium devotional scene based on:

`{{BACKGROUND}}`

**Examples**
- Morning desk with Bible
- Window light
- Coffee and Bible
- Church pew
- Forest prayer walk
- Olive tree
- Rainy window
- Candlelight
- Mountain sunrise
- Lakeside
- Library
- Garden bench

**Requirements**
- Warm natural light
- Realistic photography
- Open Bible
- Minimal composition
- Large negative space
- Soft shadows
- Golden hour
- Apple-quality photography
- No people.
- No hands.
- No distracting objects.

Scripture card must remain the hero.

---

## Design Rules

- The verse card should occupy approximately 55% of the design.
- Background exists only to support the verse.
- Everything should feel calm, modern, premium, minimal.
- The viewer's eyes should immediately go to the Scripture.
- The final result should look like it belongs to an elegant devotional book rather than a social media graphic.

---

## Review Notes (summary)

- **Color palette drift (resolved):** Primary/Secondary used Product/App indigo (`#4F46E5`/`#6366F1`), contradicting the Visual Bible's "no indigo for Marketing/Social" rule — replaced with the gold accent pair.
- **AI-imagery tension (flagged):** "Never use AI-looking imagery" sits oddly against this being a Google Flow/Veo (AI-generated) prompt — likely means "don't look AI-generated," but is worth rephrasing for clarity.
- **Material 3 vs. Apple-quality (flagged):** mixed design-system language (Google's Material 3 + "Apple-quality") not present in the Visual Bible's Marketing/Social guidance; may indicate this template was adapted from a Product/App brief.
- **Typography weight (flagged):** "Poppins ExtraBold" is heavier than the Visual Bible's documented 600–700 range.
- **Multi-language coverage (flagged):** no font fallback specified for Hindi/Malayalam verses.
- **IG Story safe zones (flagged):** no instruction to keep logo/footer clear of native Instagram UI overlap zones.
- **Gold accent hex (fixed):** clarified "match the Disciplefy logo" with the actual Visual Bible hex values (`#B8860B` / `#C79A3B`) so daily generations don't drift on gold tone.
- **Formatting (fixed):** converted the flattened, one-phrase-per-line .docx text into structured markdown headers/bullets; no wording changes to instructions.

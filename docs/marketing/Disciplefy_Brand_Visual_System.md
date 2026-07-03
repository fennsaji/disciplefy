# Disciplefy — Brand Visual System

A minimal, premium, warm, cinematic, scripture-focused identity.
Palette and type are extracted from the app's live design tokens
(`app_colors.dart`, `app_theme.dart`) and extended into a full visual language
for marketing, video, and social.

---

## 1. Brand Personality
**Reverent · Warm · Premium · Cinematic · Grounded**

Disciplefy feels like golden-hour light through a window onto an open Bible —
quiet, unhurried, and beautiful. Modern and elevated, never flashy or "churchy."
It treats Scripture as the hero and technology as the invisible servant.

---

## 2. Color Palette

### Primary — Indigo (trust, depth, the "night before dawn")
| Token | Hex | Use |
|-------|-----|-----|
| Indigo 600 (brand primary) | `#4F46E5` | Primary buttons, logo, key accents, active states |
| Indigo 500 (gradient end) | `#6366F1` | Gradient partner with 600 (top-left → bottom-right) |
| Indigo 300 (light) | `#A5B4FC` | Primary on dark backgrounds, hover/focus |
| Indigo 700 (deep) | `#4338CA` | Pressed states, high-contrast headings |

**Signature gradient:** `#4F46E5 → #6366F1`, 135°. The core brand mark background.

### Secondary — Gold (Scripture, warmth, the sacred)
| Token | Hex | Use |
|-------|-----|-----|
| Warm Gold | `#FFEEC0` | Verse containers, highlights, the "light" accent |
| Deep Gold | `#B8860B` | Gold text on light, richer gradient pairs, foil-like detail |

Gold is the **soul** color — reserve it for Scripture, sacred moments, and premium cues.

### Accent — Coral (sparing, human warmth)
| Token | Hex | Use |
|-------|-----|-----|
| Coral | `#FF6B6B` | Rare emphasis, gentle alerts. **≤5% of any composition.** |

### Neutrals — Warm, never cold
| Token | Hex | Use |
|-------|-----|-----|
| Warm Cream | `#FAF8F5` | Primary light background (NOT pure white) |
| Cream Glow | `#FBEDD9` | Splash / hero warm wash |
| Surface White | `#FFFFFF` | Cards on cream |
| Ink | `#1E1E1E` | Primary text (light mode) |
| Slate | `#4B5563` | Secondary text |
| Near-Black | `#121212` | Cinematic dark backgrounds |
| Charcoal | `#1A1A1A` | Dark surfaces |
| Soft Light | `#E0E0E0` | Text on dark |

### Semantic (functional only — keep out of brand storytelling)
Success `#10B981` · Error `#EF4444` · Warning `#F59E0B` · Info `#3B82F6`

### Palette rules
- **60 / 30 / 10:** 60% neutral (cream or near-black), 30% indigo, 10% gold.
- **Cream over white, near-black over pure black** — warmth is non-negotiable.
- Coral and semantics are *functional*, never decorative.

---

## 3. Typography

### Fonts
- **Poppins** — Headlines & display. Geometric, confident, premium. Weights 600/700.
- **Inter** — Body, UI, captions. Neutral, highly legible. Weights 400/500/600.

### Scale (from the app's type system)
| Role | Font | Size / Weight |
|------|------|----------------|
| Display | Poppins | 28–32 / Bold |
| Headline | Poppins | 20–24 / 600 |
| Title | Inter | 16–18 / 600 |
| Body | Inter | 16–18 / 400, line-height 1.5 |
| Label / caption | Inter | 11–14 / 500 |

### Usage rules
- **Scripture is always the largest, quietest element** — set verses in Poppins,
  generous line-height (1.4–1.6), often in Deep Gold or Ink on cream.
- **One headline idea per frame.** Never stack competing large type.
- **Sentence case** for warmth; ALL-CAPS only for tiny kickers/labels (tracked +0.5).
- Generous line-height and letter-spacing — **space is a feature**, not waste.
- Never more than **two type sizes** active in a single social frame.

---

## 4. Visual Style

**Tone & mood:** contemplative, warm, hopeful, still. A held breath before dawn.
**Lighting:** golden-hour and low-key. Warm key light, soft falloff, deep shadows.
Light should feel like it's *revealing* something (Scripture, a face in prayer).
**Composition:** minimal, lots of negative space, single clear focal point.
Rule-of-thirds, generous margins, letterboxed/cinematic framing.
**Texture:** subtle film grain, soft paper texture on cream, faint light bloom.
Never plastic-clean; always a little warmth and organic grain.
**Depth:** shallow depth of field, soft bokeh, atmospheric haze for premium feel.

---

## 5. Thumbnail Style Guidelines
- **One subject, one line of text, one focal light source.** Nothing crowded.
- Dark cinematic background (near-black/indigo) with a **warm gold light source** OR warm cream with a single indigo/gold accent.
- Text: Poppins, large, 3–5 words max, high contrast, lower-third or centered.
- A single **gold underline or dot** as the recurring signature accent.
- Face/hands/open-Bible imagery lit by warm light; heavy negative space.
- **No busy collages, no arrows, no red circles, no meme energy.** Restraint = premium.
- Consistent safe margins so a series reads as one family at a glance.

---

## 6. Video Style Guidelines
- **Cinematic 4:5 / 9:16** for social; letterbox for a filmic feel where it fits.
- **Warm color grade:** lifted warm shadows, gold highlights, gentle teal-indigo in the darks. Filmic, not saturated.
- Slow, intentional footage: candlelight, pages turning, golden window light, hands, nature at golden hour, quiet interiors.
- **Scripture appears as elegant on-screen type**, timed to breathe (hold 2–3s).
- Open on an atmospheric establishing shot; end on stillness + the gold-accent logo.
- **Audio:** soft ambient pads, piano, subtle swells — never busy or hype.
- Screen recordings (app demos) sit inside a clean device frame on a cream/dark stage, warmly lit — the app looks like a premium object.

---

## 7. Motion & Animation Style
- **Slow, eased, weighted.** Ease-in-out, 300–600ms; nothing snappy or bouncy.
- **Fades and gentle rises** over slides; light blooms and soft dissolves.
- Type: words fade/rise into place, letter-spacing settling — like light dawning.
- The **gold accent draws on** (underline, dot, halo) as the signature transition.
- Gradients drift slowly; grain shimmers faintly. Motion should feel like *breathing*.
- **No fast cuts, spins, whip-pans, or kinetic-typography chaos.** Calm is the brand.

---

## 8. UI Style
- **Material 3, warm-neutral base.** Cream (`#FAF8F5`) light, near-black dark.
- **Buttons:** filled indigo (or the indigo gradient) with white text, **8px radius**,
  min height 48–56px, generous horizontal padding, soft indigo-tinted shadow.
- **Cards:** white on cream / charcoal on near-black, 10–12px radius, 1px hairline
  border, whisper-soft shadow (6–10% black). Rounded, calm, never harsh.
- **Spacing:** an 8px rhythm; lean roomy (16–24px gutters). Air is premium.
- **Layout feel:** single-column, content-first, capped ~900px on wide screens,
  flat app bars (0 elevation), one primary action per screen.
- **Scripture blocks** get a Warm Gold background container — the one consistent flourish.

---

## 9. Image Style
- **Photography-led**, with minimal line/spot illustration only for icons/empty states.
- **Subjects:** open Bibles, hands (praying, writing, holding coffee), warm interiors,
  golden-hour nature, candles, a single person in quiet reflection. Real, unposed, diverse.
- **Lighting:** warm, directional, golden-hour or candlelit; soft shadows; light as metaphor.
- **Color grade:** warm, filmic, slightly desaturated; cream/gold/indigo harmony.
- **Framing:** negative space around the subject; shallow depth of field.
- **Avoid:** cheesy stock ("smiling businessperson"), cold blue light, clip-art crosses,
  over-saturated HDR, literal/cliché religious kitsch.
- Illustrations (when used): thin line, single-weight, gold or indigo, airy — never cartoonish.

---

## 10. Do's & Don'ts

### Do
- Lead with **Scripture and light** — make the Word the hero.
- Keep it **minimal**: one idea, one subject, one light source per frame.
- Use **warm neutrals** (cream, near-black) as the canvas.
- Reserve **gold for the sacred**; indigo for structure/action.
- Let type and imagery **breathe** — negative space signals premium.
- Keep motion **slow, eased, and calm.**
- Maintain a **consistent gold-accent signature** (underline/dot/halo) across assets.

### Don't
- Don't use **pure white or pure black** — always warm them.
- Don't **crowd** frames, stack headlines, or use more than two type sizes.
- Don't go **loud**: no neon, no red-circle/arrow thumbnails, no meme energy.
- Don't use **cold blue** lighting or grades — it kills the warmth.
- Don't lean on **clichéd religious clip-art** or cheesy stock.
- Don't over-animate — no fast cuts, spins, bounces, or kinetic chaos.
- Don't let **UI or tech upstage Scripture** — technology is the quiet servant.

---

### One-line brand summary
*Golden-hour light on the open Word — minimal, warm, and cinematic, where indigo
gives structure, gold marks the sacred, and Scripture is always the hero.*

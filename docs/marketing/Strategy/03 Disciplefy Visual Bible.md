# Disciplefy Visual Bible
Version: 1.1 *(updated — see Changelog)*

This document defines the complete visual identity of Disciplefy across the app, website, marketing site, social media, videos, presentations, print, and future products.
The goal is simple: **every Disciplefy asset should be recognizable without seeing the logo.**

## Scope: Two Visual Systems
This doc originally presented one color system as if it applied everywhere. In practice there are now **two**, and both are correct — they just apply to different surfaces:

- **Product/App UI** → Indigo-primary system below. Confirmed live: `frontend/lib/core/theme/app_colors.dart` sets `brandPrimary = 0xFF4F46E5` (Indigo 600), matching this doc exactly. Use this system for the app, admin dashboard, and any product screenshots.
- **Marketing / Social (Instagram, carousels, launch assets)** → warm cream/charcoal/gold system, **no indigo**, per the already-approved reference cover in `Instagram_Carousel_Image_Prompts.md`. This is the newer direction (post "light tone pass" / "From Believer to Disciple" realignment) and is what all social image-gen prompts and carousels should follow.

Don't mix them — a marketing carousel with an indigo background will look off-brand next to the approved warm/cream reference; an in-app screen using warm-cream-only would lose the indigo trust/CTA signal the product relies on.

## Design Philosophy
Disciplefy is built around one idea: **Scripture is the hero. Technology is the servant.**
Everything we design should help people focus on God's Word — not the interface.
We optimize for: Simplicity · Clarity · Warmth · Trust · Timelessness. Never for trendiness.

## Brand Personality
Disciplefy should always feel: Reverent · Warm · Premium · Cinematic · Grounded · Hope-filled · Peaceful · Authentic
Never: Loud · Flashy · Corporate · Clickbait · Cheap · "Church camp" themed

## Color System — Product/App

**Primary: Indigo**
Purpose: Trust · Wisdom · Stability · Navigation · Calls to action
- Indigo 700 — `#4338CA`
- Indigo 600 — `#4F46E5` *(= app's live `brandPrimary`)*
- Indigo 500 — `#6366F1`
- Indigo 300 — `#A5B4FC`
- Official Gradient: `#4F46E5 → #6366F1`, 135°

**Secondary: Warm Gold**
Purpose: Scripture · God's light · Premium moments · Highlights · Spiritual emphasis
- Warm Gold — `#FFEEC0`
- Deep Gold — `#B8860B`
Gold should never dominate a design — it exists to emphasize sacred moments.

**Accent: Coral**
`#FF6B6B` — used sparingly, maximum 5%.

**Neutral Palette**
Warm Cream `#FAF8F5` · Cream Glow `#FBEDD9` · Surface White `#FFFFFF` · Ink `#1E1E1E` · Slate `#4B5563` · Near Black `#121212` · Charcoal `#1A1A1A` · Soft Light `#E0E0E0`

**Color Usage Rules (Product/App)**
60% warm neutrals · 30% indigo · 10% gold. Avoid pure white. Avoid pure black. Warmth is part of the brand.

## Color System — Marketing/Social
Warm cream/off-white background (`#FAF8F5`), near-black charcoal headlines (`#1E1E1E`, Poppins), gold accents (`#B8860B` / `#C79A3B`) for logo/icons/dividers/key words. No indigo. See `Instagram_Carousel_Image_Prompts.md`'s STYLE BLOCK for the exact spec — that doc is the canonical reference for this palette, keep this section in sync with it if it changes.

## Typography
**Headlines:** Poppins, 600–700
**Body:** Inter, 400–600
Typography should feel calm and readable, never decorative.

**Typography Rules**
- Scripture is always the visual hero.
- Only one headline idea per frame.
- Maximum two font sizes on social posts.
- Use sentence case.
- Allow generous spacing — whitespace communicates confidence.

## Photography Style
Communicate: Presence · Peace · Reflection · Hope · Light · Growth
Preferred subjects: Open Bible · Hands · Prayer · Coffee + Bible · Quiet mornings · Churches · Nature · Golden-hour sunlight · Christian community · Worship · Everyday faith
Avoid: Fake smiles · Corporate stock photos · Clip-art crosses · Religious clichés · Overly posed imagery

**Lighting:** Golden Hour · Window Light · Soft Candle Light · Natural Shadows. Light symbolizes revelation. Darkness creates focus.

**Composition:** Minimal. One subject. One message. One focal point. Generous negative space. Everything unnecessary should be removed.

**Texture:** Subtle film grain · Paper texture · Soft bloom · Organic feeling. Never overly sharp or artificial.

## Video Language
Every Disciplefy video should feel: Slow · Intentional · Peaceful · Hopeful · Premium
Preferred shots: Bible opening · Walking · Prayer · Nature · Journaling · Church · Community · Family · Quiet workspaces

**Motion Language**
Use: Fade · Rise · Slow zoom · Soft dissolve · Gentle light bloom
Avoid: Fast cuts · Flash transitions · Spinning · Whip pans · Aggressive animation

## Google Flow / Veo Guidelines
Every generated scene should communicate: Hope · Grace · Reflection · Peace · Faith · Growth
Preferred locations: Homes · Churches · Coffee shops · Nature · Parks · Libraries · City mornings · Golden-hour streets
Avoid fantasy-style religious imagery unless the creative concept explicitly calls for it.

## Social Media Design
**Reels:** Large captions · Minimal overlays · Elegant scripture · Premium pacing · Warm grade
**Carousels:** One idea per slide · Minimal text · Consistent margins · Simple illustrations
**Stories:** Authentic · Behind the scenes · Prayer · Community · Polls · Bible reading. No overly polished corporate content.

## Thumbnail Rules
One face OR one Bible OR one object. Maximum five words. Large typography. Heavy negative space. One gold accent.
Never use: Red arrows · Shock faces · Clickbait expressions · Busy collages

## App Screens
Always showcase: Real content · Real verses · Clean spacing · Warm lighting · Premium framing
Never use placeholder content in marketing.

## Icons & Illustrations
Thin line icons. Rounded corners. Simple. Modern. Never cartoonish.

## Brand Consistency Checklist
Before publishing any visual asset:
- Uses approved colors *(for the correct surface — Product vs Marketing, see Scope above)*
- Uses approved fonts
- Matches the cinematic tone
- Scripture remains the focus
- Plenty of whitespace
- Premium feel
- Warm lighting
- Minimal composition
- Consistent with Disciplefy's mission

If any answer is No, revise before publishing.

## Visual North Star
Every visual should answer one question: **Does this make someone want to spend more time with God's Word?**
If the answer is yes, it belongs in Disciplefy.

---

## Changelog
- **v1.1:** Added "Scope: Two Visual Systems" section clarifying Indigo-primary applies to Product/App (verified against live `app_colors.dart`), while Marketing/Social has since moved to a separate warm-cream-gold system (per the approved Instagram carousel reference). Previously this doc implied one universal palette, which no longer matched what's actually shipping in marketing assets.

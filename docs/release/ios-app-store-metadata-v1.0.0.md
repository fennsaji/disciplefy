# iOS App Store Metadata — Disciplefy v1.0.0

Copy-paste values for App Store Connect → **Distribution → iOS App 1.0.0** (English, U.K. locale).
Char limits noted per field.

---

## Localizable Information

**Name** _(≤ 30)_:
```
Disciplefy: Bible Study Guide
```

**Subtitle** _(≤ 30)_:
```
Devotional & Scripture Memory
```
Title, subtitle and keywords are indexed together, so no word repeats across them. No AI wording.

---

## Promotional Text  _(≤ 170)_

```
Study the Bible deeper every day: guided Bible study, daily verse, prayer, Scripture memory and reading plans with your church group. Free to start.
```

---


## Description  _(≤ 4,000)_

```
Understand the Bible, not just read it

Disciplefy is a Bible study guide app that turns any Bible verse or question into a clear, personal Bible study — in seconds, in your language. Type a reference like "John 3:16" or ask something real like "What does the Bible say about anxiety?" and get an easy-to-follow study guide grounded in sound, historic Christian theology.

KEY FEATURES

Bible Study Guides
Five study modes for every kind of moment — Quick Read, Standard, Deep Dive, Lectio Divina and Sermon Outline. Each Bible study guide brings you:
• Summary — the passage in plain language
• Historical Context — background, culture and setting
• Interpretation — verse-by-verse meaning
• Related Verses — cross-references for deeper Bible study
• Reflection Questions — for personal devotions or your small group
• Prayer Points — turn what you've learned into prayer

Listen
Hear any study guide read aloud in English, Hindi or Malayalam — perfect for commuting, walking or when you'd rather listen than read.

Voice Discipler
Have a natural spoken conversation about a Bible passage or question and hear the answers in your language.

Bible Chat
Ask deeper follow-up questions about any study guide while keeping the full context of what you're studying.

Learning Paths & Bible Reading Plans
Structured discipleship journeys on prayer, faith, character and more — like a guided Bible reading plan you follow one lesson at a time. Download a path and keep studying offline.

Daily Verse & Daily Devotional
A fresh daily Bible verse and short daily devotional every morning, with a reminder so you never miss it.

Scripture Memory
Memorize Bible verses with spaced-repetition flashcards and eight practice modes — including audio, fill-in-the-blank, word scramble and type-it-out — to truly hide God's Word in your heart.

Fellowship & Church Groups
Study the Bible together with your church or small group, schedule Google Meet sessions, and share prayer requests and praise reports.

Progress
Earn XP, unlock achievements, keep your Bible study streak and climb the leaderboard.

THREE LANGUAGES
• English (KJV)
• हिन्दी — Hindi Bible study
• മലയാളം — Malayalam Bible study
Study, listen and pray in the language you think in.

PRIVACY & SECURITY
• Sign in with Google, Apple, email or phone
• Your notes, saved guides and progress stay private to you
• Read our Privacy Policy: https://www.disciplefy.in/privacy

FREE AND PAID

Start free — no card required. The Free plan includes:
• 15 study credits a day
• Daily Verse
• Learning Paths
• Up to 3 memory verses with 2 practice modes
• Join Fellowship Groups

Optional subscriptions (Standard, Plus, Premium) add more daily credits, Voice Discipler sessions, unlimited follow-ups, unlimited memory verses with all eight practice modes, unlimited fellowship groups and more. See current plans and prices inside the app.

SUPPORT
Questions or feedback? Write to hello@disciplefy.in

Whether you're a new believer taking first steps, a busy disciple who wants depth without spending hours, or someone exploring faith for the first time, Disciplefy helps you meet God in His Word through daily Bible study, prayer and Scripture memory — anytime, anywhere.

"Your word is a lamp to my feet and a light to my path." — Psalm 119:105

Terms of Use: https://www.disciplefy.in/terms
```

---


## Keywords  _(≤ 100 — comma-separated, no spaces after commas)_

```
chat,verse,daily,prayer,journal,kjv,niv,reading,plan,christian,jesus,group,hindi,malayalam,church
```

> "bible", "study", "guide", "devotional", "scripture", "memory" are already in the name/subtitle, so they are left out of the keyword field. Check candidates in ASO Scout (popularity ≥ ~20, competitiveness ≤ ~60) and re-check ranks after 2–4 weeks.

---


## Support URL

```
https://www.disciplefy.in/contact
```

## Marketing URL

```
https://www.disciplefy.in/
```

## Version

```
1.0.0
```

## Copyright  _(≤ 200)_

```
© 2026 Disciplefy
```

> Swap in your registered legal entity name if Disciplefy operates under one (e.g. `© 2026 <Legal Name>`).

## Routing App Coverage File

**Leave empty** — only for apps providing maps / turn-by-turn directions. Not applicable.

---

## ⚠️ Still required before "Add for Review"

- **App Review Information** — demo account credentials (login-required app) + review notes. _Biggest cause of rejection for sign-in apps._
- **Screenshots** for required device sizes.
- **App Privacy** answers (account data, usage, payments).
- **Age Rating** questionnaire.
- **Pricing and Availability**.
- **Subscriptions / In-App Purchases** must be submitted/approved alongside the build.

---

_Theological note: copy frames the AI as a study **companion** (not a replacement for Scripture or church) and is consistent with orthodox Christian theology._

---

## App Review → Notes  _(≤ 4,000)_

```
ACCESSING THE APP (no demo account needed)
This app requires sign-in. The simplest way to review it is to tap "Continue with Apple" on the login screen and authenticate with your own Apple ID — Sign in with Apple is fully supported. "Continue with Google" is also available. There is no guest mode; an account is required.

Account deletion is available in-app: Settings → Delete Account (removes the account and associated data).

WHAT THE APP DOES
Disciplefy generates structured Bible study guides from any verse or topic using an LLM. Enter a reference (e.g. "John 3:16") or a question (e.g. "What does the Bible say about anxiety?") and the app returns a guide with summary, historical context, interpretation, application, reflection questions, prayer points, and related verses. Content is in English, Hindi, or Malayalam.

KEY FEATURES TO TEST
• Study Guides — type a verse/topic on the home screen → "Generate".
• Talk to Discipler — a spoken conversation feature. It needs Microphone + Speech Recognition permission (granted on first use). NOTE: speech recognition does not work on the iOS Simulator (Apple limitation) — please test on a physical device.
• Daily Verse, Learning Paths, Memory Verses, Follow-Up Chat, Fellowship groups.

PERMISSIONS & WHY
• Microphone + Speech Recognition — Talk to Discipler (speak to ask questions).
• Notifications — optional daily verse / reminders.

IN-APP PURCHASES
The core app is free. Optional consumable "token" packs and an auto-renewing subscription unlock additional AI generations. Free users can fully evaluate the app without purchasing.

CONTENT & PRIVACY
• AI-generated study content is grounded in historic, orthodox Christian theology; user inputs are validated/sanitized server-side.
• Fellowship groups are private (invite-based) — there is no public user-generated content feed.

CONTACT
Support: https://www.disciplefy.in/contact
```

> **Sign-in caveat:** "Continue with Apple" must work in **production** for reviewers (you confirmed Apple is enabled on the prod Supabase project). If there's any doubt, also keep a working Google review path.

---

## What's New (release notes) — v1.0.0  _(first release)_

```
Welcome to Disciplefy! Turn any Bible verse or topic into a clear, personal study guide — in English, Hindi, or Malayalam.

• Instant study guides with context, interpretation, application & prayer points
• Talk to Discipler — talk through Scripture and hear answers in your language
• Daily Verse, Learning Paths, Memory Verses, Follow-Up Chat & Fellowship groups

Thank you for installing — we'd love your feedback.
```

> Note: for a brand-new app, the "What's New" field may not appear (it's used for updates). Use it from v1.0.1 onward if 1.0.0 doesn't show it.

---

## Attachment

Optional — leave empty unless asked. (A short screen-recording can help if a feature is non-obvious, but it's not required.)


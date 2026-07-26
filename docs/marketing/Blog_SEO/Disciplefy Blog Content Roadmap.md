# Disciplefy Blog Content Roadmap
Version: 1.3 *(updated — see Changelog)*

## Mission
Build **topical authority** for Disciplefy's marketing blog rather than publishing unrelated articles. This roadmap lists 50 evergreen articles across 6 content pillars, designed to rank for real search intent, earn backlinks, and naturally convert readers into Disciplefy users.

## Not the same system as the auto-generated blog posts
`rs-backend/src/cron/blog_generator.rs` already runs a separate, automated pipeline that generates blog posts from Learning Path topics (`recommended_topics`) via the study-generation API, in English/Hindi/Malayalam, and saves them to the same `blog_posts` table that powers `marketing/app/blog`. That system is topic-recap content tied 1:1 to in-app Learning Path topics.

This roadmap is a **separate, manually-authored editorial track** — pillar/evergreen SEO content targeting search terms no Learning Path topic covers (e.g. "SOAP Bible study method," "What does John 3:16 mean," "Gospel of Matthew Explained"). Both tracks publish to the same blog, but this one needs to be written and reviewed by a person (or by Claude, one article at a time), not auto-generated.

## Resolved: Article 9 is a deliberate exception to the "Never Say AI" rule
`Strategy/01 Disciplefy Brand Bible.md`'s **Language Rule — Never Say "AI"** governs Instagram/app-facing marketing copy. Blog SEO content is a different context — "AI Bible study" is real search intent worth targeting on the site, even though the app/Instagram voice never uses the word. Article 9 ("How AI Can Help You Study the Bible") keeps its title and keywords as planned. Logged as an explicit exception in the Brand Bible so this doesn't read as inconsistency later.

## Before publishing: theological content needs doctrinal review
Pillars 2 (Bible Questions), 3 (Prayer), 5 (Bible Books), and 6 (Bible Characters) all involve interpreting Scripture and doctrine (salvation, grace, repentance, the Kingdom of God, etc.). Per this repo's convention, run doctrinal content through the `paul-the-apostle` review agent before publishing — same bar as in-app Study Guide content.

---

## Master Tracking List
Status starts **Not Started** for all 50. Update as each is drafted/reviewed/published — this list is the queue for "write one per day."

### Pillar 1 — Bible Study (1–10)
| # | Title | Status |
|---|---|---|
| 1 | How to Study the Bible: A Complete Beginner's Guide (2026) | Not Started |
| 2 | The SOAP Bible Study Method Explained | Not Started |
| 3 | Inductive Bible Study Explained | Not Started |
| 4 | Best Bible Study Methods Compared | Not Started |
| 5 | How to Read the Bible in Context | Not Started |
| 6 | How to Understand Difficult Bible Passages | Not Started |
| 7 | How to Build a Daily Bible Study Habit | Not Started |
| 8 | Best Bible Study Apps Compared (2026) | Not Started |
| 9 | How AI Can Help You Study the Bible | Not Started |
| 10 | Common Bible Study Mistakes Christians Make | Not Started |

### Pillar 2 — Bible Questions (11–20)
| # | Title | Status |
|---|---|---|
| 11 | What Does John 3:16 Really Mean? | Draft — needs doctrinal review |
| 12 | What Does Romans 8:28 Mean? | Draft — needs doctrinal review |
| 13 | What Is Faith According to the Bible? | Draft — needs doctrinal review |
| 14 | What Is Grace? | Draft — needs doctrinal review |
| 15 | What Is Salvation? | Draft — needs doctrinal review |
| 16 | What Is Repentance? | Draft — needs doctrinal review |
| 17 | Why Did Jesus Speak in Parables? | Draft — needs doctrinal review |
| 18 | Why Did Jesus Have to Die? | Draft — needs doctrinal review |
| 19 | What Happens After Death According to the Bible? | Draft — needs doctrinal review |
| 20 | What Is the Kingdom of God? | Draft — needs doctrinal review |

### Pillar 3 — Prayer (21–25)
| # | Title | Status |
|---|---|---|
| 21 | How to Pray According to the Bible | Not Started |
| 22 | Why Doesn't God Answer Every Prayer? | Not Started |
| 23 | The Lord's Prayer Explained | Not Started |
| 24 | Powerful Bible Verses About Prayer | Not Started |
| 25 | How to Hear God's Voice | Not Started |

### Pillar 4 — Christian Living (26–35)
| # | Title | Status |
|---|---|---|
| 26 | Bible Verses for Anxiety | Not Started |
| 27 | Bible Verses About Hope | Not Started |
| 28 | Bible Verses About Depression | Not Started |
| 29 | How to Overcome Temptation | Not Started |
| 30 | How to Grow Spiritually | Not Started |
| 31 | Fruits of the Spirit Explained | Not Started |
| 32 | Spiritual Warfare Explained | Not Started |
| 33 | How to Forgive According to Jesus | Not Started |
| 34 | What Is Discipleship? | Not Started |
| 35 | How to Share Your Faith | Not Started |

### Pillar 5 — Bible Books (36–45)
| # | Title | Status |
|---|---|---|
| 36 | Gospel of Matthew Explained | Not Started |
| 37 | Gospel of Mark Explained | Not Started |
| 38 | Gospel of Luke Explained | Not Started |
| 39 | Gospel of John Explained | Not Started |
| 40 | Acts Explained | Not Started |
| 41 | Romans Explained | Not Started |
| 42 | Genesis Explained | Not Started |
| 43 | Psalms Explained | Not Started |
| 44 | Proverbs Explained | Not Started |
| 45 | Revelation Explained | Not Started |

### Pillar 6 — Bible Characters (46–50)
| # | Title | Status |
|---|---|---|
| 46 | Life Lessons from Moses | Not Started |
| 47 | Life Lessons from David | Not Started |
| 48 | Life Lessons from Paul | Not Started |
| 49 | Life Lessons from Peter | Not Started |
| 50 | Life Lessons from Joseph | Not Started |

---

## Pillar 1: Bible Study (Articles 1–10)

### 1. How to Study the Bible: A Complete Beginner's Guide (2026)
**Primary keyword:** how to study the Bible
**Secondary keywords:** Bible study for beginners, Bible study method, daily Bible study
**Should include:** Why Bible study matters · Different study methods (SOAP, Inductive, Verse Mapping) · Choosing a translation · Creating a study routine · Common mistakes · FAQs · CTA to generate a study in Disciplefy

### 2. The SOAP Bible Study Method Explained
**Keywords:** SOAP Bible study, SOAP method, Bible journaling
**Should include:** Step-by-step tutorial · Example using Psalm 23 · Printable template · Common mistakes

### 3. Inductive Bible Study Explained
**Keywords:** Inductive Bible study, observation interpretation application
**Should include:** Observation · Interpretation · Application · Practical example

### 4. Best Bible Study Methods Compared
**Compare:** SOAP · Inductive · Verse Mapping · Character Study · Topical Study

### 5. How to Read the Bible in Context
**Keywords:** Biblical context, historical context Bible
**Should include:** Cultural background · Literary context · Author · Audience

### 6. How to Understand Difficult Bible Passages
**Should include:** Prophecy · Parables · Poetry · Apocalyptic literature

### 7. How to Build a Daily Bible Study Habit
**Should include:** Habit formation · Reading plans · Time management

### 8. Best Bible Study Apps Compared (2026)
**Compare:** Disciplefy · YouVersion · Logos · Blue Letter Bible · BibleHub — explain strengths honestly (including competitors' real strengths, not just Disciplefy's).

### 9. How AI Can Help You Study the Bible
**Keywords:** AI Bible study, Bible AI *(blog-only exception to the "Never Say AI" rule — see note above)*
**Should include:** Benefits · Risks · Discernment

### 10. Common Bible Study Mistakes Christians Make
*(outline not yet specified — follow the SEO Template below)*

---

## Pillar 2: Bible Questions (Articles 11–20)
Each follows the same shape unless noted: historical context, original-language insight, cross references, practical application.

### 11. What Does John 3:16 Really Mean?
**Should include:** Historical context (Nicodemus) · Greek insights (*houtōs*, *monogenēs*, *pisteuōn*, *apollymi*) · Cross references · Applications

### 12. What Does Romans 8:28 Mean?
**Should include:** Suffering context of Romans 8 · *synergei* (work together, not "are good") · v. 29 defines the "good" as Christlikeness · Misuse in grief

### 13. What Is Faith According to the Bible?
**Should include:** *emunah* / *pistis* · Hebrews 11:1 (*hypostasis*, *elenchos*) · Object of faith over size of faith · Paul vs. James resolved

### 14. What Is Grace?
**Should include:** *charis* vs. Greco-Roman patronage · *chen* / *chesed* · Grace saves, justifies, teaches (Titus 2), sustains · Cheap grace and grace-then-effort errors

### 15. What Is Salvation?
**Should include:** Exodus pattern · Saved from penalty/power/presence of sin · Three tenses: justification, sanctification, glorification · Assurance (1 John 5:13)

### 16. What Is Repentance?
**Should include:** *shuv* / *metanoia* · Godly vs. worldly sorrow (2 Cor 7:10; Peter vs. Judas) · Confession + turning + fruit · Repentance as ongoing rhythm

### 17. Why Did Jesus Speak in Parables?
**Should include:** *parabolē* / *mashal* · Five reasons incl. the hard saying of Mark 4:11-12 (judicial concealment) · Nathan/David pattern · How to interpret parables without over-allegorizing

### 18. Why Did Jesus Have to Die?
**Should include:** Sacrificial background · Justice + mercy (Rom 3:26) · Substitution, propitiation, redemption, reconciliation, victory · *tetelestai* · Resurrection as essential · Answer the "divine child abuse" objection

### 19. What Happens After Death According to the Bible?
**Should include:** *Sheol* / *Hadēs* / *Gehenna* · Intermediate state · Bodily resurrection (1 Cor 15) · Judgment · New heaven and new earth · Hell handled soberly · Grief-sensitive note

### 20. What Is the Kingdom of God?
**Should include:** *basileia* as reign not realm · Already/not yet · Kingdom parables · Entry by new birth, repentance, childlike faith · Not the church, not politics

*Drafts for 11–20 are written and live in `articles/11-*.md` … `articles/20-*.md` — all pending `paul-the-apostle` doctrinal review before publishing.*

---

## Pillar 3: Prayer (Articles 21–25)

### 21. How to Pray According to the Bible
### 22. Why Doesn't God Answer Every Prayer?
### 23. The Lord's Prayer Explained
### 24. Powerful Bible Verses About Prayer
### 25. How to Hear God's Voice
*(outlines not yet specified — follow the SEO Template below)*

---

## Pillar 4: Christian Living (Articles 26–35)

### 26. Bible Verses for Anxiety
### 27. Bible Verses About Hope
### 28. Bible Verses About Depression
### 29. How to Overcome Temptation
### 30. How to Grow Spiritually
### 31. Fruits of the Spirit Explained
### 32. Spiritual Warfare Explained
### 33. How to Forgive According to Jesus
### 34. What Is Discipleship?
### 35. How to Share Your Faith
*(outlines not yet specified — follow the SEO Template below. Note: 27/28 touch mental health — handle with pastoral care, not platitudes; consider a light professional-help disclaimer alongside Scripture, matching how the app's own crisis-sensitive content is handled.)*

---

## Pillar 5: Bible Books (Articles 36–45)
One "Ultimate Guide" per book. Each should include: Author · Date · Audience · Historical background · Main themes · Chapter summaries · Key verses · Timeline · FAQs

36. Gospel of Matthew Explained
37. Gospel of Mark Explained
38. Gospel of Luke Explained
39. Gospel of John Explained
40. Acts Explained
41. Romans Explained
42. Genesis Explained
43. Psalms Explained
44. Proverbs Explained
45. Revelation Explained

---

## Pillar 6: Bible Characters (Articles 46–50)
Each should include: Biography · Timeline · Major events · Character strengths · Weaknesses · Lessons · Related verses

46. Life Lessons from Moses
47. Life Lessons from David
48. Life Lessons from Paul
49. Life Lessons from Peter
50. Life Lessons from Joseph

---

## SEO Template — use for every article
1. **SEO Title (≤60 characters)** — primary keyword near the beginning.
2. **Meta Description (150–160 characters)** — summarize with the keyword and a compelling reason to click.
3. **SEO-friendly URL** — short and descriptive (e.g. `/how-to-study-the-bible`).
4. **H1 Title** — match or closely align with the SEO title.
5. **Introduction** — address the reader's question immediately, preview what they'll learn.
6. **Table of Contents** — for long-form content and navigation.
7. **Historical & Cultural Context** — explain the original setting where relevant.
8. **Verse-by-Verse or Section Breakdown** — clear explanations with supporting Scripture.
9. **Original Language Insights** — Hebrew/Greek terms only when they clarify meaning.
10. **Cross References** — link to related Bible passages.
11. **Practical Application** — how the teaching applies today.
12. **Common Misunderstandings** — correct frequent misconceptions respectfully.
13. **FAQ** — 5–10 concise answers targeting long-tail searches.
14. **Summary / Key Takeaways** — reinforce the main points.
15. **Call to Action** — invite readers to generate a personalized Bible study or explore related content in Disciplefy.

## On-Page SEO Checklist
- Target **one primary keyword** and **5–10 related keywords** naturally throughout.
- Write **1,600–1,900 words** (~8-minute read at ~220 wpm) — enough for pillar depth without becoming a skim-past wall of text.
- Descriptive H2/H3 headings that include related keywords.
- **3–5 internal links** to related Disciplefy articles.
- Link to reputable external sources when helpful (Bible translations, historical references).
- Relevant images with descriptive alt text.
- Implement FAQ schema, Article schema, and Breadcrumb schema.
- Optimize images and page speed.
- End with links to related articles and a clear next step.

## Publishing Pipeline
Once an article is drafted per the SEO Template above, save it to `docs/marketing/Blog_SEO/articles/NN-slug.md` with YAML frontmatter (`title`, `slug`, `excerpt`, `tags`, `locale`, `featured`, `status`) followed by the article body — same shape as the existing 10 Pillar 1 files. `slug` and `title` are required; `slug` is used as the filename for the generated content file, so it must be unique.

Local-only publishing scripts live in `scripts/blog-publisher/` (never committed with a live token):

1. **`node convert-md-to-json.js`** — reads every `docs/marketing/Blog_SEO/articles/*.md`, strips frontmatter/H1/the "Table of Contents" section (the site auto-generates its own "On this page" nav from headings), and writes:
   - `scripts/blog-publisher/content/<slug>.md` — plain content only, no frontmatter.
   - `scripts/blog-publisher/articles.json` — one metadata entry per article, pointing at its `content_file`.

   New/unposted articles are auto-scheduled one per day at **8:30 AM IST** (`status: "scheduled"`), starting from the next 8:30 IST slot after the script runs. Articles already sent to the API (`posted: true`) are left completely untouched — never rescheduled, reworded, or double-booked onto an already-used day.

2. **`node publish-blogs.js`** — POSTs each unposted `articles.json` entry to the blog API (`rs-backend`, `POST /api/v1/admin/posts`). On success it stamps the entry `posted: true` with the remote id/status, so **re-running the script is safe** — an already-scheduled/published article is never resent. Use `--dry-run` to validate without calling the API, `--force` to intentionally resend a posted entry.

See `scripts/blog-publisher/README.md` for env setup (`BLOG_API_URL`, `BLOG_ADMIN_TOKEN`).

## Long-Term Goal
These 50 articles are the foundation of a much larger content strategy. Expand each Bible book into chapter-by-chapter guides (e.g. **Matthew 1 Explained** through **Matthew 28 Explained**, then Mark, Luke, John, Acts, Romans, etc.). Over time this can grow into 1,000+ interconnected articles, establishing Disciplefy as a comprehensive Bible study resource with strong organic search visibility.

---

## Changelog
- **v1.0:** Initial roadmap — digitized from the 50-article plan, added a Master Tracking List for daily-writing cadence, noted the distinction from the existing auto-generated Learning-Path blog pipeline, and flagged doctrinal-review requirement for Pillars 2/3/5/6.
- **v1.1:** Resolved Article 9's "AI" keyword as a deliberate blog-only exception to the Brand Bible's "Never Say AI" rule (that rule governs Instagram/app copy; blog SEO content targets real search intent). Logged the exception in the Brand Bible itself.
- **v1.2:** Trimmed the target length from 2,000-4,000 words to 1,600-1,900 words (~8-minute read) — the first 10 Pillar 1 drafts ran 2,800-3,300 words, too long for a blog reader. Applies going forward to Pillars 2-6 as well.
- **v1.4:** Drafted all ten Pillar 2 articles (11-20) into `articles/`, filled in the previously-unspecified 12-20 outlines from what was actually written, and marked 11-20 as Draft pending `paul-the-apostle` doctrinal review. Note: Pillar 1 rows (1-10) still read "Not Started" even though drafts exist in `articles/` — that status column is stale and should be corrected.
- **v1.3:** Added the Publishing Pipeline section documenting `scripts/blog-publisher/` — converts `docs/marketing/Blog_SEO/articles/*.md` into per-article content files + `articles.json`, auto-schedules new articles one per day at 8:30 AM IST, and tracks posted state so re-running the publish script never double-schedules an article.

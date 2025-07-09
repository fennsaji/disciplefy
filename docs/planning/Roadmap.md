# 📅 Disciplefy Product Roadmap

**Version:** 1.0 and Beyond
**Last Updated:** July 2025

---

## ✅ **Version 1.0 – Foundational Launch**

**Goal:** Deliver an intelligent, low-cost Bible study app powered by a spiritually aligned LLM.

### 🔎 Key Features:

* Input: Bible verse or topic → generates structured study guide
* Guide includes: Summary, Explanation, Reflection, Related Verses, Prayer Points
* Guides generated using:

  * The Holy Bible (ESV/KJV/NLT)
  * Bible study outlines and commentaries
  * Sermon transcripts (EN/HI/ML)
* Optional Supabase login (Google/Auth, guest)
* Local caching of recent and saved guides
* Daily Bible Verse integration (free open API)
* Bottom Navigation Bar with: Home, Study, Saved, Settings
* UI/UX: Flutter mobile + basic web, initial English support
* Settings: Theme toggle, Logout, Language preference
* Fully accessible (WCAG AA), light/dark themes

---

## 🕒 **Version 1.1 – Personal Touch**

**Goal:** Empower users to personalize their learning and recall saved content.

* Add personal notes to any study guide
* Favorite/starred guides for quick recall
* Local history view with timestamped entries
* Improved UX navigation and organization for saved guides

---

## 🕒 **Version 1.2 – Daily Devotion & Regional Reach**

**Goal:** Build daily spiritual engagement and multi-language support.

* Daily Bible Verse Feed with AI-generated reflection
* Daily Devotional Guide (auto-generated)
* Push/local notifications
* Full UI + guide language support for Hindi and Malayalam
* User language preference stored in Supabase

---

## 🕒 **Version 1.3 – Connect & Report**

**Goal:** Encourage spiritual fellowship and enable better feedback.

* Share study guides (WhatsApp, link, in-app)
* Anonymous user profiles (optional)
* Bug report/feedback feature inside app
* UI accessibility upgrades (font scaling, RTL)

---

## 🕒 **Version 2.0 – Jeff Reed Study Flow**

**Goal:** Guide users through a multi-step inductive Bible study method.

* 4-Step Guided Flow: Scripture → Scholar → Discussion → Application
* Topic-based sessions with saved progress
* Visual indicators and checkpoints for each step
* Individual step-level progress and timestamps

---

## 🕒 **Version 2.1 – Feedback-Aware AI**

**Goal:** Improve AI output accuracy using structured user feedback.

* Feedback on each guide (thumbs, comments)
* Prompt adaptation logic (non-fine-tuned)
* Share guides with groups and start discussions

---

## 🕒 **Version 2.2 – Thematic Discovery**

**Goal:** Enable guided exploration through tagged themes.

* Auto-tag guides with themes (e.g., Grace, Forgiveness)
* Clickable tag browsing + advanced filter/search
* Improved prompt UX for topical discovery

---

## 🕒 **Version 2.3 – Support the Mission**

**Goal:** Enable donation-based app sustainability.

* “Support Developer” feature (donate ₹100+)
* Razorpay (IN) + Stripe (INTL) secure integration
* Email receipt system with gratitude screen (EN/HI/ML)
* PCI DSS compliant flows
* Dynamic gateway selection based on region

---

## 💡 Vision Summary

| **Focus Area**      | **Strategy**                                                |
| ------------------- | ----------------------------------------------------------- |
| ✝️ Spiritual Depth  | Jeff Reed method, daily study, contextual reflection        |
| 🧠 LLM Quality      | Sermon-trained model + feedback loop                        |
| 🌍 Language Reach   | Hindi, Malayalam, English UI + content                      |
| 🤝 Fellowship       | Study guide sharing, feedback, discussion starter           |
| 🛡️ Trust & Privacy | Secure login, local-first, user-controlled data             |
| 💸 Sustainability   | Low-cost infra + donation support (₹100 default + editable) |

# **📄 Product Requirements Document (PRD)**

**Project Name:** Defeah Bible Study  
**Version:** 1.0  
**Author:** Fenn Ignatius Saji  
**Date:** July 2025

## **1. 📌 Problem Statement**

Most churchgoers and pastors struggle to access personalized, scripture-based study guides quickly. Traditional commentaries are bulky, time-consuming, and not context-aware. There's a need for an app that simplifies Bible learning by generating instant, meaningful study guides based on any verse or predefined spiritual topic (including guided formats like Jeff Reed's method).

## **2. 🎯 Goals and Objectives**

- Allow users to input a Bible verse or spiritual topic and receive a contextual study guide.
- Keep the app low-cost and fast, leveraging AI without high infra cost.
- Offer sharing capabilities for group study and sermons.
- Support both mobile (Flutter) and basic web platform access.
- Enable future multilingual support (e.g., Hindi, Malayalam).
- Include Jeff Reed's 4-step Study Flow as a structured, doctrinally sound alternative.

## **3. 👤 User Personas**

### **📖 Pastor Daniel (45)**
- Leads a rural congregation
- Uses Android phone
- Needs quick Bible insights for sermons
- Prefers offline-ready or fast-access tools

### **🙏 Sister Anjali (29)**
- Devout churchgoer in Tier-2 city
- Uses mobile for daily devotions
- Prefers short, digestible content
- Shares scriptures in WhatsApp church groups

## **4. 🧩 Key Features and Functionality**

| **Feature** | **Description** |
|-------------|-----------------|
| 📥 Input Reference or Topic | User enters a Bible verse (e.g., Romans 12:1) or selects from predefined spiritual topics |
| 📘 Generate Study Guide | AI generates **Summary**, **Context**, **Related Verses**, **Reflection Questions**, **Prayer Points** |
| 🧭 Jeff Reed Study Mode | Fixed topic guides split into 4 structured steps: Context, Scholar, Group, Application |
| 🌐 Share Guide | Share via WhatsApp, Email, or Copy |
| 🔁 View Recent | Stores last 5-10 guides for quick reuse |
| 🔒 Auth (optional) | Login with Google/Apple (Supabase Auth) |
| 📝 Feedback System | Allows users to rate or suggest improvements to the LLM-generated guide |
| 📊 Analytics (Basic) | Track usage metrics: completions, shares, inputs |
| 🧠 Multilingual (V1.2) | English, Hindi and Malayalam. Topics localized and cached for Jeff Reed mode |

## **5. 📊 Success Metrics**

- ⏱️ Avg guide generation time < 3 seconds
- ✅ 90%+ user satisfaction on relevance of study guides  
- 📈 >100 MAUs within 3 months of launch
- 🔁 70%+ of users complete at least 3 Jeff Reed steps per session
- 💸 LLM cost < $12/month for 500 queries (early phase)

## **6. ❗ Assumptions and Constraints**

| **Assumption** | **Constraint** |
|----------------|----------------|
| Max 50-100 concurrent users initially | Primary backend: Supabase for database, auth, and edge functions |
| Basic web UI acceptable | Low LLM cost (use GPT-3.5 or Claude Haiku) |
| RAG not mandatory in V1 | Predefined guide structure to control output size |
| Supabase edge functions preferred | No expensive managed hosting (e.g., VMs, GPUs) |
| Anonymous usage allowed | Rate-limited: 3 guides/hour for anonymous, 30/hour for authenticated users |
| User input optional in Jeff Reed mode | Topics are predefined static list; fallback to default topic if config fails |

## **7. 🏗️ Technical Constraints**

- **Backend:** Supabase (primary) - Auth, Database, Edge Functions
- **Frontend:** Flutter (mobile + web)
- **LLM:** OpenAI GPT-3.5 or Claude Haiku
- **Rate Limiting:** 3 guides/hour (anonymous), 30 guides/hour (authenticated)
- **Data Privacy:** Minimal PII storage, encrypted storage for user preferences

## **8. 🔐 Security & Compliance Requirements**

- All user data protected with Supabase Row Level Security (RLS)
- LLM input sanitization and output validation required
- Anonymous user abuse prevention beyond basic rate limiting
- GDPR compliance for user data and analytics
- Privacy policy required before V1.0 launch

## **9. 📋 Glossary of Terms**

| **Term** | **Definition** |
|----------|----------------|
| **Study Guide Output Sections** | Standardized as: Summary, Context, Related Verses, Reflection Questions, Prayer Points |
| **Jeff Reed Topics** | Predefined static list of spiritual topics (Gospel, Grace, Faith, Discipleship) |
| **Anonymous User** | User without authentication, subject to stricter rate limits |
| **Guide Generation** | The process of LLM creating a structured study guide from user input |
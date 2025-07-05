# **🗓 Sprint Planning Document**

This document outlines the sprint planning for versions v1.0 through
v2.3, following a 2-week sprint cadence.

### **✅ Version 1.0 -- Foundational Launch (Aug 1 -- Sept 12)**

**Goal:** Deliver intelligent AI-powered study guide generation with
core app infrastructure.

#### **🌀 Sprint 1: Aug 1--Aug 14**

**Sprint Goal:** Set up project foundation and core LLM integration.

**Key Deliverables:**

- Flutter project scaffolding (mobile + web)

- Firebase/Supabase auth integration (email & anonymous)

- Backend: Initial OpenAI/Claude LLM integration

- Prompt engineering: structured response template

- Bible verse/topic input validation (EN only)

- Accessibility check: Font scaling, color contrast

- Mock LLM mode (for local dev)

- **DoD:** Codebase pushed, auth and LLM endpoints testable, schema
  baseline defined. Accessibility validated.

- **Navigation Entry Point:** Onboarding flow \> Home screen \> Query
  input field

**Dependencies / Risks:**

- Access to LLM API keys (OpenAI or Claude)

- Prompt quality may require refinement

#### **🌀 Sprint 2: Aug 15--Aug 28**

**Sprint Goal:** Generate and display structured study guide

**Key Deliverables:**

- Guide generation service (Summary, Explanation, Related Verses,
  Reflection, Prayer)

- Save/load recent history (local device cache)

- Responsive UI for mobile + web

- Unit and integration test cases defined

- Input validation and fallback behavior testing

- Accessibility test: Screen reader + scrollable layout support

- **DoD:** Input \> Output validation working for 5+ examples.
  Accessibility & input fallback tested.

- **Navigation Entry Point:** Home \> Input \> Display guide (scroll
  view)

**Dependencies / Risks:**

- LLM cost monitoring

- Structured data mapping from unstructured output

#### **🌀 Sprint 3: Aug 29--Sept 12**

**Sprint Goal:** Polish and release MVP

**Key Deliverables:**

- Loading/error states

- LLM model prompt tuned for Bible & sermon transcripts

- Initial release to TestFlight & Play Store (internal)

- Feedback from test users

- Initial performance test (latency under 3s avg)

- Schema validation and migration test

- **DoD:** 90% test pass rate, deployable app binary, mock/fallback
  content support in dev mode

**Dependencies / Risks:**

- App Store deployment delays

- Prompt alignment with theology guidelines

### **🕸 Version 1.1 -- Personal Touch (Sept 13 -- Oct 10)**

**Goal:** Empower users to personalize and revisit study content.

#### **🌀 Sprint 4: Sept 13--Sept 26**

**Sprint Goal:** Build note-taking and saving features

**Key Deliverables:**

- Add personal notes per guide (Supabase-linked)

- Favorite/star toggle on guides

- History view with timestamps

- QA test case creation for offline/online edge cases

- Accessibility compliance check for notes editor

- **Navigation Entry Point:** Study Guide footer menu \> Save/Notes
  toggle

**Dependencies / Risks:**

- Data sync edge cases (offline vs online)

#### **🌀 Sprint 5: Sept 27--Oct 10**

**Sprint Goal:** Polish personalization and test

**Key Deliverables:**

- Filter by favorited/saved

- Notes editor with autosave

- End-to-end testing for all user states

- Accessibility testing checklist completion

- **DoD:** Manual QA + CI tests pass, filter UX validated with 3 users

**Dependencies / Risks:**

- Firebase/Supabase limits (free tier)

### **🕸 Version 1.2 -- Daily Devotion & Regional Reach (Oct 11 -- Nov 7)**

#### **🌀 Sprint 6: Oct 11--Oct 24**

**Sprint Goal:** Add Daily Bible Verse + reflection engine

**Key Deliverables:**

- Scheduled content fetch (e.g., Psalm 23:1)

- AI-based short reflection

- Push/local notifications

- Test plan for timezone variance

- Local cache or scheduled function for devotional delivery

**Dependencies / Risks:**

- Timezone handling

#### **🌀 Sprint 7: Oct 25--Nov 7**

**Sprint Goal:** Add Hindi/Malayalam generation + language switch

**Key Deliverables:**

- Language switch toggle in UI

- Bible verse/topic prompt localization (Hi/Ml)

- LLM prompt tuning for regional languages

- Fallback text if content not available in selected language

- Accessibility test for multilingual fonts

**Dependencies / Risks:**

- LLM multilingual support reliability

- Font rendering issues (esp. Malayalam)

### **🕸 Version 1.3 -- Connect & Report (Nov 8 -- Dec 5)**

#### **🌀 Sprint 8: Nov 8--Nov 21**

**Sprint Goal:** Enable study guide sharing + bug reporting

**Key Deliverables:**

- Shareable link for each guide (deep link)

- WhatsApp share intent integration

- In-app bug report form (auto-email dev)

- **Navigation Entry Point:** Study Guide screen \> Share \> Choose
  platform

**Dependencies / Risks:**

- Spam filtering or abuse of bug form

#### **🌀 Sprint 9: Nov 22--Dec 5**

**Sprint Goal:** Finalize public user alias + profile

**Key Deliverables:**

- Optional public profile alias

- Guide visibility settings (public/private)

- Multilingual UI toggle (match content language)

- Profile privacy notice

- Clarify whether UI is fully translated or content only

**Dependencies / Risks:**

- Privacy issues with shared content

### **🕸 Version 2.0 -- Jeff Reed Study Flow (Dec 6 -- Jan 2)**

#### **🌀 Sprint 10: Dec 6--Dec 19**

**Sprint Goal:** Introduce guided 4-step flow UI

**Key Deliverables:**

- 4-step UI component

- Step 1: Scripture view with context & commentary

- Step 2: AI study guide integration reuse

- API format: each step is a separate field in the response

- User flow: Predefined topic \> Guided study screen

- Figma validation walkthrough with 2+ users

**Dependencies / Risks:**

- Usability of multi-step UX

- Misconfigured topic fallback behavior

#### **🌀 Sprint 11: Dec 20--Jan 2**

**Sprint Goal:** Enable journaling & progress tracking

**Key Deliverables:**

- Step 3: Reflection prompts and group discussion share

- Step 4: Apply principles (journal entry + goal)

- Track completion timestamp per step (analytics, resumption)

- **DoD:** Analytics track per step, journaling UI tested

**Dependencies / Risks:**

- Syncing journal across devices vs local only

### **🕸 Version 2.1 -- Feedback-Aware AI (Jan 3 -- Jan 30)**

#### **🌀 Sprint 12: Jan 3--Jan 16**

**Sprint Goal:** Collect feedback on AI guides

**Key Deliverables:**

- Thumbs up/down + optional feedback field

- Save to Supabase feedback table

- Admin dashboard (CSV export)

- Anti-spam filters for feedback abuse

- Define data retention window for feedback

**Dependencies / Risks:**

- Feedback abuse and spam

#### **🌀 Sprint 13: Jan 17--Jan 30**

**Sprint Goal:** Use feedback to improve LLM prompt structure

**Key Deliverables:**

- Dynamic prompt modifier based on thumbs data

- Log mapping between generation and feedback

- Versioned prompt templates

**Dependencies / Risks:**

- Prompt tweaking only (no full fine-tune)

### **🕸 Version 2.2 -- Thematic Discovery (Jan 31 -- Feb 27)**

#### **🌀 Sprint 14: Jan 31--Feb 13**

**Sprint Goal:** Auto-tagging and guide taxonomy

**Key Deliverables:**

- Tag extractor from LLM response

- Save/retrieve guides by tags

- Suggested tags during topic entry

- Prompt fallback if no tags detected

**Dependencies / Risks:**

- Tag accuracy (no vector embedding in V2)

#### **🌀 Sprint 15: Feb 14--Feb 27**

**Sprint Goal:** Tag filtering and search UX

**Key Deliverables:**

- Tag list filter on homepage

- Search field with autosuggest

- **Navigation Entry Point:** Home \> Filter toggle

**Dependencies / Risks:**

- UI clutter or missed results

### **🕸 Version 2.3 -- Support the Mission (Feb 28 -- Mar 13)**

#### **🌀 Sprint 16: Feb 28--Mar 13**

**Sprint Goal:** Launch donation feature

**Key Deliverables:**

- Donate button in settings screen

- Razorpay/UPI payment gateway integration

- Default ₹100 donation with editable field

- Thank-you message + email receipt

- Use Razorpay-hosted UI to ensure PCI DSS compliance

- Track LLM usage vs donation coverage

- Add Razorpay failure fallback message

**Dependencies / Risks:**

- Razorpay approval delays

- Handling receipts and donor data privacy

### **🌀 Post-Release Monitoring (Sprint 17)**

**Sprint Goal:** Ensure analytics, sustainability, and user experience
continuity

**Key Deliverables:**

- Monitor LLM cost-to-donation ratio

- Guide retention analytics

- Feedback follow-up system

- Regression test suite for all major flows

- Prompt versioning audit

**Dependencies / Risks:**

- User drop-off in advanced flows

- Cost vs usage balance

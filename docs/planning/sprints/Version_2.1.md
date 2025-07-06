# **🗓 Sprint Task Breakdown -- Version 2.1 (Feedback-Aware AI)**

**Timeline:** Jan 3 -- Jan 30\
**Goal:** Collect user feedback on AI-generated study guides and
leverage it for future LLM prompt refinement.

## **🌀 Sprint 12: Jan 3 -- Jan 16**

**Sprint Goal:** Collect feedback on AI guides from users

### **✅ Frontend Tasks**

- Add thumbs up/down icons **for each study guide as a whole** (not per
  section)

- Add optional feedback textbox (visible after downvote)

- Show confirmation toast/snackbar after feedback submission

- Add multilingual support (EN/HI/ML) for all new UI strings: voting,
  feedback prompt, submit, and confirmation

### **✅ Backend Tasks**

- Create Firestore schema: guide_feedback (guide ID, user ID, vote,
  comment, timestamp, prompt_version)

- Prevent duplicate voting (user + guide ID constraint)

- Build admin feedback export dashboard (CSV export or Google Sheet
  sync)

- Extend study_guides schema to reference cumulative feedback score and
  thumbs breakdown

### **✅ DevOps Tasks**

- Create automated weekly export of feedback logs (scheduled Supabase
  function or GitHub Actions)

- Add spam detection rules:

  - Profanity check (basic regex)

  - Excessive character repetition

  - Emoji-only or gibberish detection

  - Rate-limit feedback (e.g., max 5 per 30 mins)

### **⚠️ Dependencies / Risks**

- UX friction if feedback feels like a chore

- Spam filtering may miss subtle abuse or sarcasm

## **🌀 Sprint 13: Jan 17 -- Jan 30**

**Sprint Goal:** Use feedback to improve LLM prompt quality (without
fine-tuning)

### **✅ Frontend Tasks**

- Display guide rating score (e.g., "92% found this useful")

- Highlight top-rated guides on homepage as \"Most Helpful This Week\"

- Add localized feedback reasons if selected (e.g., \"Too Short\", \"Not
  Clear\")

### **✅ Backend Tasks**

- Tag low-rated guides for admin review (score below 40% with \>20
  votes)

- Dynamically modify prompts based on common negative feedback tags

- Link feedback metadata to generation request (prompt version, model
  used)

- Store guide-level feedback score and auto-flag guides for manual
  moderation

### **✅ DevOps Tasks**

- Enable logging for generation parameters (prompt version, guide ID,
  model)

- Add auto-rotation rules: if a prompt template gets \>40% downvotes
  from 50+ users, it rotates to next version

- Track analytics events:

  - vote_cast

  - feedback_submitted

  - guide_tagged_for_rotation

  - prompt_version_switched

### **⚠️ Dependencies / Risks**

- Prompt tweaks alone may not fix deep model issues

- A/B testing loop might be needed to confirm prompt improvements
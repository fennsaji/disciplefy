# **🗓 Sprint Task Breakdown -- Version 2.2 (Thematic Discovery)**

**Timeline:** Jan 31 -- Feb 27\
**Goal:** Organize spiritual knowledge into reusable insights through
auto-tagging and tag-based discovery.

## **🌀 Sprint 14: Jan 31 -- Feb 13**

**Sprint Goal:** Auto-tag guides with meaningful themes from
LLM-generated output

### **✅ Frontend Tasks**

- Display tags on each guide detail screen (below the title or summary)

- Make tags clickable to trigger tag-based search

- Add visual tag chips (color-coded, scrollable if overflowed)

- Add multilingual tag rendering (EN/HI/ML based on UI language)

- Create entry point to \"Explore by Tags\" from homepage

### **✅ Backend Tasks**

- Create Firestore schema: tags collection (tag ID, label_en, label_hi,
  label_ml, usage_count, is_hidden)

- Extend study_guides schema to store tags: \[string\]

- Implement tag extractor logic in edge function (via LLM response
  post-processing)

- Filter invalid/vague tags (e.g., too short, numeric-only, generic
  words like \"thing\")

- Add field prompt_tag_version to guide metadata for versioning

### **✅ DevOps Tasks**

- Log analytics events:

  - tag_generated

  - tag_saved_to_guide

- Cache top 20 tags (weekly) for faster retrieval on explore screen

- Monitor tag generation cost per guide

### **⚠️ Dependencies / Risks**

- LLM may output vague or redundant tags

- Tags may not consistently reflect deep context

- No manual override in V2.2 (admin curation planned for later)

- Potential search load spike from popular tags

## **🌀 Sprint 15: Feb 14 -- Feb 27**

**Sprint Goal:** Build tag-based search, filtering and discovery UI

### **✅ Frontend Tasks**

- Create tag search screen (search bar + suggested tags)

- Implement autosuggest for tags on input (EN/HI/ML)

- Add filter view: \"Show guides with \[selected tag\]\"

- Display search result list with highlighted tag context

- Add \"Most Used Tags\" carousel on homepage

### **✅ Backend Tasks**

- Add tag-based Firestore query for study_guides (with pagination)

- Store guide-tag relationships as indexed fields

- Add analytics event tracking:

  - tag_search

  - tag_click

- Track tag engagement score for future personalization

### **✅ DevOps Tasks**

- Schedule weekly tag usage report (via Supabase Edge or GitHub Action)

- Log tag performance metrics (avg. search time, hit rate)

- Implement fallback behavior if tag search fails (graceful UX)

### **⚠️ Dependencies / Risks**

- Tag search without full-text index could degrade performance

- Risk of tag flooding if too many tags are generated per guide

- Ambiguity in language-localized tags if inconsistent
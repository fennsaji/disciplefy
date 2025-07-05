# **🎨 Figma Structure Guide -- *Defeah Bible Study App***

## **🗂️ 1. Figma Project Structure**

Bible Study App

├── 🧭 Pages (Project-Level)

│ ├── 0. Cover & Docs

│ ├── 1. Wireframes (Low-Fi)

│ ├── 2. UI Design (High-Fi)

│ ├── 3. Component Library

│ ├── 4. Dev Handoff

│ ├── 5. Archive (Old Flows)

**Tips:**

- Keep **one page per version/sprint** in Wireframes (e.g. v1.0 Guide
  Generation)

- Archive unused or deprecated flows regularly

- Cover page should include PRD + theology guidelines link

## **🧩 2. Wireframe Layout by Flow (v1.0--v2.3)**

  -----------------------------------------------------------------------
  **Flow Name**      **Screen Blocks to Include**
  ------------------ ----------------------------------------------------
  **User             Welcome → Language Select → Login/Register →
  Onboarding**       Dashboard

  **Daily Verse**    Daily Verse Preview → Share → Save
  (v1.3)             

  **Guide            Reference/Topic Input → LLM Loading → Guide Screen →
  Generation**       Save/Share

  **Study Journal    Step 1--4 UI → Note Fields → Resume/Return
  (v2.0)**           

  **Group Sharing    Share Modal → Group View → Comments (if any)
  (v2.1)**           

  **Feedback Flow**  Rate Prompt → Feedback Text → Submit

  **Donate (v2.3)**  CTA → Payment Selection → Success/Thank You
  -----------------------------------------------------------------------

## **🧱 3. Component Naming Convention**

  -----------------------------------------------------------------------
  **Type**       **Naming Example**
  -------------- --------------------------------------------------------
  Button         btn/primary/filled, btn/ghost/small

  Card           card/verse, card/guide-summary

  Input          input/text/default, input/select/language

  Text Styles    text/h1, text/body-small, text/verse-ref

  Icons          icon/share, icon/bookmark, icon/loading
  -----------------------------------------------------------------------

> 🔁 Reuse components from Component Library to ensure consistency.

## **🛠 4. Developer Handoff Checklist**

- ✅ All components named and grouped logically

- ✅ Use Inspect mode for spacing, font, color tokens

- ✅ Use **auto layout** and **variants** for responsive designs

- ✅ Comments added for behavior/tooltips (e.g., "This loads LLM async")

- ✅ Link corresponding **Sprint Task ID** in comment or Dev Handoff
  Page

- ✅ Color mode toggles (light/dark) if applicable

## **🎯 5. Versioning Practice**

  -----------------------------------------------------------------------
  **Design Type**       **How to Handle**
  --------------------- -------------------------------------------------
  Feature in active dev Create a new Frame per version (v2.0 -- Study
  (v1.0--v2.3)          Flow)

  Feature postponed or  Move frame to 5. Archive
  removed               

  Component update      Tag with vX.X inside the component name (e.g.,
                        btn/primary/filled/v2.1)
  -----------------------------------------------------------------------

## **📖 6. Theology-Driven UX Notes**

- Scripture must **always show source** (e.g., John 3:16 -- ESV)

- Avoid excessive emojis or memes in **spiritual flows\**

- LLM-generated content should include **"Powered by AI, reviewed
  by\..."** if moderation is added

- Group features must **emphasize reflection and unity**, not social
  gamification

# **🎡 UX Prompts for Figma AI Tools -- Disciplefy: Bible Study App**


### **📄 Settings Screen**

"Design a Settings screen with:

- Language selector (e.g., English, Hindi)

- Theme toggle (light/dark)

- About section

- Feedback & Support

- 'Support Developer' button (links to Donate Modal)
  Use a neutral, clean layout with icons for each section.

📎 Reached from: Home → Settings icon\
🔙 Returns to: Home Screen\
✅ UX Acceptance Checklist:

- Language change applies instantly

- Theme toggle persists between sessions

- All items accessible by screen reader\"

Here is the completed version with all `[TODO]` sections expanded thoughtfully and precisely, keeping everything consistent with the style and context you've already written:

---

## **🧭 Version 1.0**

## **📄 Sprint Task:**

✅ UX Acceptance Checklist:

* Responsive layout
* All buttons accessible by screen reader
* Follows global design tokens
* Connects to navigation flow

---
## 🌐 Global Navigation Map (v1.0)

### 🔗 Corrected Interaction Flow

1. **App Start** → **Onboarding** *(if first-time)* → **Welcome/Login Screen**
2. **Welcome/Login Screen** → **Home Screen** *(after Google Login or Guest login)*
3. **Home Screen** → **Generate Study** → **Prompt Input** → **Study Guide Screen**
4. **Home Screen** → **Recommended Topics** → **Study Guide Screen**
5. **Home Screen** → **Resume Last Session** → **Study Guide Screen**
6. **Study Guide Screen** → **Share Modal** / **Save**
7. **Settings** - Language selection / Theme / About

---

## **📄 Sprint Task:**

### Onboarding Screen

This should contain:

* Intro carousel (3 slides) to explain app features such as:

  * Generating personalized Bible study guides
  * Exploring predefined topics like Gospel or Baptism
  * Saving notes and tracking past studies
    Each slide can optionally include a Bible verse or spiritual encouragement.
* A single button at the end (e.g., “Get Started”) to move to the Welcome/Login screen

📎 Reached from: App Start
🔙 Returns to: N/A

✅ UX Acceptance Checklist:

* This is viewable only once (on first app launch)
* Smooth transition to Welcome/Login screen
* Swipe and tap support on carousel
* Skippable with “Skip” button

---

### Welcome/Login Screen

Design a Welcome/Login screen with:

* App logo and tagline (e.g., "Deepen your faith with guided studies")
* Buttons:

  * Login with Google (calls Supabase auth flow)
  * Continue as Guest (anonymous login)

📎 Reached from: App Start or Onboarding Screen
🔙 Returns to: N/A

✅ UX Acceptance Checklist:

* Login and Guest buttons functional
* Login shows spinner/loading state
* Smooth transition to Home Screen after login/guest entry
* Fallback error message if login fails

---

### Home Screen

The Home Screen should show the Bible verse of the day prominently under the logo and contain:

* App title/logo at the top (e.g., “Disciplefy”)
* Welcome message with user name if logged in (e.g., “Welcome back, John”)
* Bible verse of the day (fetched dynamically from source like Bible API)
* Main navigation button:

  * Generate Study Guide (Scripture or Topic)
* Quick access banner:

  * “Resume your last study” (appears only if there’s saved progress)
* List of Recommended Study Guides (predefined topics like Gospel, Prayer, Baptism, Grace, Faith in Trials, etc.)
* Bottom navigation bar with icons: Home, History, Settings

📎 Reached from: App Start (if logged in) or Onboarding Flow
🔙 Returns to: N/A

✅ UX Acceptance Checklist:

* Bible verse loads dynamically
* "Generate Study Guide" button functional
* Recommended topics scrollable and tappable
* Resume banner only shows when applicable
* Bottom nav is accessible and visible

---

### Generate Guide Screen

This screen should let the user choose how they want to generate a study guide:

* Toggle to switch between Scripture Reference or Topic
* Input field with suggestions/autocomplete (e.g., “John 3:16”, “Forgiveness”)
* Real-time validation (e.g., invalid references show error)
* “Generate” button (calls Supabase Edge Function)
* Optional: “Preview Prompt” before sending to LLM

📎 Reached from: Home → Generate Guide
🔙 Returns to: Home Screen

✅ UX Acceptance Checklist:

* Input mode toggle functional
* Suggestions update as user types
* “Generate” button disabled until valid input
* Smooth transition to Study Guide screen after generation

---

### Study Guide Screen

Displays the generated study with structure:

* Top bar: Shows selected Bible reference or topic
* Main content:

  * *Context*: Historical and literary context
  * *Interpretation*: Theological insights
  * *Life Application*: Practical implications for today
  * *Discussion Questions*: For reflection and group study
* Text field for personal notes (stored locally or in user’s history)
* Buttons at bottom:

  * “Save Study” (stores to local or Supabase DB)
  * “Share” (opens share modal for copying link or content)
* In case of API failure, show fallback message

📎 Reached from: Daily Verse, Home Screen (Recommended Topics), Generate Guide Screen
🔙 Returns to: Home Screen

❌ Empty State: Show message if AI fails or times out – “We couldn’t generate a study. Try again later.”

✅ UX Acceptance Checklist:

* Scrollable layout on all screen sizes
* Works offline (shows saved study if cached)
* Text is copyable
* Supports font scaling for accessibility
* AI error message shown on failure
* Save and Share buttons functional


## **🧭 Version 1.1**

## **📄 Sprint Task:**

Build Daily Verse screen\
\"Design a Daily Verse screen with:

- Top bar: current date and app logo

- Large centered scripture text (e.g., \'Psalm 23:1 - The Lord is my
  shepherd\...\')

- Share and Save buttons beneath the verse

- Horizontal history list or carousel of past verses at the bottom\
  Use a soft, devotional visual style with plenty of white space.\"

## **🧭 Version 1.2**

## **📄 Sprint Task:**

Build feedback modal\
\"Design a Feedback Modal with:

- Question prompt: \'Was this guide helpful?\' (Yes/No radio buttons)

- Optional text area: \'Tell us how we can improve\'

- Submit button centered at the bottom

- After submission: Display \'Thank you\' toast and log feedback
  anonymously\
  Should be triggered from the Study Guide screen.\
  Use a neutral and non-distracting tone.\"

## **🧭 Version 2.0**

### **📄 Jeff Reed Guided Study Flow:**

\"Design a 4-Step Bible Study Flow screen with:

- Stepper UI showing 1/4 to 4/4 progress

- Step 1: Predefined topic display (e.g., \'Gospel\') with short
  description or context

- Step 2: AI Study Guide (reused component from Study Guide screen, with
  Context/Interpretation/Application sections)

- Step 3: Reflection section (notes field + discussion prompts)

- Step 4: Life application (goal setting + journaling space)

- Navigation: Back / Continue buttons for step switching

- Auto-save progress at each step so user can resume later\
  Use a focused, immersive style to encourage deep reflection.\"

## **🧭 Version 2.1**

### **📄 Study History Screen**

\"Design a Study History screen with:

- List of previously generated study guides

- Filters: sort by scripture/topic, or by date

- Completion indicators for Jeff Reed flow studies

- Tap to resume or view completed guide\
  Use a structured, journal-style layout that promotes continuity and
  spiritual consistency.

📎 Reached from: Home Screen → Study History\
🔙 Returns to: Home Screen\
❌ Empty State: If no history, show: \'You haven't started any studies
yet. Try the Daily Verse to begin.\'\
✅ UX Acceptance Checklist:

- List scrollable and filterable

- Tappable entries resume sessions

- Visual completion tags present

- Accessible to keyboard/screen reader\"

### **📄 Share Modal**

\"Design a Share Modal with:

- Title: \'Share your study guide\'

- Options: WhatsApp, Email, Copy Link

- Toggle: Include personal notes (Yes/No)

- Confirmation banner after sharing\
  Use a light, inviting design with icon-based sharing buttons.

📎 Reached from: Study Guide Screen\
🔙 Returns to: Study Guide Screen\
✅ UX Acceptance Checklist:

- Share buttons functional (WhatsApp/Email/Link)

- Shows confirmation banner

- Content accessible for screen reader

- Respects device dark/light theme\"

## **🧭 Version 2.2**

### **📄 Feedback Insights Dashboard (Admin only)**

\"Design a simple dashboard UI that:

- Displays aggregated feedback from users

- Visual stats: % positive/negative, word clouds from feedback text

- Filters by date or type of study (topic/scripture/Jeff Reed)

- Export to CSV or copy to clipboard\
  Use a minimalist, admin-friendly design with visual clarity.

📎 Reached from: Admin Panel (future extension)\
🔙 Returns to: N/A\
✅ UX Acceptance Checklist:

- Stats and chart panels visible

- Feedback sortable by date/type

- Export button works

- Layout mobile-responsive

## **🧭 Version 2.3**

### **📄 Donate Modal**

\"Design a Donate Modal with:

- Title: \'Support the developer\'

- Amount selector: (default Rs. 100 with increment/decrement)

- Description text: Why donation matters (1--2 lines)

- Razorpay/Google Pay button

- After donation: Show success toast, confirmation email, and
  scripture-based thank-you screen\
  Use a warm, grateful tone and minimal layout.

📎 Reached from: Settings or Support CTA\
🔙 Returns to: Home Screen\
✅ UX Acceptance Checklist:

- Amount selector accessible

- Razorpay/Google Pay flows work

- Toast and thank-you display properly

- No sensitive info hardcoded

- Screen reader friendly\"

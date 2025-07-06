# **🎡 UX Prompts for Figma AI Tools -- Disciplefy: Bible Study App**

> *Auto-converted from Sprint Tasks and Feature Descriptions (v1.0 to
> v2.3)*

## **🧾 Global Entry Screens & Persistent Features**

> These screens and flows are not tied to any specific version milestone
> but are part of the persistent app experience available across all
> versions.

### **📄 Welcome & Login Screen**

\"Design a Welcome screen with:

- App logo and tagline (e.g., \'Deepen your faith with guided studies\')

- Buttons:

  - Continue as Guest

  - Login with Email/Google

- Optional intro carousel (3 slides) to explain app features\
  Use a gentle, spiritually inviting layout with scripture encouragement
  quotes.

📎 Reached from: App Start\
🔙 Returns to: N/A\
✅ UX Acceptance Checklist:

- Login and guest buttons functional

- Carousel skippable

- Smooth transition to Home screen\"

### **📄 Settings Screen**

\"Design a Settings screen with:

- Language selector (e.g., English, Hindi)

- Theme toggle (light/dark)

- About section

- Feedback & Support

- \'Support Developer\' button (links to Donate Modal)\
  Use a neutral, clean layout with icons for each section.

📎 Reached from: Home → Settings icon\
🔙 Returns to: Home Screen\
✅ UX Acceptance Checklist:

- Language change applies instantly

- Theme toggle persists between sessions

- All items accessible by screen reader\"

### **📄 Prompt Input Screen (Pre-Generation)**

\"Design a Prompt Entry screen with:

- Toggle for input mode: Scripture Reference / Topic

- Input field with suggestions (e.g., \'John 3:16\', \'Forgiveness\')

- Optional: \'Preview Prompt\' before generating

- Generate button to trigger LLM\
  Use a minimal, focus-friendly layout.

📎 Reached from: Home → Generate Study\
🔙 Returns to: Home Screen\
✅ UX Acceptance Checklist:

- Input fields validated

- Prompt editable before submission

- Clear guidance on what to enter\"

## **🧭 Version 1.0**

## **📄 Sprint Task:**

Build Home Screen with navigation to all major features.\
Include clear navigation to scripture-based and topic-based study
generation.\
Enable preview cards for predefined topics like \'Gospel\', \'Faith\',
and \'Baptism\' under the Jeff Reed Study Flow section.

🪄 UX Prompt:\
\"Design a Home Screen with:

- App title/logo at the top (e.g., \'Disciplefy: Bible Study\')

- Main navigation buttons:

  - Daily Verse

  - Generate Study Guide (Scripture or Topic)

  - Jeff Reed 4-Step Study Flow (featuring topic cards like Gospel,
    Baptism)

  - Study History

- Welcome message or quote of the day (optional)

- Segmented toggle for switching between \'Reference\' and \'Topic\'
  study entry

- Quick access banner to resume last session

- CTA or settings icon to \'Support Developer\'\
  Use a clean, warm welcome layout with large icons or cards for
  intuitive navigation and support for RTL/scripture fonts.

✅ UX Acceptance Checklist:

- Responsive layout

- RTL/scripture font compatibility

- All buttons accessible by screen reader

- Follows global design tokens

- Connects to navigation flow## 🧭 Version 1.0

## **🌐 Global Navigation Map**

### **🔗 Interaction Flow Notes**

9.  Home Screen → Generate Study → Prompt Input

10. Admin Panel → Feedback Insights Dashboard\
    Each screen prompt below should include the path users take to reach
    it and any backward navigation available. Add \"Reached from:
    \[source screen\]\" and \"Returns to: \[target screen\]\"
    annotations where missing.

11. App Entry → Onboarding (Welcome → Login or Continue as Guest)

12. Onboarding → Home Screen

13. Home Screen → Daily Verse → Generate Guide (Reference or Topic)

14. Home Screen → Jeff Reed Study Flow (Predefined Topics)

15. Generate Guide → Study Guide Screen → Feedback Modal or Share Modal

16. Study Guide Screen → Start Jeff Reed 4-Step Flow → Stepper (1 to 4)

17. Home Screen → Study History → Resume Study

18. Settings or CTA → Donate Modal

## **📄 Sprint Task:**

Build Study Guide screen with verse, AI-generated content, user notes,
and share button.\
Also allow user to input a topic to generate a study guide.

🪄 UX Prompt:\
\"Design a Study Guide screen with:

- Top bar: displays selected Bible reference or topic input (e.g.,
  \'John 3:16\' or \'Faith in Trials\')

- Input field or dropdown for user to switch between \'Reference\' and
  \'Topic\' entry modes

- Main section: LLM-generated content broken into:

  - *Context*: Historical and literary background

  - *Interpretation*: Key theological meaning

  - *Life Application*: Actionable insights for today

- Text field: for user to write notes or reflections

- Bottom section: Save and Share buttons\
  Use a clean, devotional aesthetic.\
  📎 Reached from: Daily Verse, Home Screen, Prompt Input Screen\
  🔙 Returns to: Home Screen, Study History\
  ❌ Empty State: Show message if AI fails or times out -- \'We couldn't
  generate a study. Try again later.\'\
  ✅ UX Acceptance Checklist:

- Scrollable, responsive layout

- Copy/share content supported

- Font scaling supported

- Works offline with fallback message

- AI error fallback implemented

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

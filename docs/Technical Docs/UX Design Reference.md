# **✨ UX Design Reference -- Defeah Bible Study App**

## **👤 User Personas**

- **Sarah, 28** -- A young adult Christian woman who attends weekly
  Bible study. Wants easy ways to deepen her understanding during busy
  work weeks. Comfortable with mobile apps.

- **Pastor Joseph, 45** -- Leads small groups and wants guided tools for
  scripture-based teaching. Needs theological accuracy, prefers
  traditional layouts.

- **Ravi, 19** -- New believer exploring Christianity. Wants a
  non-intimidating entry point to learn scripture with AI help.

## **⮏ Feature Flows (by Version)**

### **v1.0 -- AI Guide Generation**

1.  User inputs Bible reference or topic

2.  LLM generates a multi-paragraph study guide

3.  User can:

    - Bookmark

    - Share

    - Provide feedback

### **v1.1 -- Multilingual Support**

1.  Language select on first open

2.  All UI labels and AI output localized

### **v1.2 -- Save History & Resume**

1.  View previously generated guides

2.  Resume journaling or edit saved guides

### **v1.3 -- Daily Verse + Feedback**

1.  User sees daily verse

2.  Can share to social or save

3.  Feedback on AI-generated guides

### **v2.0 -- Jeff Reed 4-Step Flow**

1.  **Step 1:** Study Scripture (verse reading w/ context)

2.  **Step 2:** Consult Scholar (AI Guide reuse)

3.  **Step 3:** Reflect & discuss (Notes + journaling)

4.  **Step 4:** Apply (Life application goals)

### **v2.1 -- Share with Study Group**

1.  Generate link to share guide session

2.  Group members can view & comment

### **v2.3 -- Donate to Developer**

1.  CTA for donation (default Rs. 100)

2.  Payment interface

3.  Confirmation screen

## **📱 Screen / Component Names**

- SplashScreen

- OnboardingFlow

- HomeScreen

- DailyVerseCard

- ReferenceInputPage

- GuideGeneratorPage

- StudyStepCard

- JournalEntryScreen

- FeedbackModal

- GuideShareModal

- DonateSheet

## **🧠 Functional Expectations per Screen**

### **GuideGeneratorPage**

- Input field (TextFormField) for topic or scripture

- Generate CTA triggers LLM request

- Show loading shimmer while AI generates

- Display:

  - Verse reference

  - Full passage (if available)

  - Generated guide content

- Buttons: Bookmark, Share, Feedback

### **DailyVerseCard**

- Static or fetched verse of the day

- Share & Copy buttons

- Save to \"My Verses\"

### **StudyStepCard (v2.0)**

- Stepper component (1/4, 2/4\...)

- Step 1: Scrollable scripture preview

- Step 2: Reuse GuideGeneratorPage layout

- Step 3: Notes input (TextArea)

- Step 4: Goal-setting field + Journal CTA

### **DonateSheet**

- CTA button \"Support Developer\"

- Amount selector (default Rs. 100)

- Razorpay or Firebase Payments embed

- Thank You screen with scripture verse

### **FeedbackModal**

- Triggered from Guide page

- Radio: \"Helpful? Yes/No\"

- Optional text input

- Submit sends data to feedback log

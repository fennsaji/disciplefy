# **✅ QA Test Case Document**

**Project:** Defeah Bible Study App\
**Author:** QA Team\
**Date:** July 2025\
**Test Format:** Manual/Automated\
**Tooling:** Firebase Emulator, Postman, Flutter Driver, Supabase CLI
(optional)

## **🔍 Test Cases for Version 1.0**

### **🔹 TC-001: Generate Study Guide from Bible Verse**

  -----------------------------------------------------------------------------
  **Step**   **Action**         **Expected Result**
  ---------- ------------------ -----------------------------------------------
  1          Open app           Home screen loads

  2          Enter verse \"John Valid input accepted
             3:16\"             

  3          Tap generate       Guide is generated with 5 structured sections

  4          Validate section   Summary, Context, Related Verses, Questions,
             labels             Prayer are present
  -----------------------------------------------------------------------------

### **🔹 TC-002: Generate Guide from Topic**

  ---------------------------------------------------------------------------
  **Step**   **Action**              **Expected Result**
  ---------- ----------------------- ----------------------------------------
  1          Enter \"forgiveness\"   Input accepted

  2          Tap generate            Guide generated using topic context
  ---------------------------------------------------------------------------

### **🔹 TC-003: Anonymous Guide Generation**

\| Step \| User not logged in \| Anonymous session allowed \|\
\| 2 \| Generate guide \| Output is not stored but is viewable \|

### **🔹 TC-004: Login with Google**

  --------------------------------------------------------------------------
  **Step**   **Action**             **Expected Result**
  ---------- ---------------------- ----------------------------------------
  1          Tap Google login       Redirect to Google Auth

  2          Successful login       JWT stored and session initialized
  --------------------------------------------------------------------------

### **🔹 TC-005: Save Guide to History**

\| Step \| Generate + Logged In \| Guide ID saved to cloud user profile
\|\
\| 2 \| Reopen app \| Previously saved guides visible \|

### **🔹 TC-006: Share Study Guide**

\| Step \| Tap share button \| Share sheet opens (WhatsApp, Email) \|\
\| 2 \| Copy link \| Guide content copied to clipboard \|

### **🔹 TC-007: Rate Limiting (Anonymous)**

\| Step \| Generate \> 3 guides/hr \| 429 error with retry header shown
\|

## **🔍 Test Cases for Version 1.1 (History & Auth)**

### **🔹 TC-008: View Recent History**

\| Step \| Generate 2 guides \| Both show under \"Recent Guides\" \|\
\| 2 \| Tap item \| Guide opens in same structured format \|

### **🔹 TC-009: Delete Saved Guide**

\| Step \| Tap delete on saved item\| Confirm prompt appears \|\
\| 2 \| Confirm delete \| Guide removed from history \|

### **🔹 TC-010: Auth Persistence**

\| Step \| Logout + Login again \| History still accessible \|

## **🔍 Test Cases for Version 1.2 (Feedback)**

### **🔹 TC-011: Submit Feedback**

\| Step \| View generated guide \| Feedback section appears below \|\
\| 2 \| Rate + Comment \| POSTs to feedback endpoint, success toast
shown \|

## **🔍 Test Cases for Version 1.3 (Daily Verse + Bug Reporting)**

### **🔹 TC-012: Daily Verse Load**

\| Step \| Open app on new day \| New verse shown in \"Today's Word\" \|

### **🔹 TC-013: Bug Report Flow**

\| Step \| Tap menu \> Report Bug \| Bug report modal appears \|\
\| 2 \| Fill form, attach image \| Sent to backend, confirmation shown
\|

## **🔍 Test Cases for Version 2.0 (Jeff Reed Study)**

### **🔹 TC-014: Select Jeff Reed Topic**

\| Step \| Tap \"Gospel\" \| 4-step layout appears \|

### **🔹 TC-015: Step-by-Step Navigation**

\| Step \| Scroll through steps \| Context, Scholar, Discussion,
Application all visible \|

## **🔍 Test Cases for Version 2.1 (Study Group Sharing)**

### **🔹 TC-016: Share with Group**

\| Step \| Tap \"Share to Group\" \| Copy/share button allows link +
image \|

### **🔹 TC-017: Group Guide Structure Check**

\| Step \| Open shared content \| Proper headings + readable summary \|

## **🔍 Test Cases for Version 2.3 (Donate to Developer)**

### **🔹 TC-018: View Donate Prompt**

\| Step \| Open settings \| \"Support Developer\" option visible \|

### **🔹 TC-019: Process ₹100 donation**

\| Step \| Tap Donate (Google Pay) \| Razorpay opens, ₹100 prefilled \|

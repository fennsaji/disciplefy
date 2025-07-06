# **🗓 Sprint Task Breakdown -- Version 2.3 (Support the Mission)**

**Timeline:** Feb 28 -- Mar 13\
**Goal:** Introduce donation functionality to allow users to support the
developers with a default ₹100 contribution.

## **🌀 Sprint 16: Feb 28 -- Mar 13**

**Sprint Goal:** Launch donation feature with secure payment integration

### **✅ Frontend Tasks**

- Add \"Donate\" button to settings/about screen and study result screen
  (e.g., \"Found this helpful? Support with ₹100\")

- Create donation UI with:

  - Default ₹100 quick-donate button

  - Optional custom amount field with validation (₹10--₹5000,
    digit-only)

  - UPI/Wallet/Card selection

  - Error state: failed/cancelled payment toast/snackbar + retry CTA

- Design multilingual thank-you screen (EN/HI/ML) with transaction
  summary and gratitude message

- Include option to receive a digital receipt via email

- Display disclaimer: \"This is a voluntary donation to support
  development; not tax deductible.\"

- Auto-switch payment gateway (Razorpay or Stripe) based on user region
  (IN or INTL)

### **✅ Backend Tasks**

- Integrate Razorpay (India) + Stripe (international fallback)

- Firestore schema: donations (txn ID, user ID/device ID, amount,
  currency, method, timestamp, status)

- Use Firebase Functions for:

  - Receipt email (via SendGrid or Gmail API)

  - Server-side signature verification of Razorpay webhook

  - Save metadata post-confirmation only

  - Handle re-sending of receipts if payment confirmed but receipt fails

- Spam and profanity filter for custom messages (if any)

### **✅ DevOps Tasks**

- Set up Razorpay merchant account + Stripe fallback with test & live
  keys

- Configure webhook endpoint (Supabase/Cloud Function) with secure
  signature validation

- Alerts:

  - Log failed/delayed transactions

  - Retry mechanism for failed receipts

  - Slack/email alert on anomalous spikes or repeated failure patterns

- QA: test all flows in Razorpay sandbox + production using UPI, wallet,
  cards

- Backup donation logs regularly

### **⚠️ Dependencies / Risks**

- Razorpay KYC/approval delays for live environment

- Ensuring compliance with Indian digital donation regulations

- Must securely verify webhook origin to prevent fraud/spoofing

- Anonymous donations must be linked via session/device ID if user ID
  not present

- Donation restore/retry logic must work across dropped network
  scenarios

- Future: PAN/receipt handling if donation exceeds ₹2000 per user
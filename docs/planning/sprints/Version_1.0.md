# 🗓 Sprint Planning Document for Defeah Bible Study App

This document outlines the sprint planning for versions **v1.0 through v2.3** of the Defeah Bible Study App, following a 2-week sprint cadence.

---

## ✅ Version 1.0 – Foundational Launch (Aug 1 – Sept 12)

> **Goal:** Deliver intelligent AI-powered study guide generation with core app infrastructure.

### 🌀 Sprint 1: Aug 1–Aug 14

**Status:** ✅ Completed

* **Sprint Goal:** Set up project foundation and core LLM integration.

✅ Frontend Tasks

* Task 1: Scaffold new Flutter project with null safety and Clean Architecture folder structure ✅
* Task 2: Implement UI for verse/topic input with validation and loading state ✅
* Task 3: Build initial navigation stack (Onboarding > Home > Generate Guide > Study Guide > Error) ✅
* Task 4: Implement basic onboarding flow (intro carousel, welcome/login) ✅
* Task 5: Implement Settings screen (Logout) ✅
* Task 6: Implement “View Recent Guides” UI on Home screen ✅
* Task 7: Implement Bottom Navigation Bar with tabs: Home, Study, Saved, Settings ✅

✅ Backend Tasks

* Task 1: Set up Supabase Auth (Google/Apple OAuth + anonymous)  ✅
* Task 2: Integrate LLM API (OpenAI/Claude) via Supabase Edge Function  ✅
* Task 3: Create prompt templates with validation pipeline  ✅
* Task 4: Integrate Daily Bible Verse API (open-source, free license) for daily verse feed
* Task 5: Implement cache table for recent guides in Supabase and local cache 
* Task 6: Create API for saving Guides, fetching saved guides

✅ DevOps Tasks

* Task 1: Configure GitHub Actions for CI/CD (build, lint, test, deploy) 
* Task 2: Configure Supabase project (RLS, migrations, Edge Functions) 
* Task 3: Configure environment secrets for API keys 

**Dependencies / Risks:**

* LLM API keys availability
* OAuth credential setup

**Definition of Done (DoD):**

* App scaffold and navigation fully functional
* Onboarding, settings, and basic UI screens implemented
* Auth flows (anonymous + OAuth) working
* Daily verse fetch and recent guides display working
* LLM mock and live mode tested
* CI/CD pipeline green on main branch
* Accessibility baseline (font scaling, contrast) automated checks pass
* Bottom navigation tabs implemented and working

### 🌀 Sprint 2: Aug 15–Aug 28

**Sprint Goal:** Generate and display structured study guide.

✅ Frontend Tasks

* Task 1: Build Generate Guide screen (input toggle, suggestions, generate button)
* Task 2: Build Study Guide screen with sections (Context, Interpretation, Life Application, Questions, Related Verses), notes field, Save & Share buttons
* Task 3: Implement collapsible section cards and error/retry states
* Task 4: Save study guides locally and via Supabase when user clicks Save
* Task 5: Add Saved Guides bottom navigation tab showing saved list and Integrate API

✅ Backend Tasks

* Task 1: Parse and map LLM responses to JSON schema ✅
* Task 2: Save/generated guide metadata to Supabase table ✅
* Task 3: Local cache expiration and sync logic ✅

✅ DevOps Tasks

* Task 1: Add PR workflow for test & deploy edge functions ✅
* Task 2: Integration tests for LLM function and schema validation ✅

**Dependencies / Risks:**

* LLM rate limits and latency
* Schema mismatch errors

**Definition of Done (DoD):**

* Generate & Study Guide screens fully functional with live data
* Save & retrieve guide actions working locally and cloud
* Error handling and retry tested
* Accessibility checks for new screens pass
* Integration tests green
* Saved tab in bottom navigation bar functional

### 🌀 Sprint 3: Aug 29–Sept 12

**Sprint Goal:** Polish MVP & prepare internal release.

✅ Frontend Tasks

* Task 1: Add skeleton loaders and progress animations
* Task 2: Implement light/dark mode toggle with persistence ✅
* Task 3: Polish responsiveness for tablet and web breakpoints ✅
* Task 4: Persist recently viewed guides locally and display on Home screen ✅
* Task 5: Add basic localization support structure (intl package) ✅

✅ Backend Tasks

* Task 1: Finalize system prompt tuning for theological accuracy ✅
* Task 2: Add version tagging to saved guides metadata ✅
* Task 3: Implement fallback logic to mock data if LLM fails ✅

✅ DevOps Tasks

* Task 1: Create internal Android/iOS builds via TestFlight & Play Store ✅
* Task 2: Configure Supabase log monitoring and Sentry alerts ✅

**Dependencies / Risks:**

* App store approval timing
* Theological tone drift

**Definition of Done (DoD):**

* MVP build successfully deployed to internal tracks
* Animations & theme tested on multiple devices
* Localization scaffold in place
* Monitoring and alerts operational
* QA signoff on core user flows
* Recently viewed logic shown correctly on Home screen
* Theme toggle logic fully implemented and persisted
* Bottom navigation bar functional across all routes

---

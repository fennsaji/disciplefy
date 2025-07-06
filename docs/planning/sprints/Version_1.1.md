# **🛠 Sprint Task Breakdown -- Version 1.1 (Personal Touch)**

This document outlines the **task-level execution plan** for **version
v1.1**, focusing on enabling users to personalize and revisit study
content. Each sprint includes frontend, backend, and DevOps tasks, with
DoD definitions and known risks.

### **✅ Version 1.1 -- Personal Touch (Sept 13 -- Oct 10)**

**Goal:** Empower users to personalize and revisit study content.

## **🌀 Sprint 4: Sept 13--Sept 26**

**Sprint Goal:** Build note-taking and saving features

### **✅ Frontend Tasks:**

- Add UI for note input below each generated study guide

- Implement favorite/star toggle icon on guide cards

- Design "My Notes" screen to list guides with saved notes

- Handle edge cases for empty notes, invalid saves, and deleted guides

### **✅ Backend Tasks:**

- Create Supabase schema for storing notes (user_id + guide_id)

- Store starred guides with indexing and sort by timestamp

- Implement offline-first sync behavior (local-first → Supabase merge)

- Add fallback logic for anonymous users (local-only save)

### **✅ DevOps Tasks:**

- Set up Supabase table RLS for user-level access on notes

- Schedule Supabase backups for notes and starred tables

- Enforce validation rules to prevent anonymous overwrite or invalid
  save

### **✅ Deliverables:**

- Notes UI integrated and working across generated guides

- Saved/starred guides visible on personal notes screen

- Supabase syncing implemented with offline-first fallback

### **✅ DoD:**

- Starred guides persist across sessions (logged-in)

- Notes CRUD functions tested for web + mobile

- UI passes accessibility standards (keyboard nav, font scale)

### **⚠️ Dependencies / Risks:**

- Sync timing issues between local and cloud state

- User confusion between temporary and saved notes

- Supabase limits on row operations or user access if scaled

## **🌀 Sprint 5: Sept 27--Oct 10**

**Sprint Goal:** Polish personalization features and conduct full QA

### **✅ Frontend Tasks:**

- Add edit/delete functionality to saved notes

- Add filters on notes screen (recently updated, starred only,
  chronological)

- Improve visual cues and animations for starred state

- Add notes empty state and recovery UX (e.g., "No notes yet")

### **✅ Backend Tasks:**

- Implement soft delete (archived_at field) for notes

- Add created_at and updated_at fields to all note objects

- Clean up unused schema columns added in Sprint 4

- Enable tag-based query for notes (future v2.2 prep)

### **✅ DevOps Tasks:**

- Run integration tests using Supabase emulator (CRUD + RLS)

- Automate backups and test restore from backup

- Add alerts for backup failure or table lock error

### **✅ Deliverables:**

- Fully working note-taking with edit/delete/filtering

- All edge cases handled (empty state, deleted guides)

- Supabase structure cleaned and indexed for scale

### **✅ DoD:**

- Notes screen UX validated on web/mobile

- Starred logic and update propagation tested

- Backup/restore tested with 100+ records

### **⚠️ Dependencies / Risks:**

- Supabase index latency with large note collections

- User perception: saved = synced (when offline it's local-only)

- Future scaling challenge if "My Notes" exceeds pagination
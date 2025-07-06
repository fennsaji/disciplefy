# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🔁 Pre-Execution Behavior - MANDATORY INITIALIZATION

**CRITICAL RULE**: Before executing any task or prompt, you MUST perform the following initialization step:

### ✅ Required Document Loading Sequence

Load ALL documents from the `docs/` folder into memory, including:

1. **Core Specifications:**
   - `specs/Product Requirements Document.md` (PRD)
   - `architecture/Technical Architecture Document.md`
   - `security/Security Design Plan.md`
   - `architecture/Data Model.md`
   - `specs/API Contract Documentation.md`

2. **Implementation Plans:**
   - `planning/Technical Docs/sprints/Sprint_Planning_Document.md` (v1.0 to latest)
   - `specs/DevOps & Deployment Plan.md`
   - `architecture/Error Handling Strategy.md`
   - `specs/LLM Input Validation Specification.md`

3. **Quality Assurance:**
   - `specs/Dev QA Test Specs.md`
   - `specs/Admin Panel Specification.md`
   - `architecture/Offline Strategy.md`
   - `security/Anonymous User Data Lifecycle.md`
   - `architecture/Migration Strategy.md`

4. **Version Documentation:**
   - All sprint and version files in `docs/planning/Technical Docs/sprints/` directory:
     - `planning/Technical Docs/sprints/Version_1.0.md` through `planning/Technical Docs/sprints/Version_2.3.md`
     - `planning/Technical Docs/sprints/Sprint_1_Human_Tasks.md`

5. **LLM Development Standards:**
   - `internal/LLM_Development_Guide.md` - **MANDATORY** for all LLM-related tasks

### 🎯 Purpose

Ensure all decisions, outputs, suggestions, or code follow the **finalized and most accurate state** of the system as documented in the comprehensive specification set.

### ⚠️ Compliance Requirement

**Failure to perform this initialization step constitutes a violation of operating procedure.** All system interactions must be grounded in the complete documentation context to maintain consistency and avoid conflicts with established specifications.

## Project Overview

This is the Disciplefy Bible Study app project with **100% production-ready documentation** (v1.0-docs-stable). The repository contains comprehensive specifications that have undergone complete audit resolution and quality assurance validation.

## Repository Structure

- `README.md` - Basic project identifier
- `docs/` - **Production-grade documentation set** including:
  - Complete architecture and technical specifications
  - Finalized product requirements and roadmap
  - Enterprise-grade security and deployment plans
  - Comprehensive API contracts and data models
  - Complete error handling and QA specifications
  - User lifecycle and migration strategies

## Development Status

**Current State**: Documentation Complete (100% Audit Compliance)
- ✅ All architectural conflicts resolved
- ✅ Backend unified on Supabase
- ✅ Security frameworks implemented
- ✅ Error handling standardized
- ✅ Testing specifications complete
- ✅ Production deployment ready

**Next Phase**: Development Implementation

## Technology Stack (Finalized)

- **Frontend**: Flutter (Mobile + Web)
- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **Authentication**: Supabase Auth (Google, Apple, Anonymous)
- **LLM Integration**: OpenAI GPT-3.5 Turbo / Anthropic Claude Haiku
- **Payments**: Razorpay integration
- **Deployment**: Supabase Edge Functions + Flutter build pipeline

## Development Guidelines

When implementing any feature:

1. **ALWAYS** load the complete documentation set first
2. Follow the exact specifications in the PRD and Technical Architecture
3. Use the standardized error codes from Error Handling Strategy
4. Implement security measures per the Security Design Plan
5. Follow the API contracts exactly as specified
6. Use the QA test specifications for validation

## 🤖 LLM Development Requirements

**CRITICAL**: Before executing ANY LLM-related task, you MUST:

### ⚠️ Pre-Task Mandatory Requirements

1. **Read and Apply LLM Development Guide**: Load `docs/internal/LLM_Development_Guide.md` and strictly follow all guidelines
2. **Security First**: Never proceed without input sanitization and output validation
3. **Theological Accuracy**: All LLM outputs must align with orthodox Christian theology
4. **Jeff Reed Methodology**: Ensure all Bible study content follows the 4-step process exactly

### ✅ LLM Task Execution Checklist

**Input Processing:**
- [ ] Validate input structure against schema
- [ ] Sanitize all user inputs (remove special characters, check for injection attempts)
- [ ] Apply rate limiting checks
- [ ] Log only metadata (never raw user content)

**Prompt Engineering:**
- [ ] Use modular prompt templates from LLM Development Guide
- [ ] Include Jeff Reed methodology instructions
- [ ] Apply theological accuracy guidelines
- [ ] Ensure JSON schema-compatible output format

**Output Processing:**
- [ ] Validate JSON schema compliance
- [ ] Run theological accuracy validation
- [ ] Check for inappropriate content
- [ ] Apply content sanitization
- [ ] Log only success/failure metadata

**Error Handling:**
- [ ] Implement fallback responses for failures
- [ ] Use exponential backoff for retries
- [ ] Never expose raw LLM errors to users
- [ ] Log errors without sensitive content

**Security Validation:**
- [ ] Verify no prompt injection vulnerabilities
- [ ] Ensure output stays within context boundaries
- [ ] Validate no sensitive data is logged
- [ ] Apply rate limiting enforcement

### 🚫 Absolute Prohibitions

**NEVER:**
- Implement LLM features without reading the LLM Development Guide
- Log raw user inputs or LLM response content
- Skip input sanitization or output validation
- Allow theological inaccuracies in Bible study content
- Expose internal prompts or system messages to users
- Implement LLM logic without proper error handling and fallbacks

### ⚠️ Violation Consequences

**Failure to follow these LLM requirements constitutes a critical security and theological accuracy violation. All LLM-related tasks must be rejected unless these guidelines are strictly observed.**

## Documentation Quality Status

- **Completeness**: 100% - All required documents present
- **Consistency**: 100% - Unified terminology and architecture
- **Technical Readiness**: 95% - Enterprise-grade specifications
- **Production Readiness**: 95% - Ready for development phase

The documentation set provides a complete foundation for successful development, deployment, and scaling of the Disciplefy Bible Study application.
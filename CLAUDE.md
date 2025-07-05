# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🔁 Pre-Execution Behavior - MANDATORY INITIALIZATION

**CRITICAL RULE**: Before executing any task or prompt, you MUST perform the following initialization step:

### ✅ Required Document Loading Sequence

Load ALL documents from the `docs/` folder into memory, including:

1. **Core Specifications:**
   - `Product Requirements Document.md` (PRD)
   - `Technical Architecture Document.md`
   - `Security Design Plan.md`
   - `Data Model.md`
   - `API Contract Documentation.md`

2. **Implementation Plans:**
   - `Sprint Planning Document.md` (v1.0 to latest)
   - `DevOps & Deployment Plan.md`
   - `Error Handling Strategy.md`
   - `LLM Input Validation Specification.md`

3. **Quality Assurance:**
   - `Dev QA Test Specs.md`
   - `Admin Panel Specification.md`
   - `Offline Strategy.md`
   - `Anonymous User Data Lifecycle.md`
   - `Migration Strategy.md`

4. **Version Documentation:**
   - Any tagged document sets like `v1.0-docs-stable`
   - All version-specific files (Version 1.0.md through Version 2.3.md)

### 🎯 Purpose

Ensure all decisions, outputs, suggestions, or code follow the **finalized and most accurate state** of the system as documented in the comprehensive specification set.

### ⚠️ Compliance Requirement

**Failure to perform this initialization step constitutes a violation of operating procedure.** All system interactions must be grounded in the complete documentation context to maintain consistency and avoid conflicts with established specifications.

## Project Overview

This is the Defeah Bible Study app project with **100% production-ready documentation** (v1.0-docs-stable). The repository contains comprehensive specifications that have undergone complete audit resolution and quality assurance validation.

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

## Documentation Quality Status

- **Completeness**: 100% - All required documents present
- **Consistency**: 100% - Unified terminology and architecture
- **Technical Readiness**: 95% - Enterprise-grade specifications
- **Production Readiness**: 95% - Ready for development phase

The documentation set provides a complete foundation for successful development, deployment, and scaling of the Defeah Bible Study application.
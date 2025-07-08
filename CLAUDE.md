# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 📂 Document Preloading Protocol

Before executing any task or writing code, Claude MUST:
1. Load all documents under the `docs/` folder (recursively)
2. Follow the navigation flow described in `docs/Developer Documentation Guide.md`
3. Adhere strictly to all security, rate-limiting, and architectural specifications

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

## 📘 Developer Documentation Reference

Claude should always consult the official guide at:
📄 `docs/Developer Documentation Guide.md`

This guide defines the correct order, grouping, and context management for all files in the documentation set.

---

## 🧭 **Code Quality Rules**

### ⚠️ **MANDATORY COMPLIANCE**

All contributors MUST strictly adhere to the following code quality standards. **Zero tolerance policy** for violations.

### 📋 **Required Pre-Development Actions**

**Before writing ANY code, contributors MUST:**

1. **Load Coding Standards**: Read and understand `docs/standards/Coding_Standards.md` completely
2. **Setup Development Environment**: Configure all required linters, formatters, and pre-commit hooks
3. **Review Architecture**: Understand Clean Architecture patterns for Flutter and modular design for JavaScript/TypeScript
4. **Verify Dependencies**: Ensure all required development tools are installed and configured

### 🔧 **Development Standards Enforcement**

**Every line of code MUST follow:**

- **Clean Code Principles** (Robert Martin): Self-documenting, intention-revealing names
- **DRY Principle**: No code duplication - extract common functionality into reusable components
- **SOLID Principles**: Especially Single Responsibility, Open/Closed, and Dependency Inversion
- **Separation of Concerns**: Clear architectural boundaries between layers
- **Test-Driven Development**: Minimum 80% test coverage for critical paths, 100% for business logic

### 📱 **Flutter/Dart Requirements**

**Mandatory architecture patterns:**
- **Clean Architecture**: Presentation → Domain ← Data layers with proper dependency direction
- **BLoC Pattern**: Event-driven state management with immutable states
- **Dependency Injection**: Use GetIt for proper dependency management and testability
- **Feature-First Structure**: Organize code by features, not by file types
- **Dartdoc Documentation**: 100% public API documentation coverage

### 🌐 **JavaScript/TypeScript Requirements**

**Mandatory patterns:**
- **Single Responsibility Functions**: Maximum 20 lines per function
- **Proper Async/Await**: No callback hell, comprehensive error handling
- **Type Safety**: No `any` types, explicit return types for all functions
- **Security First**: Input validation, sanitization, and prompt injection prevention
- **JSDoc Documentation**: Complete documentation for all public interfaces

### 🧪 **Testing Requirements**

**Non-negotiable test standards:**
- **Unit Tests**: Every business logic function must have comprehensive unit tests
- **Integration Tests**: Critical user flows must be covered end-to-end
- **Security Tests**: All input validation and security measures must be tested
- **Performance Tests**: API endpoints and UI components must meet performance benchmarks
- **Accessibility Tests**: WCAG AA compliance verification for all UI components

### 🔍 **Code Review Process**

**Every PR MUST pass:**

1. **Automated Checks**: All linting, formatting, and test suites must pass
2. **Architecture Review**: Code follows Clean Architecture and separation of concerns
3. **Security Review**: Input validation, authentication, and authorization properly implemented
4. **Performance Review**: No memory leaks, efficient algorithms, proper async patterns
5. **Documentation Review**: Code is self-documenting with proper API documentation

### 🚨 **Quality Gates**

**PRs will be REJECTED for:**
- Failing lint or format checks
- Missing or inadequate test coverage
- Architecture violations (wrong dependency direction, god objects, tight coupling)
- Security vulnerabilities (missing validation, hardcoded secrets, XSS/injection risks)
- Performance issues (memory leaks, inefficient queries, blocking operations)
- Missing documentation for public APIs

### 🔧 **Pre-Commit Requirements**

**MANDATORY automated checks before every commit:**

```bash
# Flutter checks
flutter analyze --fatal-infos
flutter test --coverage
dart format --set-exit-if-changed .

# JavaScript/TypeScript checks
npm run lint
npm run type-check
npm run test
npm run format:check
npm run security-audit
```

### 📊 **Code Quality Metrics**

**Required standards:**
- **Test Coverage**: 80% minimum (critical paths), 100% (business logic)
- **Cyclomatic Complexity**: Maximum 10 per function
- **Function Length**: Maximum 20 lines (excluding documentation)
- **File Length**: Maximum 300 lines
- **Documentation Coverage**: 100% public APIs

### 🏗️ **Refactoring Requirements**

**When modifying existing code, contributors MUST:**
- Improve code quality to current standards if touching legacy code
- Add missing tests for modified functionality
- Update documentation to reflect changes
- Ensure no regression in performance or security
- Follow the Boy Scout Rule: "Leave the code cleaner than you found it"

### ⚡ **Performance Standards**

**All code must meet:**
- **API Response Times**: < 2 seconds for LLM calls, < 500ms for data queries
- **Memory Usage**: No memory leaks, efficient data structures
- **Bundle Size**: Frontend bundles optimized for web performance
- **Database Queries**: Optimized with proper indexing and minimal N+1 queries

### 🔒 **Security Requirements**

**Every contribution must include:**
- Input validation and sanitization for all user data
- Proper authentication and authorization checks
- Prevention of SQL injection, XSS, and prompt injection attacks
- Secure handling of API keys and sensitive data
- Rate limiting and abuse prevention measures

### 📝 **Commit Message Standards**

**Required format:**
```
type(scope): brief description

- Detailed explanation of changes
- Why the change was made
- Any breaking changes or migration notes

Fixes #issue-number
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### 🚫 **Violations and Consequences**

**Immediate PR rejection for:**
- Code that doesn't compile or pass tests
- Security vulnerabilities or missing validation
- Architecture violations or tight coupling
- Missing documentation or inadequate test coverage
- Code that violates DRY or SOLID principles

**Escalation process:**
1. **First violation**: Code review feedback and education
2. **Second violation**: Mandatory coding standards training
3. **Repeated violations**: Temporary development access suspension

### 📚 **Required Reading**

**Before contributing, study:**
- `docs/standards/Coding_Standards.md` - **MANDATORY**
- `docs/architecture/Technical Architecture Document.md`
- `docs/security/Security Design Plan.md`
- `docs/internal/LLM_Development_Guide.md` (for LLM-related work)

### 🎯 **Success Criteria**

**A successful contribution:**
- Passes all automated quality checks
- Follows all architectural patterns and principles
- Includes comprehensive tests and documentation
- Improves overall codebase quality
- Demonstrates understanding of domain requirements

**Remember**: Code quality is not optional. It's a fundamental requirement for maintaining a production-ready, scalable, and secure application.

---

*This code quality section is **mandatory** and **strictly enforced**. All contributors must comply without exception.*
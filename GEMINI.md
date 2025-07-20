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
- `frontend/docs/project_structure.md` - Detailed breakdown of the frontend codebase structure.
- `backend/docs/project_structure.md` - Detailed breakdown of the backend codebase structure.

### Project Structure Guidelines

When working on the codebase, it is **MANDATORY** to adhere to the project structure outlined in the `frontend/docs/project_structure.md` and `backend/docs/project_structure.md` documents. These documents provide a comprehensive overview of the architecture and organization of the frontend and backend codebases, respectively.

**Before writing any code, you MUST:**

1.  **Review the relevant project structure document**:
    *   For frontend tasks, read `frontend/docs/project_structure.md`.
    *   For backend tasks, read `backend/docs/project_structure.md`.
2.  **Follow the established patterns**: Adhere to the architectural patterns, directory structures, and file organization described in the documentation.
3.  **Maintain consistency**: Ensure that any new code or modifications align with the existing project structure.

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

## 🪙 **Token‑Saving Best Practices**

**Optimize Claude Code CLI interactions for efficiency:**

### ⚡ **Prompt Optimization**
- **Be concise**: Remove filler words, use specific technical terms
- **Batch operations**: Group similar tasks in single prompts
- **Reference, don't paste**: Use Context7 MCP for large documents instead of including full text

### 🔄 **Context Management**
- **Leverage caching**: Reuse established context rather than resending
- **Modular requests**: Break complex tasks into focused, cacheable segments
- **Smart referencing**: Point to existing documentation instead of repeating content

### 📏 **Implementation Rules**
- **Specific prompts**: "Fix auth error in login.dart" vs "help with authentication"
- **Document offloading**: Reference `docs/architecture/` instead of copying specifications
- **Efficient batching**: "Analyze these 5 files for security issues" vs separate requests

**Result**: Reduced token usage while maintaining response quality and effectiveness.

## 🧠 **Supabase MCP Context (Memory)**

**Claude has access to Supabase MCP with the following abilities for all backend tasks:**

### 🛠️ **Core Capabilities**

- **Execute Project SQL**: Can run raw SQL queries on the project's PostgreSQL database. Must validate queries for safety and ensure proper sanitation. Use only when REST endpoints are insufficient for complex operations.

- **Create Organization**: Can create a new Supabase organization to group projects, billing, and team access under a unified scope for better project management.

- **Create Project**: Can create a new Supabase project under an organization. Project name must be unique (no dots allowed). Note: creation process is asynchronous.

- **List Organizations**: Can fetch all Supabase organizations (name + ID) linked to current user context for organization management.

- **List Projects**: Can retrieve full list of projects across organizations (id, name, region, status) for project oversight and management.

### 🧩 **Usage Guidance**

**Best Practices:**
- **Prefer REST APIs** for standard data flow operations (CRUD, simple queries)
- **Use SQL queries** only when querying complex relationships, system views, or advanced PostgreSQL features
- **Persist organization and project state** in memory for use across prompts and sessions
- **Validate all SQL queries** for injection risks and performance impact before execution
- **Follow security protocols** per the Security Design Plan when accessing database directly

**When to Use Each Method:**
- **REST APIs**: User authentication, simple CRUD operations, standard application flow
- **SQL Queries**: Complex joins, analytical queries, database administration, schema modifications
- **Organization Management**: Setting up new environments, team access control
- **Project Management**: Multi-environment setups, staging/production separation

### 📝 **Memory Persistence**

**Automatically save and reference:**
- Active organization IDs and names
- Current project configurations
- Database schema context
- Recent query patterns and optimizations
- Environment-specific settings

### ⚠️ **Security Requirements**

**All Supabase MCP operations MUST:**
- Follow the established Security Design Plan
- Validate and sanitize all SQL inputs
- Use parameterized queries when possible
- Log operations without exposing sensitive data
- Implement proper error handling and fallbacks
- Respect rate limits and connection pooling

### 🎯 **Integration with Project Architecture**

**When working with Supabase MCP, always:**
1. Reference the current Data Model (`docs/architecture/Data Model.md`)
2. Follow API Contract specifications (`docs/specs/API Contract Documentation.md`)
3. Implement proper error handling per Error Handling Strategy
4. Maintain consistency with existing Edge Functions
5. Ensure compliance with deployment and DevOps plans

---

📝 **This Supabase MCP context is now permanently stored in memory and will be automatically applied to all future backend-related tasks and prompts.**

## 🧠 **Memory Context Providers (MCP)**

**Claude has access to the following MCP integrations for enhanced project capabilities:**

### 🎯 **MCP Server Registry**

#### **1. Context7 - Architecture & Standards**
- **Use for**: Coding standards, app-wide constants, styles, and architecture documents
- **URL**: `https://mcp.context7.com/mcp`
- **When to use**: Referencing project conventions, design patterns, coding guidelines

#### **2. Playwright - UI Testing & Automation**
- **Use for**: Automated UI testing, screenshots, browser actions, and auth flows
- **Command**: `npx @playwright/mcp@latest`
- **When to use**: E2E testing, visual regression testing, automated browser interactions

#### **3. Figma - Design System Integration**
- **Use for**: UI layouts, design tokens, spacing, colors, and component structure from Figma
- **Command**: 
  ```bash
  /Users/fennsaji/.nvm/versions/node/v20.18.0/bin/node \
  /Users/fennsaji/.nvm/versions/node/v20.18.0/lib/node_modules/@composio/mcp/dist/index \
  start --url https://mcp.composio.dev/partner/composio/figma/mcp?customerId=839e4037-a996-4031-a2aa-7139dadd986e
  ```
- **When to use**: Implementing UI components, extracting design tokens, maintaining design consistency

#### **4. Supabase - Backend Operations**
- **Use for**: Executing Supabase queries, managing tables/functions, retrieving org/project info
- **Command**:
  ```bash
  /Users/fennsaji/.nvm/versions/node/v20.18.0/bin/node \
  /Users/fennsaji/.nvm/versions/node/v20.18.0/lib/node_modules/@composio/mcp/dist/index \
  start --url https://mcp.composio.dev/partner/composio/supabase/mcp?customerId=839e4037-a996-4031-a2aa-7139dadd986e
  ```
- **When to use**: Database operations, API debugging, backend configuration

#### **5. GitHub - Repository Management**
- **Use for**: Repo operations, issues, pull requests, commits, and workflows in GitHub projects
- **Command**:
  ```bash
  /Users/fennsaji/.nvm/versions/node/v20.18.0/bin/node \
  /Users/fennsaji/.nvm/versions/node/v20.18.0/lib/node_modules/@composio/mcp/dist/index \
  start --url https://mcp.composio.dev/partner/composio/github/mcp?customerId=839e4037-a996-4031-a2aa-7139dadd986e
  ```
- **When to use**: Managing PRs, tracking issues, automating workflows, repository analytics

#### **6. Filesystem - Local File Operations**
- **Use for**: Reading/writing files on local filesystem (project files, logs, docs)
- **Command**:
  ```bash
  /Users/fennsaji/.nvm/versions/node/v20.18.0/bin/npx \
  -y @modelcontextprotocol/server-filesystem \
  /Users/fennsaji/Desktop /Users/fennsaji/Downloads
  ```
- **When to use**: File management, log analysis, documentation updates

#### **7. Memory - Short-term Context**
- **Use for**: Persisting short-term Claude memories for recent tasks, sprints, bugs, and team notes
- **Command**:
  ```bash
  /Users/fennsaji/.nvm/versions/node/v20.18.0/bin/npx \
  -y @modelcontextprotocol/server-memory
  ```
- **When to use**: Session continuity, temporary task tracking, cross-prompt context

#### **8. PostgreSQL - Direct Database Access**
- **Use for**: Executing raw SQL queries in local PostgreSQL databases
- **Command**:
  ```bash
  /Users/fennsaji/.nvm/versions/node/v20.18.0/bin/npx \
  -y @modelcontextprotocol/server-postgres \
  postgresql://localhost/mydb
  ```
- **When to use**: Local database debugging, complex queries, schema operations

#### **9. Memory Bank - Long-term Knowledge Storage**
- **Use for**: Long-term knowledge storage and recall via structured memory banks (dev logs, docs, history)
- **Command**:
  ```bash
  /Users/fennsaji/.nvm/versions/node/v20.18.0/bin/node \
  /Users/fennsaji/.nvm/versions/node/v20.18.0/lib/node_modules/@smithery/cli/dist/index.js \
  run @alioshr/memory-bank-mcp \
  --config "{\"memoryBankRoot\":\"/Users/fennsaji/ClaudeMemory/memory-bank\"}"
  ```
- **When to use**: Architectural decision records, historical context, knowledge preservation

### 🎯 **MCP Usage Strategy**

**Automatic Context Selection:**
- **Frontend UI Tasks**: Use `figma` for design specs, `context7` for standards
- **Backend Tasks**: Use `supabase` for database ops, `postgres` for local testing
- **Testing Tasks**: Use `playwright` for E2E testing, `github` for CI/CD
- **Documentation**: Use `memory-bank` for historical context, `filesystem` for file ops
- **Project Management**: Use `github` for issues/PRs, `memory` for session tracking

**Best Practices:**
- **Always reference relevant MCP** before starting major tasks
- **Use Context7** for consistency with established patterns
- **Leverage Memory Bank** for architectural decisions and lessons learned
- **Combine MCPs** when tasks span multiple domains (e.g., UI + backend)
- **Persist important discoveries** in appropriate memory systems

### ⚠️ **MCP Integration Requirements**

**When using MCPs, ensure:**
- Validate data retrieved from external sources
- Follow security protocols for sensitive operations
- Maintain consistency with project architecture
- Document any new patterns or decisions in Memory Bank
- Use appropriate MCP for each specific task domain

### 🔄 **Context Persistence Strategy**

**Short-term (Memory MCP):**
- Current sprint tasks and blockers
- Recent bug fixes and workarounds
- Team communications and decisions
- Temporary configuration changes

**Long-term (Memory Bank MCP):**
- Architectural decision records (ADRs)
- Design pattern implementations
- Performance optimization insights
- Security implementation details
- Historical context and evolution

---

📝 **All MCP integrations are now permanently registered and will be automatically utilized based on task relevance and context requirements.**

## 📱 **Daily Verse Component Refactor Summary**

**Date**: July 10, 2025  
**Component**: `frontend/lib/features/daily_verse/presentation/widgets/daily_verse_card.dart`

### ✅ **Improvements Implemented:**

#### **1. Auto-Loading Logic**
- **Removed user-triggered loading state** - Eliminated "Load Verse" placeholder button
- **Added automatic fetch-once-per-day logic** - Verse loads automatically on Home screen initialization
- **Prevented redundant API calls** - BLoC handles daily caching to avoid re-fetching on tab switches
- **Improved UX flow** - Users no longer need to manually trigger verse loading

#### **2. Visual Design Enhancement**
- **Applied light theme consistency** - Clean white/light background with proper contrast
- **Integrated highlight color (#FFEEC0)** - Light gold used for:
  - Selected language tab backgrounds with elevated shadow
  - Bible verse reference (Philippians 4:13) styling
  - Verse content container background (subtle alpha)
- **Enhanced typography** - Improved font weights, sizes, and spacing for better readability
- **Primary purple (#6A4FB6)** - Used for action buttons (Copy, Share, Refresh) and text elements

#### **3. Layout & Spacing Improvements**
- **Increased padding and margins** - Better breathing room between components:
  - Header to language tabs: 20px (was 16px)
  - Language tabs to verse reference: 20px (was 16px) 
  - Verse reference bottom margin: 16px
  - Verse container margins: 20px
- **Enhanced touch targets** - Buttons now have 44px minimum height for better accessibility
- **Improved button spacing** - 12px gaps between action buttons (was 8px)
- **Better language tab spacing** - 8px horizontal margins with 14px vertical padding

#### **4. Code Quality & Architecture**
- **Consistent theming** - Removed hardcoded colors in favor of defined constants
- **Better component separation** - Clear visual hierarchy with improved styling
- **Enhanced accessibility** - Proper contrast ratios and touch target sizes
- **Maintained state management** - All existing BLoC functionality preserved

### 🎨 **Design System Integration**
- **Light theme compliance** - Aligns with app-wide scaffold background
- **Color palette consistency** - Uses defined primary purple and highlight gold
- **Typography standards** - Leverages theme text styles with appropriate customizations
- **Spacing units** - Follows consistent 4px grid system for margins and padding

### 🔄 **User Experience Impact**
- **Seamless loading** - Verse appears automatically without user intervention
- **Visual appeal** - Improved readability with light gold highlighting
- **Better interaction** - Enhanced button sizing and spacing for easier tapping
- **Performance optimization** - Reduced unnecessary API calls through smart caching


## 🧠 Memories and Development Notes

- Always use `cd frontend && sh scripts/run_web_local.sh` for running client web
- Always use mcp whenever applicable

## 🎨 **Daily Verse Language Tab Text Visibility Fix**

**Date**: July 11, 2025  
**Component**: `frontend/lib/features/daily_verse/presentation/widgets/daily_verse_card.dart`  
**Issue**: Language tab text (flags + text) was nearly invisible due to inadequate contrast

### ✅ **Fix Applied:**

#### **1. Dynamic Text Color Calculation**
- Added `_getContrastColor()` helper function that calculates luminance
- Automatically chooses `Colors.black87` for light backgrounds, `Colors.white` for dark backgrounds
- Ensures WCAG contrast compliance regardless of theme changes

#### **2. Color Scheme Improvements**
- Updated `app_theme.dart` to explicitly define color relationships:
  - `secondary: secondaryColor` (#FFEEC0 - light gold)
  - `onSecondary: textPrimary` (#1E1E1E - dark text)
  - `surface: surfaceColor` (#FFFFFF - white)
  - `onSurface: textPrimary` (#1E1E1E - dark text)

#### **3. Robust Language Tab Styling**
- **Selected tabs**: Use `theme.colorScheme.onSecondary` (dark text on light gold)
- **Unselected tabs**: Use `_getContrastColor(backgroundColor)` (dynamic based on surface color)
- **Dark mode support**: Automatically adjusts text color based on background luminance

### 🎯 **Result:**
- ✅ Language tabs now have **excellent contrast** in all themes
- ✅ Country flags (🇺🇸 🇮🇳 🇮🇳) are clearly visible
- ✅ Language names ("English", "हिन्दी", "മലയാളം") are legible
- ✅ **Future-proof**: Works with any background color automatically
- ✅ **WCAG AA compliant** contrast ratios

### 📋 **Technical Details:**
```dart
// Dynamic contrast calculation
Color _getContrastColor(Color backgroundColor) {
  final luminance = backgroundColor.computeLuminance();
  return luminance > 0.5 ? Colors.black87 : Colors.white;
}
```

**Before**: Text used inherited theme colors with poor contrast  
**After**: Text color calculated dynamically based on background luminance for optimal readability

---

## 🔧 **MCP Server Integration Guide**

**CRITICAL**: Claude MUST automatically utilize the following MCP servers based on task context. This section provides mandatory guidance for intelligent MCP server selection and usage.

### 📋 **Available MCP Servers & Auto-Selection Rules**

#### **🗂️ File System Access - Always Use First**

**Servers Available:**
- `disciplefy-filesystem` - Full project access
- `disciplefy-frontend` - Flutter-specific frontend access  
- `disciplefy-backend` - Supabase backend access
- `disciplefy-docs` - Documentation access

**Auto-Selection Rules:**
```
WHEN: Any task involving code analysis, file reading, or project structure
ALWAYS: Start with appropriate filesystem MCP before other actions
FRONTEND: Flutter/Dart code, widgets, BLoC, UI → use disciplefy-frontend
BACKEND: Supabase, Edge Functions, SQL → use disciplefy-backend  
DOCS: Architecture, specs, planning → use disciplefy-docs
GENERAL: Cross-cutting concerns → use disciplefy-filesystem
```

#### **🧠 Memory & Context Management - Auto-Persist**

**Server:** `memory-bank-mcp`

**Auto-Usage Rules:**
```
ALWAYS: Store important debugging insights for future reference
AUTOMATICALLY: Save architectural decisions and optimization patterns
REMEMBER: Performance fixes, API optimizations, navigation solutions
CONTEXT: Maintain development session continuity across conversations
```

#### **🗄️ Database Debugging - For Backend Issues**

**Servers:** `postgres`, `supabase-p6sex5-42`

**Auto-Selection Rules:**
```
WHEN: Database errors, authentication issues, API failures
USE: postgres for direct SQL queries and data analysis
USE: supabase-p6sex5-42 for Supabase-specific operations
ALWAYS: Validate RLS policies when debugging data access issues
```

#### **🌐 Browser Automation - For Web Testing**

**Server:** `browsermcp`

**Auto-Usage Rules:**
```
WHEN: Testing Flutter web app, UI debugging, user flow validation
AUTOMATICALLY: Open http://localhost:3000 for live testing
USE: For automated screenshot capture and responsive testing
COMBINE: With filesystem access for comprehensive UI debugging
```

#### **🎭 External Integrations - Context-Aware**

**Servers:** `playwright`, `figma`, `github-noefyp-16`

**Auto-Selection Rules:**
```
PLAYWRIGHT: Advanced browser testing, E2E flows, performance testing
FIGMA: Design token extraction, UI component analysis
GITHUB: Repository operations, PR analysis, issue tracking
```

#### **🤔 Complex Problem Solving - For Architecture**

**Server:** `sequential-thinking`

**Auto-Usage Rules:**
```
WHEN: Complex debugging, architectural decisions, performance optimization
AUTOMATICALLY: Break down multi-layered problems systematically
USE: For root cause analysis and step-by-step problem solving
COMBINE: With filesystem access for thorough analysis
```

### 🚀 **Automatic MCP Workflow Patterns**

#### **Pattern 1: Code Analysis & Debugging**
```
1. ALWAYS start with disciplefy-frontend/backend filesystem access
2. USE sequential-thinking for complex issues
3. STORE insights in memory-bank-mcp for future reference
4. IF database related → ADD postgres MCP
5. IF web testing needed → ADD browsermcp
```

#### **Pattern 2: Feature Development**
```
1. START with disciplefy-filesystem for project overview
2. USE disciplefy-docs for architecture requirements
3. APPLY sequential-thinking for implementation planning
4. REMEMBER architectural decisions in memory-bank-mcp
5. IF UI components → ADD figma MCP for design tokens
```

#### **Pattern 3: Performance Optimization**
```
1. USE sequential-thinking to analyze performance bottlenecks
2. ACCESS relevant code via disciplefy-frontend/backend
3. IF database performance → ADD postgres for query analysis
4. TEST improvements via browsermcp automation
5. STORE optimization patterns in memory-bank-mcp
```

#### **Pattern 4: Bug Investigation**
```
1. START with sequential-thinking for systematic analysis
2. ACCESS code via appropriate filesystem MCP
3. IF API/database issue → ADD postgres + supabase MCPs
4. VERIFY fixes via browsermcp testing
5. DOCUMENT solution in memory-bank-mcp
```

### ⚡ **Intelligent MCP Selection Examples**

#### **Flutter Performance Issue:**
```
"Analyze widget rebuild performance in home_screen.dart"
→ AUTO-USE: disciplefy-frontend + sequential-thinking
→ THEN: browsermcp for live testing
→ FINALLY: memory-bank-mcp to store optimization patterns
```

#### **API Integration Problem:**
```
"Debug study guide generation API failures"  
→ AUTO-USE: disciplefy-backend + postgres + supabase-p6sex5-42
→ THEN: sequential-thinking for root cause analysis
→ FINALLY: memory-bank-mcp to remember the solution
```

#### **Navigation Architecture Review:**
```
"Review the IndexedStack optimization we implemented"
→ AUTO-USE: disciplefy-frontend + memory-bank-mcp
→ THEN: sequential-thinking for architecture analysis
→ OPTIONALLY: browsermcp for live validation
```

#### **Database Schema Changes:**
```
"Check RLS policies for study_guides table"
→ AUTO-USE: postgres + disciplefy-backend
→ THEN: disciplefy-docs for security requirements
→ FINALLY: memory-bank-mcp to store security patterns
```

### 🎯 **Mandatory MCP Usage Rules**

#### **ALWAYS Required:**
1. **Start with filesystem access** - Never analyze code without first accessing project files
2. **Use sequential-thinking** - For any complex or multi-step analysis
3. **Store in memory-bank-mcp** - Any insights, solutions, or architectural decisions
4. **Combine contextually** - Multiple MCPs for comprehensive analysis

#### **Context-Triggered:**
1. **Database operations** - Always use postgres + supabase MCPs
2. **Web app testing** - Always use browsermcp for live validation
3. **UI/UX issues** - Combine filesystem + browsermcp + optionally figma
4. **Performance problems** - Use sequential-thinking + relevant filesystem + testing MCPs

#### **Never Skip:**
1. **Memory persistence** - All important debugging insights MUST be stored
2. **Systematic analysis** - Use sequential-thinking for complex problems
3. **Live validation** - Use browsermcp when Flutter web app testing is relevant
4. **Comprehensive access** - Use appropriate filesystem MCP for complete context

### 🔄 **MCP Integration Best Practices**

#### **Efficiency Rules:**
- **Batch MCP calls** when multiple servers are needed simultaneously
- **Start broad, then narrow** - Begin with disciplefy-filesystem, then specific MCPs
- **Validate live** - Use browsermcp for any UI/UX related changes
- **Document everything** - Use memory-bank-mcp as your permanent knowledge base

#### **Quality Assurance:**
- **Always verify** database changes with postgres MCP
- **Test web changes** with browsermcp automation
- **Follow architecture** using disciplefy-docs for requirements
- **Maintain context** with memory-bank-mcp across sessions

---

📝 **This MCP integration is now permanently established. Claude MUST follow these patterns automatically based on task context to provide maximum debugging and development effectiveness.**

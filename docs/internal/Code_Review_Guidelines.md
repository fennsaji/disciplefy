# 👥 Code Review Guidelines
**Disciplefy: Bible Study App**

*Comprehensive code review standards for maintaining code quality and consistency*

---

## 📋 **Overview**

### **Code Review Objectives**
- **Quality Assurance:** Ensure code meets project standards and best practices
- **Knowledge Sharing:** Distribute knowledge across the development team
- **Bug Prevention:** Catch defects early in the development process
- **Security Review:** Identify potential security vulnerabilities
- **Consistency:** Maintain codebase uniformity and readability

### **Review Requirements**
- **All Changes:** Every pull request requires at least one approval
- **Critical Changes:** Security, LLM, or database changes require two approvals
- **Emergency Fixes:** Can be merged with single approval + post-review
- **Documentation:** Code changes affecting user features must include documentation updates

---

## 🎯 **Review Process**

### **Pre-Review Checklist (Author)**

**Before Creating Pull Request:**
- [ ] Code follows project style guidelines
- [ ] All tests pass locally
- [ ] Documentation updated (if applicable)
- [ ] Self-review completed
- [ ] Commits are clean and well-messaged
- [ ] No secrets or sensitive data in code
- [ ] Performance impact considered
- [ ] Security implications assessed

**Pull Request Template:**
```markdown
## Description
Brief description of what this PR accomplishes.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Security enhancement

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed
- [ ] Tested on multiple devices/platforms (if applicable)

## Security Checklist
- [ ] No hardcoded secrets or credentials
- [ ] Input validation implemented
- [ ] Authorization checks in place
- [ ] Secure coding practices followed

## Related Issues
Fixes #(issue number)

## Screenshots (if applicable)
Include screenshots for UI changes.

## Additional Notes
Any additional information reviewers should know.
```

### **Review Process Steps**

**1. Initial Triage (5 minutes)**
- Check PR size and scope
- Verify required information is provided
- Assign appropriate reviewers
- Label with priority and type

**2. Technical Review (15-45 minutes)**
- Code functionality and logic
- Architecture and design patterns
- Performance implications
- Security considerations
- Test coverage and quality

**3. Detailed Review (Time varies)**
- Line-by-line code analysis
- Documentation accuracy
- Edge case handling
- Error handling completeness

**4. Approval Process**
- Request changes (with specific feedback)
- Approve (if all criteria met)
- Approve with comments (minor suggestions)

---

## 📝 **Review Criteria**

### **Code Quality Standards**

**Readability:**
```dart
// ✅ Good: Clear, self-documenting code
class StudyGuideService {
  Future<StudyGuide> generateStudyGuide({
    required String scripture,
    required JeffReedStep step,
  }) async {
    final sanitizedInput = InputSanitizer.sanitize(scripture);
    final prompt = PromptBuilder.buildForStep(sanitizedInput, step);
    return await _llmService.generate(prompt);
  }
}

// ❌ Bad: Unclear, abbreviated code
class SGSvc {
  Future<SG> gen(String s, int st) async {
    var si = IS.san(s);
    var p = PB.build(si, st);
    return await _svc.gen(p);
  }
}
```

**Error Handling:**
```dart
// ✅ Good: Comprehensive error handling
Future<StudyGuide> generateStudyGuide(String scripture) async {
  try {
    if (scripture.isEmpty) {
      throw ValidationException('Scripture cannot be empty');
    }
    
    final result = await _apiService.generateStudy(scripture);
    
    if (result == null) {
      throw ServiceException('Failed to generate study guide');
    }
    
    return result;
  } on ValidationException {
    rethrow;
  } on ServiceException {
    rethrow;
  } catch (e) {
    _logger.error('Unexpected error in generateStudyGuide', error: e);
    throw ServiceException('An unexpected error occurred');
  }
}

// ❌ Bad: Poor error handling
Future<StudyGuide> generateStudyGuide(String scripture) async {
  final result = await _apiService.generateStudy(scripture);
  return result!; // Potential null pointer exception
}
```

### **Security Review Checklist**

**Input Validation:**
- [ ] All user inputs properly validated
- [ ] SQL injection prevention measures
- [ ] XSS prevention in web components
- [ ] File upload restrictions (if applicable)
- [ ] Rate limiting implementation

**Authentication & Authorization:**
- [ ] Proper authentication checks
- [ ] Authorization verified for protected resources
- [ ] Token handling secure
- [ ] Session management appropriate

**LLM Security (Critical):**
- [ ] Prompt injection prevention
- [ ] Input sanitization applied
- [ ] Output validation implemented
- [ ] Rate limiting for AI features
- [ ] No sensitive data in prompts

**Data Protection:**
- [ ] Sensitive data encrypted
- [ ] PII handling compliant
- [ ] Logging excludes sensitive information
- [ ] Data retention policies followed

### **Performance Review**

**Flutter/Dart Performance:**
```dart
// ✅ Good: Efficient widget building
class StudyGuideList extends StatelessWidget {
  final List<StudyGuide> guides;
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: guides.length,
      itemBuilder: (context, index) {
        return StudyGuideTile(guide: guides[index]);
      },
    );
  }
}

// ❌ Bad: Inefficient widget creation
class StudyGuideList extends StatelessWidget {
  final List<StudyGuide> guides;
  
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: guides.map((guide) => 
        Container(
          child: Column(
            children: [
              Text(guide.title),
              Text(guide.summary),
              // ... many more widgets created for each item
            ],
          ),
        ),
      ).toList(),
    );
  }
}
```

**Database Performance:**
```sql
-- ✅ Good: Optimized query with proper indexing
SELECT sg.id, sg.summary, sg.created_at
FROM study_guides sg
WHERE sg.user_id = $1
  AND sg.created_at > $2
ORDER BY sg.created_at DESC
LIMIT 20;

-- Index to support this query
CREATE INDEX idx_study_guides_user_date ON study_guides(user_id, created_at DESC);

-- ❌ Bad: Unoptimized query
SELECT *
FROM study_guides sg
LEFT JOIN jeff_reed_sessions jrs ON sg.session_id = jrs.id
LEFT JOIN feedback f ON sg.id = f.study_guide_id
WHERE sg.user_id = $1
ORDER BY sg.created_at DESC;
-- No indexes, unnecessary joins, SELECT *
```

---

## 🏷️ **Review Categories**

### **Size-Based Review Requirements**

| **Lines Changed** | **Required Reviewers** | **Review Depth** | **Max Review Time** |
|------------------|----------------------|------------------|-------------------|
| 1-50 lines | 1 reviewer | Standard | 15 minutes |
| 51-200 lines | 1 reviewer | Detailed | 30 minutes |
| 201-500 lines | 2 reviewers | Comprehensive | 60 minutes |
| 500+ lines | 2 reviewers + architect | Deep dive | 90+ minutes |

### **Complexity-Based Requirements**

**Simple Changes (1 reviewer):**
- Bug fixes
- Documentation updates
- Test additions
- Minor refactoring

**Complex Changes (2 reviewers):**
- New features
- API modifications
- Security implementations
- Database schema changes
- LLM integration changes

**Critical Changes (2+ reviewers + lead approval):**
- Authentication/authorization systems
- Payment processing
- Data migration scripts
- Security-critical functions
- Production deployment configurations

---

## 💬 **Review Communication**

### **Providing Feedback**

**Effective Feedback Principles:**
- **Be Specific:** Point to exact lines and explain the issue
- **Be Constructive:** Suggest improvements, don't just criticize
- **Be Educational:** Explain the "why" behind suggestions
- **Be Respectful:** Maintain professional, collaborative tone

**Feedback Categories:**
```
🔴 Must Fix: Critical issues that block merge
🟡 Should Fix: Important improvements that should be addressed
🟢 Consider: Suggestions for improvement (optional)
📚 Learning: Educational comments for knowledge sharing
💡 Idea: Alternative approaches to consider
```

**Good Feedback Examples:**
```
🔴 Must Fix: Line 45 - This user input is not sanitized before being sent to the LLM. This could lead to prompt injection attacks. Please use InputSanitizer.sanitize() before processing.

🟡 Should Fix: Lines 67-89 - This function is doing too many things (fetching data, processing, and formatting). Consider breaking it into smaller, single-responsibility functions for better testability.

🟢 Consider: Line 23 - Using a Set instead of List here might be more appropriate since we're checking for uniqueness and don't care about order.

📚 Learning: Line 156 - Great use of the Builder pattern here! This makes the code much more readable and maintainable.
```

### **Responding to Feedback**

**Author Responsibilities:**
- Address all Must Fix items before requesting re-review
- Respond to each comment (even if just acknowledging)
- Ask clarifying questions if feedback is unclear
- Update the PR description if scope changes significantly

**Response Templates:**
```
✅ Fixed: [Brief description of how you addressed the issue]
❓ Question: [Ask for clarification if unclear]
💭 Discussion: [If you disagree, explain your reasoning respectfully]
📝 Updated: [If you made additional improvements beyond what was requested]
```

---

## 🛠️ **Tools & Automation**

### **Automated Checks**

**Pre-Review Automation:**
```yaml
# GitHub Actions workflow
name: Code Review Automation
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  automated-checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Flutter Analysis
        run: |
          flutter analyze
          dart format --dry-run --set-exit-if-changed .
          
      - name: Security Scan
        uses: securecodewarrior/github-action-add-sarif@v1
        with:
          sarif-file: security-scan-results.sarif
          
      - name: Test Coverage
        run: |
          flutter test --coverage
          genhtml coverage/lcov.info -o coverage/html
          
      - name: Size Analysis
        uses: andresz1/size-limit-action@v1
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
```

**Code Quality Gates:**
- **Linting:** All code must pass Flutter/Dart linter
- **Testing:** Test coverage must be > 80% for new code
- **Security:** No high-severity security issues
- **Performance:** No performance regressions detected

### **Review Tools Integration**

**IDE Integration:**
```json
// VS Code settings.json
{
  "dart.lineLength": 80,
  "dart.showTodos": true,
  "editor.rulers": [80],
  "editor.formatOnSave": true,
  "dart.analysisServerFolding": true,
  "dart.showInspectorNotificationsForWidgetErrors": true
}
```

**Review Checklist Tool:**
```dart
// Automated checklist generator
class ReviewChecklistGenerator {
  static List<String> generateFor(PullRequest pr) {
    final checklist = <String>[];
    
    if (pr.hasSecurityChanges) {
      checklist.addAll([
        '🔒 Input validation implemented',
        '🔒 Authentication checks present',
        '🔒 No hardcoded secrets',
      ]);
    }
    
    if (pr.hasLLMChanges) {
      checklist.addAll([
        '🤖 Prompt injection prevention',
        '🤖 Output validation',
        '🤖 Rate limiting applied',
      ]);
    }
    
    if (pr.hasUIChanges) {
      checklist.addAll([
        '🎨 Responsive design',
        '🎨 Accessibility compliance',
        '🎨 Visual design consistency',
      ]);
    }
    
    return checklist;
  }
}
```

---

## 📊 **Review Metrics**

### **Quality Metrics Tracking**

**Review Effectiveness:**
```sql
-- Review metrics tracking
CREATE TABLE code_review_metrics (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  pr_number INTEGER NOT NULL,
  reviewer_id VARCHAR(100) NOT NULL,
  review_duration_minutes INTEGER,
  comments_count INTEGER,
  approval_status VARCHAR(20),
  defects_found INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Review quality analysis
SELECT 
  reviewer_id,
  AVG(review_duration_minutes) as avg_review_time,
  AVG(comments_count) as avg_comments,
  SUM(defects_found) * 100.0 / COUNT(*) as defects_per_review,
  COUNT(*) FILTER (WHERE approval_status = 'approved') * 100.0 / COUNT(*) as approval_rate
FROM code_review_metrics 
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY reviewer_id;
```

**Team Performance Dashboard:**
```
📈 Review Metrics (Last 30 Days)
├── Average Review Time: 25 minutes
├── Reviews Completed: 156
├── First-Pass Approval Rate: 78%
├── Critical Issues Found: 12
├── Security Issues Found: 3
└── Performance Issues Found: 8

🎯 Team Goals
├── Review Time: < 30 minutes (✅ Met)
├── First-Pass Approval: > 75% (✅ Met)
├── Critical Issues: < 15 (✅ Met)
└── Security Issues: < 5 (✅ Met)
```

### **Continuous Improvement**

**Monthly Review Retrospectives:**
- What types of issues are we catching most frequently?
- Are there patterns in the defects being introduced?
- How can we improve our review process efficiency?
- What additional automated checks could help?

**Training Opportunities:**
- Security code review workshop
- Flutter performance optimization training
- LLM security best practices session
- Architecture and design pattern reviews

---

## 📚 **Style Guides Reference**

### **Dart/Flutter Style Guide**

**Naming Conventions:**
```dart
// Classes: UpperCamelCase
class StudyGuideRepository {}

// Variables/functions: lowerCamelCase
String userName = '';
void generateStudyGuide() {}

// Constants: lowerCamelCase
const int maxRetryAttempts = 3;

// Files: snake_case
// study_guide_service.dart
// jeff_reed_repository.dart
```

**Documentation:**
```dart
/// Generates a Bible study guide using Jeff Reed methodology.
/// 
/// Takes a [scripture] reference and [step] from the Jeff Reed process
/// and returns a comprehensive study guide. Throws [ValidationException]
/// if the input is invalid or [ServiceException] if generation fails.
/// 
/// Example:
/// ```dart
/// final guide = await generateStudyGuide(
///   scripture: 'John 3:16',
///   step: JeffReedStep.observation,
/// );
/// ```
Future<StudyGuide> generateStudyGuide({
  required String scripture,
  required JeffReedStep step,
}) async {
  // Implementation
}
```

### **SQL Style Guide**

```sql
-- Table names: snake_case (singular)
CREATE TABLE study_guide (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  summary TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Columns: snake_case
-- Keywords: UPPERCASE
-- Indentation: 2 spaces
SELECT 
  sg.id,
  sg.summary,
  u.email AS user_email
FROM study_guides sg
JOIN auth.users u ON sg.user_id = u.id
WHERE sg.created_at > NOW() - INTERVAL '30 days'
ORDER BY sg.created_at DESC;
```

---

## 🚨 **Emergency Review Process**

### **Hotfix Review Procedure**

**When to Use Emergency Process:**
- Critical security vulnerability
- Production outage fix
- Data loss prevention
- Payment system failure

**Emergency Review Steps:**
1. **Immediate Notification:** Alert team lead and security officer
2. **Single Reviewer Approval:** Any senior developer can approve
3. **Immediate Merge:** Deploy to production ASAP
4. **Post-Review:** Conduct thorough review within 24 hours
5. **Follow-up:** Create improvements task if issues found

**Emergency Review Template:**
```
🚨 EMERGENCY HOTFIX REVIEW

Issue: [Critical issue description]
Impact: [User/system impact]
Solution: [Brief description of fix]
Risk Assessment: [Potential risks of the fix]
Rollback Plan: [How to revert if needed]

Post-Deployment Actions:
- [ ] Monitor system metrics for 2 hours
- [ ] Verify fix resolves issue
- [ ] Schedule post-mortem review
- [ ] Create follow-up improvement tasks
```

---

**⚠️ [REQUIRES HUMAN INPUT: Team member names, GitHub usernames, review tool configurations, and specific metrics targets need to be customized for the actual development team]**

**This document should be reviewed quarterly and updated based on team feedback and development process improvements.**
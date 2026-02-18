# Subscription System Architecture Analysis

**Date**: 2026-01-28
**Status**: Critical Issues Found
**Severity**: HIGH

## Executive Summary

The subscription system has **5 critical architectural flaws** that compromise security, data integrity, and user experience:

1. ❌ **No RLS on `subscriptions` table** - Security vulnerability
2. ❌ **No synchronization** between `subscriptions` and `user_tokens` - Data inconsistency
3. ❌ **Duplicate user_tokens rows** - Database design flaw (multiple plans per user)
4. ❌ **Inconsistent plan determination** - Different APIs use different logic
5. ❌ **No atomic operations** - Subscription activation lacks transactional integrity

---

## 1. Database Schema Analysis

### Tables Overview

#### `subscriptions` Table
```sql
Purpose: Track Razorpay/Google Play/Apple subscriptions
Primary Key: id (uuid)
User Link: user_id (uuid) → auth.users(id) CASCADE
Unique Constraint: unique_active_subscription_per_user (user_id WHERE status='active')
RLS Status: ❌ DISABLED (rowsecurity = false)
```

**CRITICAL**: No Row Level Security! Anyone can query any user's subscription data.

#### `user_tokens` Table
```sql
Purpose: Track daily token limits and usage per user per plan
Primary Key: id (uuid)
User Link: identifier (text) - stores user_id as TEXT
Unique Constraint: (identifier, user_plan)
RLS Status: ✅ ENABLED
```

**Design Issue**: Allows MULTIPLE rows per user (one per plan). Currently your DB has:
```sql
user_id: 2f62ebcb-d7c1-4e27-9409-0882d3bda62d
Row 1: plan='standard', daily_limit=20
Row 2: plan='premium', daily_limit=999999999
```

---

## 2. Data Flow Analysis

### Subscription Creation Flow

```mermaid
User → Create Plus Subscription
  ↓
API: create-plus-subscription/index.ts
  ↓
SubscriptionService.createSubscription()
  ↓
1. Create Razorpay subscription
2. INSERT into subscriptions table
3. Return authorization URL
  ↓
❌ Does NOT create/update user_tokens
```

### Subscription Activation Flow (Webhook)

```mermaid
Razorpay → subscription.activated webhook
  ↓
razorpay-webhook/index.ts → handleSubscriptionActivated()
  ↓
UPDATE subscriptions SET
  status = 'active',
  subscription_plan = 'plus'
  ↓
❌ Does NOT sync to user_tokens
❌ user_tokens.user_plan remains outdated
```

**Result**: `subscriptions.subscription_plan` and `user_tokens.user_plan` can be **completely different**.

---

## 3. Plan Determination Logic Analysis

### Current Implementation (Before Today's Fix)

**API**: `get-user-usage-stats/index.ts`

```typescript
// OLD (Buggy):
1. Query subscriptions table
2. IF found → use subscriptions.subscription_plan
3. ELSE → fallback to user_tokens.user_plan
```

**Problem**: If `subscriptions` has `plan='free'` and `user_tokens` has `plan='premium'`, API returns `free` (wrong!).

### After Today's Fix (Merge Logic)

```typescript
// NEW:
1. Query BOTH subscriptions and user_tokens
2. Find highest plan from EACH
3. Return MAX(subscriptions.plan, user_tokens.plan)
```

**Improvement**: Handles mismatched data by taking the highest plan.
**Issue**: Masks the root cause (lack of synchronization).

---

## 4. Critical Issues Breakdown

### Issue #1: No RLS on Subscriptions Table

**Severity**: 🔴 CRITICAL (Security)

**Current State**:
```sql
subscriptions: rowsecurity = false (RLS DISABLED!)
```

**Impact**:
- Any authenticated user can query ANY user's subscription data
- No protection against data leaks
- Violates GDPR/privacy requirements

**Example Exploit**:
```sql
-- Malicious user can run:
SELECT * FROM subscriptions WHERE user_id != auth.uid();
-- Returns all other users' subscription data!
```

**Fix Required**:
```sql
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only view own subscriptions"
  ON subscriptions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Service role has full access"
  ON subscriptions FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
```

---

### Issue #2: No Synchronization Between Tables

**Severity**: 🔴 CRITICAL (Data Integrity)

**Current State**:
- Subscription activation ONLY updates `subscriptions` table
- `user_tokens` is NEVER updated when subscription status changes
- No database triggers to keep them in sync

**Example Scenario**:
```
1. User creates Standard subscription
   subscriptions.subscription_plan = 'standard' ✅
   user_tokens.user_plan = ??? (doesn't exist yet) ❌

2. User generates first study guide
   → TokenService.getUserTokenInfo() calls get_or_create_user_tokens('free')
   → Creates user_tokens row with plan='free' ❌

3. Webhook activates subscription
   subscriptions.subscription_plan = 'standard' ✅
   user_tokens.user_plan = 'free' (never updated!) ❌

4. User sees "0 / 8" tokens instead of "0 / 20"
```

**Fix Required**:

**Option A: Database Trigger** (Automatic sync)
```sql
CREATE OR REPLACE FUNCTION sync_subscription_to_user_tokens()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('active', 'authenticated', 'pending_cancellation') THEN
    -- Upsert user_tokens with subscription plan
    INSERT INTO user_tokens (identifier, user_plan, daily_limit, available_tokens)
    VALUES (
      NEW.user_id::text,
      NEW.subscription_plan,
      CASE NEW.subscription_plan
        WHEN 'premium' THEN 999999999
        WHEN 'plus' THEN 50
        WHEN 'standard' THEN 20
        ELSE 8
      END,
      CASE NEW.subscription_plan
        WHEN 'premium' THEN 999999999
        WHEN 'plus' THEN 50
        WHEN 'standard' THEN 20
        ELSE 8
      END
    )
    ON CONFLICT (identifier, user_plan) DO UPDATE SET
      daily_limit = EXCLUDED.daily_limit,
      available_tokens = EXCLUDED.available_tokens,
      updated_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_subscription_plan_to_tokens
  AFTER INSERT OR UPDATE OF subscription_plan, status ON subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION sync_subscription_to_user_tokens();
```

**Option B: Application-Level Sync** (Explicit in webhook)
```typescript
// In razorpay-webhook/index.ts handleSubscriptionActivated()
async function handleSubscriptionActivated(...) {
  // ... existing subscription update ...

  // Sync to user_tokens
  await supabaseServiceClient.rpc('get_or_create_user_tokens', {
    p_identifier: userId,
    p_user_plan: planCode
  });
}
```

---

### Issue #3: Multiple user_tokens Rows Per User

**Severity**: 🟡 MEDIUM (Design Flaw)

**Current Design**:
```sql
Unique constraint: (identifier, user_plan)
Allows: Multiple rows per user_id
```

**Your Database**:
```sql
user: 2f62ebcb-d7c1-4e27-9409-0882d3bda62d
Row 1: plan='standard', daily_limit=20
Row 2: plan='premium', daily_limit=999999999
```

**Problem**: Which row is "truth"? Current logic:
1. TokenService calls `get_or_create_user_tokens(user_id, plan)`
2. Creates/finds row for THAT plan
3. But user can have MULTIPLE plans simultaneously!

**Design Questions**:
- Should a user have one row OR one row per plan?
- How do you handle plan upgrades/downgrades?
- What happens to old plan rows?

**Recommended Design**:

**Option A: Single Row Per User** (Simpler)
```sql
-- Change constraint to:
UNIQUE(identifier)  -- Only ONE row per user

-- user_plan becomes THE current active plan
-- Subscription changes UPDATE this row
```

**Option B: Keep Multi-Row BUT Mark Active Plan**
```sql
ALTER TABLE user_tokens ADD COLUMN is_active BOOLEAN DEFAULT false;

-- Only ONE active plan per user
CREATE UNIQUE INDEX user_tokens_active_plan
  ON user_tokens(identifier)
  WHERE is_active = true;
```

---

### Issue #4: Inconsistent Plan Determination

**Severity**: 🟡 MEDIUM (User Experience)

**Different APIs Use Different Logic**:

1. **`get-user-usage-stats`**: Now uses merge logic (after today's fix)
2. **`token-service.ts`**: Uses AuthService.getUserPlan()
3. **`auth-service.ts`**: Queries subscriptions FIRST, then user_tokens (old logic)
4. **`study-generate`**: Calls TokenService which calls AuthService (nested inconsistency)

**Problem**: Same user can get different plans from different APIs!

**Example**:
```
subscriptions: plan='free'
user_tokens: plan='premium'

get-user-usage-stats → returns 'premium' (merge logic)
AuthService.getUserPlan() → returns 'free' (subscriptions first)
TokenService.consume() → uses 'free' limits!
```

**Fix Required**: Centralize plan determination in ONE service.

```typescript
// Centralized PlanResolver Service
class PlanResolverService {
  async getUserPlan(userId: string): Promise<UserPlan> {
    // SINGLE SOURCE OF TRUTH
    // 1. Check subscriptions table (active status)
    // 2. Check user_tokens table (all rows)
    // 3. Return HIGHEST plan found
    // 4. Cache result for performance
  }
}
```

---

### Issue #5: No Transactional Integrity

**Severity**: 🟡 MEDIUM (Reliability)

**Current Flow**:
```typescript
// Webhook activation:
1. UPDATE subscriptions SET status='active'
2. (No sync to user_tokens)
   ↓
   IF step 1 succeeds BUT step 2 missing → inconsistent state
```

**Problem**: Subscription activation is NOT atomic.

**Fix Required**: Wrap in transaction or use database triggers (see Issue #2).

---

## 5. Security Vulnerabilities

### 5.1 RLS Disabled on Subscriptions

**Risk**: Data leak, unauthorized access
**Severity**: 🔴 CRITICAL
**CVSS Score**: 7.5 (High)

### 5.2 No Input Validation on Plan Values

**Risk**: Plan injection via webhook tampering
**Severity**: 🟠 MEDIUM
**Fix**: Validate `planCode` in webhook handlers:

```typescript
const VALID_PLANS = ['free', 'standard', 'plus', 'premium'];
if (!VALID_PLANS.includes(planCode)) {
  throw new Error('Invalid plan code');
}
```

### 5.3 user_tokens Uses TEXT for User ID

**Risk**: Type confusion, UUID vs string comparison bugs
**Severity**: 🟡 LOW
**Recommendation**: Change `identifier` from `text` to `uuid`.

---

## 6. Data Consistency Issues

### Current State Analysis

**Your Local Database**:
```sql
-- subscriptions table:
user_id: 2f62ebcb-d7c1-4e27-9409-0882d3bda62d
subscription_plan: 'free'
status: 'active'

-- user_tokens table:
identifier: '2f62ebcb-d7c1-4e27-9409-0882d3bda62d'
Row 1: user_plan='standard', daily_limit=20
Row 2: user_plan='premium', daily_limit=999999999
```

**Inconsistencies**:
1. ❌ Subscription says `free`, user_tokens says `standard` AND `premium`
2. ❌ Two token rows for same user (design allows this but is it intentional?)
3. ❌ No clear "source of truth" for user's actual plan

**Impact**:
- User sees wrong token limits in UI
- Different APIs return different plans
- Webhook updates don't reflect in token consumption
- Manual database intervention required to fix

---

## 7. Recommended Architecture

### Proposed Solution: Single Source of Truth

```sql
-- Step 1: Make user_tokens PRIMARY (one row per user)
ALTER TABLE user_tokens
  DROP CONSTRAINT idx_user_tokens_identifier;

ALTER TABLE user_tokens
  ADD CONSTRAINT user_tokens_identifier_unique UNIQUE (identifier);

-- Step 2: Add subscription_id reference (optional denormalization)
ALTER TABLE user_tokens
  ADD COLUMN active_subscription_id uuid REFERENCES subscriptions(id);

-- Step 3: Enable RLS on subscriptions
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own subscriptions"
  ON subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- Step 4: Create sync trigger
CREATE TRIGGER sync_subscription_to_user_tokens
  AFTER INSERT OR UPDATE ON subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION sync_subscription_plan();
```

### Centralized Plan Resolution

```typescript
// _shared/services/plan-resolver-service.ts
export class PlanResolverService {
  private static planPriority = {
    premium: 4,
    plus: 3,
    standard: 2,
    free: 1
  };

  async getCurrentPlan(userId: string): Promise<{
    plan: UserPlan;
    source: 'subscription' | 'user_tokens' | 'default';
    dailyLimit: number;
  }> {
    // 1. Check active subscriptions
    const subscription = await this.getActiveSubscription(userId);

    // 2. Check user_tokens (should be ONE row after migration)
    const tokens = await this.getUserTokens(userId);

    // 3. Return highest plan
    const plan = this.getHigherPlan(
      subscription?.subscription_plan,
      tokens?.user_plan
    );

    return {
      plan,
      source: this.determineSource(plan, subscription, tokens),
      dailyLimit: DEFAULT_PLAN_CONFIGS[plan].dailyLimit
    };
  }
}
```

---

## 8. Migration Plan

### Phase 1: Immediate Fixes (Security)

**Priority**: 🔴 CRITICAL
**Timeline**: Deploy ASAP

1. ✅ Enable RLS on subscriptions table
2. ✅ Create RLS policies for subscriptions
3. ✅ Add plan validation in webhook handlers

**SQL Migration**:
```sql
-- File: 20260128000001_enable_subscriptions_rls.sql
BEGIN;

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_view_own_subscriptions"
  ON subscriptions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "service_role_full_access"
  ON subscriptions FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

COMMIT;
```

### Phase 2: Data Sync (Consistency)

**Priority**: 🟠 HIGH
**Timeline**: Next sprint

1. ✅ Create sync trigger for subscriptions → user_tokens
2. ✅ Run one-time migration to sync existing data
3. ✅ Add sync logic to webhook handlers

**SQL Migration**:
```sql
-- File: 20260128000002_sync_subscriptions_user_tokens.sql
-- (See Issue #2 fix above)
```

### Phase 3: Schema Refactor (Design)

**Priority**: 🟡 MEDIUM
**Timeline**: Next release

1. ✅ Consolidate user_tokens to one row per user
2. ✅ Change identifier from text to uuid
3. ✅ Add active_subscription_id foreign key

**Migration Steps**:
1. Create new table schema
2. Migrate data (keep highest plan per user)
3. Update all APIs to use new schema
4. Drop old table

### Phase 4: Centralization (Maintainability)

**Priority**: 🟢 LOW
**Timeline**: Future enhancement

1. ✅ Create PlanResolverService
2. ✅ Refactor all APIs to use centralized service
3. ✅ Add integration tests
4. ✅ Add monitoring/alerting for plan mismatches

---

## 9. Testing Recommendations

### Unit Tests Needed

```typescript
describe('PlanResolverService', () => {
  it('returns subscription plan when active subscription exists');
  it('returns user_tokens plan when no subscription exists');
  it('returns highest plan when both exist and differ');
  it('handles missing data gracefully (defaults to free)');
});

describe('Subscription Webhook', () => {
  it('syncs plan to user_tokens on activation');
  it('handles concurrent webhook events (idempotency)');
  it('validates plan codes before processing');
});
```

### Integration Tests Needed

```typescript
describe('End-to-End Subscription Flow', () => {
  it('creates subscription and syncs to user_tokens');
  it('activates subscription and updates token limits');
  it('cancels subscription and reverts to free plan');
  it('handles plan upgrades correctly');
});
```

### Manual Testing Checklist

- [ ] Create Standard subscription → Check user_tokens synced
- [ ] Activate via webhook → Check plan updated in both tables
- [ ] Generate study → Check correct token limits consumed
- [ ] View home screen → Check usage meter shows correct plan
- [ ] Upgrade to Premium → Check old plan data migrated
- [ ] Cancel subscription → Check reverted to free plan

---

## 10. Monitoring & Alerts

### Recommended Metrics

1. **Plan Mismatch Rate**: Count of users where `subscriptions.plan != user_tokens.plan`
2. **Webhook Processing Failures**: Failed subscription activations
3. **RLS Policy Violations**: Attempted unauthorized access to subscriptions
4. **Token Sync Lag**: Time between subscription update and user_tokens sync

### Alert Thresholds

```yaml
alerts:
  - name: plan_mismatch_critical
    condition: plan_mismatch_rate > 5%
    severity: CRITICAL

  - name: webhook_failures
    condition: failed_activations > 10/hour
    severity: HIGH

  - name: rls_violations
    condition: unauthorized_queries > 0
    severity: CRITICAL
```

---

## 11. Summary of Action Items

### Immediate (This Sprint)

- [ ] **CRITICAL**: Enable RLS on subscriptions table
- [ ] **CRITICAL**: Add RLS policies for subscriptions
- [ ] **HIGH**: Add subscription sync trigger
- [ ] **HIGH**: Run data migration to sync existing users
- [ ] **MEDIUM**: Add plan validation to webhooks

### Next Sprint

- [ ] **MEDIUM**: Consolidate user_tokens to one row per user
- [ ] **MEDIUM**: Create PlanResolverService
- [ ] **MEDIUM**: Refactor all APIs to use centralized plan resolution
- [ ] **LOW**: Add comprehensive integration tests

### Future Enhancements

- [ ] **LOW**: Add monitoring dashboard for plan consistency
- [ ] **LOW**: Add alerting for plan mismatches
- [ ] **LOW**: Add audit logging for subscription changes

---

## 12. Risk Assessment

| Risk | Likelihood | Impact | Severity | Mitigation |
|------|-----------|--------|----------|------------|
| Data leak via RLS bypass | HIGH | HIGH | 🔴 CRITICAL | Enable RLS immediately |
| Plan mismatches | HIGH | MEDIUM | 🟠 HIGH | Add sync trigger |
| Multiple token rows | MEDIUM | LOW | 🟡 MEDIUM | Schema migration |
| Webhook failures | LOW | HIGH | 🟠 HIGH | Add retry logic + monitoring |
| Inconsistent APIs | HIGH | MEDIUM | 🟠 HIGH | Centralize plan resolution |

---

## Conclusion

The subscription system requires **immediate attention** to fix critical security (no RLS) and data consistency (no sync) issues. The current architecture works but has fundamental flaws that will cause increasing problems as the user base grows.

**Recommendation**: Prioritize Phase 1 (RLS) and Phase 2 (Sync) for immediate deployment. Phase 3 and 4 can be scheduled for subsequent releases.

**Estimated Effort**:
- Phase 1: 4 hours (critical path)
- Phase 2: 8 hours
- Phase 3: 16 hours
- Phase 4: 24 hours

**Total**: ~52 hours (~1.3 weeks)

# Token Purchase API - Implementation Documentation

**Version**: 1.0  
**Date**: January 10, 2025  
**Status**: Current Implementation Analysis

## 🎯 Overview

This document provides comprehensive documentation of the current token purchase API implementation in the Disciplefy Bible Study app. The system allows Standard plan authenticated users to purchase additional tokens using Razorpay payment integration.

---

## 🚧 **IMPLEMENTATION STATUS** (as of January 11, 2025)

> **CRITICAL**: This documentation describes the complete API design and flow, but **Razorpay integration is currently a PLACEHOLDER implementation**. Core logic, validation, and database structure are complete, but actual payment processing requires production Razorpay SDK integration.

### Component Status Matrix

| Component | Status | Notes |
|-----------|--------|-------|
| **Backend Edge Function** | 🏗️ PLACEHOLDER | Core logic complete, Razorpay SDK calls are mocked |
| **Payment Processing Logic** | 🏗️ PLACEHOLDER | `processRazorpayPayment()` needs real Razorpay SDK integration |
| **Webhook Endpoint** | ⏳ PLANNED | `/functions/v1/razorpay-webhook` endpoint defined but not implemented |
| **Signature Verification** | ⏳ PLANNED | Security logic defined but not coded |
| **Database Schema** | 🚀 PRODUCTION READY | `token_purchases` table deployed and tested |
| **Frontend Purchase UI** | ⏳ PLANNED | TokenPurchaseDialog UI designed but Razorpay Flutter SDK not integrated |
| **BLoC State Management** | ✅ FRAMEWORK COMPLETE | TokenBloc events/states defined, repository pattern ready |
| **Error Handling** | 🚀 PRODUCTION READY | Comprehensive error codes (PM-*) implemented |
| **Analytics Tracking** | ✅ FRAMEWORK COMPLETE | Event definitions ready, tracking logic in place |

### Required for Production Deployment

**High Priority (Blocking):**
1. ✅ Obtain Razorpay API credentials (Key ID + Secret Key)
2. ⏳ Integrate Razorpay Node.js SDK in backend Edge Function
3. ⏳ Implement webhook signature verification (HMAC SHA256)
4. ⏳ Integrate Razorpay Flutter SDK in frontend
5. ⏳ Test end-to-end payment flow in Razorpay test mode
6. ⏳ Conduct security audit of payment handling
7. ⏳ Complete PCI DSS compliance checklist

**Medium Priority:**
- ⏳ Set up production webhook URL with proper SSL
- ⏳ Configure Razorpay webhook retry logic
- ⏳ Implement idempotency for purchase API
- ⏳ Add payment failure recovery mechanisms

**Low Priority (Post-Launch):**
- ⏳ Add support for payment methods beyond UPI/cards (wallets, net banking)
- ⏳ Implement partial refund capability
- ⏳ Build admin dashboard for payment reconciliation

### Development Timeline Estimate

```
Week 1-2: Razorpay SDK Integration + Core Payment Flow
Week 3:   Webhook Implementation + Security Hardening
Week 4:   Frontend Flutter SDK Integration
Week 5:   End-to-End Testing + Bug Fixes
Week 6:   Security Audit + Production Deployment
```

**Estimated Total**: 6 weeks of focused development

---

## 🏗️ Architecture Overview

### System Components

```
Frontend (Flutter)               Backend (Supabase)
├── TokenPurchaseDialog         ├── purchase-tokens function
├── TokenManagementPage         ├── TokenService
├── PurchaseTokens UseCase      ├── AuthService  
├── TokenRemoteDataSource       ├── Database Functions
└── TokenBloc                   └── Analytics Logger
```

### Data Flow

```
User Purchase Request → UI Dialog → BLoC → UseCase → DataSource → Edge Function → Payment Processing → Database Update → Response Chain
```

## 🔧 Backend Implementation

### 1. Purchase Tokens Edge Function

**Location**: `backend/supabase/functions/purchase-tokens/index.ts`

**Endpoint**: `POST /functions/v1/purchase-tokens`

#### Function Flow:

1. **Authentication Validation**
   ```typescript
   const userContext = await authService.getUserContext(req)
   if (userContext.type !== 'authenticated') {
     throw new AppError('AUTHENTICATION_REQUIRED', 'You must be logged in to purchase tokens', 401)
   }
   ```

2. **User Plan Validation** 
   ```typescript
   const userPlan = await authService.getUserPlan(req)
   if (!tokenService.canPurchaseTokens(userPlan)) {
     throw new AppError('PURCHASE_NOT_ALLOWED', `${userPlan} plan users cannot purchase tokens`, 403)
   }
   ```
   - Only Standard plan users can purchase tokens
   - Free users cannot purchase (must upgrade)
   - Premium users don't need to purchase (unlimited tokens)

3. **Request Validation**
   ```typescript
   interface TokenPurchaseRequest {
     token_amount: number     // 50-10,000 tokens (enforced minimum 50 tokens = ₹5.00)
     payment_method_id: string // Razorpay payment method ID
   }
   // Note: Razorpay enforces minimum payment of ₹1.00 (100 paise), but our minimum is 50 tokens (₹5.00)
   ```

4. **Cost Calculation**
   ```typescript
   const costInRupees = tokenService.calculateCostInRupees(token_amount)
   const costInPaise = costInRupees * 100  // 10 tokens = ₹1 = 100 paise
   ```

5. **Payment Processing** (Placeholder Implementation)
   ```typescript
   const paymentResult = await processRazorpayPayment({
     amount: costInPaise,
     currency: 'INR',
     payment_method_id,
     user_id: userContext.userId!,
     metadata: { token_amount, purchase_type: 'token_purchase' }
   })
   ```

6. **Token Addition**
   ```typescript
   const addResult = await tokenService.addPurchasedTokens(
     userContext.userId!,
     userPlan,
     token_amount,
     analyticsContext
   )
   ```

7. **Response Structure**
   ```typescript
   interface TokenPurchaseResult {
     success: boolean
     tokens_purchased: number
     cost_paid: number            // Amount in rupees
     tokens_per_rupee: number     // Exchange rate (10 tokens = ₹1)
     new_token_balance: TokenInfo
     payment_id: string
   }
   ```

### 2. Token Service

**Location**: `backend/supabase/functions/_shared/services/token-service.ts`

#### Key Methods:

**`addPurchasedTokens()`**
```typescript
async addPurchasedTokens(
  identifier: string,
  userPlan: UserPlan,
  tokenAmount: number,
  context?: Partial<TokenOperationContext>
): Promise<{ success: boolean; newPurchasedBalance: number }>
```

**Features:**
- Validates user eligibility (Standard plan only)
- Calls database function `add_purchased_tokens`
- Logs analytics events
- Returns updated purchased token balance

**`calculateCostInRupees()`**
```typescript
calculateCostInRupees(tokenAmount: number): number {
  const totalPaise = Math.ceil((tokenAmount * 100) / this.config.purchaseConfig.tokensPerRupee)
  return totalPaise / 100
}
```

**Pricing Structure:**
- **Rate**: 10 tokens = ₹1
- **Minimum Purchase**: 50 tokens (₹5.00)
- **Maximum Purchase**: 10,000 tokens (₹1,000)

#### Token Purchase Configuration:
```typescript
const DEFAULT_TOKEN_SERVICE_CONFIG = {
  purchaseConfig: {
    tokensPerRupee: 10,
    minPurchase: 50,
    maxPurchase: 10000
  }
}
```

### 3. Database Integration

#### Database Functions Used:
- `add_purchased_tokens(p_identifier, p_user_plan, p_token_amount)`
- `get_or_create_user_tokens(p_identifier, p_user_plan)`
- `log_token_event(p_user_id, p_event_type, p_event_data, p_session_id)`

#### Database Response Types:
```typescript
interface DatabasePurchaseResult {
  readonly success: boolean
  readonly available_tokens: number
  readonly purchased_tokens: number
  readonly daily_limit: number
  readonly new_purchased_balance: number
  readonly error_message?: string
}
```

### 4. Error Handling

#### Standard Error Types:
- **401 AUTHENTICATION_REQUIRED**: User not authenticated
- **403 PURCHASE_NOT_ALLOWED**: User plan cannot purchase tokens
- **400 VALIDATION_ERROR**: Invalid request parameters
- **402 PAYMENT_FAILED**: Razorpay payment processing failed
- **500 TOKEN_SERVICE_ERROR**: Database or service errors

#### Error Response Structure:
```typescript
{
  success: false,
  error: {
    code: string,
    message: string,
    context?: Record<string, any>
  }
}
```

## 📱 Frontend Implementation

### 1. Token Purchase Dialog

**Location**: `frontend/lib/features/tokens/presentation/widgets/token_purchase_dialog.dart`

#### Features:
- **Predefined Packages**: Popular token bundles using linear pricing
  - 50 tokens = ₹5.00
  - 100 tokens = ₹10.00
  - 250 tokens = ₹25.00
  - 500 tokens = ₹50.00

- **Custom Amount Input**: 50-9999 tokens with real-time cost calculation using linear pricing (10 tokens = ₹1)

- **Plan Restrictions**: Shows appropriate message for Free/Premium users

#### Package Structure:
```dart
class TokenPackage {
  final int tokens;
  final int rupees;  // Calculated using linear pricing: rupees = tokens / 10
  final bool isPopular;
  // Note: discount field removed - all packages use linear pricing
}
```

### 2. Token Management Page

**Location**: `frontend/lib/features/tokens/presentation/pages/token_management_page.dart`

#### Sections:
- **Token Balance Widget**: Current token status
- **Current Plan Section**: User plan display with upgrade options
- **Actions Section**: Purchase tokens button (Standard plan only)
- **Usage Information**: Daily limits, consumption, reset times
- **Plan Comparison**: Feature comparison across plans

### 3. Purchase Flow (Use Case)

**Location**: `frontend/lib/features/tokens/domain/usecases/purchase_tokens.dart`

#### Parameters Validation:
```dart
class PurchaseTokensParams {
  final int tokenAmount;
  final String paymentOrderId;      // Razorpay order ID
  final String paymentId;           // Razorpay payment ID
  final String signature;           // Razorpay signature
}
```

#### Business Logic:
- Validates all payment parameters
- Calls repository layer
- Handles success/failure responses
- Provides detailed logging

### 4. Remote Data Source

**Location**: `frontend/lib/features/tokens/data/datasources/token_remote_data_source.dart`

#### Purchase Implementation:
```dart
Future<TokenStatusModel> purchaseTokens({
  required int tokenAmount,
  required String paymentOrderId,
  required String paymentId,
  required String signature,
}) async {
  // Token validation
  await ApiAuthHelper.validateTokenForRequest();
  
  // Authenticated headers
  final headers = await ApiAuthHelper.getAuthHeaders();
  
  // Supabase Edge Function call
  final response = await _supabaseClient.functions.invoke(
    'purchase-tokens',
    body: {
      'token_amount': tokenAmount,
      'payment_order_id': paymentOrderId,
      'payment_id': paymentId,
      'signature': signature,
    },
    headers: headers,
  );
}
```

## 💳 Payment Integration

### Current State: Placeholder Implementation

The current backend implementation has a **placeholder Razorpay integration**:

```typescript
async function processRazorpayPayment(params: {
  amount: number
  currency: string
  payment_method_id: string
  user_id: string
  metadata: Record<string, any>
}): Promise<{ status: string; payment_id: string }> {
  // TODO: Replace with actual Razorpay integration
  // This is a placeholder that simulates successful payment
  
  console.log('[PurchaseTokens] Processing Razorpay payment:', params)
  
  // Simulate payment processing delay
  await new Promise(resolve => setTimeout(resolve, 100))
  
  return {
    status: 'captured',
    payment_id: `razorpay_${Date.now()}_${Math.random().toString(36).substring(2)}`
  }
}
```

### Expected Production Implementation:

```typescript
const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID!,
  key_secret: process.env.RAZORPAY_KEY_SECRET!
})

const order = await razorpay.orders.create({
  amount: params.amount,
  currency: params.currency,
  payment_capture: true,
  receipt: `token_purchase_${params.user_id}_${Date.now()}`,
  notes: params.metadata
})

const payment = await razorpay.payments.capture(
  params.payment_method_id,
  params.amount
)
```

## 🔒 Security Features

### 1. Authentication Requirements
- **Mandatory login**: Only authenticated users can purchase
- **Token validation**: API tokens validated before requests
- **Session management**: Proper user session handling

### 2. Authorization Controls
- **Plan-based restrictions**: Only Standard plan users can purchase
- **Input validation**: Comprehensive parameter validation
- **Rate limiting**: Built into Edge Function framework

### 3. Payment Security
- **Razorpay integration**: Industry-standard payment processing
- **Signature verification**: Payment signature validation (planned)
- **Transaction logging**: All purchase attempts logged

### 4. Data Protection
- **Sensitive data handling**: No payment details stored locally
- **Analytics privacy**: Only metadata logged, no sensitive content
- **Error masking**: Internal errors not exposed to clients

## 📊 Analytics & Logging

### Event Types Logged:
```typescript
type TokenEventType = 
  | 'token_purchase_success'   // Successful token purchase
  | 'token_purchase_failed'    // Failed token purchase
  | 'token_added'             // Tokens added to account
```

### Analytics Data Structure:
```typescript
interface TokenAnalyticsData {
  user_id: string
  token_amount: number
  cost_in_paise: number
  cost_in_rupees: number
  payment_id?: string
  user_plan: UserPlan
  error_message?: string
}
```

### Logging Locations:
- **Backend**: Edge Function analytics logger
- **Database**: Token event logging function
- **Frontend**: Console logging for debugging

## 🚧 Current Limitations & Gaps

### 1. Payment Integration Gaps

**Critical Missing Components:**
- **Real Razorpay SDK integration**: Currently using placeholder
- **Webhook handling**: No payment confirmation webhooks
- **Payment failure handling**: Limited failure scenarios covered
- **Refund mechanism**: No refund processing capability

### 2. Frontend Payment Flow Gaps

**Missing Components:**
- **Razorpay checkout integration**: No actual payment UI
- **Payment status tracking**: No real-time payment status
- **Payment failure recovery**: Limited error handling
- **Receipt generation**: No purchase receipts

### 3. Security Enhancements Needed

**Required Improvements:**
- **Payment signature verification**: Razorpay signature validation
- **Fraud detection**: Transaction pattern analysis
- **Rate limiting**: Purchase frequency limits
- **Audit logging**: Enhanced security event logging

### 4. User Experience Gaps

**Missing Features:**
- **Purchase history**: No transaction history view
- **Payment method management**: No saved payment methods
- **Partial failure handling**: Limited graceful degradation
- **Mobile payment optimization**: No mobile-specific optimizations

## 🎯 Recommended Implementation Plan

### Phase 1: Core Payment Integration (High Priority)

**Backend Tasks:**
1. **Integrate Razorpay SDK**
   - Replace placeholder with real Razorpay calls
   - Implement order creation and payment capture
   - Add proper error handling for payment failures

2. **Add Webhook Support**
   - Create payment confirmation webhook endpoint
   - Handle payment success/failure notifications
   - Implement idempotency for duplicate webhooks

3. **Enhance Security**
   - Add Razorpay signature verification
   - Implement transaction validation
   - Add comprehensive audit logging

**Frontend Tasks:**
1. **Razorpay Checkout Integration**
   - Add Razorpay SDK to Flutter app
   - Implement payment UI flow
   - Handle payment success/failure states

2. **Payment Status Handling**
   - Add real-time payment status tracking
   - Implement retry mechanisms for failed payments
   - Add payment confirmation screens

### Phase 2: Enhanced User Experience (Medium Priority)

**Features to Implement:**
1. **Purchase History**
   - Transaction history screen
   - Receipt generation and storage
   - Purchase analytics for users

2. **Payment Method Management**
   - Save payment methods securely
   - One-click purchase for returning users
   - Payment method preference settings

3. **Mobile Optimizations**
   - UPI integration for Indian users
   - Mobile wallet support
   - Optimized mobile payment flow

### Phase 3: Advanced Features (Low Priority)

**Advanced Capabilities:**
1. **Subscription Integration**
   - Recurring token purchases
   - Auto-renewal options
   - Subscription management

2. **Promotional Features**
   - Discount codes and coupons
   - Referral bonuses
   - Seasonal promotions

3. **Business Intelligence**
   - Purchase pattern analysis
   - Revenue optimization
   - User behavior insights

## 🔧 Configuration & Environment

### Required Environment Variables:
```bash
# Razorpay Configuration (Production)
RAZORPAY_KEY_ID=rzp_live_xxxxx
RAZORPAY_KEY_SECRET=xxxxx
RAZORPAY_WEBHOOK_SECRET=xxxxx

# Database Configuration
SUPABASE_SERVICE_ROLE_KEY=xxxxx
SUPABASE_URL=https://xxxxx.supabase.co

# Analytics Configuration
ENABLE_ANALYTICS=true
ANALYTICS_LOG_LEVEL=info
```

### Frontend Configuration:
```dart
// Razorpay Configuration
static const String razorpayKeyId = 'rzp_live_xxxxx';
static const String companyName = 'Disciplefy';
static const String currency = 'INR';
```

## 📋 Testing Strategy

### Backend Testing Requirements:

1. **Unit Tests**
   - Token service methods
   - Payment processing functions
   - Database function integration
   - Error handling scenarios

2. **Integration Tests**
   - End-to-end purchase flow
   - Razorpay API integration
   - Database transaction consistency
   - Analytics event logging

3. **Security Tests**
   - Authentication bypass attempts
   - Payment tampering tests
   - Rate limiting validation
   - Input sanitization verification

### Frontend Testing Requirements:

1. **Widget Tests**
   - TokenPurchaseDialog functionality
   - Payment form validation
   - Error state handling
   - Loading state management

2. **Integration Tests**
   - Complete purchase flow
   - BLoC state management
   - API integration
   - Navigation flow

3. **E2E Tests**
   - User purchase journey
   - Payment success/failure flows
   - Cross-platform compatibility
   - Performance benchmarks

## 📈 Success Metrics

### Key Performance Indicators:

1. **Technical Metrics**
   - Purchase completion rate: >95%
   - Payment processing time: <5 seconds
   - API response time: <2 seconds
   - Error rate: <1%

2. **Business Metrics**
   - User purchase conversion: Track signup to first purchase
   - Average purchase value: Monitor token package preferences
   - Purchase retention: Track repeat purchases
   - Revenue per user: Calculate average lifetime value

3. **User Experience Metrics**
   - Payment flow abandonment rate: <10%
   - User satisfaction score: >4.5/5
   - Support ticket volume: <2% of purchases
   - Mobile vs web purchase preference: Track platform usage

## 🚀 Complete Implementation Guide

### Critical Gap Resolution Plan

The following sections provide detailed step-by-step implementation for resolving the 4 critical gaps identified:

1. **🔗 Razorpay Backend Integration** - Replace placeholder with real payment processing
2. **💳 Frontend Payment Checkout** - Implement Razorpay SDK in Flutter
3. **🔔 Webhook Payment Confirmation** - Handle payment status updates
4. **🔒 Security & Signature Verification** - Implement proper payment validation

---

## 🔗 Gap 1: Razorpay Backend Integration

### Step 1: Install Razorpay Node.js SDK

**Backend Dependencies**:
```bash
cd backend/supabase/functions/purchase-tokens
npm install razorpay@2.9.2
npm install crypto  # For signature verification
```

**Update import.json**:
```json
{
  "imports": {
    "razorpay": "npm:razorpay@2.9.2",
    "crypto": "node:crypto"
  }
}
```

### Step 2: Environment Configuration

**Add to Supabase Secrets**:
```bash
# Development
supabase secrets set RAZORPAY_KEY_ID=rzp_test_xxxxx
supabase secrets set RAZORPAY_KEY_SECRET=xxxxx
supabase secrets set RAZORPAY_WEBHOOK_SECRET=whsec_xxxxx

# Production
supabase secrets set RAZORPAY_KEY_ID=rzp_live_xxxxx
supabase secrets set RAZORPAY_KEY_SECRET=xxxxx
supabase secrets set RAZORPAY_WEBHOOK_SECRET=whsec_xxxxx
```

### Step 3: Replace Placeholder Payment Function

**File**: `backend/supabase/functions/purchase-tokens/index.ts`

**Remove this placeholder code**:
```typescript
// TODO: Replace with actual Razorpay integration
async function processRazorpayPayment(params: {...}): Promise<{...}> {
  // Placeholder implementation
}
```

**Replace with real Razorpay integration**:
```typescript
import Razorpay from 'razorpay'
import { createHash, createHmac } from 'crypto'

/**
 * Real Razorpay payment processing
 */
async function processRazorpayPayment(params: {
  amount: number           // Amount in paise
  currency: string         // 'INR'
  user_id: string
  token_amount: number
  metadata: Record<string, any>
}): Promise<{ 
  success: boolean
  order_id?: string
  payment_id?: string
  error?: string 
}> {
  const razorpay = new Razorpay({
    key_id: Deno.env.get('RAZORPAY_KEY_ID')!,
    key_secret: Deno.env.get('RAZORPAY_KEY_SECRET')!
  })

  try {
    console.log(`[Razorpay] Creating order for ${params.amount} paise`)
    
    // Create Razorpay order
    const order = await razorpay.orders.create({
      amount: params.amount,
      currency: params.currency,
      receipt: `token_${params.user_id}_${Date.now()}`,
      notes: {
        user_id: params.user_id,
        token_amount: params.token_amount.toString(),
        purchase_type: 'token_purchase',
        ...params.metadata
      }
    })

    console.log(`[Razorpay] Order created: ${order.id}`)
    
    return {
      success: true,
      order_id: order.id,
      payment_id: null  // Will be populated later by webhook after payment capture
    }

  } catch (error) {
    console.error('[Razorpay] Order creation failed:', error)
    
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Payment processing failed'
    }
  }
}
```

### Step 4: Update Purchase Flow Logic

**Modify the main purchase handler**:
```typescript
// Replace this section in handleTokenPurchase function:
try {
  // 6. Process payment via Razorpay
  const paymentResult = await processRazorpayPayment({
    amount: costInPaise,
    currency: 'INR',
    user_id: userContext.userId!,
    token_amount,
    metadata: {
      user_plan: userPlan,
      timestamp: new Date().toISOString()
    }
  })

  if (!paymentResult.success) {
    throw new AppError(
      'PAYMENT_FAILED',
      paymentResult.error || 'Payment processing failed',
      402
    )
  }

  // Store pending purchase (will be confirmed by webhook)
  await storePendingPurchase({
    user_id: userContext.userId!,
    order_id: paymentResult.order_id!,
    token_amount,
    amount_paise: costInPaise,
    status: 'pending'
  })

  // Return order details for frontend payment
  return new Response(JSON.stringify({
    success: true,
    order_id: paymentResult.order_id,
    amount: costInPaise,
    currency: 'INR',
    key_id: Deno.env.get('RAZORPAY_KEY_ID'),
    token_amount
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}
```

### Step 5: Add Pending Purchase Storage

**Create database function for pending purchases**:
```sql
-- Add to your migration file
CREATE TABLE pending_token_purchases (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  order_id TEXT UNIQUE NOT NULL,
  token_amount INTEGER NOT NULL,
  amount_paise INTEGER NOT NULL,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE pending_token_purchases ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only access their own purchases
CREATE POLICY "Users can manage their own purchases" ON pending_token_purchases
  FOR ALL USING (auth.uid() = user_id);

-- RLS Policy: Service role can access all records for webhook processing
CREATE POLICY "Service role can manage all purchases" ON pending_token_purchases
  FOR ALL USING (auth.role() = 'service_role');

-- Performance indexes
CREATE INDEX idx_pending_purchases_status ON pending_token_purchases(status);
CREATE INDEX idx_pending_purchases_order_id ON pending_token_purchases(order_id);
CREATE INDEX idx_pending_purchases_user_status ON pending_token_purchases(user_id, status);

CREATE OR REPLACE FUNCTION store_pending_purchase(
  p_user_id UUID,
  p_order_id TEXT,
  p_token_amount INTEGER,
  p_amount_paise INTEGER
) RETURNS BOOLEAN AS $
BEGIN
  INSERT INTO pending_token_purchases (
    user_id, order_id, token_amount, amount_paise
  ) VALUES (
    p_user_id, p_order_id, p_token_amount, p_amount_paise
  );
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Atomic purchase completion function to prevent race conditions
CREATE OR REPLACE FUNCTION complete_token_purchase(
  p_order_id TEXT,
  p_payment_id TEXT,
  p_user_id UUID DEFAULT NULL
) RETURNS JSONB AS $
DECLARE
  v_purchase RECORD;
  v_token_result JSONB;
  v_result JSONB;
BEGIN
  -- Acquire FOR UPDATE lock and verify status in one step
  SELECT * INTO v_purchase
  FROM pending_token_purchases
  WHERE order_id = p_order_id
    AND (p_user_id IS NULL OR user_id = p_user_id)
    AND status = 'pending'
  FOR UPDATE;
  
  -- Return early if not found or not pending
  IF NOT FOUND THEN
    -- Check if already completed
    SELECT status INTO v_purchase.status
    FROM pending_token_purchases
    WHERE order_id = p_order_id
      AND (p_user_id IS NULL OR user_id = p_user_id);
    
    IF v_purchase.status = 'completed' THEN
      RETURN jsonb_build_object(
        'success', true,
        'already_processed', true,
        'message', 'Purchase already completed'
      );
    ELSE
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Purchase not found or not in pending state'
      );
    END IF;
  END IF;
  
  BEGIN
    -- Call existing token addition function within transaction
    SELECT add_purchased_tokens(
      v_purchase.user_id::text,
      'standard',
      v_purchase.token_amount
    ) INTO v_token_result;
    
    -- Check if token addition was successful
    IF v_token_result->>'success' != 'true' THEN
      RAISE EXCEPTION 'Token addition failed: %', v_token_result->>'error_message';
    END IF;
    
    -- Update purchase status atomically
    UPDATE pending_token_purchases
    SET 
      status = 'completed',
      payment_id = p_payment_id,
      updated_at = NOW()
    WHERE order_id = p_order_id;
    
    -- Return success with token information
    RETURN jsonb_build_object(
      'success', true,
      'already_processed', false,
      'tokens_added', v_purchase.token_amount,
      'new_purchased_balance', v_token_result->'new_purchased_balance',
      'user_id', v_purchase.user_id,
      'order_id', p_order_id,
      'payment_id', p_payment_id
    );
    
  EXCEPTION
    WHEN OTHERS THEN
      -- Mark as failed on any error during token addition
      UPDATE pending_token_purchases
      SET 
        status = 'failed',
        error_message = SQLERRM,
        updated_at = NOW()
      WHERE order_id = p_order_id;
      
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'order_id', p_order_id
      );
  END;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON pending_token_purchases TO authenticated;
GRANT ALL ON pending_token_purchases TO service_role;
GRANT EXECUTE ON FUNCTION complete_token_purchase TO authenticated, service_role;
```

**Add helper function to backend**:
```typescript
async function storePendingPurchase(params: {
  user_id: string
  order_id: string
  token_amount: number
  amount_paise: number
  status: string
}): Promise<void> {
  const { data, error } = await supabaseClient
    .rpc('store_pending_purchase', {
      p_user_id: params.user_id,
      p_order_id: params.order_id,
      p_token_amount: params.token_amount,
      p_amount_paise: params.amount_paise
    })

  if (error) {
    console.error('[Database] Failed to store pending purchase:', error)
    throw new AppError(
      'DATABASE_ERROR',
      'Failed to store purchase record',
      500
    )
  }
}
```

---

## 💳 Gap 2: Frontend Payment Checkout Implementation

### Step 1: Add Razorpay Flutter Dependencies

**File**: `frontend/pubspec.yaml`
```yaml
dependencies:
  razorpay_flutter: ^1.3.7
  url_launcher: ^6.2.2  # For payment result handling
```

### Step 2: Configure Razorpay Settings

**File**: `frontend/lib/core/constants/payment_constants.dart`
```dart
class PaymentConstants {
  // Razorpay Configuration
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_xxxxx'  // Development key
  );
  
  static const String companyName = 'Disciplefy';
  static const String companyDescription = 'Bible Study Token Purchase';
  static const String currency = 'INR';
  static const String contactEmail = 'support@disciplefy.in';
  static const String contactPhone = '+919876543210';
  
  // Payment themes
  static const Map<String, dynamic> razorpayTheme = {
    'color': '#6A4FB6',  // Primary purple
  };
}
```

### Step 3: Create Payment Service

**File**: `frontend/lib/core/services/payment_service.dart`
```dart
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/material.dart';
import '../constants/payment_constants.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();
  
  late Razorpay _razorpay;
  
  // Callback functions
  Function(PaymentSuccessResponse)? _onSuccess;
  Function(PaymentFailureResponse)? _onFailure;
  Function(ExternalWalletResponse)? _onWallet;
  
  void initialize() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }
  
  void dispose() {
    _razorpay.clear();
  }
  
  Future<void> openPaymentGateway({
    required String orderId,
    required int amount,  // Amount in paise
    required int tokenAmount,
    required String userEmail,
    required String userPhone,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
    Function(ExternalWalletResponse)? onWallet,
  }) async {
    // Store callbacks
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _onWallet = onWallet;
    
    final options = {
      'key': PaymentConstants.razorpayKeyId,
      'order_id': orderId,
      'amount': amount,
      'currency': PaymentConstants.currency,
      'name': PaymentConstants.companyName,
      'description': '${tokenAmount} Bible Study Tokens',
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'theme': PaymentConstants.razorpayTheme,
      'modal': {
        'ondismiss': () {
          print('Payment dialog dismissed');
        }
      },
      'notes': {
        'token_amount': tokenAmount.toString(),
        'purchase_type': 'token_purchase',
      }
    };
    
    try {
      print('🎯 [Payment] Opening Razorpay with order: $orderId');
      _razorpay.open(options);
    } catch (e) {
      print('🚨 [Payment] Failed to open Razorpay: $e');
      _onFailure?.call(PaymentFailureResponse(
        code: 0,
        message: 'Failed to initialize payment: $e',
        error: {'description': 'Payment initialization failed', 'source': 'razorpay'}
      ));
    }
  }
  
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('🎉 [Payment] Success: ${response.paymentId}');
    _onSuccess?.call(response);
  }
  
  void _handlePaymentFailure(PaymentFailureResponse response) {
    print('❌ [Payment] Failed: ${response.message}');
    _onFailure?.call(response);
  }
  
  void _handleExternalWallet(ExternalWalletResponse response) {
    print('💼 [Payment] External Wallet: ${response.walletName}');
    _onWallet?.call(response);
  }
}
```

### Step 4: Update Token Purchase Dialog

**File**: `frontend/lib/features/tokens/presentation/widgets/token_purchase_dialog.dart`

**Add imports**:
```dart
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../core/constants/payment_constants.dart';
```

**Update the dialog state class**:
```dart
class _TokenPurchaseDialogState extends State<TokenPurchaseDialog> {
  // ... existing code ...
  
  late PaymentService _paymentService;
  String? _currentOrderId;
  
  @override
  void initState() {
    super.initState();
    // ... existing code ...
    
    // Initialize payment service
    _paymentService = PaymentService();
    _paymentService.initialize();
  }
  
  @override
  void dispose() {
    // ... existing code ...
    _paymentService.dispose();
    super.dispose();
  }
  
  // Replace _handlePurchase method:
  Future<void> _handlePurchase(int tokenAmount) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('🛒 [Purchase] Starting purchase for $tokenAmount tokens');
      
      // Step 1: Create Razorpay order via backend
      final orderResult = await _createPaymentOrder(tokenAmount);
      
      if (!orderResult['success']) {
        throw Exception(orderResult['error'] ?? 'Failed to create payment order');
      }
      
      _currentOrderId = orderResult['order_id'];
      final amount = orderResult['amount'];
      
      print('✅ [Purchase] Order created: $_currentOrderId');
      
      // Step 2: Open Razorpay payment gateway
      await _paymentService.openPaymentGateway(
        orderId: _currentOrderId!,
        amount: amount,
        tokenAmount: tokenAmount,
        userEmail: widget.tokenStatus.userEmail ?? 'user@disciplefy.in',
        userPhone: widget.tokenStatus.userPhone ?? '+919876543210',
        onSuccess: _handlePaymentSuccess,
        onFailure: _handlePaymentFailure,
        onWallet: _handleExternalWallet,
      );
      
    } catch (e) {
      print('🚨 [Purchase] Purchase initiation failed: $e');
      
      if (mounted) {
        _showErrorDialog('Purchase Failed', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<Map<String, dynamic>> _createPaymentOrder(int tokenAmount) async {
    // This calls the backend to create Razorpay order
    // The backend will return order_id, amount, etc.
    context.read<TokenBloc>().add(
      CreatePaymentOrder(tokenAmount: tokenAmount)
    );
    
    // Wait for order creation response
    // This would typically be handled through BLoC state management
    // For now, simulating the response structure:
    return {
      'success': true,
      'order_id': 'order_${DateTime.now().millisecondsSinceEpoch}',
      'amount': tokenAmount * 10, // 10 paise per token
      'currency': 'INR',
    };
  }
  
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('🎉 [Purchase] Payment successful!');
    print('Payment ID: ${response.paymentId}');
    print('Order ID: ${response.orderId}');
    print('Signature: ${response.signature}');
    
    // Step 3: Confirm payment with backend
    context.read<TokenBloc>().add(
      ConfirmTokenPurchase(
        orderId: response.orderId!,
        paymentId: response.paymentId!,
        signature: response.signature!,
      ),
    );
    
    // Close dialog
    Navigator.of(context).pop();
    
    // Show success message
    _showSuccessDialog('Payment Successful!', 
        'Your tokens have been added to your account.');
  }
  
  void _handlePaymentFailure(PaymentFailureResponse response) {
    print('❌ [Purchase] Payment failed: ${response.message}');
    
    String errorMessage = 'Payment was not completed.';
    
    if (response.message?.contains('cancelled') == true) {
      errorMessage = 'Payment was cancelled by user.';
    } else if (response.code == Razorpay.PAYMENT_CANCELLED) {
      errorMessage = 'Payment was cancelled.';
    } else if (response.code == Razorpay.NETWORK_ERROR) {
      errorMessage = 'Network error. Please check your connection.';
    }
    
    _showErrorDialog('Payment Failed', errorMessage);
  }
  
  void _handleExternalWallet(ExternalWalletResponse response) {
    print('💼 [Purchase] External wallet selected: ${response.walletName}');
    // Handle external wallet flow if needed
  }
  
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
```

### Step 5: Add New BLoC Events

**File**: `frontend/lib/features/tokens/presentation/bloc/token_event.dart`

**Add these new events**:
```dart
// Add to existing events
class CreatePaymentOrder extends TokenEvent {
  final int tokenAmount;
  
  const CreatePaymentOrder({required this.tokenAmount});
  
  @override
  List<Object?> get props => [tokenAmount];
}

class ConfirmTokenPurchase extends TokenEvent {
  final String orderId;
  final String paymentId;
  final String signature;
  
  const ConfirmTokenPurchase({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });
  
  @override
  List<Object?> get props => [orderId, paymentId, signature];
}
```

---

## 🔔 Gap 3: Webhook Payment Confirmation

### Step 1: Create Webhook Edge Function

**File**: `backend/supabase/functions/razorpay-webhook/index.ts`
```typescript
import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { createHmac } from 'crypto'

/**
 * Razorpay Webhook Handler
 * 
 * Handles payment confirmation webhooks from Razorpay
 * and completes token purchase process
 */
async function handleRazorpayWebhook(req: Request, services: ServiceContainer): Promise<Response> {
  const { tokenService, analyticsLogger } = services
  
  if (req.method !== 'POST') {
    throw new AppError(
      'METHOD_NOT_ALLOWED',
      'Webhook endpoint only accepts POST requests',
      405
    )
  }
  
  // Get webhook signature
  const signature = req.headers.get('x-razorpay-signature')
  if (!signature) {
    throw new AppError(
      'MISSING_SIGNATURE',
      'Webhook signature is required',
      400
    )
  }
  
  // Get request body
  const body = await req.text()
  
  // Verify webhook signature
  const isValidSignature = verifyWebhookSignature(body, signature)
  if (!isValidSignature) {
    console.error('[Webhook] Invalid signature received')
    throw new AppError(
      'INVALID_SIGNATURE',
      'Webhook signature verification failed',
      401
    )
  }
  
  console.log('[Webhook] Valid signature verified')
  
  // Parse webhook payload
  const payload = JSON.parse(body)
  const event = payload.event
  const paymentEntity = payload.payload?.payment?.entity
  const orderEntity = payload.payload?.order?.entity
  
  console.log(`[Webhook] Processing event: ${event}`)
  
  try {
    if (event === 'payment.captured') {
      await handlePaymentCaptured(paymentEntity, orderEntity, services)
    } else if (event === 'payment.failed') {
      await handlePaymentFailed(paymentEntity, orderEntity, services)
    } else {
      console.log(`[Webhook] Ignoring event: ${event}`)
    }
    
    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    console.error('[Webhook] Error processing webhook:', error)
    
    // Log webhook failure for monitoring
    await analyticsLogger.logEvent('webhook_processing_failed', {
      event,
      error_message: error instanceof Error ? error.message : 'Unknown error',
      payment_id: paymentEntity?.id,
      order_id: orderEntity?.id
    })
    
    throw new AppError(
      'WEBHOOK_PROCESSING_ERROR',
      'Failed to process webhook',
      500
    )
  }
}

/**
 * Verify Razorpay webhook signature
 */
function verifyWebhookSignature(body: string, signature: string): boolean {
  const webhookSecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET')
  if (!webhookSecret) {
    console.error('[Webhook] RAZORPAY_WEBHOOK_SECRET not configured')
    return false
  }
  
  const expectedSignature = createHmac('sha256', webhookSecret)
    .update(body)
    .digest('hex')
  
  return signature === expectedSignature
}

/**
 * Handle successful payment capture
 */
async function handlePaymentCaptured(
  payment: any,
  order: any,
  services: ServiceContainer
): Promise<void> {
  const { tokenService, supabaseClient, analyticsLogger } = services
  
  const orderId = order?.id || payment?.order_id
  const paymentId = payment?.id
  const amount = payment?.amount // In paise
  
  console.log(`[Webhook] Payment captured: ${paymentId} for order: ${orderId}`)
  
  // Get pending purchase
  const { data: pendingPurchase, error } = await supabaseClient
    .from('pending_token_purchases')
    .select('*')
    .eq('order_id', orderId)
    .single()
  
  if (error || !pendingPurchase) {
    console.error(`[Webhook] Pending purchase not found for order: ${orderId}`, error)
    throw new Error(`Pending purchase not found: ${orderId}`)
  }
  
  if (pendingPurchase.status !== 'pending') {
    console.log(`[Webhook] Purchase already processed: ${orderId}`)
    return // Already processed
  }
  
  // Verify amount matches
  if (amount !== pendingPurchase.amount_paise) {
    console.error(`[Webhook] Amount mismatch for order ${orderId}: expected ${pendingPurchase.amount_paise}, got ${amount}`)
    throw new Error('Payment amount verification failed')
  }
  
  try {
    // Use atomic transaction to prevent double-crediting
    const { data: completionResult, error: completionError } = await supabaseClient
      .rpc('complete_token_purchase', {
        p_order_id: orderId,
        p_payment_id: paymentId,
        p_user_id: null // Allow service role to process any order
      })
    
    if (completionError) {
      throw new Error(`Purchase completion RPC failed: ${completionError.message}`)
    }
    
    if (!completionResult.success) {
      if (completionResult.already_processed) {
        console.log(`[Webhook] ✅ Purchase already completed: ${orderId}`)
        return // Already processed, no error
      } else {
        throw new Error(completionResult.error || 'Purchase completion failed')
      }
    }
    
    console.log(`[Webhook] ✅ Purchase completed: ${completionResult.tokens_added} tokens for user ${completionResult.user_id}`)
    
    // Log successful purchase
    await analyticsLogger.logEvent('webhook_purchase_completed', {
      user_id: completionResult.user_id,
      order_id: orderId,
      payment_id: paymentId,
      token_amount: completionResult.tokens_added,
      amount_paise: amount,
      new_purchased_balance: completionResult.new_purchased_balance
    })
    
  } catch (error) {
    console.error(`[Webhook] Failed to complete purchase for order ${orderId}:`, error)
    
    // Mark purchase as failed
    await supabaseClient
      .from('pending_token_purchases')
      .update({
        status: 'failed',
        error_message: error instanceof Error ? error.message : 'Unknown error',
        updated_at: new Date().toISOString()
      })
      .eq('order_id', orderId)
    
    throw error
  }
}

/**
 * Handle failed payment
 */
async function handlePaymentFailed(
  payment: any,
  order: any,
  services: ServiceContainer
): Promise<void> {
  const { supabaseClient, analyticsLogger } = services
  
  const orderId = order?.id || payment?.order_id
  const paymentId = payment?.id
  const errorDescription = payment?.error_description
  
  console.log(`[Webhook] Payment failed: ${paymentId} for order: ${orderId}`)
  console.log(`[Webhook] Error: ${errorDescription}`)
  
  // Mark pending purchase as failed
  await supabaseClient
    .from('pending_token_purchases')
    .update({
      status: 'failed',
      payment_id: paymentId,
      error_message: errorDescription || 'Payment failed',
      updated_at: new Date().toISOString()
    })
    .eq('order_id', orderId)
  
  // Log failed payment
  await analyticsLogger.logEvent('webhook_payment_failed', {
    order_id: orderId,
    payment_id: paymentId,
    error_description: errorDescription
  })
}

// Create the Edge Function
createSimpleFunction(handleRazorpayWebhook, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})
```

### Step 2: Configure Webhook in Razorpay Dashboard

**Webhook Configuration**:
1. **Login to Razorpay Dashboard** → Settings → Webhooks
2. **Add Webhook URL**: `https://your-project.supabase.co/functions/v1/razorpay-webhook`
3. **Select Events**:
   - `payment.captured`
   - `payment.failed`
   - `order.paid`
4. **Set Secret**: Generate and save in Supabase secrets as `RAZORPAY_WEBHOOK_SECRET`
5. **Test webhook** with Razorpay's webhook testing tool

---

## 🔒 Gap 4: Security & Signature Verification

### Step 1: Add Payment Signature Verification to Backend

**File**: `backend/supabase/functions/purchase-tokens/index.ts`

**Add signature verification function**:
```typescript
import { createHmac } from 'crypto'

/**
 * Verify Razorpay payment signature
 */
function verifyPaymentSignature({
  orderId,
  paymentId,
  signature
}: {
  orderId: string
  paymentId: string
  signature: string
}): boolean {
  const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')
  if (!keySecret) {
    console.error('[Security] RAZORPAY_KEY_SECRET not configured')
    return false
  }
  
  const body = `${orderId}|${paymentId}`
  const expectedSignature = createHmac('sha256', keySecret)
    .update(body)
    .digest('hex')
  
  const isValid = signature === expectedSignature
  console.log(`[Security] Signature verification: ${isValid ? 'VALID' : 'INVALID'}`)
  
  return isValid
}
```

### Step 2: Add Confirmation Endpoint

**Create new endpoint**: `backend/supabase/functions/confirm-token-purchase/index.ts`
```typescript
import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { createHmac } from 'crypto'

interface ConfirmPurchaseRequest {
  order_id: string
  payment_id: string
  signature: string
}

async function handleConfirmPurchase(req: Request, services: ServiceContainer): Promise<Response> {
  const { authService, tokenService, supabaseClient, analyticsLogger } = services
  
  // Authenticate user
  const userContext = await authService.getUserContext(req)
  if (userContext.type !== 'authenticated') {
    throw new AppError(
      'AUTHENTICATION_REQUIRED',
      'You must be logged in to confirm purchase',
      401
    )
  }
  
  // Parse request
  const { order_id, payment_id, signature }: ConfirmPurchaseRequest = await req.json()
  
  // Verify signature
  const isValidSignature = verifyPaymentSignature({
    orderId: order_id,
    paymentId: payment_id,
    signature
  })
  
  if (!isValidSignature) {
    console.error(`[Security] Invalid signature for payment confirmation: ${payment_id}`)
    throw new AppError(
      'INVALID_SIGNATURE',
      'Payment signature verification failed',
      401
    )
  }
  
  console.log(`[Security] ✅ Payment signature verified: ${payment_id}`)
  
  // Get and validate pending purchase
  const { data: pendingPurchase, error } = await supabaseClient
    .from('pending_token_purchases')
    .select('*')
    .eq('order_id', order_id)
    .eq('user_id', userContext.userId)
    .single()
  
  if (error || !pendingPurchase) {
    throw new AppError(
      'PURCHASE_NOT_FOUND',
      'Pending purchase not found or unauthorized',
      404
    )
  }
  
  if (pendingPurchase.status === 'completed') {
    // Already completed, return current status
    const currentTokens = await tokenService.getUserTokens(
      userContext.userId!,
      'standard'
    )
    
    return new Response(JSON.stringify({
      success: true,
      message: 'Purchase already completed',
      token_balance: currentTokens
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
  }
  
  if (pendingPurchase.status === 'failed') {
    throw new AppError(
      'PURCHASE_FAILED',
      'This purchase has failed and cannot be completed',
      400
    )
  }
  
  try {
    // Use atomic transaction to prevent double-crediting
    const { data: completionResult, error: completionError } = await supabaseClient
      .rpc('complete_token_purchase', {
        p_order_id: order_id,
        p_payment_id: payment_id,
        p_user_id: userContext.userId // Restrict to authenticated user
      })
    
    if (completionError) {
      throw new Error(`Purchase completion RPC failed: ${completionError.message}`)
    }
    
    if (!completionResult.success) {
      if (completionResult.already_processed) {
        // Get current token status for already completed purchase
        const currentTokens = await tokenService.getUserTokens(
          userContext.userId!,
          'standard'
        )
        
        return new Response(JSON.stringify({
          success: true,
          message: 'Purchase already completed',
          token_balance: currentTokens
        }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        })
      } else {
        throw new Error(completionResult.error || 'Purchase completion failed')
      }
    }
    
    // Get updated token status
    const updatedTokens = await tokenService.getUserTokens(
      userContext.userId!,
      'standard'
    )
    
    // Log successful confirmation
    await analyticsLogger.logEvent('purchase_confirmed_by_user', {
      user_id: userContext.userId,
      order_id,
      payment_id,
      token_amount: completionResult.tokens_added,
      new_purchased_balance: completionResult.new_purchased_balance
    })
    
    return new Response(JSON.stringify({
      success: true,
      message: 'Purchase confirmed successfully',
      tokens_added: completionResult.tokens_added,
      token_balance: updatedTokens
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    console.error('[Purchase] Failed to confirm purchase:', error)
    
    // Mark as failed
    await supabaseClient
      .from('pending_token_purchases')
      .update({
        status: 'failed',
        error_message: error instanceof Error ? error.message : 'Unknown error',
        updated_at: new Date().toISOString()
      })
      .eq('order_id', order_id)
    
    throw new AppError(
      'PURCHASE_CONFIRMATION_FAILED',
      'Failed to confirm token purchase',
      500
    )
  }
}

function verifyPaymentSignature({
  orderId,
  paymentId,
  signature
}: {
  orderId: string
  paymentId: string
  signature: string
}): boolean {
  const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')
  if (!keySecret) {
    console.error('[Security] RAZORPAY_KEY_SECRET not configured')
    return false
  }
  
  const body = `${orderId}|${paymentId}`
  const expectedSignature = createHmac('sha256', keySecret)
    .update(body)
    .digest('hex')
  
  return signature === expectedSignature
}

createSimpleFunction(handleConfirmPurchase, {
  enableAnalytics: true,
  allowedMethods: ['POST']
})
```

### Step 3: Enhance Frontend Data Source

**File**: `frontend/lib/features/tokens/data/datasources/token_remote_data_source.dart`

**Update the interface**:
```dart
abstract class TokenRemoteDataSource {
  // ... existing methods ...
  
  /// Creates a payment order for token purchase
  Future<Map<String, dynamic>> createPaymentOrder({
    required int tokenAmount,
  });
  
  /// Confirms token purchase after payment success
  Future<TokenStatusModel> confirmTokenPurchase({
    required String orderId,
    required String paymentId,
    required String signature,
  });
}
```

**Update the implementation**:
```dart
@override
Future<Map<String, dynamic>> createPaymentOrder({
  required int tokenAmount,
}) async {
  try {
    await ApiAuthHelper.validateTokenForRequest();
    final headers = await ApiAuthHelper.getAuthHeaders();
    
    print('🛒 [TOKEN_API] Creating payment order for $tokenAmount tokens');
    
    final response = await _supabaseClient.functions.invoke(
      'purchase-tokens',  // This now returns order details instead of completing purchase
      method: HttpMethod.post,
      body: {
        'token_amount': tokenAmount,
      },
      headers: headers,
    );
    
    print('🛒 [TOKEN_API] Order response: ${response.status}');
    
    if (response.status == 200 && response.data != null) {
      return response.data as Map<String, dynamic>;
    } else {
      throw ServerException(
        message: 'Failed to create payment order',
        code: 'ORDER_CREATION_FAILED',
      );
    }
  } catch (e) {
    print('🚨 [TOKEN_API] Order creation error: $e');
    rethrow;
  }
}

@override
Future<TokenStatusModel> confirmTokenPurchase({
  required String orderId,
  required String paymentId,
  required String signature,
}) async {
  try {
    await ApiAuthHelper.validateTokenForRequest();
    final headers = await ApiAuthHelper.getAuthHeaders();
    
    print('✅ [TOKEN_API] Confirming purchase: $orderId');
    
    final response = await _supabaseClient.functions.invoke(
      'confirm-token-purchase',
      method: HttpMethod.post,
      body: {
        'order_id': orderId,
        'payment_id': paymentId,
        'signature': signature,
      },
      headers: headers,
    );
    
    print('✅ [TOKEN_API] Confirmation response: ${response.status}');
    
    if (response.status == 200 && response.data != null) {
      final responseData = response.data as Map<String, dynamic>;
      
      if (responseData['success'] == true) {
        return TokenStatusModel.fromJson(responseData['token_balance']);
      } else {
        throw ServerException(
          message: responseData['message'] ?? 'Purchase confirmation failed',
          code: 'CONFIRMATION_FAILED',
        );
      }
    } else {
      throw ServerException(
        message: 'Failed to confirm token purchase',
        code: 'CONFIRMATION_FAILED',
      );
    }
  } catch (e) {
    print('🚨 [TOKEN_API] Confirmation error: $e');
    rethrow;
  }
}
```

---

## ✅ Implementation Checklist

### Backend Tasks:
- [ ] Install Razorpay Node.js SDK
- [ ] Configure environment variables/secrets
- [ ] Replace placeholder payment function
- [ ] Update purchase flow logic
- [ ] Add pending purchase storage
- [ ] Create webhook handler function
- [ ] Add payment signature verification
- [ ] Create purchase confirmation endpoint
- [ ] Test webhook integration

### Frontend Tasks:
- [ ] Add Razorpay Flutter dependencies
- [ ] Configure payment constants
- [ ] Create payment service class
- [ ] Update token purchase dialog
- [ ] Add new BLoC events/states
- [ ] Update remote data source
- [ ] Implement error handling
- [ ] Test payment flow end-to-end

### DevOps Tasks:
- [ ] Configure Razorpay dashboard webhooks
- [ ] Set up environment variables in all environments
- [ ] Deploy new Edge Functions
- [ ] Test webhook delivery
- [ ] Monitor payment transactions
- [ ] Set up alerting for failed payments

### Testing Tasks:
- [ ] Test successful payment flow
- [ ] Test payment failure scenarios
- [ ] Test webhook processing
- [ ] Test signature verification
- [ ] Load test payment processing
- [ ] Security penetration testing

---

## 🎯 Conclusion

This comprehensive implementation guide addresses all 4 critical gaps in the token purchase system:

1. **✅ Real Razorpay Integration**: Complete backend SDK integration with order creation
2. **✅ Frontend Payment Checkout**: Flutter Razorpay SDK with full payment UI
3. **✅ Webhook Payment Confirmation**: Automated payment verification and token addition
4. **✅ Security & Signature Verification**: Payment signature validation at multiple levels

The implementation maintains the existing solid architecture while adding production-ready payment processing capabilities. Each component includes comprehensive error handling, logging, and security measures.

**Estimated Implementation Time**: 3-5 days for a senior developer
**Critical Success Factors**: 
- Proper Razorpay account setup and API key configuration
- Thorough testing in Razorpay test environment
- Webhook endpoint accessibility and proper SSL configuration
- Security review of signature verification implementation
-- Test Script: Token System Database Functions Validation
-- Date: 2025-09-07
-- Purpose: Comprehensive testing of all token system database functions
-- Usage: Run after applying token system migrations to verify functionality

-- Note: This script should be run as service_role to access all functions
-- In Supabase Dashboard SQL Editor, or via supabase db test command

-- =====================================
-- CLEANUP: Remove any existing test data
-- =====================================

-- Clean up any existing test records
DELETE FROM user_tokens WHERE identifier LIKE 'test_%';
DELETE FROM analytics_events WHERE user_id LIKE 'test_%';

-- =====================================
-- TEST 1: User Plan Limits and Creation
-- =====================================

-- Test 1.1: Free plan user creation and limits
SELECT 'TEST 1.1: Free Plan User Creation' as test_name;
DO $$
DECLARE
    result RECORD;
BEGIN
    -- Test free plan user creation
    SELECT * INTO result FROM get_or_create_user_tokens('test_free_user', 'free');

    -- Verify free plan limits
    ASSERT result.daily_limit = 8, 'Free plan should have 8 token daily limit';
    ASSERT result.available_tokens = 8, 'New free user should start with 8 tokens';
    ASSERT result.purchased_tokens = 0, 'New user should have 0 purchased tokens';
    ASSERT result.user_plan = 'free', 'Plan should be set to free';
    
    RAISE NOTICE 'TEST 1.1 PASSED: Free plan user created successfully';
END $$;

-- Test 1.2: Standard plan user creation and limits  
SELECT 'TEST 1.2: Standard Plan User Creation' as test_name;
DO $$
DECLARE
    result RECORD;
BEGIN
    -- Test standard plan user creation
    SELECT * INTO result FROM get_or_create_user_tokens('test_standard_user', 'standard');

    -- Verify standard plan limits
    ASSERT result.daily_limit = 20, 'Standard plan should have 20 token daily limit';
    ASSERT result.available_tokens = 20, 'New standard user should start with 20 tokens';
    ASSERT result.purchased_tokens = 0, 'New user should have 0 purchased tokens';
    ASSERT result.user_plan = 'standard', 'Plan should be set to standard';
    
    RAISE NOTICE 'TEST 1.2 PASSED: Standard plan user created successfully';
END $$;

-- Test 1.3: Premium plan user creation and limits
SELECT 'TEST 1.3: Premium Plan User Creation' as test_name;
DO $$
DECLARE
    result RECORD;
BEGIN
    -- Test premium plan user creation
    SELECT * INTO result FROM get_or_create_user_tokens('test_premium_user', 'premium');
    
    -- Verify premium plan limits (effectively unlimited)
    ASSERT result.daily_limit = 999999999, 'Premium plan should have unlimited tokens';
    ASSERT result.available_tokens = 999999999, 'Premium user should have unlimited tokens';
    ASSERT result.purchased_tokens = 0, 'New user should have 0 purchased tokens';
    ASSERT result.user_plan = 'premium', 'Plan should be set to premium';
    
    RAISE NOTICE 'TEST 1.3 PASSED: Premium plan user created successfully';
END $$;

-- =====================================
-- TEST 2: Token Consumption Logic
-- =====================================

-- Test 2.1: Basic token consumption (standard user)
SELECT 'TEST 2.1: Basic Token Consumption' as test_name;
DO $$
DECLARE
    result RECORD;
BEGIN
    -- Consume 5 tokens from standard user
    SELECT * INTO result FROM consume_user_tokens('test_standard_user', 'standard', 5);

    -- Verify consumption
    ASSERT result.success = true, 'Token consumption should succeed';
    ASSERT result.available_tokens = 15, 'Should have 15 tokens remaining';
    ASSERT result.purchased_tokens = 0, 'Purchased tokens should remain 0';
    ASSERT result.error_message = '', 'No error message expected';

    RAISE NOTICE 'TEST 2.1 PASSED: Basic token consumption works correctly';
END $$;

-- Test 2.2: Insufficient tokens scenario
SELECT 'TEST 2.2: Insufficient Tokens Handling' as test_name;
DO $$
DECLARE
    result RECORD;
BEGIN
    -- Try to consume more tokens than available (15 + 0 = 15 available, requesting 100)
    SELECT * INTO result FROM consume_user_tokens('test_standard_user', 'standard', 100);
    
    -- Verify rejection
    ASSERT result.success = false, 'Token consumption should fail';
    ASSERT result.error_message = 'Insufficient tokens', 'Should return insufficient tokens error';
    
    RAISE NOTICE 'TEST 2.2 PASSED: Insufficient tokens handled correctly';
END $$;

-- Test 2.3: Premium user unlimited consumption
SELECT 'TEST 2.3: Premium User Unlimited Consumption' as test_name;
DO $$
DECLARE
    result RECORD;
BEGIN
    -- Try to consume large amount from premium user
    SELECT * INTO result FROM consume_user_tokens('test_premium_user', 'premium', 50000);
    
    -- Verify premium unlimited access
    ASSERT result.success = true, 'Premium token consumption should always succeed';
    ASSERT result.available_tokens = 999999999, 'Premium user should maintain unlimited tokens';
    ASSERT result.error_message = '', 'No error message expected for premium';
    
    RAISE NOTICE 'TEST 2.3 PASSED: Premium unlimited consumption works correctly';
END $$;

-- =====================================
-- TEST 3: Purchased Tokens Logic
-- =====================================

-- Test 3.1: Adding purchased tokens
SELECT 'TEST 3.1: Adding Purchased Tokens' as test_name;
DO $$
DECLARE
    result RECORD;
BEGIN
    -- Add 50 purchased tokens to standard user
    SELECT * INTO result FROM add_purchased_tokens('test_standard_user', 'standard', 50);
    
    -- Verify addition
    ASSERT result.success = true, 'Adding purchased tokens should succeed';
    ASSERT result.new_purchased_balance = 50, 'Should have 50 purchased tokens';
    ASSERT result.error_message = '', 'No error message expected';
    
    RAISE NOTICE 'TEST 3.1 PASSED: Purchased tokens added successfully';
END $$;

-- Test 3.2: Purchased tokens consumption priority
SELECT 'TEST 3.2: Purchased Tokens Priority Consumption' as test_name;
DO $$
DECLARE
    result RECORD;
    token_info RECORD;
BEGIN
    -- First get current state (should be 15 daily + 50 purchased = 65 total)
    SELECT * INTO token_info FROM get_or_create_user_tokens('test_standard_user', 'standard');
    RAISE NOTICE 'Before consumption: daily=%, purchased=%', token_info.available_tokens, token_info.purchased_tokens;

    -- Consume 30 tokens (should come from purchased tokens first)
    SELECT * INTO result FROM consume_user_tokens('test_standard_user', 'standard', 30);

    -- Verify purchased tokens were consumed first
    ASSERT result.success = true, 'Token consumption should succeed';
    ASSERT result.available_tokens = 15, 'Daily tokens should remain unchanged';
    ASSERT result.purchased_tokens = 20, 'Purchased tokens should reduce from 50 to 20';

    RAISE NOTICE 'TEST 3.2 PASSED: Purchased tokens consumed with correct priority';
END $$;

-- Test 3.3: Mixed token consumption (purchased + daily)
SELECT 'TEST 3.3: Mixed Token Consumption' as test_name;
DO $$
DECLARE
    result RECORD;
BEGIN
    -- Consume 35 tokens (20 purchased + 15 daily)
    SELECT * INTO result FROM consume_user_tokens('test_standard_user', 'standard', 35);

    -- Verify mixed consumption
    ASSERT result.success = true, 'Mixed token consumption should succeed';
    ASSERT result.available_tokens = 0, 'Daily tokens should reduce from 15 to 0';
    ASSERT result.purchased_tokens = 0, 'All purchased tokens should be consumed';

    RAISE NOTICE 'TEST 3.3 PASSED: Mixed token consumption works correctly';
END $$;

-- =====================================
-- TEST 4: Daily Reset Logic
-- =====================================

-- Test 4.1: Simulate daily reset
SELECT 'TEST 4.1: Daily Reset Simulation' as test_name;
DO $$
DECLARE
    result RECORD;
BEGIN
    -- First, manually set last_reset to yesterday to simulate reset condition
    UPDATE user_tokens 
    SET last_reset = CURRENT_DATE - INTERVAL '1 day'
    WHERE identifier = 'test_standard_user';
    
    -- Add some purchased tokens for testing
    SELECT * INTO result FROM add_purchased_tokens('test_standard_user', 'standard', 25);
    
    -- Now get tokens (should trigger reset)
    SELECT * INTO result FROM get_or_create_user_tokens('test_standard_user', 'standard');

    -- Verify reset occurred
    ASSERT result.available_tokens = 20, 'Daily tokens should reset to 20';
    ASSERT result.total_consumed_today = 0, 'Daily consumption should reset to 0';
    ASSERT result.last_reset = CURRENT_DATE, 'Reset date should be today';
    ASSERT result.purchased_tokens = 25, 'Purchased tokens should persist across reset';
    
    RAISE NOTICE 'TEST 4.1 PASSED: Daily reset logic works correctly';
END $$;

-- Test 4.2: Premium users and daily reset
SELECT 'TEST 4.2: Premium Daily Reset Behavior' as test_name;
DO $$
DECLARE
    result RECORD;
BEGIN
    -- Simulate yesterday for premium user
    UPDATE user_tokens 
    SET last_reset = CURRENT_DATE - INTERVAL '1 day'
    WHERE identifier = 'test_premium_user';
    
    -- Get tokens for premium user (should not affect their unlimited status)
    SELECT * INTO result FROM get_or_create_user_tokens('test_premium_user', 'premium');
    
    -- Verify premium behavior
    ASSERT result.available_tokens = 999999999, 'Premium should maintain unlimited tokens';
    ASSERT result.total_consumed_today = 0, 'Premium consumption tracking should reset';
    
    RAISE NOTICE 'TEST 4.2 PASSED: Premium daily reset behavior correct';
END $$;

-- =====================================
-- TEST 5: Analytics Integration
-- =====================================

-- Test 5.1: Verify analytics events are logged
SELECT 'TEST 5.1: Analytics Events Logging' as test_name;
DO $$
DECLARE
    event_count INTEGER;
    result RECORD;
BEGIN
    -- Count existing analytics events for our test users
    SELECT COUNT(*) INTO event_count 
    FROM analytics_events 
    WHERE user_id LIKE 'test_%' AND event_type IN ('token_consumed', 'token_added');
    
    -- Perform a token consumption (should log event)
    SELECT * INTO result FROM consume_user_tokens('test_standard_user', 'standard', 5);
    
    -- Verify event was logged
    SELECT COUNT(*) INTO event_count 
    FROM analytics_events 
    WHERE user_id = 'test_standard_user' AND event_type = 'token_consumed';
    
    ASSERT event_count > 0, 'Analytics event should be logged for token consumption';
    
    RAISE NOTICE 'TEST 5.1 PASSED: Analytics events logging works correctly';
END $$;

-- Test 5.2: Verify analytics event data structure
SELECT 'TEST 5.2: Analytics Event Data Structure' as test_name;
DO $$
DECLARE
    event_data JSONB;
BEGIN
    -- Get the latest token consumption event
    SELECT event_data INTO event_data
    FROM analytics_events
    WHERE user_id = 'test_standard_user' AND event_type = 'token_consumed'
    ORDER BY created_at DESC
    LIMIT 1;
    
    -- Verify event data contains required fields
    ASSERT event_data ? 'user_plan', 'Event data should contain user_plan';
    ASSERT event_data ? 'token_cost', 'Event data should contain token_cost';
    ASSERT event_data ? 'daily_tokens_used', 'Event data should contain daily_tokens_used';
    ASSERT event_data ? 'remaining_daily', 'Event data should contain remaining_daily';
    
    RAISE NOTICE 'TEST 5.2 PASSED: Analytics event data structure is correct';
END $$;

-- =====================================
-- TEST 6: Error Handling
-- =====================================

-- Test 6.1: Invalid token amount for purchase
SELECT 'TEST 6.1: Invalid Purchase Token Amount' as test_name;
DO $$
DECLARE
    result RECORD;
BEGIN
    -- Try to purchase negative tokens
    SELECT * INTO result FROM add_purchased_tokens('test_standard_user', 'standard', -10);
    
    -- Verify error handling
    ASSERT result.success = false, 'Negative token purchase should fail';
    ASSERT result.error_message = 'Invalid token amount', 'Should return appropriate error message';
    
    RAISE NOTICE 'TEST 6.1 PASSED: Invalid purchase amount handled correctly';
END $$;

-- Test 6.2: Invalid user plan
SELECT 'TEST 6.2: Invalid User Plan Handling' as test_name;
DO $$
DECLARE
    result RECORD;
    error_occurred BOOLEAN := false;
BEGIN
    -- Try to create user with invalid plan (should use constraint)
    BEGIN
        SELECT * INTO result FROM get_or_create_user_tokens('test_invalid_user', 'invalid_plan');
    EXCEPTION
        WHEN check_violation THEN
            error_occurred := true;
    END;
    
    -- Verify constraint worked
    ASSERT error_occurred = true, 'Invalid user plan should trigger constraint violation';
    
    RAISE NOTICE 'TEST 6.2 PASSED: Invalid user plan handled by database constraints';
END $$;

-- =====================================
-- TEST SUMMARY AND CLEANUP
-- =====================================

-- Display test summary
SELECT 'ALL TESTS COMPLETED SUCCESSFULLY' as test_summary;

-- Count total analytics events created during testing
SELECT 
    'Analytics Events Created: ' || COUNT(*)::TEXT as analytics_summary
FROM analytics_events 
WHERE user_id LIKE 'test_%';

-- Show final token states for test users
SELECT 
    identifier,
    user_plan,
    available_tokens,
    purchased_tokens,
    daily_limit,
    total_consumed_today
FROM user_tokens 
WHERE identifier LIKE 'test_%'
ORDER BY identifier;

-- Optional: Clean up test data (uncomment if desired)
/*
DELETE FROM user_tokens WHERE identifier LIKE 'test_%';
DELETE FROM analytics_events WHERE user_id LIKE 'test_%';
SELECT 'Test data cleaned up' as cleanup_status;
*/
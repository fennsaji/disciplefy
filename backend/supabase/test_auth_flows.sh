#!/bin/bash

# Test Authentication Flows for Disciplefy Backend
# This script tests both anonymous and Google OAuth authentication flows

set -e

# Configuration
SUPABASE_URL="http://127.0.0.1:54321"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
COLORS=true

# Colors for output
if [[ "$COLORS" == "true" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Helper functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Test 1: Anonymous Session Creation
test_anonymous_session() {
    print_header "Testing Anonymous Session Creation"
    
    local response=$(curl -s -X POST \
        "${SUPABASE_URL}/functions/v1/auth-session" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
        -d '{
            "action": "create_anonymous",
            "device_fingerprint": "test-device-123"
        }')
    
    if echo "$response" | grep -q '"success":true'; then
        print_success "Anonymous session created successfully"
        local session_id=$(echo "$response" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)
        print_info "Session ID: $session_id"
        echo "$session_id" > /tmp/anonymous_session_id.txt
        return 0
    else
        print_error "Failed to create anonymous session"
        echo "Response: $response"
        return 1
    fi
}

# Test 2: Anonymous User Read Access
test_anonymous_read_access() {
    print_header "Testing Anonymous Read Access"
    
    # Test topics table access
    print_info "Testing topics table read access..."
    local response=$(curl -s -X GET \
        "${SUPABASE_URL}/rest/v1/topics?select=*" \
        -H "apikey: ${SUPABASE_ANON_KEY}" \
        -H "Content-Type: application/json")
    
    if echo "$response" | grep -q '\['; then
        print_success "Anonymous users can read topics table"
        local count=$(echo "$response" | grep -o '"title"' | wc -l)
        print_info "Found $count topics"
    else
        print_error "Failed to read topics table"
        echo "Response: $response"
        return 1
    fi
    
    # Test daily_verse table access
    print_info "Testing daily_verse table read access..."
    local response=$(curl -s -X GET \
        "${SUPABASE_URL}/rest/v1/daily_verse?select=*" \
        -H "apikey: ${SUPABASE_ANON_KEY}" \
        -H "Content-Type: application/json")
    
    if echo "$response" | grep -q '\['; then
        print_success "Anonymous users can read daily_verse table"
        local count=$(echo "$response" | grep -o '"verse_reference"' | wc -l)
        print_info "Found $count daily verses"
    else
        print_error "Failed to read daily_verse table"
        echo "Response: $response"
        return 1
    fi
}

# Test 3: Anonymous User Write Restrictions
test_anonymous_write_restrictions() {
    print_header "Testing Anonymous Write Restrictions"
    
    # Test topics table write restriction
    print_info "Testing topics table write restriction..."
    local response=$(curl -s -X POST \
        "${SUPABASE_URL}/rest/v1/topics" \
        -H "apikey: ${SUPABASE_ANON_KEY}" \
        -H "Content-Type: application/json" \
        -d '{
            "title": "Test Topic",
            "description": "This should fail",
            "category": "test"
        }')
    
    if echo "$response" | grep -q 'insufficient_privilege\|permission denied'; then
        print_success "Anonymous users correctly restricted from writing to topics"
    else
        print_error "Anonymous users can unexpectedly write to topics"
        echo "Response: $response"
        return 1
    fi
    
    # Test study_guides table write restriction
    print_info "Testing study_guides table write restriction..."
    local response=$(curl -s -X POST \
        "${SUPABASE_URL}/rest/v1/study_guides" \
        -H "apikey: ${SUPABASE_ANON_KEY}" \
        -H "Content-Type: application/json" \
        -d '{
            "input_type": "topic",
            "input_value": "test",
            "summary": "test",
            "context": "test",
            "related_verses": ["test"],
            "reflection_questions": ["test"],
            "prayer_points": ["test"]
        }')
    
    if echo "$response" | grep -q 'insufficient_privilege\|permission denied'; then
        print_success "Anonymous users correctly restricted from writing to study_guides"
    else
        print_error "Anonymous users can unexpectedly write to study_guides"
        echo "Response: $response"
        return 1
    fi
}

# Test 4: Google OAuth Flow (Mock)
test_google_oauth_flow() {
    print_header "Testing Google OAuth Flow (Mock)"
    
    print_info "Testing OAuth callback endpoint..."
    local response=$(curl -s -X POST \
        "${SUPABASE_URL}/functions/v1/auth-google-callback" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
        -d '{
            "error": "access_denied",
            "error_description": "User denied access"
        }')
    
    if echo "$response" | grep -q '"error"'; then
        print_success "OAuth callback correctly handles error responses"
    else
        print_error "OAuth callback error handling failed"
        echo "Response: $response"
        return 1
    fi
    
    print_info "Testing invalid authorization code..."
    local response=$(curl -s -X POST \
        "${SUPABASE_URL}/functions/v1/auth-google-callback" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
        -d '{
            "code": "invalid_code_123"
        }')
    
    if echo "$response" | grep -q '"error"'; then
        print_success "OAuth callback correctly handles invalid authorization codes"
    else
        print_error "OAuth callback should reject invalid codes"
        echo "Response: $response"
        return 1
    fi
}

# Test 5: Anonymous Session Migration
test_anonymous_session_migration() {
    print_header "Testing Anonymous Session Migration"
    
    if [[ ! -f /tmp/anonymous_session_id.txt ]]; then
        print_warning "No anonymous session ID found, skipping migration test"
        return 0
    fi
    
    local session_id=$(cat /tmp/anonymous_session_id.txt)
    
    print_info "Testing migration attempt without authentication..."
    local response=$(curl -s -X POST \
        "${SUPABASE_URL}/functions/v1/auth-session" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
        -d "{
            \"action\": \"migrate_to_authenticated\",
            \"anonymous_session_id\": \"$session_id\"
        }")
    
    if echo "$response" | grep -q 'UNAUTHORIZED'; then
        print_success "Migration correctly requires authentication"
    else
        print_error "Migration should require authentication"
        echo "Response: $response"
        return 1
    fi
}

# Test 6: Rate Limiting
test_rate_limiting() {
    print_header "Testing Rate Limiting"
    
    print_info "Testing anonymous session creation rate limiting..."
    local success_count=0
    local total_requests=35  # Should exceed the limit of 30
    
    for i in $(seq 1 $total_requests); do
        local response=$(curl -s -X POST \
            "${SUPABASE_URL}/functions/v1/auth-session" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
            -d "{
                \"action\": \"create_anonymous\",
                \"device_fingerprint\": \"test-device-$i\"
            }")
        
        if echo "$response" | grep -q '"success":true'; then
            ((success_count++))
        fi
        
        # Small delay to avoid overwhelming the server
        sleep 0.1
    done
    
    if [[ $success_count -lt $total_requests ]]; then
        print_success "Rate limiting is working (success: $success_count/$total_requests)"
    else
        print_warning "Rate limiting might not be working properly (all requests succeeded)"
    fi
}

# Test 7: Database Functions
test_database_functions() {
    print_header "Testing Database Functions"
    
    print_info "Testing validate_anonymous_session function..."
    local response=$(curl -s -X POST \
        "${SUPABASE_URL}/rest/v1/rpc/validate_anonymous_session" \
        -H "apikey: ${SUPABASE_ANON_KEY}" \
        -H "Content-Type: application/json" \
        -d '{
            "session_uuid": "00000000-0000-0000-0000-000000000000"
        }')
    
    if echo "$response" | grep -q 'false'; then
        print_success "validate_anonymous_session correctly rejects invalid sessions"
    else
        print_error "validate_anonymous_session function failed"
        echo "Response: $response"
        return 1
    fi
    
    print_info "Testing is_admin function..."
    local response=$(curl -s -X POST \
        "${SUPABASE_URL}/rest/v1/rpc/is_admin" \
        -H "apikey: ${SUPABASE_ANON_KEY}" \
        -H "Content-Type: application/json")
    
    if echo "$response" | grep -q 'false'; then
        print_success "is_admin correctly returns false for anonymous users"
    else
        print_error "is_admin function failed"
        echo "Response: $response"
        return 1
    fi
}

# Test 8: Security Validation
test_security_validation() {
    print_header "Testing Security Validation"
    
    print_info "Testing SQL injection prevention..."
    local response=$(curl -s -X GET \
        "${SUPABASE_URL}/rest/v1/topics?title=eq.'; DROP TABLE topics; --" \
        -H "apikey: ${SUPABASE_ANON_KEY}" \
        -H "Content-Type: application/json")
    
    if echo "$response" | grep -q '\[\]'; then
        print_success "SQL injection attempt safely handled"
    else
        print_error "Potential SQL injection vulnerability"
        echo "Response: $response"
        return 1
    fi
    
    print_info "Testing XSS prevention..."
    local response=$(curl -s -X GET \
        "${SUPABASE_URL}/rest/v1/topics?title=eq.<script>alert('xss')</script>" \
        -H "apikey: ${SUPABASE_ANON_KEY}" \
        -H "Content-Type: application/json")
    
    if echo "$response" | grep -q '\[\]'; then
        print_success "XSS attempt safely handled"
    else
        print_error "Potential XSS vulnerability"
        echo "Response: $response"
        return 1
    fi
}

# Main test runner
main() {
    print_header "Disciplefy Backend Authentication Tests"
    print_info "Testing Supabase instance at: $SUPABASE_URL"
    
    local failed_tests=0
    local total_tests=8
    
    # Run all tests
    test_anonymous_session || ((failed_tests++))
    test_anonymous_read_access || ((failed_tests++))
    test_anonymous_write_restrictions || ((failed_tests++))
    test_google_oauth_flow || ((failed_tests++))
    test_anonymous_session_migration || ((failed_tests++))
    test_rate_limiting || ((failed_tests++))
    test_database_functions || ((failed_tests++))
    test_security_validation || ((failed_tests++))
    
    # Print summary
    print_header "Test Summary"
    local passed_tests=$((total_tests - failed_tests))
    
    if [[ $failed_tests -eq 0 ]]; then
        print_success "All tests passed! ($passed_tests/$total_tests)"
    else
        print_error "$failed_tests tests failed, $passed_tests tests passed"
    fi
    
    # Cleanup
    rm -f /tmp/anonymous_session_id.txt
    
    exit $failed_tests
}

# Run tests
main "$@"
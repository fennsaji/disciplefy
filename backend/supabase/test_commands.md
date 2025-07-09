# Disciplefy Backend Authentication Test Commands

This document provides comprehensive test commands to verify both anonymous and Google OAuth authentication flows.

## 🚀 Quick Start

```bash
# Run all tests
./test_auth_flows.sh

# Run specific test sections (modify the script to comment out others)
# Individual test functions are available in test_auth_flows.sh
```

## 🔧 Manual Test Commands

### 1. Anonymous Session Creation

```bash
# Create anonymous session
curl -X POST "http://127.0.0.1:54321/functions/v1/auth-session" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -d '{
    "action": "create_anonymous",
    "device_fingerprint": "test-device-123"
  }'

# Expected response:
# {
#   "success": true,
#   "data": {
#     "session_id": "uuid-here",
#     "expires_at": "2024-01-01T00:00:00.000Z",
#     "is_anonymous": true
#   }
# }
```

### 2. Anonymous Read Access Tests

```bash
# Test topics table read access (should work)
curl -X GET "http://127.0.0.1:54321/rest/v1/topics?select=*" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -H "Content-Type: application/json"

# Test daily_verse table read access (should work)
curl -X GET "http://127.0.0.1:54321/rest/v1/daily_verse?select=*" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -H "Content-Type: application/json"
```

### 3. Anonymous Write Restrictions Tests

```bash
# Test topics table write restriction (should fail)
curl -X POST "http://127.0.0.1:54321/rest/v1/topics" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Topic",
    "description": "This should fail",
    "category": "test"
  }'

# Expected response: Error with insufficient_privilege or permission denied

# Test study_guides table write restriction (should fail)
curl -X POST "http://127.0.0.1:54321/rest/v1/study_guides" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -H "Content-Type: application/json" \
  -d '{
    "input_type": "topic",
    "input_value": "test",
    "summary": "test",
    "context": "test",
    "related_verses": ["test"],
    "reflection_questions": ["test"],
    "prayer_points": ["test"]
  }'

# Expected response: Error with insufficient_privilege or permission denied
```

### 4. Google OAuth Flow Tests

```bash
# Test OAuth callback endpoint with error
curl -X POST "http://127.0.0.1:54321/functions/v1/auth-google-callback" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -d '{
    "error": "access_denied",
    "error_description": "User denied access"
  }'

# Test OAuth callback with invalid authorization code
curl -X POST "http://127.0.0.1:54321/functions/v1/auth-google-callback" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -d '{
    "code": "invalid_code_123"
  }'
```

### 5. Anonymous Session Migration Tests

```bash
# Test migration attempt without authentication (should fail)
curl -X POST "http://127.0.0.1:54321/functions/v1/auth-session" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -d '{
    "action": "migrate_to_authenticated",
    "anonymous_session_id": "00000000-0000-0000-0000-000000000000"
  }'

# Expected response: Error with UNAUTHORIZED
```

### 6. Database Functions Tests

```bash
# Test validate_anonymous_session function
curl -X POST "http://127.0.0.1:54321/rest/v1/rpc/validate_anonymous_session" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -H "Content-Type: application/json" \
  -d '{
    "session_uuid": "00000000-0000-0000-0000-000000000000"
  }'

# Test is_admin function
curl -X POST "http://127.0.0.1:54321/rest/v1/rpc/is_admin" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -H "Content-Type: application/json"
```

### 7. Security Validation Tests

```bash
# Test SQL injection prevention
curl -X GET "http://127.0.0.1:54321/rest/v1/topics?title=eq.'; DROP TABLE topics; --" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -H "Content-Type: application/json"

# Test XSS prevention
curl -X GET "http://127.0.0.1:54321/rest/v1/topics?title=eq.<script>alert('xss')</script>" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -H "Content-Type: application/json"
```

## 🔄 Complete Google OAuth Flow Test

To test the complete Google OAuth flow:

1. **Frontend Initiates OAuth:**
   ```javascript
   // In your Flutter app
   await supabase.auth.signInWithOAuth(
     Provider.google,
     options: AuthOptions(
       redirectTo: 'com.disciplefy.bible_study://auth/callback',
     ),
   );
   ```

2. **Backend Processes Callback:**
   ```bash
   # The auth-google-callback function will be called automatically
   # You can monitor logs with:
   supabase functions logs auth-google-callback
   ```

3. **Verify Session:**
   ```bash
   # Check if session was created successfully
   curl -X GET "http://127.0.0.1:54321/rest/v1/user_profiles?select=*" \
     -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
     -H "Authorization: Bearer YOUR_ACCESS_TOKEN_HERE"
   ```

## 📊 Expected Results

### ✅ Successful Tests
- Anonymous session creation returns valid session_id
- Anonymous users can read topics and daily_verse tables
- Anonymous users cannot write to protected tables
- OAuth callback handles errors gracefully
- Rate limiting prevents excessive requests
- Database functions work correctly
- Security validations prevent common attacks

### ❌ Failed Tests (What to investigate)
- Authentication endpoints returning 500 errors
- Anonymous users able to write to protected tables
- OAuth callback accepting invalid codes
- Rate limiting not working
- Database functions not found
- SQL injection or XSS vulnerabilities

## 🔧 Troubleshooting

### Common Issues:

1. **Connection Refused:**
   ```bash
   # Start Supabase locally
   supabase start
   ```

2. **Function Not Found:**
   ```bash
   # Deploy functions
   supabase functions deploy auth-session
   supabase functions deploy auth-google-callback
   ```

3. **Database Changes Not Applied:**
   ```bash
   # Apply migrations
   supabase db reset
   ```

4. **Environment Variables:**
   ```bash
   # Check environment variables
   supabase secrets list
   ```

### Debug Commands:

```bash
# Check Supabase status
supabase status

# View function logs
supabase functions logs auth-session
supabase functions logs auth-google-callback

# Check database connections
supabase db inspect

# View real-time logs
supabase logs
```

## 🎯 Production Checklist

Before deploying to production:

- [ ] Update site_url in config.toml to production domain
- [ ] Set up proper SMTP for email sending
- [ ] Update redirect URLs for production
- [ ] Test with real Google OAuth credentials
- [ ] Enable proper rate limiting
- [ ] Set up monitoring and alerting
- [ ] Test email templates in production environment
- [ ] Verify all security policies are working
- [ ] Test anonymous session cleanup
- [ ] Verify SSL/TLS configuration
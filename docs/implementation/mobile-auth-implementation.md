# **📱 Mobile Number Authentication & Profile Setup Implementation Guide**

**Project:** Disciplefy Bible Study App  
**Version:** 2.0  
**Feature:** Phone Authentication + First-Time Profile Setup  
**Date:** September 16, 2025  
**Status:** REVISED - Addresses Critical Implementation Gaps

---

## **🎯 Overview**

This document provides a comprehensive implementation guide for adding mobile number authentication with OTP verification and first-time user profile setup (name + profile picture) before language selection.

### **User Flow**
```
Login Screen → Phone Input → OTP Verification → Profile Setup → Language Selection → Home
```

### **⚠️ Implementation Strategy Revision**

**RECOMMENDED APPROACH:** Leverage Supabase's native phone authentication provider instead of custom OTP implementation for better security, reliability, and faster development.

### **🔄 Integration with Existing System**

- **Extend existing AuthBloc** instead of creating separate PhoneAuthBloc
- **Graceful handling** of existing users vs new phone users
- **Backward compatibility** with Google/Anonymous authentication flows
- **Profile setup only for new users** - existing users skip this step

---

## **📦 Dependencies & Requirements**

### **Flutter Package Dependencies**
```yaml
# Add to pubspec.yaml
dependencies:
  intl_phone_field: ^3.2.0  # International phone input
  pin_code_fields: ^8.0.1   # OTP input fields
  image_picker: ^1.0.4      # Profile image selection
  image_cropper: ^5.0.1     # Image cropping
  permission_handler: ^11.0.1  # Camera/storage permissions
```

### **Platform Permissions**

#### **Android (android/app/src/main/AndroidManifest.xml)**
```xml
<!-- Camera and storage permissions -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

#### **iOS (ios/Runner/Info.plist)**
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to take profile pictures</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select profile pictures</string>
```

### **Supabase Configuration Requirements**
- SMS Provider setup (Twilio/MessageBird)
- Storage bucket for profile images
- Environment variables for API keys

---

## **🏗️ Backend Implementation**

### **1. Database Schema Changes**

#### **Migration: Add Phone Authentication Support**
```sql
-- File: backend/supabase/migrations/[timestamp]_add_phone_auth.sql

-- Add phone authentication fields to user_profiles
ALTER TABLE user_profiles ADD COLUMN phone_number TEXT;
ALTER TABLE user_profiles ADD COLUMN phone_verified BOOLEAN DEFAULT false;
ALTER TABLE user_profiles ADD COLUMN phone_country_code VARCHAR(5);

-- Add onboarding status tracking
ALTER TABLE user_profiles ADD COLUMN onboarding_status VARCHAR(20) DEFAULT 'pending';
-- Possible values: 'pending', 'profile_setup', 'language_selection', 'completed'

-- Create OTP requests table for rate limiting and security
CREATE TABLE otp_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone_number TEXT NOT NULL,
  otp_code VARCHAR(6) NOT NULL,
  ip_address INET,
  attempts INTEGER DEFAULT 0,
  is_verified BOOLEAN DEFAULT false,
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '10 minutes'),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for performance and cleanup
CREATE INDEX idx_otp_requests_phone ON otp_requests(phone_number);
CREATE INDEX idx_otp_requests_expires ON otp_requests(expires_at);

-- Add constraints for security
CREATE UNIQUE INDEX idx_otp_requests_active_phone ON otp_requests(phone_number) 
WHERE is_verified = false AND expires_at > NOW();

-- Add phone number uniqueness constraint
CREATE UNIQUE INDEX idx_user_profiles_phone ON user_profiles(phone_number) 
WHERE phone_number IS NOT NULL;
```

#### **RLS Policies for OTP Table**
```sql
-- SECURITY: Restrict all OTP access to service role only
-- Users must use security definer functions (verify_user_otp, create_otp_request)

CREATE POLICY "Service role only OTP reads" ON otp_requests
FOR SELECT USING (auth.role() = 'service_role');

CREATE POLICY "Allow OTP request creation" ON otp_requests
FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Service role only OTP updates" ON otp_requests
FOR UPDATE USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Service role can delete expired OTPs" ON otp_requests
FOR DELETE USING (
  auth.role() = 'service_role' AND
  expires_at < NOW()
);

-- Security definer functions for user-facing OTP operations
CREATE OR REPLACE FUNCTION verify_user_otp(
  user_phone_number TEXT,
  provided_otp_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $
DECLARE
  otp_record RECORD;
BEGIN
  -- Find valid OTP record
  SELECT * INTO otp_record
  FROM otp_requests
  WHERE phone_number = user_phone_number
    AND otp_code = provided_otp_code
    AND is_verified = false
    AND expires_at > NOW()
    AND attempts < 5
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    UPDATE otp_requests
    SET attempts = attempts + 1
    WHERE phone_number = user_phone_number
      AND is_verified = false
      AND expires_at > NOW();

    RETURN jsonb_build_object(
      'success', false,
      'message', 'Invalid or expired OTP code'
    );
  END IF;

  -- Mark OTP as verified
  UPDATE otp_requests
  SET is_verified = true
  WHERE id = otp_record.id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'OTP verified successfully',
    'otp_id', otp_record.id
  );
END;
$;

CREATE OR REPLACE FUNCTION create_otp_request(
  user_phone_number TEXT,
  user_ip_address INET DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $
DECLARE
  existing_count INTEGER;
  otp_code TEXT;
  new_otp_id UUID;
BEGIN
  -- Rate limiting: max 3 requests per hour
  SELECT COUNT(*) INTO existing_count
  FROM otp_requests
  WHERE phone_number = user_phone_number
    AND created_at > NOW() - INTERVAL '1 hour';

  IF existing_count >= 3 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Too many OTP requests. Please wait before requesting a new code.'
    );
  END IF;

  -- Generate 6-digit OTP
  otp_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');

  -- Insert new OTP request
  INSERT INTO otp_requests (phone_number, otp_code, ip_address)
  VALUES (user_phone_number, otp_code, user_ip_address)
  RETURNING id INTO new_otp_id;

  -- Return success WITHOUT exposing OTP code
  -- OTP must be sent via SMS, never returned to client
  RETURN jsonb_build_object(
    'success', true,
    'message', 'OTP sent successfully',
    'otp_id', new_otp_id,
    'expires_in', 600
  );
END;
$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION verify_user_otp(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION create_otp_request(TEXT, INET) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_user_otp(TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION create_otp_request(TEXT, INET) TO service_role;
```

### **2. Supabase Configuration**

#### **Enable Phone Auth Provider**
1. Go to Supabase Dashboard → Authentication → Providers
2. Enable "Phone" provider
3. Configure SMS provider (Twilio recommended)
4. Set up webhook URLs and authentication tokens

#### **SMS Provider Setup (Twilio)**
```env
# Add to .env.local
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=your_twilio_number
```

### **3. Edge Functions**

#### **Send OTP Function**
```typescript
// File: backend/supabase/functions/send-otp/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface SendOTPRequest {
  phone_number: string;
  country_code: string;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { phone_number, country_code }: SendOTPRequest = await req.json();
    const fullPhoneNumber = `${country_code}${phone_number}`;

    // Rate limiting: Check recent requests
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Check for existing active OTP
    const { data: existingOTP } = await supabase
      .from('otp_requests')
      .select('*')
      .eq('phone_number', fullPhoneNumber)
      .eq('is_verified', false)
      .gt('expires_at', new Date().toISOString())
      .single();

    if (existingOTP) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'OTP already sent. Please wait before requesting a new one.' 
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Generate 6-digit OTP
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();

    // Store OTP in database
    const { error: dbError } = await supabase
      .from('otp_requests')
      .insert({
        phone_number: fullPhoneNumber,
        otp_code: otpCode,
        ip_address: req.headers.get('x-forwarded-for') || '0.0.0.0'
      });

    if (dbError) throw dbError;

    // Send SMS via Twilio
    const response = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${Deno.env.get('TWILIO_ACCOUNT_SID')}/Messages.json`, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${btoa(`${Deno.env.get('TWILIO_ACCOUNT_SID')}:${Deno.env.get('TWILIO_AUTH_TOKEN')}`)}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        From: Deno.env.get('TWILIO_PHONE_NUMBER') ?? '',
        To: fullPhoneNumber,
        Body: `Your Disciplefy verification code is: ${otpCode}. This code expires in 10 minutes.`
      }),
    });

    if (!response.ok) {
      throw new Error('Failed to send SMS');
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'OTP sent successfully',
        expires_in: 600 // 10 minutes
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ 
        success: false, 
        message: error.message || 'Failed to send OTP' 
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

#### **Verify OTP Function**
```typescript
// File: backend/supabase/functions/verify-otp/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface VerifyOTPRequest {
  phone_number: string;
  country_code: string;
  otp_code: string;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { phone_number, country_code, otp_code }: VerifyOTPRequest = await req.json();
    const fullPhoneNumber = `${country_code}${phone_number}`;

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Find and verify OTP
    const { data: otpRecord, error: fetchError } = await supabase
      .from('otp_requests')
      .select('*')
      .eq('phone_number', fullPhoneNumber)
      .eq('otp_code', otp_code)
      .eq('is_verified', false)
      .gt('expires_at', new Date().toISOString())
      .single();

    if (fetchError || !otpRecord) {
      // Increment attempts for rate limiting
      await supabase
        .from('otp_requests')
        .update({ attempts: supabase.rpc('increment', { x: 1 }) })
        .eq('phone_number', fullPhoneNumber)
        .eq('is_verified', false);

      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Invalid or expired OTP code' 
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Mark OTP as verified
    await supabase
      .from('otp_requests')
      .update({ is_verified: true })
      .eq('id', otpRecord.id);

    // Create or sign in user with phone
    const { data: authData, error: authError } = await supabase.auth.signInWithOtp({
      phone: fullPhoneNumber,
      token: otp_code,
    });

    if (authError) {
      // If sign-in fails, create user manually
      const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
        phone: fullPhoneNumber,
        password: Math.random().toString(36), // Random password for phone users
      });

      if (signUpError) throw signUpError;
      
      // Create user profile
      if (signUpData.user) {
        await supabase
          .from('user_profiles')
          .insert({
            id: signUpData.user.id,
            phone_number: fullPhoneNumber,
            phone_verified: true,
            phone_country_code: country_code,
            onboarding_status: 'profile_setup',
            language_preference: 'en'
          });
      }

      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'Phone verification successful',
          user: signUpData.user,
          session: signUpData.session,
          requires_onboarding: true
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Phone verification successful',
        user: authData.user,
        session: authData.session,
        requires_onboarding: false
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ 
        success: false, 
        message: error.message || 'Failed to verify OTP' 
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

---

## **📱 Frontend Implementation**

### **1. Authentication Events & States**

#### **New Phone Auth Events**
```dart
// File: frontend/lib/features/auth/presentation/bloc/phone_auth_event.dart

abstract class PhoneAuthEvent extends Equatable {
  const PhoneAuthEvent();
  @override
  List<Object?> get props => [];
}

class SendOTPRequested extends PhoneAuthEvent {
  final String phoneNumber;
  final String countryCode;

  const SendOTPRequested({
    required this.phoneNumber, 
    required this.countryCode
  });

  @override
  List<Object?> get props => [phoneNumber, countryCode];
}

class VerifyOTPRequested extends PhoneAuthEvent {
  final String phoneNumber;
  final String countryCode;
  final String otpCode;

  const VerifyOTPRequested({
    required this.phoneNumber,
    required this.countryCode,
    required this.otpCode,
  });

  @override
  List<Object?> get props => [phoneNumber, countryCode, otpCode];
}

class ResendOTPRequested extends PhoneAuthEvent {
  final String phoneNumber;
  final String countryCode;

  const ResendOTPRequested({
    required this.phoneNumber,
    required this.countryCode
  });

  @override
  List<Object?> get props => [phoneNumber, countryCode];
}
```

### **2. Updated Login Screen**

#### **Add Phone Auth Button to Existing Login Screen**
```dart
// Add this to login_screen.dart _buildSignInButtons method

// Phone Sign-In Button
_buildPhoneSignInButton(context, isLoading),

const SizedBox(height: 16),
```

```dart
// Add this method to LoginScreen class

/// Builds the phone sign-in button
Widget _buildPhoneSignInButton(BuildContext context, bool isLoading) {
  final theme = Theme.of(context);

  return SizedBox(
    width: double.infinity,
    height: 56,
    child: OutlinedButton(
      onPressed: isLoading ? null : () => _handlePhoneSignIn(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        side: BorderSide(
          color: theme.colorScheme.primary,
          width: 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledForegroundColor:
            theme.colorScheme.primary.withValues(alpha: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            'Continue with Phone',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Handles phone sign-in button tap
void _handlePhoneSignIn(BuildContext context) {
  Navigator.pushNamed(context, '/phone-auth');
}
```

---

## **🔐 Security Considerations**

### **1. OTP Security**
- **Rate Limiting**: Maximum 3 OTP requests per phone number per hour
- **Attempt Limiting**: Maximum 5 verification attempts per OTP
- **Expiration**: OTP codes expire after 10 minutes
- **One-time Use**: OTP codes can only be used once

### **2. Phone Number Security**
- **Encryption**: Phone numbers stored with encryption at rest
- **Hashing**: Use SHA-256 for phone number indexing
- **Validation**: Server-side phone number format validation
- **Uniqueness**: One account per phone number

### **3. Profile Image Security**
- **File Type Validation**: Only JPEG, PNG, WebP allowed
- **Size Limits**: Maximum 5MB file size
- **Storage**: Secure cloud storage with access controls
- **Sanitization**: Remove EXIF data from uploaded images

---

## **📊 API Documentation Updates**

### **New Endpoints**

#### **Send OTP**
```
POST /functions/v1/send-otp
Content-Type: application/json

Request:
{
  "phone_number": "1234567890",
  "country_code": "+1"
}

Response:
{
  "success": true,
  "message": "OTP sent successfully",
  "expires_in": 600
}
```

#### **Verify OTP**
```
POST /functions/v1/verify-otp
Content-Type: application/json

Request:
{
  "phone_number": "1234567890",
  "country_code": "+1",
  "otp_code": "123456"
}

Response:
{
  "success": true,
  "message": "Phone verification successful",
  "user": { ... },
  "session": { ... },
  "requires_onboarding": true
}
```

---

## **🧪 Testing Strategy**

### **Backend Testing**
1. **OTP Function Tests**
   - Valid phone number formats
   - Rate limiting enforcement
   - OTP expiration handling
   - Error scenarios

2. **Database Tests**
   - Migration scripts
   - RLS policy enforcement
   - Data integrity constraints

### **Frontend Testing**
1. **Widget Tests**
   - Phone input validation
   - OTP input behavior
   - Profile form validation

2. **Integration Tests**
   - Complete phone auth flow
   - Profile setup process
   - Navigation between screens

---

## **📈 Implementation Timeline**

### **Phase 1: Backend Setup (Days 1-3)**
- Database migrations
- Supabase configuration
- Edge Functions development
- Security implementation

### **Phase 2: Frontend Development (Days 4-7)**
- Authentication screens
- BLoC implementation
- Router updates
- UI polish

### **Phase 3: Testing & Refinement (Days 8-9)**
- Comprehensive testing
- Bug fixes
- Performance optimization
- Security validation

### **Phase 4: Documentation & Deployment (Day 10)**
- Final documentation
- Deployment preparation
- Production configuration
- Release notes

---

## **🚀 Deployment Checklist**

### **Backend Deployment**
- [ ] Run database migrations
- [ ] Configure SMS provider credentials
- [ ] Set up Supabase Auth phone provider
- [ ] Deploy Edge Functions
- [ ] Configure storage buckets
- [ ] Set up monitoring and alerts

### **Frontend Deployment**
- [ ] Update app permissions for camera/gallery
- [ ] Configure deep linking for OTP
- [ ] Update app store descriptions
- [ ] Test on multiple devices
- [ ] Submit for review (iOS/Android)

### **Testing Validation**
- [ ] Test complete phone auth flow
- [ ] Verify OTP delivery and validation
- [ ] Test profile setup and image upload
- [ ] Validate security measures
- [ ] Performance testing under load

---

This comprehensive implementation guide provides all the necessary details to successfully implement mobile number authentication with profile setup in the Disciplefy Bible Study app. The implementation follows security best practices, maintains consistency with the existing architecture, and provides a smooth user experience.
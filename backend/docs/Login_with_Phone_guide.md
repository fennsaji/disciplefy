# Login with Phone Setup Guide

## 📱 **Setup Overview**
Complete guide to enable "Login with Phone" functionality using SMS OTP authentication. This guide covers Twilio SMS setup with Canada phone numbers for cost-effective international SMS delivery.

## 💰 **Cost Analysis**
- **Canada Phone Number**: ~$1 CAD/month
- **SMS to India**: ~$0.0075 USD per SMS
- **Total Cost**: Very low, approximately $1-2/month for moderate usage
- **No Registration**: No A2P 10DLC or special registration required

## 🚀 **Step-by-Step Setup**

### **Step 0: Enable Phone Login UI**

The phone login button is currently commented out in the login screen. To enable it:

1. **Open**: `frontend/lib/features/auth/presentation/pages/login_screen.dart`

2. **Uncomment** the phone login button call (around line 238):
   ```dart
   // CHANGE FROM:
   // Phone Sign-In Button - COMMENTED OUT FOR NOW
   // _buildPhoneSignInButton(context, isLoading),
   //
   // const SizedBox(height: 16),

   // TO:
   // Phone Sign-In Button
   _buildPhoneSignInButton(context, isLoading),

   const SizedBox(height: 16),
   ```

3. **Uncomment** the phone button method (around line 309):
   ```dart
   // Uncomment the entire _buildPhoneSignInButton method
   Widget _buildPhoneSignInButton(BuildContext context, bool isLoading) {
     // ... entire method content
   }
   ```

4. **Uncomment** the phone handler method (around line 465):
   ```dart
   // Uncomment the handler method
   void _handlePhoneSignIn(BuildContext context) {
     context.push(AppRoutes.phoneAuth);
   }
   ```

### **Step 1: Purchase Canada Phone Number**

1. **Go to**: [Twilio Console → Phone Numbers → Buy a number](https://console.twilio.com/us1/develop/phone-numbers/manage/search)

2. **Configure Search**:
   - **Country**: Canada 🇨🇦
   - **Capabilities**: ✅ SMS (required)
   - **Capabilities**: ✅ Voice (optional)
   - **Type**: Local or Toll-Free (both work)

3. **Select Number**:
   - Choose any available Canada number
   - **Format**: `+1-XXX-XXX-XXXX` (Canada uses +1 country code)
   - **Cost**: ~$1 CAD/month

4. **Purchase**: Click "Buy" and confirm

### **Step 2: Configure Messaging Service**

1. **Go to**: [Your Messaging Service](https://console.twilio.com/us1/develop/sms/services/MGf4ea40db47d9db20ed06ebe6382b7551)

2. **Update Sender Pool**:
   - **Remove**: "DISCIPLEFY" (alphanumeric sender - doesn't work on trial)
   - **Add**: Your new Canada phone number
   - **Click**: "Add Senders" → Select your Canada number

3. **Verify Configuration**:
   - Ensure Canada number appears in "Sender Pool"
   - Status should show as "Active"

### **Step 3: Update Environment Variables**

Update your `.env.local` file:

```bash
# Twilio Configuration
TWILIO_ACCOUNT_SID=YOUR_TWILIO_ACCOUNT_SID
TWILIO_AUTH_TOKEN=YOUR_TWILIO_AUTH_TOKEN
TWILIO_MESSAGE_SERVICE_SID=YOUR_TWILIO_MESSAGE_SERVICE_SID

# Update with your new Canada phone number
TWILIO_PHONE_NUMBER=+1234567890  # Replace with your actual Canada number
```

### **Step 4: Disable Test Mode**

Edit `backend/supabase/config.toml`:

```toml
# Use pre-defined map of phone number to OTP for testing.
# Disabled for production - using real SMS with Canada phone number
# [auth.sms.test_otp]
# "+917015538461" = "123456"
```

Comment out or remove the `[auth.sms.test_otp]` section.

### **Step 5: Restart Backend**

```bash
cd backend
supabase stop
sh scripts/run_local_server.sh
```

## 🧪 **Testing Production SMS**

### **Test SMS Delivery**

Once setup is complete, test with a real phone number:

```bash
# Test SMS using Twilio API directly
source .env.local
curl -X POST "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT_SID/Messages.json" \
-u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN" \
--data-urlencode "MessagingServiceSid=$TWILIO_MESSAGE_SERVICE_SID" \
--data-urlencode "To=+917015538461" \
--data-urlencode "Body=Your Disciplefy verification code is 123456. Do not share this code with anyone."
```

### **Expected Result**

Users will receive SMS from Canada number:
```
From: +1-XXX-XXX-XXXX (Canada)
Message: "Your Disciplefy verification code is [6-digit-code]. Do not share this code with anyone."
```

### **Test Application Flow**

1. **Open**: `http://localhost:59641` (Flutter web app)
2. **Go to**: Phone authentication screen
3. **Enter**: Any valid phone number (e.g., `+917015538461`)
4. **Receive**: Real SMS with dynamic OTP code
5. **Enter**: OTP code from SMS
6. **Verify**: Authentication completes successfully

## ✅ **Production Readiness Checklist**

- [ ] Canada phone number purchased and active
- [ ] Number added to Messaging Service sender pool
- [ ] Environment variables updated with Canada number
- [ ] Test mode disabled in `config.toml`
- [ ] Backend restarted with new configuration
- [ ] SMS delivery tested successfully
- [ ] Application authentication flow tested end-to-end

## 🌍 **International SMS Coverage**

Canada phone numbers work excellently for:
- ✅ **India**: High delivery rates, low cost
- ✅ **United States**: Domestic delivery
- ✅ **Europe**: International SMS
- ✅ **Asia-Pacific**: Reliable delivery
- ✅ **Global**: Most countries supported

## 🔧 **Troubleshooting**

### **Common Issues**

1. **SMS Not Delivered**:
   - Check phone number format: `+1XXXXXXXXXX` (Canada)
   - Verify number is added to Messaging Service
   - Ensure sufficient Twilio account balance

2. **Configuration Errors**:
   - Verify environment variables are loaded
   - Check `config.toml` syntax
   - Restart backend after changes

3. **Trial Account Limitations**:
   - Canada numbers work on trial accounts
   - Can only send to verified phone numbers on trial
   - Upgrade to paid account for unrestricted sending

### **Support Commands**

```bash
# Check Twilio account balance
curl -X GET "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT_SID/Balance.json" \
-u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN"

# List all purchased phone numbers
curl -X GET "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT_SID/IncomingPhoneNumbers.json" \
-u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN"

# Check message delivery status
curl -X GET "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT_SID/Messages/[MESSAGE_SID].json" \
-u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN"
```

## 📊 **Cost Monitoring**

### **Expected Costs**
- **Development**: $1 CAD/month (number only)
- **Light Usage**: $1-2 USD/month (< 100 SMS)
- **Moderate Usage**: $2-5 USD/month (100-500 SMS)
- **High Usage**: $5-10 USD/month (500-1000 SMS)

### **Cost Optimization**
- Monitor SMS usage in Twilio Console
- Set up billing alerts
- Use test mode for development/staging
- Implement rate limiting in application

## 🎯 **Next Steps**

1. **Purchase Canada number** from Twilio Console
2. **Follow setup steps** in this document
3. **Test thoroughly** before production deployment
4. **Monitor costs** and delivery rates
5. **Scale up** by upgrading to paid Twilio account when needed

---

**📝 Created**: September 27, 2025
**👨‍💻 Author**: Claude Code Assistant
**🔄 Status**: Ready for implementation
**💰 Budget**: ~$1-2 USD/month
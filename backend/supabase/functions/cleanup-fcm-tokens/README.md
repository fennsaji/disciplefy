# FCM Token Cleanup Function

Automated cleanup of expired FCM (Firebase Cloud Messaging) tokens from the database.

## Overview

This Edge Function removes FCM tokens that have been inactive for 90+ days from the `user_notification_preferences` table. This maintains database hygiene, reduces storage costs, and ensures GDPR compliance by not retaining stale personal data.

## Why Token Cleanup?

### Data Minimization (GDPR Article 5)
- **Principle**: Only retain data for as long as necessary
- **Compliance**: Removing inactive tokens after 90 days demonstrates good data governance
- **User Privacy**: Users who've uninstalled the app or stopped using notifications shouldn't have their tokens stored indefinitely

### Database Hygiene
- **Storage Efficiency**: Reduces unnecessary database records
- **Query Performance**: Smaller tables mean faster queries
- **Cost Optimization**: Less storage = lower costs

### Security
- **Attack Surface Reduction**: Fewer stored tokens = less exposure if database is compromised
- **Token Rotation**: Forces users to register new tokens, ensuring fresh credentials

## How It Works

### Scheduled Execution
- **Frequency**: Daily at 02:00 UTC (low-traffic time)
- **Trigger**: GitHub Actions workflow (`cleanup-fcm-tokens.yml`)
- **Authentication**: Service role key required

### Cleanup Process

1. **Calculate Cutoff Date**: 90 days before current date
2. **Count Expired Tokens**: Query tokens with `updated_at < cutoff_date`
3. **Batch Processing**: Delete tokens in batches of 100
4. **Progress Logging**: Log each batch deletion
5. **Final Report**: Return summary with counts and cutoff date

### What Happens to Users?

When a user's token is removed:
- ✅ **No disruption**: User can still use the app normally
- ✅ **Automatic re-registration**: New token is registered on next app open
- ✅ **Seamless experience**: User doesn't notice any change

## API Specification

### Endpoint

```
POST /functions/v1/cleanup-fcm-tokens
```

### Authentication

**Required**: Service role key in `Authorization` header

```http
Authorization: Bearer YOUR_SERVICE_ROLE_KEY
```

### Request

No request body required.

### Response

**Success (200)**:
```json
{
  "success": true,
  "message": "FCM token cleanup completed",
  "removedCount": 42,
  "expectedCount": 42,
  "cutoffDate": "2024-07-11T02:00:00.000Z",
  "daysInactive": 90
}
```

**No Tokens to Clean (200)**:
```json
{
  "success": true,
  "message": "No expired tokens to clean up",
  "removedCount": 0,
  "cutoffDate": "2024-07-11T02:00:00.000Z"
}
```

**Unauthorized (401)**:
```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Service role authentication required"
  }
}
```

**Error (500)**:
```json
{
  "success": false,
  "error": {
    "code": "DATABASE_ERROR",
    "message": "Failed to count expired tokens: [error details]"
  }
}
```

## Configuration

### Retention Period

Default: **90 days**

To adjust, modify `CLEANUP_CONFIG` in `index.ts`:

```typescript
const CLEANUP_CONFIG = {
  DAYS_INACTIVE: 90, // Change this value
  BATCH_SIZE: 100,
} as const;
```

### Batch Size

Default: **100 tokens per batch**

Larger batches = faster cleanup but higher memory usage
Smaller batches = slower cleanup but more stable

## Deployment

### GitHub Actions Workflow

The cleanup function is triggered by `.github/workflows/cleanup-fcm-tokens.yml`:

```yaml
name: Cleanup FCM Tokens
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 02:00 UTC
  workflow_dispatch:      # Manual trigger
```

### Required Secrets

Set these in GitHub repository settings:

- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key for authentication
- `SUPABASE_PROJECT_ID` - Project ID (for CLI operations)
- `SUPABASE_ACCESS_TOKEN` - API access token (for CLI operations)

### Manual Trigger

1. Go to **Actions** tab in GitHub
2. Select **Cleanup FCM Tokens** workflow
3. Click **Run workflow**
4. View results in workflow summary

## Testing

### Local Testing

```bash
# Set environment variables
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"

# Run the function locally
npx supabase functions serve cleanup-fcm-tokens --no-verify-jwt

# Call the function
curl -X POST http://localhost:54321/functions/v1/cleanup-fcm-tokens \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json"
```

### Testing with Dry Run

To count tokens without deleting (for testing):

1. Manually trigger the GitHub Actions workflow
2. Select **dry_run: true** option
3. Review the count in the workflow summary

(Note: Dry run functionality would require code modification to implement)

## Monitoring

### GitHub Actions Summary

Each run generates a summary with:
- ✅ Status (success/failed)
- 📊 Tokens removed
- 📊 Tokens expected
- 📅 Cutoff date
- ⏰ Timestamp

### Logs

Check Supabase Edge Function logs for:
- `Starting FCM token cleanup process...`
- `Found X expired tokens to remove`
- `Deleted batch of Y tokens (total: Z/X)`
- `Token cleanup complete: X tokens removed`

### Alerts

Set up alerts for:
- **Workflow failures** - Indicates cleanup didn't run
- **High deletion counts** - May indicate configuration issue
- **Zero deletions for 30+ days** - May indicate workflow is stuck

## Database Schema

### Table: `user_notification_preferences`

```sql
CREATE TABLE user_notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  timezone_offset_minutes INTEGER NOT NULL,
  daily_verse_enabled BOOLEAN DEFAULT true,
  recommended_topic_enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Cleanup Query

```sql
DELETE FROM user_notification_preferences
WHERE updated_at < NOW() - INTERVAL '90 days';
```

## Compliance

### GDPR Compliance

- ✅ **Data Minimization** (Article 5(1)(c)) - Only retains necessary data
- ✅ **Storage Limitation** (Article 5(1)(e)) - Automatic deletion after 90 days
- ✅ **Accountability** (Article 5(2)) - Documented retention policy

### Retention Policy

**Personal Data**: FCM tokens (contain device identifiers)
- **Retention Period**: 90 days from last activity
- **Justification**: Balance between user experience and data minimization
- **Deletion Method**: Automated daily cleanup

## Troubleshooting

### Workflow Not Running

**Check**:
1. Workflow is enabled in GitHub Actions
2. Schedule syntax is correct (`0 2 * * *`)
3. Repository has required secrets configured

### High Number of Deletions

**Possible Causes**:
- Large inactive user base (expected)
- Token registration issues (users can't update tokens)
- Retention period misconfigured

**Action**:
- Review retention policy (maybe 90 days is too short)
- Check token registration logs for errors
- Verify users can successfully register tokens

### Cleanup Failing Mid-Process

**Symptoms**: Some batches delete, then errors occur

**Possible Causes**:
- Database connection timeout
- Rate limiting
- Concurrent modifications

**Action**:
- Reduce batch size in `CLEANUP_CONFIG`
- Check database connection pool settings
- Review Supabase logs for specific errors

### Zero Deletions for Long Period

**Possible Issues**:
- Workflow not running (check GitHub Actions)
- Service role key expired/invalid
- Database permissions issue

**Action**:
- Manually trigger workflow to test
- Verify service role key is valid
- Check database RLS policies don't block service role

## Best Practices

### Production Deployment

1. ✅ **Test first**: Run manually with monitoring before relying on schedule
2. ✅ **Monitor initially**: Watch first few runs closely for issues
3. ✅ **Set up alerts**: Configure notifications for failures
4. ✅ **Document policy**: Include retention period in privacy policy

### Retention Period Selection

**Considerations**:
- **User Behavior**: How long do users typically stay inactive?
- **Compliance**: GDPR doesn't specify exact periods, but shorter is better
- **UX Impact**: Longer = fewer token re-registrations

**Recommendations**:
- **90 days** (current) - Good balance for most apps
- **60 days** - For strict privacy requirements
- **120 days** - For apps with seasonal usage patterns

## Related Documentation

- [Push Notification System](../../send-daily-verse-notification/README.md)
- [Rate Limiting](../../_shared/utils/rate-limiter.README.md)
- [GitHub Actions Workflow](../../../../../.github/workflows/cleanup-fcm-tokens.yml)
- [PR #70 Review](../../../../../docs/reviews/PR_70_Push_Notification_Review.md)

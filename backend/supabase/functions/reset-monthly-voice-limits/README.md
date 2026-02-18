# Reset Monthly Voice Limits Cron Job

## Overview

This Edge Function is a scheduled cron job that runs on the 1st of every month at 00:00 UTC to reset monthly voice conversation counters for all users.

## Schedule

**Cron Expression**: `0 0 1 * *`
- Runs: 1st day of every month
- Time: 00:00 UTC (midnight)
- Frequency: Monthly

## Configuration

### Supabase Dashboard Setup

1. Go to Supabase Dashboard → Edge Functions
2. Navigate to the `reset-monthly-voice-limits` function
3. Click on "Cron" tab
4. Enable cron scheduling
5. Set schedule: `0 0 1 * *`
6. Add custom header:
   - Key: `Authorization`
   - Value: `Bearer ${CRON_SECRET}`

### Environment Variable

Ensure `CRON_SECRET` is set in your Supabase project secrets:

```bash
# Generate a secure secret
openssl rand -base64 32

# Set in Supabase
supabase secrets set CRON_SECRET=<generated-secret>
```

## Manual Testing

You can manually trigger this function for testing:

```bash
# Using curl (replace with your values)
curl -X POST https://[project-ref].supabase.co/functions/v1/reset-monthly-voice-limits \
  -H "Authorization: Bearer [CRON_SECRET]" \
  -H "Content-Type: application/json"
```

## What It Does

1. **Archives Previous Month Data**: Retrieves and logs statistics from the previous month for analytics
2. **Deletes Old Records**: Removes records older than 3 months to maintain database performance
3. **Implicit Reset**: Users automatically get fresh counters when they start conversations in the new month (via `get_or_create_monthly_voice_usage` function)

## Monitoring

Check function logs in Supabase Dashboard to verify:
- Successful execution on 1st of each month
- Number of records archived and deleted
- Statistics summary for previous month
- Any errors or issues

## Error Handling

- **Fail-safe**: If cron job fails, users will still be able to start conversations
- **Logging**: All operations are logged for debugging
- **Non-blocking**: Archive and delete operations don't block each other
- **Graceful Degradation**: If archiving fails, deletion still proceeds

## Statistics Tracked

The function logs monthly statistics including:
- Total users with voice conversations
- Total conversations started and completed
- Breakdown by subscription tier (Free, Standard, Plus, Premium)
- Completion rate (started vs completed)

## Maintenance

- Review logs monthly to ensure proper execution
- Monitor database size and adjust retention policy (currently 3 months) if needed
- Update `CRON_SECRET` periodically for security

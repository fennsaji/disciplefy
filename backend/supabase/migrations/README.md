# Consolidated Supabase Migrations

This directory contains the consolidated version of 193 scattered migrations, reorganized into exactly **15 clean, well-structured migration files**.

## Migration File Structure

### Execution Order

```
20260119000000_core_schema.sql           ← MUST be first (foundation)
20260119000100_study_guides.sql          ← Study system
20260119000200_token_system.sql          ← Token management
20260119000300_subscription_system.sql   ← Subscription plans + promo codes
20260119000400_payment_system.sql        ← Payment processing
20260119000500_voice_system.sql          ← Voice conversations + monthly limits
20260119000600_memory_system.sql         ← Memory verses + practice modes
20260119000700_gamification.sql          ← Achievements + streaks
20260119000800_learning_paths.sql        ← Learning journey system
20260119000900_usage_tracking.sql        ← Usage analytics + profitability
20260119001000_recommended_topics.sql    ← Curated topics + translations
20260119001100_learning_paths_translations.sql ← Path translations (large JSONB)
20260119001200_indexes.sql               ← All performance indexes
20260119001300_seed_data.sql             ← Seed data for all tables
20260119001400_admin_config.sql          ← Admin users + test accounts
```

## Purpose

This consolidation:
- ✅ Eliminates 193 → 15 files (12.87:1 reduction)
- ✅ Removes redundant bug fixes (applied inline)
- ✅ Clean separation of schema, functions, RLS, indexes
- ✅ Proper dependency ordering
- ✅ All recent features integrated (promo codes, usage logs, practice unlocking)
- ✅ Production-ready for database reset across all environments

## Table Inventory (48 Total)

### Core (11 tables)
user_profiles, anonymous_sessions, oauth_states, otp_requests, admin_logs, analytics_events, llm_security_events, notification_logs, user_notification_tokens, user_notification_preferences, feedback

### Study System (4 tables)
study_guides, study_guide_conversations, anonymous_study_guides, recommended_guide_sessions

### Token System (2 tables)
user_tokens, token_usage_history

### Subscription System (5 tables)
subscriptions, subscription_plans, subscription_history, subscription_invoices, promotional_campaigns

### Payment System (5 tables)
saved_payment_methods, payment_preferences, purchase_history, receipt_counters, donations

### Voice System (3 tables)
voice_buddy_conversations, conversation_messages, monthly_voice_limits

### Memory Verses (4 tables)
memory_verses, memory_collections, practice_sessions, daily_unlocked_modes

### Gamification (4 tables)
achievements, user_achievements, study_streaks, weekly_challenges

### Learning Paths (4 tables)
learning_paths, learning_path_topics, user_topic_progress, user_learning_path_progress

### Usage Tracking (4 tables)
usage_logs, llm_api_costs, rate_limit_rules, usage_alerts

### Recommended Topics (2 tables)
recommended_topics, recommended_topics_translations, learning_path_translations

## Usage

### Deploy to New Environment

```bash
# Set database URL
export SUPABASE_DB_URL="postgresql://user:pass@host:port/db"

# Run migrations in sequence (sorted by timestamp)
for file in $(ls -1 *.sql | sort); do
  echo "Running migration $file..."
  psql "$SUPABASE_DB_URL" -f "$file"
done
```

### Deploy to Supabase via CLI

```bash
cd /path/to/backend/supabase

# Link to your project
supabase link --project-ref your-project-ref

# Push migrations
supabase db push
```

## Testing

Before production deployment:

1. Test each migration individually on clean database
2. Test full sequence (all 15 migrations in timestamp order)
3. Verify all 48 tables created
4. Verify all 60+ functions present
5. Run enhanced validation queries
6. Test Edge Function compatibility

## Post-Deployment

### Required Steps:

1. **Restore encryption keys**: Run `scripts/backup/restore_encryption_keys.sh`
2. **Setup cron job**: Run `scripts/backup/setup_monthly_voice_reset_cron.sh`
3. **Restore user data**: Run data restore scripts
4. **Validate**: Run 12 enhanced validation queries

## Rollback Plan

If migration fails:

```bash
# Backup current state
pg_dump "$SUPABASE_DB_URL" > backup_failed_migration.sql

# Drop schema
psql "$SUPABASE_DB_URL" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

# Restore from backup
pg_restore --clean --if-exists old_backup.sql
```

## Files in Original Directory

Original migrations remain in `../migrations/` directory for reference. This consolidated set supersedes them for fresh deployments.

## Documentation

See comprehensive plan at: `/Users/fennsaji/.claude/plans/wise-booping-nebula.md`

## Support Scripts

Located in `../scripts/backup/`:
- `backup_encryption_keys.sh` - Backup encryption keys before migration
- `restore_encryption_keys.sh` - Restore encryption keys after migration
- `setup_monthly_voice_reset_cron.sh` - Setup automated voice limit resets

---

**Status**: Ready for implementation
**Last Updated**: 2026-01-19 (Migration naming standardized to timestamp format)
**Plan Version**: Production-Ready v1.0

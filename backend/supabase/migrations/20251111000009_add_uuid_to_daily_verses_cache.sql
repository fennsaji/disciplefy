-- Migration: Add UUID to daily_verses_cache for memory_verses integration
-- Created: 2025-11-12
-- Purpose: Add uuid field to daily_verses_cache to support foreign key references from memory_verses

-- Add uuid column with automatic generation for new rows
ALTER TABLE daily_verses_cache 
ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL;

-- Create index on uuid for foreign key lookups
CREATE INDEX IF NOT EXISTS idx_daily_verses_cache_uuid 
    ON daily_verses_cache(uuid);

-- Backfill UUIDs for existing rows (in case there are any)
UPDATE daily_verses_cache 
SET uuid = gen_random_uuid() 
WHERE uuid IS NULL;

-- Add helpful comment
COMMENT ON COLUMN daily_verses_cache.uuid IS 'UUID for stable foreign key references from memory_verses and other features';

-- Migration: Daily Verse Cache Table
-- Created: 2025-07-10
-- Purpose: Cache daily Bible verses to minimize external API calls and improve performance

-- Create daily_verses_cache table
CREATE TABLE IF NOT EXISTS daily_verses_cache (
    id BIGSERIAL PRIMARY KEY,
    date_key VARCHAR(10) NOT NULL UNIQUE, -- YYYY-MM-DD format
    verse_data JSONB NOT NULL, -- Complete verse data with translations
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_daily_verses_cache_date_key 
    ON daily_verses_cache(date_key) 
    WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_daily_verses_cache_expires_at 
    ON daily_verses_cache(expires_at);

-- Add RLS (Row Level Security) policies
ALTER TABLE daily_verses_cache ENABLE ROW LEVEL SECURITY;

-- Allow public read access to active verses (for anonymous users)
CREATE POLICY "Allow public read access to active daily verses" 
    ON daily_verses_cache FOR SELECT 
    USING (is_active = true);

-- Allow service role full access for cache management
CREATE POLICY "Allow service role full access to daily verse cache" 
    ON daily_verses_cache FOR ALL 
    USING (auth.role() = 'service_role');

-- Create trigger for updated_at timestamp
CREATE OR REPLACE FUNCTION update_daily_verse_cache_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_daily_verse_cache_updated_at_trigger
    BEFORE UPDATE ON daily_verses_cache
    FOR EACH ROW
    EXECUTE FUNCTION update_daily_verse_cache_updated_at();

-- Create function to clean up expired cache entries
CREATE OR REPLACE FUNCTION cleanup_expired_daily_verses()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM daily_verses_cache 
    WHERE expires_at < timezone('utc'::text, now())
    OR (created_at < timezone('utc'::text, now()) - INTERVAL '30 days');
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Add helpful comments
COMMENT ON TABLE daily_verses_cache IS 'Cache table for daily Bible verses with multi-language translations';
COMMENT ON COLUMN daily_verses_cache.date_key IS 'Date in YYYY-MM-DD format for consistent daily caching';
COMMENT ON COLUMN daily_verses_cache.verse_data IS 'Complete verse data including reference and translations (ESV, Hindi, Malayalam)';
COMMENT ON COLUMN daily_verses_cache.expires_at IS 'Cache expiration timestamp for automatic cleanup';
COMMENT ON FUNCTION cleanup_expired_daily_verses() IS 'Removes expired and old cache entries to keep table size manageable';
-- Migration: Suggested Verses Schema
-- Created: 2025-12-19
-- Purpose: Create tables for curated suggested verses feature
--          allowing users to browse and add popular Bible verses to their memory deck

BEGIN;

-- =============================================================================
-- TABLE: suggested_verses
-- =============================================================================
-- Stores curated/popular Bible verses that users can easily add to their memory deck

CREATE TABLE IF NOT EXISTS suggested_verses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference TEXT NOT NULL,              -- "John 3:16" (English canonical reference)
    book TEXT NOT NULL,                   -- "John"
    chapter INTEGER NOT NULL,             -- 3
    verse_start INTEGER NOT NULL,         -- 16
    verse_end INTEGER,                    -- NULL for single verse, or end verse for ranges
    category TEXT NOT NULL CHECK (category IN (
        'salvation', 'comfort', 'strength', 'wisdom',
        'promise', 'guidance', 'faith', 'love'
    )),
    tags TEXT[] DEFAULT '{}',             -- Additional tags for filtering
    display_order INTEGER DEFAULT 0,      -- Order within category
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_suggested_verses_category
    ON suggested_verses(category);

CREATE INDEX IF NOT EXISTS idx_suggested_verses_active
    ON suggested_verses(is_active) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_suggested_verses_display_order
    ON suggested_verses(category, display_order);

-- =============================================================================
-- TABLE: suggested_verse_translations
-- =============================================================================
-- Multi-language support for suggested verses (EN, HI, ML)

CREATE TABLE IF NOT EXISTS suggested_verse_translations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    suggested_verse_id UUID NOT NULL REFERENCES suggested_verses(id) ON DELETE CASCADE,
    language_code TEXT NOT NULL CHECK (language_code IN ('en', 'hi', 'ml')),
    verse_text TEXT NOT NULL,             -- Full verse text in this language
    localized_reference TEXT NOT NULL,    -- Localized reference (e.g., "यूहन्ना 3:16")
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT unique_verse_language UNIQUE(suggested_verse_id, language_code)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_suggested_verse_translations_verse_id
    ON suggested_verse_translations(suggested_verse_id);

CREATE INDEX IF NOT EXISTS idx_suggested_verse_translations_language
    ON suggested_verse_translations(language_code);

-- =============================================================================
-- RLS POLICIES
-- =============================================================================
-- Suggested verses are public read-only (no user-specific data)

ALTER TABLE suggested_verses ENABLE ROW LEVEL SECURITY;
ALTER TABLE suggested_verse_translations ENABLE ROW LEVEL SECURITY;

-- Everyone can read active suggested verses
DROP POLICY IF EXISTS "Everyone can read active suggested verses" ON suggested_verses;
CREATE POLICY "Everyone can read active suggested verses"
    ON suggested_verses FOR SELECT
    USING (is_active = TRUE);

-- Everyone can read translations
DROP POLICY IF EXISTS "Everyone can read suggested verse translations" ON suggested_verse_translations;
CREATE POLICY "Everyone can read suggested verse translations"
    ON suggested_verse_translations FOR SELECT
    USING (TRUE);

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON TABLE suggested_verses IS 'Curated popular Bible verses that users can easily add to their memory deck';
COMMENT ON TABLE suggested_verse_translations IS 'Multi-language translations for suggested verses (English, Hindi, Malayalam)';
COMMENT ON COLUMN suggested_verses.category IS 'Category for filtering: salvation, comfort, strength, wisdom, promise, guidance, faith, love';
COMMENT ON COLUMN suggested_verses.tags IS 'Additional tags for flexible filtering beyond category';
COMMENT ON COLUMN suggested_verses.display_order IS 'Order within category for consistent display';

COMMIT;

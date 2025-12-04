-- ============================================================================
-- Scripture-Based Topic Search System
-- Allows users to find study topics related to specific Bible verses or books
-- Part of Phase 4: Enhanced Discovery
-- ============================================================================

BEGIN;

-- ============================================================================
-- Scripture References Table
-- Maps topics to specific Bible books, chapters, and verses
-- ============================================================================

CREATE TABLE IF NOT EXISTS topic_scripture_references (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id UUID NOT NULL REFERENCES recommended_topics(id) ON DELETE CASCADE,
  book_name TEXT NOT NULL,              -- e.g., "John", "Genesis", "Psalms"
  book_abbrev TEXT NOT NULL,            -- e.g., "Jn", "Gen", "Ps"
  book_number INTEGER NOT NULL,         -- 1-66 for canonical ordering
  chapter_start INTEGER,                -- NULL means entire book
  chapter_end INTEGER,                  -- NULL means single chapter or entire book
  verse_start INTEGER,                  -- NULL means entire chapter
  verse_end INTEGER,                    -- NULL means single verse or entire chapter
  reference_text TEXT NOT NULL,         -- Human-readable: "John 3:16", "Genesis 1-3"
  relevance_score INTEGER DEFAULT 100,  -- 1-100, higher = more relevant
  is_primary_reference BOOLEAN DEFAULT false, -- Is this the main scripture for the topic?
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Ensure we don't duplicate exact same reference for a topic
  CONSTRAINT unique_topic_reference UNIQUE(topic_id, book_name, chapter_start, chapter_end, verse_start, verse_end)
);

-- Create indexes for efficient scripture search
CREATE INDEX idx_scripture_ref_book ON topic_scripture_references(book_name);
CREATE INDEX idx_scripture_ref_book_number ON topic_scripture_references(book_number);
CREATE INDEX idx_scripture_ref_topic ON topic_scripture_references(topic_id);
CREATE INDEX idx_scripture_ref_chapter ON topic_scripture_references(book_name, chapter_start);
CREATE INDEX idx_scripture_ref_primary ON topic_scripture_references(is_primary_reference) WHERE is_primary_reference = true;

-- Enable RLS
ALTER TABLE topic_scripture_references ENABLE ROW LEVEL SECURITY;

-- Public read access
CREATE POLICY "Anyone can read scripture references" ON topic_scripture_references
  FOR SELECT USING (true);

-- Service role can manage
CREATE POLICY "Service role can manage scripture references" ON topic_scripture_references
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- Bible Books Reference Table (for autocomplete and validation)
-- ============================================================================

CREATE TABLE IF NOT EXISTS bible_books (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  abbrev TEXT NOT NULL,
  testament TEXT NOT NULL CHECK (testament IN ('OT', 'NT')),
  chapters INTEGER NOT NULL,
  search_terms TEXT[] NOT NULL DEFAULT '{}'  -- Alternative names/spellings
);

-- Seed Bible books
INSERT INTO bible_books (id, name, abbrev, testament, chapters, search_terms) VALUES
  -- Old Testament
  (1, 'Genesis', 'Gen', 'OT', 50, ARRAY['gen', 'genesis', 'gn']),
  (2, 'Exodus', 'Exod', 'OT', 40, ARRAY['exod', 'exodus', 'ex']),
  (3, 'Leviticus', 'Lev', 'OT', 27, ARRAY['lev', 'leviticus', 'lv']),
  (4, 'Numbers', 'Num', 'OT', 36, ARRAY['num', 'numbers', 'nm']),
  (5, 'Deuteronomy', 'Deut', 'OT', 34, ARRAY['deut', 'deuteronomy', 'dt']),
  (6, 'Joshua', 'Josh', 'OT', 24, ARRAY['josh', 'joshua', 'jos']),
  (7, 'Judges', 'Judg', 'OT', 21, ARRAY['judg', 'judges', 'jdg']),
  (8, 'Ruth', 'Ruth', 'OT', 4, ARRAY['ruth', 'ru']),
  (9, '1 Samuel', '1 Sam', 'OT', 31, ARRAY['1 sam', '1 samuel', '1sam', 'i samuel']),
  (10, '2 Samuel', '2 Sam', 'OT', 24, ARRAY['2 sam', '2 samuel', '2sam', 'ii samuel']),
  (11, '1 Kings', '1 Kgs', 'OT', 22, ARRAY['1 kgs', '1 kings', '1kgs', 'i kings']),
  (12, '2 Kings', '2 Kgs', 'OT', 25, ARRAY['2 kgs', '2 kings', '2kgs', 'ii kings']),
  (13, '1 Chronicles', '1 Chr', 'OT', 29, ARRAY['1 chr', '1 chronicles', '1chr', 'i chronicles']),
  (14, '2 Chronicles', '2 Chr', 'OT', 36, ARRAY['2 chr', '2 chronicles', '2chr', 'ii chronicles']),
  (15, 'Ezra', 'Ezra', 'OT', 10, ARRAY['ezra', 'ezr']),
  (16, 'Nehemiah', 'Neh', 'OT', 13, ARRAY['neh', 'nehemiah', 'ne']),
  (17, 'Esther', 'Esth', 'OT', 10, ARRAY['esth', 'esther', 'est']),
  (18, 'Job', 'Job', 'OT', 42, ARRAY['job', 'jb']),
  (19, 'Psalms', 'Ps', 'OT', 150, ARRAY['ps', 'psalms', 'psalm', 'psa']),
  (20, 'Proverbs', 'Prov', 'OT', 31, ARRAY['prov', 'proverbs', 'pr']),
  (21, 'Ecclesiastes', 'Eccl', 'OT', 12, ARRAY['eccl', 'ecclesiastes', 'ec', 'qoheleth']),
  (22, 'Song of Solomon', 'Song', 'OT', 8, ARRAY['song', 'song of solomon', 'song of songs', 'sos', 'canticles']),
  (23, 'Isaiah', 'Isa', 'OT', 66, ARRAY['isa', 'isaiah', 'is']),
  (24, 'Jeremiah', 'Jer', 'OT', 52, ARRAY['jer', 'jeremiah', 'je']),
  (25, 'Lamentations', 'Lam', 'OT', 5, ARRAY['lam', 'lamentations', 'la']),
  (26, 'Ezekiel', 'Ezek', 'OT', 48, ARRAY['ezek', 'ezekiel', 'eze']),
  (27, 'Daniel', 'Dan', 'OT', 12, ARRAY['dan', 'daniel', 'dn']),
  (28, 'Hosea', 'Hos', 'OT', 14, ARRAY['hos', 'hosea', 'ho']),
  (29, 'Joel', 'Joel', 'OT', 3, ARRAY['joel', 'jl']),
  (30, 'Amos', 'Amos', 'OT', 9, ARRAY['amos', 'am']),
  (31, 'Obadiah', 'Obad', 'OT', 1, ARRAY['obad', 'obadiah', 'ob']),
  (32, 'Jonah', 'Jonah', 'OT', 4, ARRAY['jonah', 'jon']),
  (33, 'Micah', 'Mic', 'OT', 7, ARRAY['mic', 'micah', 'mi']),
  (34, 'Nahum', 'Nah', 'OT', 3, ARRAY['nah', 'nahum', 'na']),
  (35, 'Habakkuk', 'Hab', 'OT', 3, ARRAY['hab', 'habakkuk', 'hb']),
  (36, 'Zephaniah', 'Zeph', 'OT', 3, ARRAY['zeph', 'zephaniah', 'zep']),
  (37, 'Haggai', 'Hag', 'OT', 2, ARRAY['hag', 'haggai', 'hg']),
  (38, 'Zechariah', 'Zech', 'OT', 14, ARRAY['zech', 'zechariah', 'zec']),
  (39, 'Malachi', 'Mal', 'OT', 4, ARRAY['mal', 'malachi', 'ml']),
  -- New Testament
  (40, 'Matthew', 'Matt', 'NT', 28, ARRAY['matt', 'matthew', 'mt']),
  (41, 'Mark', 'Mark', 'NT', 16, ARRAY['mark', 'mk', 'mr']),
  (42, 'Luke', 'Luke', 'NT', 24, ARRAY['luke', 'lk', 'lu']),
  (43, 'John', 'John', 'NT', 21, ARRAY['john', 'jn', 'joh']),
  (44, 'Acts', 'Acts', 'NT', 28, ARRAY['acts', 'ac', 'acts of the apostles']),
  (45, 'Romans', 'Rom', 'NT', 16, ARRAY['rom', 'romans', 'ro']),
  (46, '1 Corinthians', '1 Cor', 'NT', 16, ARRAY['1 cor', '1 corinthians', '1cor', 'i corinthians']),
  (47, '2 Corinthians', '2 Cor', 'NT', 13, ARRAY['2 cor', '2 corinthians', '2cor', 'ii corinthians']),
  (48, 'Galatians', 'Gal', 'NT', 6, ARRAY['gal', 'galatians', 'ga']),
  (49, 'Ephesians', 'Eph', 'NT', 6, ARRAY['eph', 'ephesians', 'ep']),
  (50, 'Philippians', 'Phil', 'NT', 4, ARRAY['phil', 'philippians', 'php']),
  (51, 'Colossians', 'Col', 'NT', 4, ARRAY['col', 'colossians', 'co']),
  (52, '1 Thessalonians', '1 Thess', 'NT', 5, ARRAY['1 thess', '1 thessalonians', '1thess', 'i thessalonians']),
  (53, '2 Thessalonians', '2 Thess', 'NT', 3, ARRAY['2 thess', '2 thessalonians', '2thess', 'ii thessalonians']),
  (54, '1 Timothy', '1 Tim', 'NT', 6, ARRAY['1 tim', '1 timothy', '1tim', 'i timothy']),
  (55, '2 Timothy', '2 Tim', 'NT', 4, ARRAY['2 tim', '2 timothy', '2tim', 'ii timothy']),
  (56, 'Titus', 'Titus', 'NT', 3, ARRAY['titus', 'ti']),
  (57, 'Philemon', 'Phlm', 'NT', 1, ARRAY['phlm', 'philemon', 'phm']),
  (58, 'Hebrews', 'Heb', 'NT', 13, ARRAY['heb', 'hebrews', 'he']),
  (59, 'James', 'Jas', 'NT', 5, ARRAY['jas', 'james', 'jm']),
  (60, '1 Peter', '1 Pet', 'NT', 5, ARRAY['1 pet', '1 peter', '1pet', 'i peter']),
  (61, '2 Peter', '2 Pet', 'NT', 3, ARRAY['2 pet', '2 peter', '2pet', 'ii peter']),
  (62, '1 John', '1 John', 'NT', 5, ARRAY['1 john', '1john', '1jn', 'i john']),
  (63, '2 John', '2 John', 'NT', 1, ARRAY['2 john', '2john', '2jn', 'ii john']),
  (64, '3 John', '3 John', 'NT', 1, ARRAY['3 john', '3john', '3jn', 'iii john']),
  (65, 'Jude', 'Jude', 'NT', 1, ARRAY['jude', 'jd']),
  (66, 'Revelation', 'Rev', 'NT', 22, ARRAY['rev', 'revelation', 'revelations', 'apocalypse'])
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  abbrev = EXCLUDED.abbrev,
  testament = EXCLUDED.testament,
  chapters = EXCLUDED.chapters,
  search_terms = EXCLUDED.search_terms;

-- Enable RLS
ALTER TABLE bible_books ENABLE ROW LEVEL SECURITY;

-- Public read access
CREATE POLICY "Anyone can read bible books" ON bible_books
  FOR SELECT USING (true);

-- ============================================================================
-- Scripture Search Function
-- Search for topics by book, chapter, or specific verse reference
-- ============================================================================

CREATE OR REPLACE FUNCTION search_topics_by_scripture(
  p_search_query TEXT,
  p_book_name TEXT DEFAULT NULL,
  p_chapter INTEGER DEFAULT NULL,
  p_verse INTEGER DEFAULT NULL,
  p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
  topic_id UUID,
  title TEXT,
  description TEXT,
  category VARCHAR(100),
  tags TEXT[],
  reference_text TEXT,
  relevance_score INTEGER,
  is_primary_reference BOOLEAN,
  book_name TEXT,
  chapter_start INTEGER,
  verse_start INTEGER
) AS $$
DECLARE
  v_book_name TEXT;
  v_book_number INTEGER;
BEGIN
  -- If search query is provided, try to parse it or find matching book
  IF p_search_query IS NOT NULL AND p_search_query != '' THEN
    -- Find book by search term
    SELECT bb.name, bb.id INTO v_book_name, v_book_number
    FROM bible_books bb
    WHERE LOWER(p_search_query) = ANY(bb.search_terms)
       OR LOWER(bb.name) LIKE LOWER(p_search_query) || '%'
       OR LOWER(bb.abbrev) = LOWER(p_search_query)
    ORDER BY bb.id
    LIMIT 1;

    -- Use found book name, or the provided one
    v_book_name := COALESCE(v_book_name, p_book_name);
  ELSE
    v_book_name := p_book_name;
  END IF;

  RETURN QUERY
  SELECT
    rt.id AS topic_id,
    rt.title,
    rt.description,
    rt.category,
    rt.tags,
    tsr.reference_text,
    tsr.relevance_score,
    tsr.is_primary_reference,
    tsr.book_name,
    tsr.chapter_start,
    tsr.verse_start
  FROM topic_scripture_references tsr
  JOIN recommended_topics rt ON tsr.topic_id = rt.id
  WHERE rt.is_active = true
    AND (v_book_name IS NULL OR LOWER(tsr.book_name) = LOWER(v_book_name))
    AND (p_chapter IS NULL OR
         (tsr.chapter_start IS NULL) OR  -- Whole book reference matches any chapter
         (tsr.chapter_start <= p_chapter AND
          (tsr.chapter_end IS NULL OR tsr.chapter_end >= p_chapter)))
    AND (p_verse IS NULL OR
         (tsr.verse_start IS NULL) OR  -- Whole chapter reference matches any verse
         (tsr.verse_start <= p_verse AND
          (tsr.verse_end IS NULL OR tsr.verse_end >= p_verse)))
  ORDER BY
    tsr.is_primary_reference DESC,
    tsr.relevance_score DESC,
    rt.display_order ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Get Scripture Suggestions (for autocomplete)
-- ============================================================================

CREATE OR REPLACE FUNCTION get_scripture_suggestions(
  p_query TEXT,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
  book_name TEXT,
  book_abbrev TEXT,
  testament TEXT,
  topic_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    bb.name AS book_name,
    bb.abbrev AS book_abbrev,
    bb.testament,
    COUNT(DISTINCT tsr.topic_id) AS topic_count
  FROM bible_books bb
  LEFT JOIN topic_scripture_references tsr ON LOWER(tsr.book_name) = LOWER(bb.name)
  WHERE LOWER(p_query) = ANY(bb.search_terms)
     OR LOWER(bb.name) LIKE '%' || LOWER(p_query) || '%'
     OR LOWER(bb.abbrev) LIKE LOWER(p_query) || '%'
  GROUP BY bb.id, bb.name, bb.abbrev, bb.testament
  ORDER BY
    CASE WHEN LOWER(bb.name) LIKE LOWER(p_query) || '%' THEN 0 ELSE 1 END,
    bb.id
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Seed Scripture References for Existing Topics
-- ============================================================================

-- Foundations of Faith topics
INSERT INTO topic_scripture_references (topic_id, book_name, book_abbrev, book_number, chapter_start, verse_start, verse_end, reference_text, relevance_score, is_primary_reference) VALUES
  -- Who is Jesus Christ?
  ('111e8400-e29b-41d4-a716-446655440001', 'John', 'Jn', 43, 1, 1, 14, 'John 1:1-14', 100, true),
  ('111e8400-e29b-41d4-a716-446655440001', 'Colossians', 'Col', 51, 1, 15, 20, 'Colossians 1:15-20', 95, false),
  ('111e8400-e29b-41d4-a716-446655440001', 'Philippians', 'Phil', 50, 2, 5, 11, 'Philippians 2:5-11', 90, false),
  ('111e8400-e29b-41d4-a716-446655440001', 'Hebrews', 'Heb', 58, 1, 1, 4, 'Hebrews 1:1-4', 85, false),

  -- What is the Gospel?
  ('111e8400-e29b-41d4-a716-446655440002', 'Romans', 'Rom', 45, 1, 16, 17, 'Romans 1:16-17', 100, true),
  ('111e8400-e29b-41d4-a716-446655440002', '1 Corinthians', '1 Cor', 46, 15, 1, 8, '1 Corinthians 15:1-8', 95, false),
  ('111e8400-e29b-41d4-a716-446655440002', 'John', 'Jn', 43, 3, 16, 17, 'John 3:16-17', 100, false),
  ('111e8400-e29b-41d4-a716-446655440002', 'Ephesians', 'Eph', 49, 2, 8, 9, 'Ephesians 2:8-9', 90, false),

  -- Assurance of Salvation
  ('111e8400-e29b-41d4-a716-446655440003', '1 John', '1 Jn', 62, 5, 11, 13, '1 John 5:11-13', 100, true),
  ('111e8400-e29b-41d4-a716-446655440003', 'Romans', 'Rom', 45, 8, 38, 39, 'Romans 8:38-39', 95, false),
  ('111e8400-e29b-41d4-a716-446655440003', 'John', 'Jn', 43, 10, 27, 29, 'John 10:27-29', 90, false),

  -- Why Read the Bible?
  ('111e8400-e29b-41d4-a716-446655440004', '2 Timothy', '2 Tim', 55, 3, 16, 17, '2 Timothy 3:16-17', 100, true),
  ('111e8400-e29b-41d4-a716-446655440004', 'Psalms', 'Ps', 19, 119, 105, 105, 'Psalm 119:105', 95, false),
  ('111e8400-e29b-41d4-a716-446655440004', 'Hebrews', 'Heb', 58, 4, 12, 12, 'Hebrews 4:12', 90, false),
  ('111e8400-e29b-41d4-a716-446655440004', 'Joshua', 'Josh', 6, 1, 8, 8, 'Joshua 1:8', 85, false),

  -- Importance of Prayer
  ('111e8400-e29b-41d4-a716-446655440005', 'Matthew', 'Matt', 40, 6, 5, 15, 'Matthew 6:5-15', 100, true),
  ('111e8400-e29b-41d4-a716-446655440005', 'Philippians', 'Phil', 50, 4, 6, 7, 'Philippians 4:6-7', 95, false),
  ('111e8400-e29b-41d4-a716-446655440005', '1 Thessalonians', '1 Thess', 52, 5, 16, 18, '1 Thessalonians 5:16-18', 90, false),
  ('111e8400-e29b-41d4-a716-446655440005', 'James', 'Jas', 59, 5, 16, 16, 'James 5:16', 85, false),

  -- The Role of the Holy Spirit
  ('111e8400-e29b-41d4-a716-446655440006', 'John', 'Jn', 43, 14, 15, 17, 'John 14:15-17', 100, true),
  ('111e8400-e29b-41d4-a716-446655440006', 'John', 'Jn', 43, 16, 7, 15, 'John 16:7-15', 95, false),
  ('111e8400-e29b-41d4-a716-446655440006', 'Galatians', 'Gal', 48, 5, 22, 23, 'Galatians 5:22-23', 90, false),
  ('111e8400-e29b-41d4-a716-446655440006', 'Acts', 'Acts', 44, 2, 1, 4, 'Acts 2:1-4', 85, false)
ON CONFLICT (topic_id, book_name, chapter_start, chapter_end, verse_start, verse_end) DO NOTHING;

-- Christian Life topics
INSERT INTO topic_scripture_references (topic_id, book_name, book_abbrev, book_number, chapter_start, verse_start, verse_end, reference_text, relevance_score, is_primary_reference) VALUES
  -- Walking with God Daily
  ('222e8400-e29b-41d4-a716-446655440001', 'Micah', 'Mic', 33, 6, 8, 8, 'Micah 6:8', 100, true),
  ('222e8400-e29b-41d4-a716-446655440001', 'Proverbs', 'Prov', 20, 3, 5, 6, 'Proverbs 3:5-6', 95, false),
  ('222e8400-e29b-41d4-a716-446655440001', 'Galatians', 'Gal', 48, 5, 16, 16, 'Galatians 5:16', 90, false),

  -- Overcoming Temptation
  ('222e8400-e29b-41d4-a716-446655440002', '1 Corinthians', '1 Cor', 46, 10, 13, 13, '1 Corinthians 10:13', 100, true),
  ('222e8400-e29b-41d4-a716-446655440002', 'James', 'Jas', 59, 1, 12, 15, 'James 1:12-15', 95, false),
  ('222e8400-e29b-41d4-a716-446655440002', 'Matthew', 'Matt', 40, 4, 1, 11, 'Matthew 4:1-11', 90, false),
  ('222e8400-e29b-41d4-a716-446655440002', 'Hebrews', 'Heb', 58, 4, 15, 16, 'Hebrews 4:15-16', 85, false),

  -- Forgiveness and Reconciliation
  ('222e8400-e29b-41d4-a716-446655440003', 'Matthew', 'Matt', 40, 6, 14, 15, 'Matthew 6:14-15', 100, true),
  ('222e8400-e29b-41d4-a716-446655440003', 'Colossians', 'Col', 51, 3, 13, 13, 'Colossians 3:13', 95, false),
  ('222e8400-e29b-41d4-a716-446655440003', 'Ephesians', 'Eph', 49, 4, 32, 32, 'Ephesians 4:32', 90, false),
  ('222e8400-e29b-41d4-a716-446655440003', 'Matthew', 'Matt', 40, 18, 21, 22, 'Matthew 18:21-22', 85, false),

  -- The Importance of Fellowship
  ('222e8400-e29b-41d4-a716-446655440004', 'Hebrews', 'Heb', 58, 10, 24, 25, 'Hebrews 10:24-25', 100, true),
  ('222e8400-e29b-41d4-a716-446655440004', 'Acts', 'Acts', 44, 2, 42, 47, 'Acts 2:42-47', 95, false),
  ('222e8400-e29b-41d4-a716-446655440004', '1 John', '1 Jn', 62, 1, 7, 7, '1 John 1:7', 90, false),

  -- Giving and Generosity
  ('222e8400-e29b-41d4-a716-446655440005', '2 Corinthians', '2 Cor', 47, 9, 6, 7, '2 Corinthians 9:6-7', 100, true),
  ('222e8400-e29b-41d4-a716-446655440005', 'Malachi', 'Mal', 39, 3, 10, 10, 'Malachi 3:10', 95, false),
  ('222e8400-e29b-41d4-a716-446655440005', 'Acts', 'Acts', 44, 20, 35, 35, 'Acts 20:35', 90, false),
  ('222e8400-e29b-41d4-a716-446655440005', 'Luke', 'Luke', 42, 6, 38, 38, 'Luke 6:38', 85, false),

  -- Living a Holy Life
  ('222e8400-e29b-41d4-a716-446655440006', '1 Peter', '1 Pet', 60, 1, 15, 16, '1 Peter 1:15-16', 100, true),
  ('222e8400-e29b-41d4-a716-446655440006', 'Romans', 'Rom', 45, 12, 1, 2, 'Romans 12:1-2', 95, false),
  ('222e8400-e29b-41d4-a716-446655440006', 'Hebrews', 'Heb', 58, 12, 14, 14, 'Hebrews 12:14', 90, false)
ON CONFLICT (topic_id, book_name, chapter_start, chapter_end, verse_start, verse_end) DO NOTHING;

-- Discipleship & Growth topics
INSERT INTO topic_scripture_references (topic_id, book_name, book_abbrev, book_number, chapter_start, verse_start, verse_end, reference_text, relevance_score, is_primary_reference) VALUES
  -- What is Discipleship?
  ('444e8400-e29b-41d4-a716-446655440001', 'Matthew', 'Matt', 40, 4, 19, 19, 'Matthew 4:19', 100, true),
  ('444e8400-e29b-41d4-a716-446655440001', 'Luke', 'Luke', 42, 9, 23, 23, 'Luke 9:23', 95, false),
  ('444e8400-e29b-41d4-a716-446655440001', 'John', 'Jn', 43, 8, 31, 32, 'John 8:31-32', 90, false),

  -- The Cost of Following Jesus
  ('444e8400-e29b-41d4-a716-446655440002', 'Luke', 'Luke', 42, 14, 25, 33, 'Luke 14:25-33', 100, true),
  ('444e8400-e29b-41d4-a716-446655440002', 'Matthew', 'Matt', 40, 16, 24, 26, 'Matthew 16:24-26', 95, false),
  ('444e8400-e29b-41d4-a716-446655440002', 'Mark', 'Mark', 41, 10, 28, 31, 'Mark 10:28-31', 90, false),

  -- Bearing Fruit
  ('444e8400-e29b-41d4-a716-446655440003', 'John', 'Jn', 43, 15, 1, 8, 'John 15:1-8', 100, true),
  ('444e8400-e29b-41d4-a716-446655440003', 'Galatians', 'Gal', 48, 5, 22, 23, 'Galatians 5:22-23', 95, false),
  ('444e8400-e29b-41d4-a716-446655440003', 'Matthew', 'Matt', 40, 7, 16, 20, 'Matthew 7:16-20', 90, false),

  -- The Great Commission
  ('444e8400-e29b-41d4-a716-446655440004', 'Matthew', 'Matt', 40, 28, 18, 20, 'Matthew 28:18-20', 100, true),
  ('444e8400-e29b-41d4-a716-446655440004', 'Mark', 'Mark', 41, 16, 15, 15, 'Mark 16:15', 95, false),
  ('444e8400-e29b-41d4-a716-446655440004', 'Acts', 'Acts', 44, 1, 8, 8, 'Acts 1:8', 90, false),

  -- Mentoring Others
  ('444e8400-e29b-41d4-a716-446655440005', '2 Timothy', '2 Tim', 55, 2, 2, 2, '2 Timothy 2:2', 100, true),
  ('444e8400-e29b-41d4-a716-446655440005', 'Titus', 'Titus', 56, 2, 3, 5, 'Titus 2:3-5', 95, false),
  ('444e8400-e29b-41d4-a716-446655440005', 'Proverbs', 'Prov', 20, 27, 17, 17, 'Proverbs 27:17', 90, false)
ON CONFLICT (topic_id, book_name, chapter_start, chapter_end, verse_start, verse_end) DO NOTHING;

-- Family & Relationships topics
INSERT INTO topic_scripture_references (topic_id, book_name, book_abbrev, book_number, chapter_start, verse_start, verse_end, reference_text, relevance_score, is_primary_reference) VALUES
  -- Marriage and Faith
  ('777e8400-e29b-41d4-a716-446655440001', 'Ephesians', 'Eph', 49, 5, 22, 33, 'Ephesians 5:22-33', 100, true),
  ('777e8400-e29b-41d4-a716-446655440001', 'Genesis', 'Gen', 1, 2, 24, 24, 'Genesis 2:24', 95, false),
  ('777e8400-e29b-41d4-a716-446655440001', '1 Corinthians', '1 Cor', 46, 7, 1, 16, '1 Corinthians 7:1-16', 90, false),

  -- Raising Children in Christ
  ('777e8400-e29b-41d4-a716-446655440002', 'Proverbs', 'Prov', 20, 22, 6, 6, 'Proverbs 22:6', 100, true),
  ('777e8400-e29b-41d4-a716-446655440002', 'Deuteronomy', 'Deut', 5, 6, 4, 9, 'Deuteronomy 6:4-9', 95, false),
  ('777e8400-e29b-41d4-a716-446655440002', 'Ephesians', 'Eph', 49, 6, 4, 4, 'Ephesians 6:4', 90, false),

  -- Honoring Parents
  ('777e8400-e29b-41d4-a716-446655440003', 'Exodus', 'Exod', 2, 20, 12, 12, 'Exodus 20:12', 100, true),
  ('777e8400-e29b-41d4-a716-446655440003', 'Ephesians', 'Eph', 49, 6, 1, 3, 'Ephesians 6:1-3', 95, false),
  ('777e8400-e29b-41d4-a716-446655440003', 'Colossians', 'Col', 51, 3, 20, 20, 'Colossians 3:20', 90, false),

  -- Healthy Friendships
  ('777e8400-e29b-41d4-a716-446655440004', 'Proverbs', 'Prov', 20, 17, 17, 17, 'Proverbs 17:17', 100, true),
  ('777e8400-e29b-41d4-a716-446655440004', 'Proverbs', 'Prov', 20, 27, 17, 17, 'Proverbs 27:17', 95, false),
  ('777e8400-e29b-41d4-a716-446655440004', 'Ecclesiastes', 'Eccl', 21, 4, 9, 12, 'Ecclesiastes 4:9-12', 90, false),

  -- Resolving Conflicts Biblically
  ('777e8400-e29b-41d4-a716-446655440005', 'Matthew', 'Matt', 40, 18, 15, 17, 'Matthew 18:15-17', 100, true),
  ('777e8400-e29b-41d4-a716-446655440005', 'Romans', 'Rom', 45, 12, 18, 18, 'Romans 12:18', 95, false),
  ('777e8400-e29b-41d4-a716-446655440005', 'Proverbs', 'Prov', 20, 15, 1, 1, 'Proverbs 15:1', 90, false)
ON CONFLICT (topic_id, book_name, chapter_start, chapter_end, verse_start, verse_end) DO NOTHING;

-- Mission & Service topics
INSERT INTO topic_scripture_references (topic_id, book_name, book_abbrev, book_number, chapter_start, verse_start, verse_end, reference_text, relevance_score, is_primary_reference) VALUES
  -- Being the Light in Your Community
  ('888e8400-e29b-41d4-a716-446655440001', 'Matthew', 'Matt', 40, 5, 14, 16, 'Matthew 5:14-16', 100, true),
  ('888e8400-e29b-41d4-a716-446655440001', 'Philippians', 'Phil', 50, 2, 14, 15, 'Philippians 2:14-15', 95, false),

  -- Sharing Your Testimony
  ('888e8400-e29b-41d4-a716-446655440002', '1 Peter', '1 Pet', 60, 3, 15, 15, '1 Peter 3:15', 100, true),
  ('888e8400-e29b-41d4-a716-446655440002', 'Revelation', 'Rev', 66, 12, 11, 11, 'Revelation 12:11', 95, false),
  ('888e8400-e29b-41d4-a716-446655440002', 'Mark', 'Mark', 41, 5, 19, 19, 'Mark 5:19', 90, false),

  -- Serving the Poor and Needy
  ('888e8400-e29b-41d4-a716-446655440003', 'Matthew', 'Matt', 40, 25, 35, 40, 'Matthew 25:35-40', 100, true),
  ('888e8400-e29b-41d4-a716-446655440003', 'James', 'Jas', 59, 2, 15, 17, 'James 2:15-17', 95, false),
  ('888e8400-e29b-41d4-a716-446655440003', 'Proverbs', 'Prov', 20, 19, 17, 17, 'Proverbs 19:17', 90, false),

  -- Evangelism Made Simple
  ('888e8400-e29b-41d4-a716-446655440004', 'Romans', 'Rom', 45, 10, 14, 15, 'Romans 10:14-15', 100, true),
  ('888e8400-e29b-41d4-a716-446655440004', 'Acts', 'Acts', 44, 1, 8, 8, 'Acts 1:8', 95, false),
  ('888e8400-e29b-41d4-a716-446655440004', '2 Corinthians', '2 Cor', 47, 5, 20, 20, '2 Corinthians 5:20', 90, false),

  -- Praying for the Nations
  ('888e8400-e29b-41d4-a716-446655440005', '1 Timothy', '1 Tim', 54, 2, 1, 4, '1 Timothy 2:1-4', 100, true),
  ('888e8400-e29b-41d4-a716-446655440005', 'Psalms', 'Ps', 19, 67, 1, 7, 'Psalm 67:1-7', 95, false),
  ('888e8400-e29b-41d4-a716-446655440005', 'Revelation', 'Rev', 66, 7, 9, 10, 'Revelation 7:9-10', 90, false)
ON CONFLICT (topic_id, book_name, chapter_start, chapter_end, verse_start, verse_end) DO NOTHING;

-- Add index for full-text search on titles and descriptions
CREATE INDEX IF NOT EXISTS idx_scripture_ref_text ON topic_scripture_references USING gin(to_tsvector('english', reference_text));

-- Comments for documentation
COMMENT ON TABLE topic_scripture_references IS 'Maps study topics to their related Bible scripture references';
COMMENT ON TABLE bible_books IS 'Reference table of all 66 books of the Bible with metadata for search';
COMMENT ON FUNCTION search_topics_by_scripture IS 'Search for study topics related to a specific scripture reference';
COMMENT ON FUNCTION get_scripture_suggestions IS 'Get autocomplete suggestions for Bible book names';

COMMIT;

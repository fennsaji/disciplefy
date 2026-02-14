-- =====================================================
-- Consolidated Migration: Recommended Topics System
-- =====================================================
-- Source: Manual merge of 11 recommended topics migrations
-- Tables: 2 (recommended_topics, recommended_topics_translations)
-- Description: Curated Bible study topics with multi-language support,
--              categorization, tagging, and question-based topic types
-- =====================================================

-- Dependencies: None (standalone tables)

BEGIN;

-- =====================================================
-- SUMMARY: Migration creates recommended topics system
-- Completed 0001-0010 (42 tables), now creating 0011 with
-- recommended topics infrastructure and translations
-- =====================================================

-- =====================================================
-- PART 1: TABLES
-- =====================================================

-- Table: recommended_topics
-- Purpose: Curated Bible study topics organized by category
CREATE TABLE IF NOT EXISTS recommended_topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  input_type TEXT DEFAULT 'topic' CHECK (input_type IN ('topic', 'verse', 'question')),
  tags TEXT[] DEFAULT ARRAY[]::TEXT[],
  is_active BOOLEAN DEFAULT true,
  xp_value INTEGER DEFAULT 50,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table: recommended_topics_translations
-- Purpose: Multi-language translations for recommended topics (Hindi, Malayalam)
CREATE TABLE IF NOT EXISTS recommended_topics_translations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id UUID NOT NULL REFERENCES recommended_topics(id) ON DELETE CASCADE,
  language_code VARCHAR(5) NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(topic_id, language_code)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_recommended_topics_category ON recommended_topics(category);
CREATE INDEX IF NOT EXISTS idx_recommended_topics_display_order ON recommended_topics(display_order);
CREATE INDEX IF NOT EXISTS idx_recommended_topics_tags ON recommended_topics USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_recommended_topics_input_type ON recommended_topics(input_type);
CREATE INDEX IF NOT EXISTS idx_recommended_topics_is_active ON recommended_topics(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_recommended_topics_translations_topic_id ON recommended_topics_translations(topic_id);
CREATE INDEX IF NOT EXISTS idx_recommended_topics_translations_language ON recommended_topics_translations(language_code);

-- =====================================================
-- PART 2: FUNCTIONS
-- =====================================================

-- Function: get_recommended_topics (latest version without difficulty_level)
-- Purpose: Retrieve recommended topics with optional filters
CREATE OR REPLACE FUNCTION get_recommended_topics(
  p_category TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT NULL,
  p_offset INTEGER DEFAULT 0,
  p_language_code VARCHAR(5) DEFAULT 'en'
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  category TEXT,
  input_type TEXT,
  tags TEXT[],
  display_order INTEGER,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    CASE
      WHEN p_language_code = 'en' THEN rt.id
      ELSE COALESCE(rtt.topic_id, rt.id)
    END AS id,
    CASE
      WHEN p_language_code = 'en' THEN rt.title
      ELSE COALESCE(rtt.title, rt.title)
    END AS title,
    CASE
      WHEN p_language_code = 'en' THEN rt.description
      ELSE COALESCE(rtt.description, rt.description)
    END AS description,
    CASE
      WHEN p_language_code = 'en' THEN rt.category
      ELSE COALESCE(rtt.category, rt.category)
    END AS category,
    rt.input_type,
    rt.tags,
    rt.display_order,
    rt.created_at,
    rt.updated_at
  FROM recommended_topics rt
  LEFT JOIN recommended_topics_translations rtt
    ON rt.id = rtt.topic_id AND rtt.language_code = p_language_code
  WHERE (p_category IS NULL OR rt.category = p_category)
  ORDER BY rt.display_order ASC, rt.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Legacy wrapper for backward compatibility (with difficulty_level parameter)
CREATE OR REPLACE FUNCTION get_recommended_topics(
  p_category TEXT DEFAULT NULL,
  p_difficulty_level TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT NULL,
  p_offset INTEGER DEFAULT 0,
  p_language_code VARCHAR(5) DEFAULT 'en'
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  category TEXT,
  input_type TEXT,
  tags TEXT[],
  display_order INTEGER,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  -- Log deprecation warning
  RAISE WARNING 'get_recommended_topics: difficulty_level parameter is deprecated and ignored. Use version without difficulty_level.';

  -- Call the new function without difficulty_level
  RETURN QUERY
  SELECT * FROM get_recommended_topics(p_category, p_limit, p_offset, p_language_code);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Function: get_recommended_topics_categories
-- Purpose: Get list of unique categories with counts
CREATE OR REPLACE FUNCTION get_recommended_topics_categories(
  p_language_code VARCHAR(5) DEFAULT 'en'
)
RETURNS TABLE (
  category TEXT,
  topic_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    CASE
      WHEN p_language_code = 'en' THEN rt.category
      ELSE COALESCE(rtt.category, rt.category)
    END AS category,
    COUNT(*) AS topic_count
  FROM recommended_topics rt
  LEFT JOIN recommended_topics_translations rtt
    ON rt.id = rtt.topic_id AND rtt.language_code = p_language_code
  GROUP BY
    CASE
      WHEN p_language_code = 'en' THEN rt.category
      ELSE COALESCE(rtt.category, rt.category)
    END
  ORDER BY category ASC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Function: get_recommended_topics_count
-- Purpose: Get total count of topics with optional filters
CREATE OR REPLACE FUNCTION get_recommended_topics_count(
  p_category TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM recommended_topics
  WHERE (p_category IS NULL OR category = p_category);

  RETURN v_count;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- =====================================================
-- PART 3: ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on both tables
ALTER TABLE recommended_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE recommended_topics_translations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Allow public read access to recommended topics" ON recommended_topics;
DROP POLICY IF EXISTS "Deny anonymous writes to recommended topics" ON recommended_topics;
DROP POLICY IF EXISTS "Allow service role full access to recommended topics" ON recommended_topics;
DROP POLICY IF EXISTS "Allow public read access to topic translations" ON recommended_topics_translations;
DROP POLICY IF EXISTS "Deny anonymous writes to topic translations" ON recommended_topics_translations;
DROP POLICY IF EXISTS "Allow service role full access to topic translations" ON recommended_topics_translations;

-- Policy: Public read access to recommended topics
CREATE POLICY "Allow public read access to recommended topics"
  ON recommended_topics
  FOR SELECT
  TO public
  USING (true);

-- Policy: Deny anonymous writes to recommended topics
CREATE POLICY "Deny anonymous writes to recommended topics"
  ON recommended_topics
  FOR ALL
  TO anon
  USING (false)
  WITH CHECK (false);

-- Policy: Service role full access to recommended topics
CREATE POLICY "Allow service role full access to recommended topics"
  ON recommended_topics
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Policy: Public read access to translations
CREATE POLICY "Allow public read access to topic translations"
  ON recommended_topics_translations
  FOR SELECT
  TO public
  USING (true);

-- Policy: Deny anonymous writes to translations
CREATE POLICY "Deny anonymous writes to topic translations"
  ON recommended_topics_translations
  FOR ALL
  TO anon
  USING (false)
  WITH CHECK (false);

-- Policy: Service role full access to translations
CREATE POLICY "Allow service role full access to topic translations"
  ON recommended_topics_translations
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- PART 4: SEED DATA - RECOMMENDED TOPICS
-- =====================================================

-- NOTE: Using latest seed data from 20250819000005 (43 topics across 8 categories)
-- Enhancements applied: input_type column with 'question' type for 9 theological topics

-- ========================
-- Category: Foundations of Faith
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('111e8400-e29b-41d4-a716-446655440001', 'Who is Jesus Christ?', 'Understanding the identity of Jesus: Son of God, Savior, and Lord.', 'Foundations of Faith', ARRAY['jesus', 'son of god', 'savior', 'lord'], 1),
  ('111e8400-e29b-41d4-a716-446655440002', 'What is the Gospel?', 'Learning the good news of salvation through Jesus Christ.', 'Foundations of Faith', ARRAY['gospel', 'salvation', 'good news'], 2),
  ('111e8400-e29b-41d4-a716-446655440003', 'Assurance of Salvation', 'How believers can be confident in their salvation by faith in Christ.', 'Foundations of Faith', ARRAY['assurance', 'salvation', 'faith'], 3),
  ('111e8400-e29b-41d4-a716-446655440004', 'Why Read the Bible?', 'Understanding the importance of God''s Word for guidance and growth.', 'Foundations of Faith', ARRAY['bible', 'scripture', 'word of god'], 4),
  ('111e8400-e29b-41d4-a716-446655440005', 'Importance of Prayer', 'Discovering prayer as communication with God and a source of strength.', 'Foundations of Faith', ARRAY['prayer', 'communication with god', 'faith'], 5),
  ('111e8400-e29b-41d4-a716-446655440006', 'The Role of the Holy Spirit', 'Learning how the Holy Spirit guides, empowers, and transforms believers.', 'Foundations of Faith', ARRAY['holy spirit', 'guidance', 'empowerment'], 6)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Christian Life
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('222e8400-e29b-41d4-a716-446655440001', 'Walking with God Daily', 'Practical steps for building a consistent walk with God every day.', 'Christian Life', ARRAY['daily walk', 'faith', 'discipline'], 1),
  ('222e8400-e29b-41d4-a716-446655440002', 'Overcoming Temptation', 'How to resist sin and rely on God''s strength in moments of weakness.', 'Christian Life', ARRAY['temptation', 'sin', 'victory'], 2),
  ('222e8400-e29b-41d4-a716-446655440003', 'Forgiveness and Reconciliation', 'Learning to forgive others and seek peace in relationships.', 'Christian Life', ARRAY['forgiveness', 'reconciliation', 'peace'], 3),
  ('222e8400-e29b-41d4-a716-446655440004', 'The Importance of Fellowship', 'Why believers need community, encouragement, and accountability.', 'Christian Life', ARRAY['fellowship', 'community', 'church'], 4),
  ('222e8400-e29b-41d4-a716-446655440005', 'Giving and Generosity', 'Understanding biblical giving and living with a generous heart.', 'Christian Life', ARRAY['giving', 'tithing', 'generosity'], 5),
  ('222e8400-e29b-41d4-a716-446655440006', 'Living a Holy Life', 'God''s call to holiness in thought, word, and action.', 'Christian Life', ARRAY['holiness', 'purity', 'obedience'], 6)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Church & Community
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('333e8400-e29b-41d4-a716-446655440001', 'What is the Church?', 'Understanding the biblical meaning and purpose of the church.', 'Church & Community', ARRAY['church', 'body of christ', 'community'], 1),
  ('333e8400-e29b-41d4-a716-446655440002', 'Why Fellowship Matters', 'Learning why being connected to other believers is vital.', 'Church & Community', ARRAY['fellowship', 'unity', 'believers'], 2),
  ('333e8400-e29b-41d4-a716-446655440003', 'Serving in the Church', 'Discovering how every believer can serve with their gifts.', 'Church & Community', ARRAY['service', 'ministry', 'spiritual gifts'], 3),
  ('333e8400-e29b-41d4-a716-446655440004', 'Unity in Christ', 'The importance of unity and love in the body of Christ.', 'Church & Community', ARRAY['unity', 'love', 'body of christ'], 4),
  ('333e8400-e29b-41d4-a716-446655440005', 'Spiritual Gifts and Their Use', 'Identifying and using spiritual gifts to build up the church.', 'Church & Community', ARRAY['spiritual gifts', 'service', 'church'], 5)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Discipleship & Growth
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('444e8400-e29b-41d4-a716-446655440001', 'What is Discipleship?', 'Understanding the call to follow Jesus and grow in His likeness.', 'Discipleship & Growth', ARRAY['discipleship', 'follow jesus', 'growth'], 1),
  ('444e8400-e29b-41d4-a716-446655440002', 'The Cost of Following Jesus', 'Learning what it means to deny self and live fully for Christ.', 'Discipleship & Growth', ARRAY['cost', 'sacrifice', 'following jesus'], 2),
  ('444e8400-e29b-41d4-a716-446655440003', 'Bearing Fruit', 'Exploring what it means to bear spiritual fruit as a disciple.', 'Discipleship & Growth', ARRAY['fruit', 'spiritual growth', 'discipleship'], 3),
  ('444e8400-e29b-41d4-a716-446655440004', 'The Great Commission', 'Understanding Jesus'' command to make disciples of all nations.', 'Discipleship & Growth', ARRAY['great commission', 'evangelism', 'discipleship'], 4),
  ('444e8400-e29b-41d4-a716-446655440005', 'Mentoring Others', 'How to guide and encourage others in their faith journey.', 'Discipleship & Growth', ARRAY['mentorship', 'discipleship', 'growth'], 5)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Spiritual Disciplines
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('555e8400-e29b-41d4-a716-446655440001', 'Daily Devotions', 'Building the habit of daily time with God in prayer and the Word.', 'Spiritual Disciplines', ARRAY['devotion', 'quiet time', 'discipline'], 1),
  ('555e8400-e29b-41d4-a716-446655440002', 'Fasting and Prayer', 'Discovering the power of fasting and prayer in seeking God''s will.', 'Spiritual Disciplines', ARRAY['fasting', 'prayer', 'discipline'], 2),
  ('555e8400-e29b-41d4-a716-446655440003', 'Worship as a Lifestyle', 'Learning how worship is more than songs—it is a way of living.', 'Spiritual Disciplines', ARRAY['worship', 'lifestyle', 'obedience'], 3),
  ('555e8400-e29b-41d4-a716-446655440004', 'Meditation on God''s Word', 'How to reflect deeply on Scripture for transformation.', 'Spiritual Disciplines', ARRAY['meditation', 'scripture', 'word of god'], 4),
  ('555e8400-e29b-41d4-a716-446655440005', 'Journaling Your Walk with God', 'Using journaling as a tool to track growth and record prayers.', 'Spiritual Disciplines', ARRAY['journaling', 'prayer', 'growth'], 5)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Apologetics & Defense of Faith
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('666e8400-e29b-41d4-a716-446655440001', 'Why We Believe in One God', 'Explaining the biblical foundation of monotheism.', 'Apologetics & Defense of Faith', ARRAY['one god', 'monotheism', 'faith'], 1),
  ('666e8400-e29b-41d4-a716-446655440002', 'The Uniqueness of Jesus', 'Why Jesus is the only way of salvation among many religions.', 'Apologetics & Defense of Faith', ARRAY['jesus', 'salvation', 'uniqueness'], 2),
  ('666e8400-e29b-41d4-a716-446655440003', 'Is the Bible Reliable?', 'Evidence for the trustworthiness of the Scriptures.', 'Apologetics & Defense of Faith', ARRAY['bible', 'scripture', 'trustworthy'], 3),
  ('666e8400-e29b-41d4-a716-446655440004', 'Responding to Common Questions from Other Faiths', 'Equipping believers to answer questions about Christianity with grace.', 'Apologetics & Defense of Faith', ARRAY['apologetics', 'faith questions', 'dialogue'], 4),
  ('666e8400-e29b-41d4-a716-446655440005', 'Standing Firm in Persecution', 'Encouragement to stay strong in faith under opposition.', 'Apologetics & Defense of Faith', ARRAY['persecution', 'faith', 'courage'], 5)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Family & Relationships
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('777e8400-e29b-41d4-a716-446655440001', 'Marriage and Faith', 'Building a Christ-centered marriage.', 'Family & Relationships', ARRAY['marriage', 'faith', 'family'], 1),
  ('777e8400-e29b-41d4-a716-446655440002', 'Raising Children in Christ', 'Teaching children to follow Jesus from a young age.', 'Family & Relationships', ARRAY['children', 'parenting', 'faith'], 2),
  ('777e8400-e29b-41d4-a716-446655440003', 'Honoring Parents', 'Understanding God''s command to honor father and mother.', 'Family & Relationships', ARRAY['parents', 'honor', 'obedience'], 3),
  ('777e8400-e29b-41d4-a716-446655440004', 'Healthy Friendships', 'Building Christ-centered and supportive friendships.', 'Family & Relationships', ARRAY['friends', 'relationships', 'faith'], 4),
  ('777e8400-e29b-41d4-a716-446655440005', 'Resolving Conflicts Biblically', 'Learning to handle disagreements with love and wisdom.', 'Family & Relationships', ARRAY['conflict', 'forgiveness', 'relationships'], 5)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Mission & Service
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('888e8400-e29b-41d4-a716-446655440001', 'Being the Light in Your Community', 'Practical ways to reflect Christ in everyday life.', 'Mission & Service', ARRAY['light', 'witness', 'community'], 1),
  ('888e8400-e29b-41d4-a716-446655440002', 'Sharing Your Testimony', 'Learning how to tell others what Jesus has done in your life.', 'Mission & Service', ARRAY['testimony', 'evangelism', 'faith'], 2),
  ('888e8400-e29b-41d4-a716-446655440003', 'Serving the Poor and Needy', 'Understanding God''s heart for the poor and how to serve them.', 'Mission & Service', ARRAY['service', 'poor', 'justice'], 3),
  ('888e8400-e29b-41d4-a716-446655440004', 'Evangelism Made Simple', 'Practical steps to share the Gospel with boldness and love.', 'Mission & Service', ARRAY['evangelism', 'gospel', 'mission'], 4),
  ('888e8400-e29b-41d4-a716-446655440005', 'Praying for the Nations', 'Joining God''s mission through intercession for the world.', 'Mission & Service', ARRAY['prayer', 'missions', 'nations'], 5)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Apply input_type='question' for theological question topics
-- (From 20260106000003_add_input_type_to_recommended_topics.sql)
-- ========================
UPDATE recommended_topics
SET input_type = 'question'
WHERE id IN (
  '111e8400-e29b-41d4-a716-446655440001', -- Who is Jesus Christ?
  '111e8400-e29b-41d4-a716-446655440002', -- What is the Gospel?
  '111e8400-e29b-41d4-a716-446655440004', -- Why Read the Bible?
  '333e8400-e29b-41d4-a716-446655440001', -- What is the Church?
  '333e8400-e29b-41d4-a716-446655440002', -- Why Fellowship Matters
  '444e8400-e29b-41d4-a716-446655440001', -- What is Discipleship?
  '666e8400-e29b-41d4-a716-446655440001', -- Why We Believe in One God
  '666e8400-e29b-41d4-a716-446655440003', -- Is the Bible Reliable?
  '666e8400-e29b-41d4-a716-446655440004'  -- Responding to Common Questions from Other Faiths
);

-- =====================================================
-- PART 5: SEED DATA - TRANSLATIONS (Hindi + Malayalam)
-- =====================================================

-- ========================
-- Category: Foundations of Faith (विश्वास की नींव / വിശ്വാസത്തിന്റെ അടിത്തറകൾ)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('111e8400-e29b-41d4-a716-446655440001', 'hi', 'यीशु मसीह कौन हैं?', 'यीशु की पहचान को समझना: परमेश्वर का पुत्र, उद्धारकर्ता और प्रभु।', 'विश्वास की नींव'),
  ('111e8400-e29b-41d4-a716-446655440002', 'hi', 'सुसमाचार क्या है?', 'यीशु मसीह के माध्यम से उद्धार का शुभ संदेश सीखना।', 'विश्वास की नींव'),
  ('111e8400-e29b-41d4-a716-446655440003', 'hi', 'उद्धार का विश्वास', 'विश्वासी कैसे मसीह में विश्वास द्वारा अपने उद्धार में आश्वस्त हो सकते हैं।', 'विश्वास की नींव'),
  ('111e8400-e29b-41d4-a716-446655440004', 'hi', 'बाइबिल क्यों पढ़ें?', 'मार्गदर्शन और विकास के लिए परमेश्वर के वचन के महत्व को समझना।', 'विश्वास की नींव'),
  ('111e8400-e29b-41d4-a716-446655440005', 'hi', 'प्रार्थना का महत्व', 'प्रार्थना को परमेश्वर के साथ संवाद और शक्ति के स्रोत के रूप में खोजना।', 'विश्वास की नींव'),
  ('111e8400-e29b-41d4-a716-446655440006', 'hi', 'पवित्र आत्मा की भूमिका', 'सीखना कि पवित्र आत्मा विश्वासियों का मार्गदर्शन, सशक्तिकरण और परिवर्तन कैसे करता है।', 'विश्वास की नींव')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('111e8400-e29b-41d4-a716-446655440001', 'ml', 'യേശുക്രിസ്തു ആരാണ്?', 'യേശുവിന്റെ ഐഡന്റിറ്റി മനസ്സിലാക്കുക: ദൈവപുത്രൻ, രക്ഷകൻ, കർത്താവ്.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('111e8400-e29b-41d4-a716-446655440002', 'ml', 'സുവിശേഷം എന്താണ്?', 'യേശുക്രിസ്തുവിലൂടെയുള്ള രക്ഷയുടെ സന്തോഷവാർത്ത പഠിക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('111e8400-e29b-41d4-a716-446655440003', 'ml', 'രക്ഷയുടെ ഉറപ്പ്', 'ക്രിസ്തുവിലുള്ള വിശ്വാസത്താൽ വിശ്വാസികൾക്ക് അവരുടെ രക്ഷയിൽ എങ്ങനെ ആത്മവിശ്വാസം ഉണ്ടാകാം.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('111e8400-e29b-41d4-a716-446655440004', 'ml', 'ബൈബിൾ എന്തിനു വായിക്കണം?', 'മാർഗനിർദ്ദേശത്തിനും വളർച്ചയ്ക്കും ദൈവവചനത്തിന്റെ പ്രാധാന്യം മനസ്സിലാക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('111e8400-e29b-41d4-a716-446655440005', 'ml', 'പ്രാർത്ഥനയുടെ പ്രാധാന്യം', 'ദൈവവുമായുള്ള ആശയവിനിമയമെന്ന നിലയിലും ശക്തിയുടെ സ്രോതസ്സെന്ന നിലയിലും പ്രാർത്ഥനയെ കണ്ടെത്തുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('111e8400-e29b-41d4-a716-446655440006', 'ml', 'പരിശുദ്ധാത്മാവിന്റെ പങ്ക്', 'പരിശുദ്ധാത്മാവ് വിശ്വാസികളെ എങ്ങനെ നയിക്കുകയും ശക്തീകരിക്കുകയും പരിവർത്തനം ചെയ്യുകയും ചെയ്യുന്നുവെന്ന് പഠിക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Christian Life (मसीही जीवन / ക്രൈസ്തവ ജീവിതം)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('222e8400-e29b-41d4-a716-446655440001', 'hi', 'परमेश्वर के साथ दैनिक चलना', 'हर दिन परमेश्वर के साथ लगातार चलने के लिए व्यावहारिक कदम।', 'मसीही जीवन'),
  ('222e8400-e29b-41d4-a716-446655440002', 'hi', 'प्रलोभन पर विजय', 'पाप का विरोध कैसे करें और कमजोरी के क्षणों में परमेश्वर की शक्ति पर निर्भर रहें।', 'मसीही जीवन'),
  ('222e8400-e29b-41d4-a716-446655440003', 'hi', 'क्षमा और सुलह', 'दूसरों को क्षमा करना और रिश्तों में शांति की तलाश करना सीखना।', 'मसीही जीवन'),
  ('222e8400-e29b-41d4-a716-446655440004', 'hi', 'संगति का महत्व', 'विश्वासियों को समुदाय, प्रोत्साहन और जवाबदेही की आवश्यकता क्यों है।', 'मसीही जीवन'),
  ('222e8400-e29b-41d4-a716-446655440005', 'hi', 'देना और उदारता', 'बाइबिल के अनुसार देना और उदार हृदय के साथ जीना समझना।', 'मसीही जीवन'),
  ('222e8400-e29b-41d4-a716-446655440006', 'hi', 'पवित्र जीवन जीना', 'विचार, वचन और कर्म में पवित्रता के लिए परमेश्वर का आह्वान।', 'मसीही जीवन')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('222e8400-e29b-41d4-a716-446655440001', 'ml', 'ദൈവത്തോടൊപ്പം ദിവസേന നടക്കുക', 'എല്ലാ ദിവസവും ദൈവവുമായി സ്ഥിരമായ നടത്തം ഉണ്ടാക്കുന്നതിനുള്ള പ്രായോഗിക നടപടികൾ.', 'ക്രൈസ്തവ ജീവിതം'),
  ('222e8400-e29b-41d4-a716-446655440002', 'ml', 'പ്രലോഭനത്തെ അതിജീവിക്കുക', 'പാപത്തെ എങ്ങനെ എതിർക്കാമെന്നും ബലഹീനതയുടെ നിമിഷങ്ങളിൽ ദൈവത്തിന്റെ ശക്തിയിൽ ആശ്രയിക്കാമെന്നും.', 'ക്രൈസ്തവ ജീവിതം'),
  ('222e8400-e29b-41d4-a716-446655440003', 'ml', 'ക്ഷമയും അനുരഞ്ജനവും', 'മറ്റുള്ളവരെ ക്ഷമിക്കാനും ബന്ധങ്ങളിൽ സമാധാനം തേടാനും പഠിക്കുക.', 'ക്രൈസ്തവ ജീവിതം'),
  ('222e8400-e29b-41d4-a716-446655440004', 'ml', 'സംഗമത്തിന്റെ പ്രാധാന്യം', 'വിശ്വാസികൾക്ക് സമൂഹവും പ്രോത്സാഹനവും ഉത്തരവാദിത്തവും എന്തുകൊണ്ട് ആവശ്യമാണ്.', 'ക്രൈസ്തവ ജീവിതം'),
  ('222e8400-e29b-41d4-a716-446655440005', 'ml', 'നൽകലും ഔദാര്യവും', 'ബൈബിളനുസരിച്ച് നൽകലും ഔദാര്യമുള്ള ഹൃദയത്തോടെ ജീവിക്കലും മനസ്സിലാക്കുക.', 'ക്രൈസ്തവ ജീവിതം'),
  ('222e8400-e29b-41d4-a716-446655440006', 'ml', 'പരിശുദ്ധമായ ജീവിതം നയിക്കുക', 'ചിന്തയിലും വാക്കിലും പ്രവൃത്തിയിലും പരിശുദ്ധിക്കായി ദൈവത്തിന്റെ ആഹ്വാനം.', 'ക്രൈസ്തവ ജീവിതം')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Church & Community (कलीसिया और समुदाय / സഭയും സമൂഹവും)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('333e8400-e29b-41d4-a716-446655440001', 'hi', 'कलीसिया क्या है?', 'कलीसिया के बाइबिल अर्थ और उद्देश्य को समझना।', 'कलीसिया और समुदाय'),
  ('333e8400-e29b-41d4-a716-446655440002', 'hi', 'संगति क्यों मायने रखती है', 'अन्य विश्वासियों से जुड़े रहना क्यों महत्वपूर्ण है, यह सीखना।', 'कलीसिया और समुदाय'),
  ('333e8400-e29b-41d4-a716-446655440003', 'hi', 'कलीसिया में सेवा', 'खोजना कि प्रत्येक विश्वासी अपने वरदानों से कैसे सेवा कर सकता है।', 'कलीसिया और समुदाय'),
  ('333e8400-e29b-41d4-a716-446655440004', 'hi', 'मसीह में एकता', 'मसीह की देह में एकता और प्रेम का महत्व।', 'कलीसिया और समुदाय'),
  ('333e8400-e29b-41d4-a716-446655440005', 'hi', 'आत्मिक वरदान और उनका उपयोग', 'कलीसिया को बनाने के लिए आत्मिक वरदानों की पहचान और उपयोग करना।', 'कलीसिया और समुदाय')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('333e8400-e29b-41d4-a716-446655440001', 'ml', 'സഭ എന്താണ്?', 'സഭയുടെ ബൈബിളധിഷ്ഠിതമായ അർത്ഥവും ഉദ്ദേശ്യവും മനസ്സിലാക്കുക.', 'സഭയും സമൂഹവും'),
  ('333e8400-e29b-41d4-a716-446655440002', 'ml', 'സംഗമം എന്തുകൊണ്ട് പ്രധാനമാണ്', 'മറ്റ് വിശ്വാസികളുമായി ബന്ധപ്പെട്ടിരിക്കുന്നത് എന്തുകൊണ്ട് അത്യാവശ്യമാണെന്ന് പഠിക്കുക.', 'സഭയും സമൂഹവും'),
  ('333e8400-e29b-41d4-a716-446655440003', 'ml', 'സഭയിൽ സേവനം', 'ഓരോ വിശ്വാസിക്കും അവരുടെ വരദാനങ്ങൾ കൊണ്ട് എങ്ങനെ സേവിക്കാമെന്ന് കണ്ടെത്തുക.', 'സഭയും സമൂഹവും'),
  ('333e8400-e29b-41d4-a716-446655440004', 'ml', 'ക്രിസ്തുവിൽ ഐക്യം', 'ക്രിസ്തുവിന്റെ ശരീരത്തിൽ ഐക്യത്തിന്റെയും സ്നേഹത്തിന്റെയും പ്രാധാന്യം.', 'സഭയും സമൂഹവും'),
  ('333e8400-e29b-41d4-a716-446655440005', 'ml', 'ആത്മീയ വരദാനങ്ങളും അവയുടെ ഉപയോഗവും', 'സഭയെ പടുത്തുയർത്താൻ ആത്മീയ വരദാനങ്ങൾ തിരിച്ചറിയുകയും ഉപയോഗിക്കുകയും ചെയ്യുക.', 'സഭയും സമൂഹവും')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Discipleship & Growth (शिष्यत्व और विकास / ശിഷ്യത്വവും വളർച്ചയും)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('444e8400-e29b-41d4-a716-446655440001', 'hi', 'शिष्यत्व क्या है?', 'यीशु का अनुसरण करने और उसके स्वरूप में बढ़ने के आह्वान को समझना।', 'शिष्यत्व और विकास'),
  ('444e8400-e29b-41d4-a716-446655440002', 'hi', 'यीशु का अनुसरण करने की कीमत', 'सीखना कि स्वयं को इनकार करने और मसीह के लिए पूर्णतः जीने का क्या अर्थ है।', 'शिष्यत्व और विकास'),
  ('444e8400-e29b-41d4-a716-446655440003', 'hi', 'फल लाना', 'एक शिष्य के रूप में आत्मिक फल लाने का क्या अर्थ है, यह जानना।', 'शिष्यत्व और विकास'),
  ('444e8400-e29b-41d4-a716-446655440004', 'hi', 'महान आज्ञा', 'सभी राष्ट्रों के शिष्य बनाने की यीशु की आज्ञा को समझना।', 'शिष्यत्व और विकास'),
  ('444e8400-e29b-41d4-a716-446655440005', 'hi', 'दूसरों का मार्गदर्शन', 'विश्वास यात्रा में दूसरों का मार्गदर्शन और प्रोत्साहन कैसे करें।', 'शिष्यत्व और विकास')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('444e8400-e29b-41d4-a716-446655440001', 'ml', 'ശിഷ്യത്വം എന്താണ്?', 'യേശുവിനെ അനുഗമിക്കാനും അവന്റെ സാദൃശ്യത്തിൽ വളരാനുമുള്ള ആഹ്വാനം മനസ്സിലാക്കുക.', 'ശിഷ്യത്വവും വളർച്ചയും'),
  ('444e8400-e29b-41d4-a716-446655440002', 'ml', 'യേശുവിനെ അനുഗമിക്കുന്നതിന്റെ വില', 'സ്വയം നിഷേധിക്കുകയും ക്രിസ്തുവിനായി പൂർണ്ണമായി ജീവിക്കുകയും ചെയ്യുക എന്നതിന്റെ അർത്ഥം പഠിക്കുക.', 'ശിഷ്യത്വവും വളർച്ചയും'),
  ('444e8400-e29b-41d4-a716-446655440003', 'ml', 'ഫലം കായ്ക്കൽ', 'ഒരു ശിഷ്യനെന്ന നിലയിൽ ആത്മീയ ഫലം കായ്ക്കുക എന്നതിന്റെ അർത്ഥം പര്യവേക്ഷണം ചെയ്യുക.', 'ശിഷ്യത്വവും വളർച്ചയും'),
  ('444e8400-e29b-41d4-a716-446655440004', 'ml', 'മഹാനിയോഗം', 'എല്ലാ രാഷ്ട്രങ്ങളെയും ശിഷ്യന്മാരാക്കാനുള്ള യേശുവിന്റെ കൽപ്പന മനസ്സിലാക്കുക.', 'ശിഷ്യത്വവും വളർച്ചയും'),
  ('444e8400-e29b-41d4-a716-446655440005', 'ml', 'മറ്റുള്ളവരെ നയിക്കുക', 'വിശ്വാസയാത്രയിൽ മറ്റുള്ളവരെ എങ്ങനെ നയിക്കാമെന്നും പ്രോത്സാഹിപ്പിക്കാമെന്നും.', 'ശിഷ്യത്വവും വളർച്ചയും')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Spiritual Disciplines (आत्मिक अनुशासन / ആത്മീയ അനുശാസനം)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('555e8400-e29b-41d4-a716-446655440001', 'hi', 'दैनिक भक्ति', 'प्रार्थना और वचन में परमेश्वर के साथ दैनिक समय की आदत बनाना।', 'आत्मिक अनुशासन'),
  ('555e8400-e29b-41d4-a716-446655440002', 'hi', 'उपवास और प्रार्थना', 'परमेश्वर की इच्छा जानने में उपवास और प्रार्थना की शक्ति को खोजना।', 'आत्मिक अनुशासन'),
  ('555e8400-e29b-41d4-a716-446655440003', 'hi', 'जीवनशैली के रूप में आराधना', 'सीखना कि आराधना केवल गीत से अधिक है—यह जीने का एक तरीका है।', 'आत्मिक अनुशासन'),
  ('555e8400-e29b-41d4-a716-446655440004', 'hi', 'परमेश्वर के वचन पर मनन', 'परिवर्तन के लिए पवित्रशास्त्र पर गहराई से विचार कैसे करें।', 'आत्मिक अनुशासन'),
  ('555e8400-e29b-41d4-a716-446655440005', 'hi', 'परमेश्वर के साथ चलने की डायरी', 'विकास को ट्रैक करने और प्रार्थनाओं को रिकॉर्ड करने के लिए डायरी का उपयोग करना।', 'आत्मिक अनुशासन')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('555e8400-e29b-41d4-a716-446655440001', 'ml', 'ദിവസേനയുള്ള ഭക്തി', 'പ്രാർത്ഥനയിലും വചനത്തിലും ദൈവവുമായുള്ള ദിവസേനയുള്ള സമയത്തിന്റെ ശീലം വളർത്തുക.', 'ആത്മീയ അനുശാസനം'),
  ('555e8400-e29b-41d4-a716-446655440002', 'ml', 'ഉപവാസവും പ്രാർത്ഥനയും', 'ദൈവത്തിന്റെ ഇഷ്ടം അന്വേഷിക്കുന്നതിൽ ഉപവാസത്തിന്റെയും പ്രാർത്ഥനയുടെയും ശക്തി കണ്ടെത്തുക.', 'ആത്മീയ അനുശാസനം'),
  ('555e8400-e29b-41d4-a716-446655440003', 'ml', 'ജീവിതരീതിയെന്ന നിലയിൽ ആരാധന', 'ആരാധന പാട്ടുകൾ മാത്രമല്ല—അത് ജീവിക്കുന്നതിന്റെ ഒരു മാർഗ്ഗമാണെന്ന് പഠിക്കുക.', 'ആത്മീയ അനുശാസനം'),
  ('555e8400-e29b-41d4-a716-446655440004', 'ml', 'ദൈവവചനത്തിൽ ധ്യാനിക്കൽ', 'പരിവർത്തനത്തിനായി തിരുവെഴുത്തുകളിൽ ആഴത്തിൽ പ്രതിഫലിപ്പിക്കുന്നത് എങ്ങനെ.', 'ആത്മീയ അനുശാസനം'),
  ('555e8400-e29b-41d4-a716-446655440005', 'ml', 'ദൈവവുമായുള്ള നിങ്ങളുടെ നടത്തം ജേർണലിംഗ് ചെയ്യുക', 'വളർച്ച ട്രാക്ക് ചെയ്യാനും പ്രാർത്ഥനകൾ റെക്കോർഡ് ചെയ്യാനും ജേർണലിംഗ് ഒരു ഉപകരണമായി ഉപയോഗിക്കുക.', 'ആത്മീയ അനുശാസനം')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Apologetics & Defense of Faith (धर्मशास्त्र और विश्वास की रक्षा / ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('666e8400-e29b-41d4-a716-446655440001', 'hi', 'हम एक ईश्वर में विश्वास क्यों करते हैं', 'एकेश्वरवाद की बाइबिल नींव को समझाना।', 'धर्मशास्त्र और विश्वास की रक्षा'),
  ('666e8400-e29b-41d4-a716-446655440002', 'hi', 'यीशु की विशिष्टता', 'कई धर्मों के बीच यीशु ही उद्धार का एकमात्र मार्ग क्यों है।', 'धर्मशास्त्र और विश्वास की रक्षा'),
  ('666e8400-e29b-41d4-a716-446655440003', 'hi', 'क्या बाइबिल विश्वसनीय है?', 'पवित्रशास्त्र की विश्वसनीयता के लिए प्रमाण।', 'धर्मशास्त्र और विश्वास की रक्षा'),
  ('666e8400-e29b-41d4-a716-446655440004', 'hi', 'अन्य धर्मों से सामान्य प्रश्नों का जवाब', 'विश्वासियों को अनुग्रह के साथ ईसाई धर्म के बारे में प्रश्नों के उत्तर देने के लिए तैयार करना।', 'धर्मशास्त्र और विश्वास की रक्षा'),
  ('666e8400-e29b-41d4-a716-446655440005', 'hi', 'उत्पीड़न में दृढ़ रहना', 'विरोध में विश्वास में मजबूत रहने के लिए प्रोत्साहन।', 'धर्मशास्त्र और विश्वास की रक्षा')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('666e8400-e29b-41d4-a716-446655440001', 'ml', 'നമ്മൾ ഒരു ദൈവത്തിൽ വിശ്വസിക്കുന്നത് എന്തുകൊണ്ട്', 'ഏകദൈവാരാധനയുടെ ബൈബിളാധിഷ്ഠിത അടിത്തറ വിശദീകരിക്കുക.', 'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും'),
  ('666e8400-e29b-41d4-a716-446655440002', 'ml', 'യേശുവിന്റെ അനന്യത', 'നിരവധി മതങ്ങളിൽ യേശു മാത്രമാണ് രക്ഷയുടെ ഏക മാർഗ്ഗമായിട്ടുള്ളത് എന്തുകൊണ്ട്.', 'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും'),
  ('666e8400-e29b-41d4-a716-446655440003', 'ml', 'ബൈബിൾ വിശ്വാസയോഗ്യമാണോ?', 'തിരുവെഴുത്തുകളുടെ വിശ്വാസ്യതയ്ക്കുള്ള തെളിവ്.', 'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും'),
  ('666e8400-e29b-41d4-a716-446655440004', 'ml', 'മറ്റു വിശ്വാസങ്ങളിൽ നിന്നുള്ള സാധാരണ ചോദ്യങ്ങൾക്ക് പ്രതികരിക്കുക', 'ക്രിസ്തുമതത്തെക്കുറിച്ചുള്ള ചോദ്യങ്ങൾക്ക് കൃപയോടെ ഉത്തരം നൽകാൻ വിശ്വാസികളെ സജ്ജമാക്കുക.', 'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും'),
  ('666e8400-e29b-41d4-a716-446655440005', 'ml', 'ഉപദ്രവത്തിൽ ഉറച്ചുനിൽക്കുക', 'എതിർപ്പിൽ വിശ്വാസത്തിൽ ശക്തരായിരിക്കാനുള്ള പ്രോത്സാഹനം.', 'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Family & Relationships (परिवार और रिश्ते / കുടുംബവും ബന്ധങ്ങളും)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('777e8400-e29b-41d4-a716-446655440001', 'hi', 'विवाह और विश्वास', 'मसीह-केंद्रित विवाह का निर्माण।', 'परिवार और रिश्ते'),
  ('777e8400-e29b-41d4-a716-446655440002', 'hi', 'बच्चों को मसीह में पालना', 'बच्चों को कम उम्र से यीशु का अनुसरण करना सिखाना।', 'परिवार और रिश्ते'),
  ('777e8400-e29b-41d4-a716-446655440003', 'hi', 'माता-पिता का सम्मान', 'माता और पिता का सम्मान करने की परमेश्वर की आज्ञा को समझना।', 'परिवार और रिश्ते'),
  ('777e8400-e29b-41d4-a716-446655440004', 'hi', 'स्वस्थ मित्रता', 'मसीह-केंद्रित और सहायक मित्रता का निर्माण।', 'परिवार और रिश्ते'),
  ('777e8400-e29b-41d4-a716-446655440005', 'hi', 'संघर्षों को बाइबिल के अनुसार हल करना', 'प्रेम और ज्ञान के साथ असहमतियों को कैसे संभालना है, यह सीखना।', 'परिवार और रिश्ते')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('777e8400-e29b-41d4-a716-446655440001', 'ml', 'വിവാഹവും വിശ്വാസവും', 'ക്രിസ്തു കേന്ദ്രീകൃത വിവാഹം കെട്ടിപ്പടുക്കുക.', 'കുടുംബവും ബന്ധങ്ങളും'),
  ('777e8400-e29b-41d4-a716-446655440002', 'ml', 'കുട്ടികളെ ക്രിസ്തുവിൽ വളർത്തുക', 'ചെറുപ്പത്തിൽ തന്നെ യേശുവിനെ അനുഗമിക്കാൻ കുട്ടികളെ പഠിപ്പിക്കുക.', 'കുടുംബവും ബന്ധങ്ങളും'),
  ('777e8400-e29b-41d4-a716-446655440003', 'ml', 'മാതാപിതാക്കളെ ബഹുമാനിക്കുക', 'അമ്മയെയും അച്ഛനെയും ബഹുമാനിക്കാനുള്ള ദൈവത്തിന്റെ കൽപ്പന മനസ്സിലാക്കുക.', 'കുടുംബവും ബന്ധങ്ങളും'),
  ('777e8400-e29b-41d4-a716-446655440004', 'ml', 'ആരോഗ്യകരമായ സൗഹൃദങ്ങൾ', 'ക്രിസ്തു കേന്ദ്രീകൃതവും പിന്തുണയ്ക്കുന്നതുമായ സൗഹൃദങ്ങൾ കെട്ടിപ്പടുക്കുക.', 'കുടുംബവും ബന്ധങ്ങളും'),
  ('777e8400-e29b-41d4-a716-446655440005', 'ml', 'സംഘർഷങ്ങൾ ബൈബിൾ അനുസരിച്ച് പരിഹരിക്കുക', 'സ്നേഹവും ജ്ഞാനവും കൊണ്ട് അഭിപ്രായവ്യത്യാസങ്ങൾ കൈകാര്യം ചെയ്യാൻ പഠിക്കുക.', 'കുടുംബവും ബന്ധങ്ങളും')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Mission & Service (मिशन और सेवा / മിഷനും സേവനവും)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('888e8400-e29b-41d4-a716-446655440001', 'hi', 'अपने समुदाय में ज्योति बनना', 'रोज़मर्रा की ज़िंदगी में मसीह को प्रतिबिंबित करने के व्यावहारिक तरीके।', 'मिशन और सेवा'),
  ('888e8400-e29b-41d4-a716-446655440002', 'hi', 'अपनी गवाही साझा करना', 'दूसरों को बताना सीखना कि यीशु ने आपके जीवन में क्या किया है।', 'मिशन और सेवा'),
  ('888e8400-e29b-41d4-a716-446655440003', 'hi', 'गरीबों और ज़रूरतमंदों की सेवा', 'गरीबों के लिए परमेश्वर के हृदय को समझना और उनकी सेवा कैसे करें।', 'मिशन और सेवा'),
  ('888e8400-e29b-41d4-a716-446655440004', 'hi', 'सरल बनाया गया प्रचार', 'साहस और प्रेम के साथ सुसमाचार साझा करने के व्यावहारिक कदम।', 'मिशन और सेवा'),
  ('888e8400-e29b-41d4-a716-446655440005', 'hi', 'राष्ट्रों के लिए प्रार्थना', 'दुनिया के लिए मध्यस्थता के माध्यम से परमेश्वर के मिशन से जुड़ना।', 'मिशन और सेवा')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('888e8400-e29b-41d4-a716-446655440001', 'ml', 'നിങ്ങളുടെ സമൂഹത്തിൽ വെളിച്ചമായിരിക്കുക', 'ദൈനംദിന ജീവിതത്തിൽ ക്രിസ്തുവിനെ പ്രതിഫലിപ്പിക്കാനുള്ള പ്രായോഗിക മാർഗ്ഗങ്ങൾ.', 'മിഷനും സേവനവും'),
  ('888e8400-e29b-41d4-a716-446655440002', 'ml', 'നിങ്ങളുടെ സാക്ഷ്യം പങ്കുവെക്കുക', 'യേശു നിങ്ങളുടെ ജീവിതത്തിൽ ചെയ്തത് മറ്റുള്ളവരോട് എങ്ങനെ പറയാമെന്ന് പഠിക്കുക.', 'മിഷനും സേവനവും'),
  ('888e8400-e29b-41d4-a716-446655440003', 'ml', 'ദരിദ്രർക്കും അവശരായവർക്കും സേവനം ചെയ്യുക', 'ദരിദ്രർക്കായുള്ള ദൈവത്തിന്റെ ഹൃദയം മനസ്സിലാക്കുകയും അവരെ എങ്ങനെ സേവിക്കാമെന്നും.', 'മിഷനും സേവനവും'),
  ('888e8400-e29b-41d4-a716-446655440004', 'ml', 'ലളിതമാക്കിയ സുവിശേഷവൽക്കരണം', 'ധൈര്യത്തോടും സ്നേഹത്തോടുംകൂടി സുവിശേഷം പങ്കുവെക്കാനുള്ള പ്രായോഗിക നടപടികൾ.', 'മിഷനും സേവനവും'),
  ('888e8400-e29b-41d4-a716-446655440005', 'ml', 'രാഷ്ട്രങ്ങൾക്കായി പ്രാർത്ഥിക്കുക', 'ലോകത്തിനായുള്ള മദ്ധ്യസ്ഥതയിലൂടെ ദൈവത്തിന്റെ മിഷനിൽ ചേരുക.', 'മിഷനും സേവനവും')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- =====================================================
-- PART 6: COMMENTS AND DOCUMENTATION
-- =====================================================

COMMENT ON TABLE recommended_topics IS
  'Curated Bible study topics organized by category with multi-language support.
   Supports different input types: topic (standard study guide), verse (verse-based),
   or question (generates direct answer instead of full study guide).';

COMMENT ON TABLE recommended_topics_translations IS
  'Multi-language translations (Hindi, Malayalam) for recommended topics.
   Linked to recommended_topics via topic_id foreign key.';

COMMENT ON FUNCTION get_recommended_topics(TEXT, INTEGER, INTEGER, VARCHAR) IS
  'Retrieves recommended topics with optional category filter and language support.
   Returns topic details in specified language (en/hi/ml) or falls back to English.
   Supports pagination with limit and offset parameters.';

COMMENT ON FUNCTION get_recommended_topics_categories(VARCHAR) IS
  'Returns list of unique topic categories with count of topics in each category.
   Supports language-specific category names based on p_language_code.';

COMMENT ON FUNCTION get_recommended_topics_count(TEXT) IS
  'Returns total count of recommended topics with optional category filter.
   Used for pagination and statistics.';

-- =====================================================
-- ADDITIONAL TOPICS: Theology & Philosophy
-- =====================================================
-- Added: 2026-01-22
-- Purpose: Topics for "Faith & Reason" learning path

INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value, input_type)
VALUES
  -- 1. Does God Exist?
  ('AAA00000-e29b-41d4-a716-446655440001',
   'Does God Exist?',
   'Examining philosophical and biblical evidence for God''s existence through cosmological, teleological, and moral arguments.',
   'Theology & Philosophy',
   ARRAY['existence of god', 'apologetics', 'philosophy', 'cosmology', 'evidence'],
   56, 50, 'question'),

  -- 2. Why Does God Allow Evil and Suffering?
  ('AAA00000-e29b-41d4-a716-446655440002',
   'Why Does God Allow Evil and Suffering?',
   'Understanding theodicy, free will, and God''s sovereignty in a fallen world. Biblical perspectives on pain and redemption.',
   'Theology & Philosophy',
   ARRAY['problem of evil', 'theodicy', 'suffering', 'free will', 'sovereignty'],
   57, 50, 'question'),

  -- 3. Is Jesus the Only Way to Salvation?
  ('AAA00000-e29b-41d4-a716-446655440003',
   'Is Jesus the Only Way to Salvation?',
   'Exploring biblical exclusivity claims, Jesus'' own words, and responding to pluralism with grace and truth.',
   'Theology & Philosophy',
   ARRAY['salvation', 'exclusivity', 'jesus', 'pluralism', 'soteriology'],
   58, 50, 'question'),

  -- 4. What About Those Who Never Hear the Gospel?
  ('AAA00000-e29b-41d4-a716-446655440004',
   'What About Those Who Never Hear the Gospel?',
   'Biblical perspectives on general revelation, God''s justice, and the fate of the unreached.',
   'Theology & Philosophy',
   ARRAY['unreached', 'general revelation', 'justice', 'missions', 'romans 1-2'],
   59, 50, 'question'),

  -- 5. What is the Trinity?
  ('AAA00000-e29b-41d4-a716-446655440005',
   'What is the Trinity?',
   'Understanding the nature of God as one being in three persons - Father, Son, and Holy Spirit.',
   'Theology & Philosophy',
   ARRAY['trinity', 'god', 'theology', 'monotheism', 'godhead'],
   60, 50, 'question'),

  -- 6. Why Doesn't God Answer My Prayers?
  ('AAA00000-e29b-41d4-a716-446655440006',
   'Why Doesn''t God Answer My Prayers?',
   'Understanding God''s timing, His will, and the purpose of persistent prayer in light of unanswered petitions.',
   'Theology & Philosophy',
   ARRAY['prayer', 'unanswered prayer', 'gods will', 'faith', 'persistence'],
   61, 50, 'question'),

  -- 7. Predestination vs. Free Will
  ('AAA00000-e29b-41d4-a716-446655440007',
   'Predestination vs. Free Will',
   'Exploring God''s sovereignty and human responsibility - biblical tensions, Reformed vs. Arminian perspectives.',
   'Theology & Philosophy',
   ARRAY['predestination', 'free will', 'sovereignty', 'election', 'calvinism'],
   62, 50, 'topic'),

  -- 8. Why Are There So Many Christian Denominations?
  ('AAA00000-e29b-41d4-a716-446655440008',
   'Why Are There So Many Christian Denominations?',
   'Understanding church history, essential vs. non-essential doctrines, and unity in diversity.',
   'Theology & Philosophy',
   ARRAY['denominations', 'church history', 'unity', 'doctrine', 'ecclesiology'],
   63, 50, 'topic'),

  -- 9. What is My Purpose in Life?
  ('AAA00000-e29b-41d4-a716-446655440009',
   'What is My Purpose in Life?',
   'Discovering God''s design for your life through creation, redemption, and your unique calling.',
   'Theology & Philosophy',
   ARRAY['purpose', 'calling', 'identity', 'meaning', 'vocation'],
   64, 50, 'topic')
ON CONFLICT (id) DO NOTHING;

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, category, title, description)
VALUES
  ('AAA00000-e29b-41d4-a716-446655440001', 'hi',
   'धर्मशास्त्र और दर्शन',
   'क्या परमेश्वर है?',
   'ब्रह्मांडीय, उद्देश्यमूलक और नैतिक तर्कों के माध्यम से परमेश्वर के अस्तित्व के लिए दार्शनिक और बाइबिलीय साक्ष्य की जांच।'),

  ('AAA00000-e29b-41d4-a716-446655440002', 'hi',
   'धर्मशास्त्र और दर्शन',
   'परमेश्वर बुराई और पीड़ा क्यों होने देता है?',
   'पतित संसार में थियोडिसी, स्वतंत्र इच्छा और परमेश्वर की संप्रभुता को समझना। दर्द और छुटकारे पर बाइबिलीय दृष्टिकोण।'),

  ('AAA00000-e29b-41d4-a716-446655440003', 'hi',
   'धर्मशास्त्र और दर्शन',
   'क्या यीशु ही उद्धार का एकमात्र रास्ता है?',
   'बाइबिलीय विशिष्टता के दावों, यीशु के अपने शब्दों की खोज और कृपा और सत्य के साथ बहुलवाद पर प्रतिक्रिया।'),

  ('AAA00000-e29b-41d4-a716-446655440004', 'hi',
   'धर्मशास्त्र और दर्शन',
   'उनके बारे में क्या जो कभी सुसमाचार नहीं सुनते?',
   'सामान्य प्रकाशन, परमेश्वर की न्याय और अप्राप्त लोगों के भाग्य पर बाइबिलीय दृष्टिकोण।'),

  ('AAA00000-e29b-41d4-a716-446655440005', 'hi',
   'धर्मशास्त्र और दर्शन',
   'त्रिएकता क्या है?',
   'तीन व्यक्तियों - पिता, पुत्र और पवित्र आत्मा में एक परमेश्वर के रूप में परमेश्वर की प्रकृति को समझना।'),

  ('AAA00000-e29b-41d4-a716-446655440006', 'hi',
   'धर्मशास्त्र और दर्शन',
   'परमेश्वर मेरी प्रार्थनाओं का उत्तर क्यों नहीं देता?',
   'अनुत्तरित याचनाओं के प्रकाश में परमेश्वर के समय, उसकी इच्छा और लगातार प्रार्थना के उद्देश्य को समझना।'),

  ('AAA00000-e29b-41d4-a716-446655440007', 'hi',
   'धर्मशास्त्र और दर्शन',
   'पूर्वनियति बनाम स्वतंत्र इच्छा',
   'परमेश्वर की संप्रभुता और मानव जिम्मेदारी की खोज - बाइबिलीय तनाव, सुधारवादी बनाम आर्मिनियन दृष्टिकोण।'),

  ('AAA00000-e29b-41d4-a716-446655440008', 'hi',
   'धर्मशास्त्र और दर्शन',
   'इतने सारे ईसाई संप्रदाय क्यों हैं?',
   'कलीसिया के इतिहास, आवश्यक बनाम गैर-आवश्यक सिद्धांतों और विविधता में एकता को समझना।'),

  ('AAA00000-e29b-41d4-a716-446655440009', 'hi',
   'धर्मशास्त्र और दर्शन',
   'मेरे जीवन का उद्देश्य क्या है?',
   'सृष्टि, छुटकारे और अपने अनोखे बुलावे के माध्यम से अपने जीवन के लिए परमेश्वर की योजना को खोजना।')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, category, title, description)
VALUES
  ('AAA00000-e29b-41d4-a716-446655440001', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'ദൈവം ഉണ്ടോ?',
   'പ്രപഞ്ചശാസ്ത്ര, ലക്ഷ്യശാസ്ത്ര, ധാർമ്മിക വാദങ്ങളിലൂടെ ദൈവത്തിന്റെ അസ്തിത്വത്തിനുള്ള ദാർശനികവും ബൈബിൾപരവുമായ തെളിവുകൾ പരിശോധിക്കുന്നു.'),

  ('AAA00000-e29b-41d4-a716-446655440002', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'ദൈവം തിന്മയും കഷ്ടപ്പാടും അനുവദിക്കുന്നത് എന്തുകൊണ്ട്?',
   'പതിതമായ ലോകത്ത് ദൈവശാസ്ത്രം, സ്വതന്ത്ര ഇച്ഛാശക്തി, ദൈവത്തിന്റെ പരമാധികാരം എന്നിവ മനസ്സിലാക്കുന്നു. വേദനയെയും വീണ്ടെടുപ്പിനെയും കുറിച്ചുള്ള ബൈബിൾ കാഴ്ചപ്പാടുകൾ.'),

  ('AAA00000-e29b-41d4-a716-446655440003', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'രക്ഷയ്ക്കുള്ള ഏക മാർഗം യേശുവാണോ?',
   'ബൈബിൾ പ്രത്യേകാവകാശ അവകാശവാദങ്ങൾ, യേശുവിന്റെ സ്വന്തം വാക്കുകൾ, കൃപയോടും സത്യത്തോടും കൂടി ബഹുസ്വരതയോട് പ്രതികരിക്കൽ എന്നിവ പര്യവേക്ഷണം ചെയ്യുന്നു.'),

  ('AAA00000-e29b-41d4-a716-446655440004', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'സുവിശേഷം കേൾക്കാത്തവരെ കുറിച്ച് എന്ത്?',
   'പൊതു വെളിപാട്, ദൈവത്തിന്റെ നീതി, എത്തിച്ചേരാത്തവരുടെ വിധി എന്നിവയെക്കുറിച്ചുള്ള ബൈബിൾ കാഴ്ചപ്പാടുകൾ.'),

  ('AAA00000-e29b-41d4-a716-446655440005', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'ത്രിത്വം എന്താണ്?',
   'മൂന്ന് വ്യക്തികളായ പിതാവ്, പുത്രൻ, പരിശുദ്ധാത്മാവ് എന്നിവയിലുള്ള ഒരു ദൈവമെന്ന നിലയിൽ ദൈവത്തിന്റെ സ്വഭാവം മനസ്സിലാക്കുന്നു.'),

  ('AAA00000-e29b-41d4-a716-446655440006', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'എന്തുകൊണ്ട് ദൈവം എന്റെ പ്രാർത്ഥനകൾക്ക് ഉത്തരം നൽകുന്നില്ല?',
   'ഉത്തരം ലഭിക്കാത്ത അപേക്ഷകളുടെ വെളിച്ചത്തിൽ ദൈവത്തിന്റെ സമയം, അവന്റെ ഇച്ഛ, നിരന്തരമായ പ്രാർത്ഥനയുടെ ലക്ഷ്യം എന്നിവ മനസ്സിലാക്കുന്നു.'),

  ('AAA00000-e29b-41d4-a716-446655440007', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'മുൻനിർണയം vs. സ്വതന്ത്ര ഇച്ഛാശക്തി',
   'ദൈവത്തിന്റെ പരമാധികാരവും മനുഷ്യ ഉത്തരവാദിത്വവും പര്യവേക്ഷണം ചെയ്യുന്നു - ബൈബിൾ പിരിമുറുക്കങ്ങൾ, പരിഷ്കൃത vs. ആർമിനിയൻ കാഴ്ചപ്പാടുകൾ.'),

  ('AAA00000-e29b-41d4-a716-446655440008', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'എന്തുകൊണ്ട് ഇത്ര അധികം ക്രൈസ്തവ വിഭാഗങ്ങൾ?',
   'സഭാ ചരിത്രം, അത്യാവശ്യവും അല്ലാത്തതുമായ പ്രമാണങ്ങൾ, വൈവിധ്യത്തിലെ ഐക്യം എന്നിവ മനസ്സിലാക്കുന്നു.'),

  ('AAA00000-e29b-41d4-a716-446655440009', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'എന്റെ ജീവിതത്തിന്റെ ലക്ഷ്യം എന്താണ്?',
   'സൃഷ്ടി, വീണ്ടെടുപ്പ്, നിങ്ങളുടെ അതുല്യമായ വിളിക്കൽ എന്നിവയിലൂടെ നിങ്ങളുടെ ജീവിതത്തിനായുള്ള ദൈവത്തിന്റെ ആഭിമുഖ്യം കണ്ടെത്തുന്നു.')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ADDITIONAL TOPICS: Hope & Future and Apologetics
-- Added: 2026-01-22
-- Purpose: Missing topics referenced by Faith & Reason learning path

INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value, input_type)
VALUES
  -- Foundations of Faith
  ('111e8400-e29b-41d4-a716-446655440007',
   'Your Identity in Christ',
   'Discover who you are as a child of God - a new creation, forgiven, loved, and empowered by the Holy Spirit.',
   'Foundations of Faith',
   ARRAY['identity', 'new creation', 'child of god', 'freedom'],
   67, 50, 'topic'),
  ('111e8400-e29b-41d4-a716-446655440008',
   'Understanding God''s Grace',
   'Learn the transforming power of grace - unmerited favor that saves us and empowers holy living without legalism.',
   'Foundations of Faith',
   ARRAY['grace', 'salvation', 'freedom', 'legalism'],
   68, 50, 'topic'),

  -- Christian Life
  ('222e8400-e29b-41d4-a716-446655440007',
   'Spiritual Warfare',
   'Understanding the spiritual battle, putting on the armor of God, and walking in victory through Christ.',
   'Christian Life',
   ARRAY['spiritual warfare', 'armor of god', 'victory', 'enemy'],
   69, 50, 'topic'),
  ('222e8400-e29b-41d4-a716-446655440008',
   'Dealing with Doubt and Fear',
   'How to overcome doubt and fear through Scripture, prayer, and trusting God''s faithfulness.',
   'Christian Life',
   ARRAY['doubt', 'fear', 'faith', 'trust'],
   70, 50, 'topic'),

  -- Church & Community
  ('333e8400-e29b-41d4-a716-446655440006',
   'Baptism and Communion',
   'Understanding the meaning and importance of the two ordinances given by Christ to the church.',
   'Church & Community',
   ARRAY['baptism', 'communion', 'lords supper', 'ordinances'],
   71, 50, 'topic'),

  -- Spiritual Disciplines
  ('555e8400-e29b-41d4-a716-446655440006',
   'How to Study the Bible',
   'Practical methods for reading, understanding, and applying Scripture effectively in your daily life.',
   'Spiritual Disciplines',
   ARRAY['bible study', 'hermeneutics', 'scripture', 'application'],
   72, 50, 'topic'),
  ('555e8400-e29b-41d4-a716-446655440007',
   'Hearing God''s Voice',
   'Learning to discern God''s guidance through Scripture, prayer, the Holy Spirit, and godly counsel.',
   'Spiritual Disciplines',
   ARRAY['hearing god', 'guidance', 'discernment', 'holy spirit'],
   73, 50, 'topic'),

  -- Faith and Science (Apologetics)
  ('666e8400-e29b-41d4-a716-446655440006',
   'Faith and Science',
   'Exploring how faith and science complement each other, and evidence for God in creation.',
   'Apologetics & Defense of Faith',
   ARRAY['faith', 'science', 'creation', 'evidence'],
   74, 50, 'topic'),

  -- Family & Relationships
  ('777e8400-e29b-41d4-a716-446655440006',
   'Singleness and Contentment',
   'Finding purpose and contentment in singleness while trusting God''s timing and plan for your life.',
   'Family & Relationships',
   ARRAY['singleness', 'contentment', 'waiting', 'purpose'],
   75, 50, 'topic'),

  -- Mission & Service
  ('888e8400-e29b-41d4-a716-446655440006',
   'Workplace as Mission',
   'Being salt and light in your workplace - living out your faith and making an impact for Christ at work.',
   'Mission & Service',
   ARRAY['workplace', 'mission', 'salt and light', 'witness'],
   76, 50, 'topic'),

  -- Discipleship & Growth
  ('444e8400-e29b-41d4-a716-446655440006',
   'Living by Faith, Not Feelings',
   'Learning to walk by faith and trust God''s promises even when emotions and circumstances are difficult.',
   'Discipleship & Growth',
   ARRAY['faith', 'feelings', 'trust', 'perseverance'],
   77, 50, 'topic'),

  -- Hope & Future
  ('999e8400-e29b-41d4-a716-446655440001',
   'The Return of Christ',
   'Understanding the blessed hope of Jesus'' second coming and how it shapes our daily living.',
   'Hope & Future',
   ARRAY['second coming', 'return of christ', 'hope', 'eschatology'],
   78, 50, 'topic'),
  ('999e8400-e29b-41d4-a716-446655440002',
   'Heaven and Eternal Life',
   'What the Bible teaches about heaven, eternity, and the glorious future that awaits believers.',
   'Hope & Future',
   ARRAY['heaven', 'eternal life', 'eternity', 'resurrection'],
   79, 50, 'topic')
ON CONFLICT (id) DO NOTHING;

-- Hindi translations
INSERT INTO recommended_topics_translations (topic_id, language_code, category, title, description)
VALUES
  -- Foundations of Faith
  ('111e8400-e29b-41d4-a716-446655440007', 'hi',
   'विश्वास की नींव',
   'मसीह में आपकी पहचान',
   'जानें कि आप परमेश्वर की संतान के रूप में कौन हैं - एक नई सृष्टि, क्षमा किया हुआ, प्रेमित, और पवित्र आत्मा द्वारा सशक्त।'),
  ('111e8400-e29b-41d4-a716-446655440008', 'hi',
   'विश्वास की नींव',
   'परमेश्वर की कृपा को समझना',
   'कृपा की परिवर्तनकारी शक्ति को जानें - अयोग्य अनुग्रह जो हमें बचाता है और कानूनवाद के बिना पवित्र जीवन जीने में सक्षम बनाता है।'),

  -- Christian Life
  ('222e8400-e29b-41d4-a716-446655440007', 'hi',
   'मसीही जीवन',
   'आत्मिक युद्ध',
   'आत्मिक युद्ध को समझना, परमेश्वर का हथियार पहनना, और मसीह के माध्यम से विजय में चलना।'),
  ('222e8400-e29b-41d4-a716-446655440008', 'hi',
   'मसीही जीवन',
   'संदेह और भय से निपटना',
   'वचन, प्रार्थना, और परमेश्वर की विश्वासयोग्यता पर भरोसा करके संदेह और भय पर कैसे विजय पाएं।'),

  -- Church & Community
  ('333e8400-e29b-41d4-a716-446655440006', 'hi',
   'कलीसिया और समुदाय',
   'बपतिस्मा और प्रभु भोज',
   'मसीह द्वारा कलीसिया को दिए गए दो अनुष्ठानों के अर्थ और महत्व को समझना।'),

  -- Spiritual Disciplines
  ('555e8400-e29b-41d4-a716-446655440006', 'hi',
   'आत्मिक अनुशासन',
   'बाइबल का अध्ययन कैसे करें',
   'अपने दैनिक जीवन में शास्त्र को प्रभावी ढंग से पढ़ने, समझने और लागू करने के व्यावहारिक तरीके।'),
  ('555e8400-e29b-41d4-a716-446655440007', 'hi',
   'आत्मिक अनुशासन',
   'परमेश्वर की आवाज सुनना',
   'वचन, प्रार्थना, पवित्र आत्मा, और भक्तिमय सलाह के माध्यम से परमेश्वर के मार्गदर्शन को समझना सीखना।'),

  -- Apologetics
  ('666e8400-e29b-41d4-a716-446655440006', 'hi',
   'धर्मशास्त्र और विश्वास की रक्षा',
   'विश्वास और विज्ञान',
   'कैसे विश्वास और विज्ञान एक दूसरे के पूरक हैं, और सृष्टि में परमेश्वर के लिए प्रमाण खोजना।'),

  -- Family & Relationships
  ('777e8400-e29b-41d4-a716-446655440006', 'hi',
   'परिवार और रिश्ते',
   'एकलता और संतोष',
   'एकलता में उद्देश्य और संतोष खोजना जबकि अपने जीवन के लिए परमेश्वर की समय और योजना पर भरोसा करना।'),

  -- Mission & Service
  ('888e8400-e29b-41d4-a716-446655440006', 'hi',
   'मिशन और सेवा',
   'कार्यस्थल मिशन के रूप में',
   'अपने कार्यस्थल में नमक और ज्योति बनना - अपने विश्वास को जीना और काम पर मसीह के लिए प्रभाव डालना।'),

  -- Discipleship & Growth
  ('444e8400-e29b-41d4-a716-446655440006', 'hi',
   'शिष्यत्व और विकास',
   'विश्वास से जीना, भावनाओं से नहीं',
   'विश्वास से चलना और परमेश्वर की प्रतिज्ञाओं पर भरोसा करना सीखना, भले ही भावनाएं और परिस्थितियां कठिन हों।'),

  -- Hope & Future
  ('999e8400-e29b-41d4-a716-446655440001', 'hi',
   'आशा और भविष्य',
   'मसीह की वापसी',
   'यीशु के दूसरे आगमन की धन्य आशा को समझना और यह हमारे दैनिक जीवन को कैसे आकार देता है।'),
  ('999e8400-e29b-41d4-a716-446655440002', 'hi',
   'आशा और भविष्य',
   'स्वर्ग और अनंत जीवन',
   'बाइबल स्वर्ग, अनंत काल, और विश्वासियों के लिए प्रतीक्षारत महिमामय भविष्य के बारे में क्या सिखाती है।')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam translations
INSERT INTO recommended_topics_translations (topic_id, language_code, category, title, description)
VALUES
  -- Foundations of Faith
  ('111e8400-e29b-41d4-a716-446655440007', 'ml',
   'വിശ്വാസത്തിന്റെ അടിത്തറകൾ',
   'ക്രിസ്തുവിലുള്ള നിങ്ങളുടെ സ്വത്വം',
   'നിങ്ങൾ ദൈവത്തിന്റെ മകനായി/മകളായി ആരാണെന്ന് കണ്ടെത്തുക - ഒരു പുതിയ സൃഷ്ടി, ക്ഷമിക്കപ്പെട്ട, സ്നേഹിക്കപ്പെട്ട, പരിശുദ്ധാത്മാവിനാൽ ശാക്തീകരിക്കപ്പെട്ട.'),
  ('111e8400-e29b-41d4-a716-446655440008', 'ml',
   'വിശ്വാസത്തിന്റെ അടിത്തറകൾ',
   'ദൈവത്തിന്റെ കൃപ മനസ്സിലാക്കുക',
   'കൃപയുടെ രൂപാന്തരപ്പെടുത്തുന്ന ശക്തി പഠിക്കുക - നമ്മെ രക്ഷിക്കുകയും നിയമവാദമില്ലാതെ വിശുദ്ധ ജീവിതം നയിക്കാൻ ശക്തിപ്പെടുത്തുകയും ചെയ്യുന്ന അയോഗ്യമായ അനുഗ്രഹം.'),

  -- Christian Life
  ('222e8400-e29b-41d4-a716-446655440007', 'ml',
   'ക്രൈസ്തവ ജീവിതം',
   'ആത്മീയ യുദ്ധം',
   'ആത്മീയ യുദ്ധം മനസ്സിലാക്കുക, ദൈവത്തിന്റെ കവചം ധരിക്കുക, ക്രിസ്തുവിലൂടെ വിജയത്തിൽ നടക്കുക.'),
  ('222e8400-e29b-41d4-a716-446655440008', 'ml',
   'ക്രൈസ്തവ ജീവിതം',
   'സംശയവും ഭയവും കൈകാര്യം ചെയ്യുക',
   'തിരുവെഴുത്ത്, പ്രാർത്ഥന, ദൈവത്തിന്റെ വിശ്വസ്തതയിൽ ആശ്രയിക്കുന്നതിലൂടെ സംശയവും ഭയവും എങ്ങനെ മറികടക്കാം.'),

  -- Church & Community
  ('333e8400-e29b-41d4-a716-446655440006', 'ml',
   'സഭയും സമൂഹവും',
   'സ്നാനവും കർത്താവിന്റെ അത്താഴവും',
   'ക്രിസ്തു സഭയ്ക്ക് നൽകിയ രണ്ട് കൽപ്പനകളുടെ അർത്ഥവും പ്രാധാന്യവും മനസ്സിലാക്കുക.'),

  -- Spiritual Disciplines
  ('555e8400-e29b-41d4-a716-446655440006', 'ml',
   'ആത്മീയ അനുശാസനം',
   'ബൈബിൾ എങ്ങനെ പഠിക്കാം',
   'നിങ്ങളുടെ ദൈനംദിന ജീവിതത്തിൽ തിരുവെഴുത്തുകൾ ഫലപ്രദമായി വായിക്കാനും മനസ്സിലാക്കാനും പ്രയോഗിക്കാനുമുള്ള പ്രായോഗിക മാർഗങ്ങൾ.'),
  ('555e8400-e29b-41d4-a716-446655440007', 'ml',
   'ആത്മീയ അനുശാസനം',
   'ദൈവത്തിന്റെ ശബ്ദം കേൾക്കുക',
   'തിരുവെഴുത്ത്, പ്രാർത്ഥന, പരിശുദ്ധാത്മാവ്, ഭക്തിയുള്ള ഉപദേശം എന്നിവയിലൂടെ ദൈവത്തിന്റെ മാർഗദർശനം തിരിച്ചറിയാൻ പഠിക്കുക.'),

  -- Apologetics
  ('666e8400-e29b-41d4-a716-446655440006', 'ml',
   'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും',
   'വിശ്വാസവും ശാസ്ത്രവും',
   'വിശ്വാസവും ശാസ്ത്രവും എങ്ങനെ പരസ്പരം പൂർത്തീകരിക്കുന്നു, സൃഷ്ടിയിൽ ദൈവത്തിനുള്ള തെളിവുകൾ എന്നിവ പര്യവേക്ഷണം ചെയ്യുക.'),

  -- Family & Relationships
  ('777e8400-e29b-41d4-a716-446655440006', 'ml',
   'കുടുംബവും ബന്ധങ്ങളും',
   'ഏകാന്തതയും സംതൃപ്തിയും',
   'നിങ്ങളുടെ ജീവിതത്തിനായുള്ള ദൈവത്തിന്റെ സമയത്തെയും പദ്ധതിയെയും വിശ്വസിക്കുമ്പോൾ ഏകാന്തതയിൽ ഉദ്ദേശ്യവും സംതൃപ്തിയും കണ്ടെത്തുക.'),

  -- Mission & Service
  ('888e8400-e29b-41d4-a716-446655440006', 'ml',
   'മിഷനും സേവനവും',
   'ജോലിസ്ഥലം മിഷനായി',
   'നിങ്ങളുടെ ജോലിസ്ഥലത്ത് ഉപ്പും വെളിച്ചവുമാകുക - നിങ്ങളുടെ വിശ്വാസം ജീവിക്കുകയും ജോലിസ്ഥലത്ത് ക്രിസ്തുവിനായി സ്വാധീനം ചെലുത്തുകയും ചെയ്യുക.'),

  -- Discipleship & Growth
  ('444e8400-e29b-41d4-a716-446655440006', 'ml',
   'ശിഷ്യത്വവും വളർച്ചയും',
   'വിശ്വാസത്താൽ ജീവിക്കുക, വികാരങ്ങളാൽ അല്ല',
   'വികാരങ്ങളും സാഹചര്യങ്ങളും ബുദ്ധിമുട്ടായിരിക്കുമ്പോൾ പോലും വിശ്വാസത്താൽ നടക്കാനും ദൈവത്തിന്റെ വാഗ്ദാനങ്ങളിൽ വിശ്വസിക്കാനും പഠിക്കുക.'),

  -- Hope & Future
  ('999e8400-e29b-41d4-a716-446655440001', 'ml',
   'പ്രത്യാശയും ഭാവിയും',
   'ക്രിസ്തുവിന്റെ മടങ്ങിവരവ്',
   'യേശുവിന്റെ രണ്ടാം വരവിന്റെ അനുഗ്രഹീത പ്രത്യാശ മനസ്സിലാക്കുക, അത് നമ്മുടെ ദൈനംദിന ജീവിതത്തെ എങ്ങനെ രൂപപ്പെടുത്തുന്നു.'),
  ('999e8400-e29b-41d4-a716-446655440002', 'ml',
   'പ്രത്യാശയും ഭാവിയും',
   'സ്വർഗവും നിത്യജീവനും',
   'സ്വർഗം, നിത്യത, വിശ്വാസികളെ കാത്തിരിക്കുന്ന മഹത്തായ ഭാവി എന്നിവയെക്കുറിച്ച് ബൈബിൾ എന്താണ് പഠിപ്പിക്കുന്നത്.')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

COMMIT;

-- Verification query
SELECT
  'Migration 0011 Complete' as status,
  (SELECT COUNT(*) FROM recommended_topics) as topics_count,
  (SELECT COUNT(*) FROM recommended_topics_translations) as translations_count,
  (SELECT COUNT(DISTINCT category) FROM recommended_topics) as categories_count;
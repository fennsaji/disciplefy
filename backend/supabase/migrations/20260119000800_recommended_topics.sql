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
  ('111e8400-e29b-41d4-a716-446655440001', 'Who is Jesus Christ?', 'Explore the biblical truth about Jesus Christ''s identity as fully God and fully man—the eternal Son of God who became flesh to accomplish our salvation. Learn how Scripture reveals Jesus as the promised Messiah, the only Savior who died for sinners and rose from the dead, and the sovereign Lord over all creation. Understand why recognizing who Jesus truly is forms the foundation of genuine Christian faith and how His person and work are central to the gospel message. This study grounds believers in the historic, orthodox understanding of Christ''s deity, humanity, and redemptive mission.', 'Foundations of Faith', ARRAY['jesus', 'son of god', 'savior', 'lord'], 1),
  ('111e8400-e29b-41d4-a716-446655440002', 'What is the Gospel?', 'Discover the heart of the Christian message: the gospel of Jesus Christ. Learn how the good news proclaims that sinful humanity, under God''s righteous judgment, can be saved only through faith in Christ''s substitutionary death and bodily resurrection. Understand the gospel as God''s gracious provision of salvation—not earned by human works or merit, but received through repentance and faith alone in Christ alone. This study clarifies the essential elements of the gospel: human sinfulness, Christ''s perfect life and atoning death, His victorious resurrection, and the call to respond in repentant faith. Grasp how the gospel transforms lives and establishes the foundation for all Christian living.', 'Foundations of Faith', ARRAY['gospel', 'salvation', 'good news'], 2),
  ('111e8400-e29b-41d4-a716-446655440003', 'Confidence in Your Salvation', 'Learn how true believers can have certain assurance that they HAVE salvation, grounded in Christ''s finished work and the unchanging promises of God''s Word—not in their own performance, feelings, or fluctuating emotions. Understand how assurance comes from the objective truth of the gospel, the internal testimony of the Holy Spirit confirming you are God''s child (Romans 8:16), and the evidence of genuine faith producing spiritual fruit in your life. This study distinguishes between saving faith and mere intellectual assent, addresses doubts biblically, and affirms that those truly born again are kept secure by God''s power (1 Peter 1:5, John 10:28-29) and will persevere in faith to the end. Discover the threefold basis of assurance: God''s promises in Scripture (1 John 5:13), the Spirit''s witness within, and the transformed life that flows from genuine conversion (2 Corinthians 5:17, 1 John 3:14).', 'Foundations of Faith', ARRAY['assurance', 'salvation', 'faith'], 3),
  ('111e8400-e29b-41d4-a716-446655440004', 'Why Read the Bible?', 'Understand why the Bible is essential for the Christian life—not merely as helpful literature, but as God''s inspired, inerrant, and authoritative Word. Learn how Scripture alone (Sola Scriptura) serves as the final authority for doctrine, reproof, correction, and training in righteousness (2 Timothy 3:16-17). Discover how God speaks through His Word to reveal Himself, convict of sin, point to Christ, and transform believers into His likeness. This study equips you to approach the Bible as living and active truth, essential for knowing God, discerning His will, and growing in holiness and obedience through the power of the Holy Spirit.', 'Foundations of Faith', ARRAY['bible', 'scripture', 'word of god'], 4),
  ('111e8400-e29b-41d4-a716-446655440005', 'Importance of Prayer', 'Learn the biblical foundation and practice of prayer as vital communion with the living God. Discover how prayer is not a ritual to earn God''s favor, but the privilege of approaching the throne of grace through Christ our mediator (Hebrews 4:16). Understand prayer as conversation with God—expressing adoration, confession, thanksgiving, and supplication—and as dependence on the Holy Spirit who intercedes for us (Romans 8:26). This study teaches how prayer strengthens faith, aligns our hearts with God''s will, and demonstrates our trust in His sovereignty and goodness. Grow in confident, persistent, and God-centered prayer rooted in Scripture and faith in Christ.', 'Foundations of Faith', ARRAY['prayer', 'communication with god', 'faith'], 5),
  ('111e8400-e29b-41d4-a716-446655440006', 'The Role of the Holy Spirit', 'Explore the biblical teaching on the Holy Spirit, the third person of the Trinity, who indwells all believers at conversion and empowers them for godly living. Learn how the Spirit convicts of sin, regenerates the heart, illuminates Scripture, sanctifies believers, and produces spiritual fruit (Galatians 5:22-23). Understand the Spirit''s ministry as the One who glorifies Christ, assures believers of their adoption as children of God (Romans 8:16), and equips the church with spiritual gifts for service. This study guards against both neglecting the Spirit''s work and embracing charismatic excess, grounding you in the biblical balance of the Spirit''s indwelling presence and transforming power in every believer''s life.', 'Foundations of Faith', ARRAY['holy spirit', 'guidance', 'empowerment'], 6)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Christian Life
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('222e8400-e29b-41d4-a716-446655440001', 'Walking with God Daily', 'Practical steps for growing in obedience and communion with God through faith, empowered by the Holy Spirit, not human effort alone.', 'Christian Life', ARRAY['daily walk', 'faith', 'discipline'], 1),
  ('222e8400-e29b-41d4-a716-446655440002', 'Overcoming Temptation', 'How to resist sin through the power of the Holy Spirit, Scripture, and the promises of God, not through willpower alone.', 'Christian Life', ARRAY['temptation', 'sin', 'victory'], 2),
  ('222e8400-e29b-41d4-a716-446655440003', 'Forgiveness and Reconciliation', 'Discover the biblical call to forgive others as God in Christ has forgiven you (Ephesians 4:32). Learn how Christian forgiveness is not based on feelings or the offender''s repentance, but flows from the grace we have received through the gospel. Understand the difference between genuine biblical forgiveness and worldly tolerance or enabling sin. This study teaches how to extend grace, pursue reconciliation where possible, and live at peace with others without compromising truth or justice. Explore how forgiveness demonstrates the transforming power of the gospel and reflects God''s character, freeing believers from bitterness and enabling restored relationships grounded in Christ-like love and humility.', 'Christian Life', ARRAY['forgiveness', 'reconciliation', 'peace'], 3),
  ('222e8400-e29b-41d4-a716-446655440004', 'The Importance of Fellowship', 'Understand why biblical fellowship is not optional but essential for the Christian life. Learn how God designed believers to live in community within the local church, where they receive encouragement, accountability, teaching, and mutual care (Hebrews 10:24-25). Discover how authentic Christian fellowship is rooted in shared faith in Christ, characterized by love, truth-speaking, confession of sin, prayer, and bearing one another''s burdens (Galatians 6:2). This study challenges the individualistic mindset of modern culture and calls believers to commit to the body of Christ, where spiritual growth is nurtured, spiritual gifts are exercised, and the gospel witness is strengthened through visible unity and love.', 'Christian Life', ARRAY['fellowship', 'community', 'church'], 4),
  ('222e8400-e29b-41d4-a716-446655440005', 'Giving and Generosity', 'Understanding biblical generosity as a joyful response to God''s grace, not as a requirement for earning favor or prosperity.', 'Christian Life', ARRAY['giving', 'tithing', 'generosity'], 5),
  ('222e8400-e29b-41d4-a716-446655440006', 'Living a Holy Life', 'God''s call to holiness in thought, word, and action—pursued through the Spirit''s power, not legalistic self-effort.', 'Christian Life', ARRAY['holiness', 'purity', 'obedience'], 6)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Church & Community
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('333e8400-e29b-41d4-a716-446655440001', 'What is the Church?', 'Explore the biblical doctrine of the church as the body of Christ—the assembly of all true believers called out from the world to worship God, proclaim the gospel, and live in obedience to Christ the Head. Learn how the church is not merely a building or institution, but a spiritual organism united by faith in Christ and indwelt by the Holy Spirit. Understand the church''s purposes: worship, discipleship, fellowship, evangelism, and service. This study distinguishes between the universal church (all believers across time) and the local church (gathered congregations), emphasizing the importance of commitment to a local body where believers are equipped, shepherded, and held accountable as they grow in Christ-likeness together.', 'Church & Community', ARRAY['church', 'body of christ', 'community'], 1),
  ('333e8400-e29b-41d4-a716-446655440002', 'Why Fellowship Matters', 'Discover the non-negotiable importance of Christian fellowship within the local church. Learn how Scripture commands believers not to forsake assembling together (Hebrews 10:25), because spiritual growth, accountability, encouragement, and protection from false teaching require committed relationships with other Christians. Understand fellowship as more than casual socializing—it is shared life in Christ, characterized by mutual love, truth-telling, confession, prayer, and the exercise of spiritual gifts. This study challenges cultural individualism and calls believers to deep, intentional relationships within the body of Christ, where iron sharpens iron (Proverbs 27:17) and the gospel is lived out in visible community.', 'Church & Community', ARRAY['fellowship', 'unity', 'believers'], 2),
  ('333e8400-e29b-41d4-a716-446655440003', 'Serving in the Church', 'Learn the biblical truth that every believer is called to serve in the body of Christ using the spiritual gifts God has given. Understand that service is not reserved for professional clergy but is the privilege and responsibility of all Christians, empowered by the Holy Spirit to build up the church (1 Peter 4:10-11). Discover how to identify your spiritual gifts, serve with humility and faithfulness, and contribute to the health and mission of the local church. This study emphasizes that Christian service flows from grace, not works-righteousness—it is a grateful response to God''s mercy, done for His glory and the good of others, rooted in love for Christ and His church.', 'Church & Community', ARRAY['service', 'ministry', 'spiritual gifts'], 3),
  ('333e8400-e29b-41d4-a716-446655440004', 'Unity in Christ', 'Explore the biblical call to pursue unity within the church, grounded in the truth of the gospel and empowered by the Holy Spirit. Learn how Christian unity is not mere agreement or tolerance, but spiritual oneness rooted in shared faith in Christ, devotion to Scripture, and mutual love (John 17:20-23). Understand how to maintain unity while upholding doctrinal truth, avoiding both divisive legalism and compromising pluralism. This study teaches how to bear with one another in love, resolve conflicts biblically, and demonstrate to the watching world the authenticity of the gospel through visible love and harmony among believers, all for the glory of God and the witness of the church.', 'Church & Community', ARRAY['unity', 'love', 'body of christ'], 4),
  ('333e8400-e29b-41d4-a716-446655440005', 'Spiritual Gifts and Their Use', 'Discover the biblical teaching on spiritual gifts—abilities given by the Holy Spirit to every believer for the edification of the church and the glory of God (1 Corinthians 12:7). Learn how to identify your spiritual gifts, develop them through faithful service, and use them in love and humility to strengthen the body of Christ. Understand the purpose of spiritual gifts: not personal prestige or self-fulfillment, but building up others in faith and maturity (Ephesians 4:11-13). This study guards against both neglecting spiritual gifts and seeking spectacular manifestations, grounding you in the biblical principles of stewardship, service, and the supremacy of love in all expressions of gifting within the church.', 'Church & Community', ARRAY['spiritual gifts', 'service', 'church'], 5)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Discipleship & Growth
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('444e8400-e29b-41d4-a716-446655440001', 'What is Discipleship?', 'Explore the biblical meaning of discipleship as the lifelong process of following Jesus Christ, learning from Him, and becoming conformed to His image. Understand that discipleship is not optional for Christians—it is the normal Christian life, characterized by obedience to Christ''s commands, dependence on the Holy Spirit, and growth in godliness (Matthew 28:19-20). Learn how discipleship involves dying to self, taking up your cross daily, and prioritizing Christ above all else (Luke 9:23). This study clarifies that discipleship is not self-improvement or moral effort, but Spirit-empowered transformation rooted in union with Christ, sustained by His grace, and directed toward His glory and the mission of making other disciples.', 'Discipleship & Growth', ARRAY['discipleship', 'follow jesus', 'growth'], 1),
  ('444e8400-e29b-41d4-a716-446655440002', 'The Cost of Following Jesus', 'Understand the sobering yet glorious reality that following Jesus requires counting the cost and surrendering all to Him as Lord. Learn how Jesus calls disciples to deny themselves, take up their cross, and lose their life for His sake (Mark 8:34-35). Discover that discipleship may involve sacrifice, suffering, rejection, and the loss of worldly comforts—but it also brings the surpassing joy of knowing Christ and the promise of eternal life. This study guards against cheap grace and cultural Christianity, calling believers to wholehearted devotion to Jesus, where obedience flows from love, sacrifice is joyful, and the cost of discipleship is far outweighed by the treasure of Christ Himself.', 'Discipleship & Growth', ARRAY['cost', 'sacrifice', 'following jesus'], 2),
  ('444e8400-e29b-41d4-a716-446655440003', 'Bearing Fruit', 'Exploring what it means to bear spiritual fruit as evidence of genuine faith and the Spirit''s work in us, not as a means of earning salvation.', 'Discipleship & Growth', ARRAY['fruit', 'spiritual growth', 'discipleship'], 3),
  ('444e8400-e29b-41d4-a716-446655440004', 'The Great Commission', 'Explore Jesus'' final command to His disciples: "Go therefore and make disciples of all nations, baptizing them and teaching them to observe all that I have commanded you" (Matthew 28:19-20). Learn how the Great Commission is not only for missionaries or pastors, but for every believer as participants in God''s redemptive plan to gather people from every tribe, tongue, and nation. Understand the essential elements: going with the gospel, making disciples (not just converts), baptizing as a sign of covenant membership, and teaching obedience to Christ. This study inspires faithful evangelism and discipleship, grounded in confidence in Christ''s authority, empowered by the Spirit''s presence, and motivated by love for God''s glory and the salvation of the lost.', 'Discipleship & Growth', ARRAY['great commission', 'evangelism', 'discipleship'], 4),
  ('444e8400-e29b-41d4-a716-446655440005', 'Mentoring Others', 'Learn the biblical model of spiritual mentorship, where mature believers invest in younger Christians by teaching, modeling godliness, and providing encouragement and accountability (2 Timothy 2:2). Understand that mentoring is not about superiority or perfection, but humbly sharing the grace you have received, pointing others to Christ, and helping them grow in faith and obedience. Discover practical ways to mentor others through Scripture study, prayer, honest conversation, and intentional discipleship relationships. This study emphasizes that mentoring is both a privilege and a responsibility, flowing from the overflow of God''s work in your own life and contributing to the multiplication of faithful disciples across generations for the glory of God.', 'Discipleship & Growth', ARRAY['mentorship', 'discipleship', 'growth'], 5)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Spiritual Disciplines
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('555e8400-e29b-41d4-a716-446655440001', 'Daily Devotions', 'Discover the essential practice of daily devotional time with God—setting apart regular moments to read Scripture, pray, and commune with the Lord. Learn how daily devotions are not legalistic rituals to earn God''s favor, but vital means of grace that nourish your soul, deepen your relationship with God, and sustain your walk with Christ. Understand how consistent time in God''s Word and prayer strengthens faith, provides guidance, renews your mind, and equips you for spiritual battles (Ephesians 6:10-18). This study provides practical guidance for establishing a sustainable rhythm of devotion, emphasizing that the goal is not mere religious duty but delighting in God, growing in holiness, and abiding in Christ daily.', 'Spiritual Disciplines', ARRAY['devotion', 'quiet time', 'discipline'], 1),
  ('555e8400-e29b-41d4-a716-446655440002', 'Fasting and Prayer', 'Discovering fasting and prayer as spiritual disciplines for focusing on God, not as means to manipulate God or earn His favor.', 'Spiritual Disciplines', ARRAY['fasting', 'prayer', 'discipline'], 2),
  ('555e8400-e29b-41d4-a716-446655440003', 'Worship as a Lifestyle', 'Learning how worship is more than songs—it is living all of life in grateful obedience to God through Christ.', 'Spiritual Disciplines', ARRAY['worship', 'lifestyle', 'obedience'], 3),
  ('555e8400-e29b-41d4-a716-446655440004', 'Meditation on God''s Word', 'Learn the biblical practice of meditating on God''s Word—not empty-minded Eastern mysticism, but focused, prayerful reflection on Scripture to understand, internalize, and apply divine truth. Discover how meditation involves reading Scripture slowly, pondering its meaning, praying through it, and allowing the Holy Spirit to illuminate and transform your heart and mind (Psalm 1:2-3). Understand how meditation on God''s Word strengthens faith, renews thinking, exposes sin, and conforms you to Christ''s image. This study equips you to move beyond superficial Bible reading to deep engagement with Scripture, where God''s truth takes root in your soul and produces lasting spiritual fruit and Christ-like character.', 'Spiritual Disciplines', ARRAY['meditation', 'scripture', 'word of god'], 4),
  ('555e8400-e29b-41d4-a716-446655440005', 'Journaling Your Walk with God', 'Explore the practice of spiritual journaling as a means of recording God''s faithfulness, tracking your spiritual growth, and processing your walk with Christ through written reflection. Learn how journaling can include recording prayers, answers to prayer, insights from Scripture, confession of sin, expressions of gratitude, and reflections on God''s providence in your life. Understand that journaling is not about literary skill or performance, but honest communion with God and intentional self-examination before Him. This study shows how journaling fosters greater awareness of God''s work, deeper gratitude, and clearer spiritual discernment, serving as a personal testimony of God''s grace and a tool for ongoing sanctification and remembrance of His goodness.', 'Spiritual Disciplines', ARRAY['journaling', 'prayer', 'growth'], 5)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Apologetics & Defense of Faith
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('666e8400-e29b-41d4-a716-446655440001', 'Why We Believe in One God', 'Explore the biblical doctrine of monotheism—the truth that there is only one true God, eternal, self-existent, and sovereign over all creation (Deuteronomy 6:4; Isaiah 44:6). Learn how Scripture consistently reveals God as the only deity worthy of worship, in contrast to the polytheism of surrounding cultures and modern pluralistic claims. Understand how Christian monotheism is Trinitarian: one God in three persons—Father, Son, and Holy Spirit—distinct yet united in essence. This study equips you to defend the uniqueness of the biblical God against false religions, idolatry, and relativism, grounding your faith in the clear testimony of Scripture and preparing you to articulate the truth of God''s singular majesty and glory.', 'Apologetics & Defense of Faith', ARRAY['one god', 'monotheism', 'faith'], 1),
  ('666e8400-e29b-41d4-a716-446655440002', 'The Uniqueness of Jesus', 'Discover why Jesus Christ is the only way to salvation, as He Himself declared: "I am the way, and the truth, and the life. No one comes to the Father except through me" (John 14:6). Learn how Jesus'' unique identity as God incarnate, His sinless life, substitutionary death, and bodily resurrection make Him the sole mediator between God and humanity (1 Timothy 2:5). Understand why religious pluralism—the idea that all paths lead to God—contradicts both Scripture and the gospel. This study equips you to graciously yet firmly proclaim the exclusive claims of Christ in a pluralistic world, grounded in biblical truth and motivated by love for the lost and zeal for God''s glory.', 'Apologetics & Defense of Faith', ARRAY['jesus', 'salvation', 'uniqueness'], 2),
  ('666e8400-e29b-41d4-a716-446655440003', 'Is the Bible Reliable?', 'Examine the compelling evidence for the reliability and trustworthiness of the Bible as the inspired, inerrant Word of God. Learn how manuscript evidence, archaeological discoveries, fulfilled prophecy, internal consistency, and the testimony of the Holy Spirit all affirm Scripture''s divine origin and authority. Understand how the Bible''s reliability is not based on human opinion or scholarly consensus, but on God''s character as the God of truth who cannot lie. This study equips you to answer skeptics'' objections, strengthen your confidence in God''s Word, and stand firm on the foundation of Scripture as the final authority for faith and practice in all matters of doctrine and life.', 'Apologetics & Defense of Faith', ARRAY['bible', 'scripture', 'trustworthy'], 3),
  ('666e8400-e29b-41d4-a716-446655440004', 'Responding to Common Questions from Other Faiths', 'Learn how to engage respectfully and biblically with people of other faiths, answering their questions about Christianity with both truth and grace (1 Peter 3:15-16). Discover how to understand common objections from Hinduism, Islam, Buddhism, and other religions, and respond with clear gospel-centered answers rooted in Scripture. Understand the balance between defending the faith (apologetics) and demonstrating Christ-like love and humility. This study prepares you to articulate the uniqueness of the gospel, expose the inadequacy of false religions, and point others to Jesus as the only Savior—all while maintaining a posture of gentleness, respect, and genuine concern for the souls of those who do not yet know Christ.', 'Apologetics & Defense of Faith', ARRAY['apologetics', 'faith questions', 'dialogue'], 4),
  ('666e8400-e29b-41d4-a716-446655440005', 'Standing Firm in Persecution', 'Discover biblical encouragement and practical wisdom for enduring persecution and opposition for the sake of Christ. Learn how Jesus promised that His followers would face tribulation (John 16:33), yet also promised His presence, power, and ultimate victory. Understand how persecution is not a sign of God''s absence but often a mark of genuine discipleship (2 Timothy 3:12). This study teaches how to stand firm in faith through suffering, resist the temptation to compromise or deny Christ, and find joy in sharing in His sufferings (1 Peter 4:12-14). Be equipped to endure hardship with hope, grounded in the promises of Scripture, sustained by the Holy Spirit, and confident in the eternal reward awaiting those who remain faithful to Christ.', 'Apologetics & Defense of Faith', ARRAY['persecution', 'faith', 'courage'], 5)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Family & Relationships
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('777e8400-e29b-41d4-a716-446655440001', 'Marriage and Faith', 'Explore the biblical vision for marriage as a covenant union between one man and one woman, designed by God to reflect Christ''s relationship with His church (Ephesians 5:22-33). Learn how a Christ-centered marriage is built on mutual submission to God''s Word, sacrificial love modeled after Christ, and roles that honor God''s created order. Understand how the gospel transforms marriage from self-centered partnership to selfless, covenant faithfulness. This study addresses practical areas such as communication, conflict resolution, intimacy, and spiritual leadership, all grounded in Scripture. Discover how marriage is not ultimately about personal happiness but about glorifying God, displaying the gospel, and partnering together in service to Christ and His kingdom.', 'Family & Relationships', ARRAY['marriage', 'faith', 'family'], 1),
  ('777e8400-e29b-41d4-a716-446655440002', 'Raising Children in Christ', 'Learn the biblical mandate for parents to raise their children in the fear and instruction of the Lord (Ephesians 6:4), training them to know, love, and obey God from their earliest years. Discover how Christian parenting is not merely about behavioral modification or moral instruction, but about pointing children to their need for the gospel and the grace of Jesus Christ. Understand the balance between discipline and grace, instruction and prayer, authority and love. This study equips parents to create a home where God''s Word is central, prayer is habitual, and the gospel is modeled and taught consistently, preparing children to embrace faith in Christ as their own and live faithfully for His glory throughout their lives.', 'Family & Relationships', ARRAY['children', 'parenting', 'faith'], 2),
  ('777e8400-e29b-41d4-a716-446655440003', 'Honoring Parents', 'Explore the Fifth Commandment''s call to honor father and mother (Exodus 20:12), understanding how this command reveals God''s design for family order and the blessing that comes from obedience. Learn what biblical honor looks like in practice: respect, gratitude, care, and submission to godly authority—while also recognizing that ultimate obedience belongs to God alone. Understand how honoring parents extends throughout life, from childhood obedience to adult care and respect. This study addresses difficult situations such as dishonoring or abusive parents, showing how to honor while maintaining biblical boundaries. Discover how honoring parents glorifies God, strengthens families, and demonstrates the transforming power of the gospel in relationships.', 'Family & Relationships', ARRAY['parents', 'honor', 'obedience'], 3),
  ('777e8400-e29b-41d4-a716-446655440004', 'Healthy Friendships', 'Discover the biblical principles for building Christ-centered friendships that encourage spiritual growth, accountability, and mutual edification. Learn how Scripture warns against ungodly friendships that lead to compromise (1 Corinthians 15:33) while commending friendships rooted in love for God and pursuit of holiness (Proverbs 27:17). Understand the qualities of healthy Christian friendship: loyalty, honesty, encouragement, accountability, and shared commitment to Christ. This study provides practical guidance for choosing friends wisely, maintaining godly boundaries, and investing in relationships that point one another toward Jesus. Explore how true friendship reflects the love of Christ and serves as a means of grace in the Christian life.', 'Family & Relationships', ARRAY['friends', 'relationships', 'faith'], 4),
  ('777e8400-e29b-41d4-a716-446655440005', 'Resolving Conflicts Biblically', 'Learn the biblical process for resolving conflicts and disagreements in a way that honors God and preserves relationships. Discover how Jesus outlined steps for confronting sin and pursuing reconciliation (Matthew 18:15-17), emphasizing humility, honesty, and a commitment to truth spoken in love. Understand how to identify the root causes of conflict (often pride and selfishness, James 4:1-2), confess your own sin first, seek forgiveness, and extend grace. This study teaches how to navigate difficult conversations, pursue peace without compromising truth, and involve the church when necessary. Grow in biblical peacemaking that reflects the gospel, glorifies God, and restores broken relationships through Christ-like love, humility, and grace.', 'Family & Relationships', ARRAY['conflict', 'forgiveness', 'relationships'], 5)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Mission & Service
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('888e8400-e29b-41d4-a716-446655440001', 'Being the Light in Your Community', 'Explore Jesus'' call for believers to be "the light of the world" (Matthew 5:14-16), reflecting His character and truth in every sphere of life—at work, in your neighborhood, at school, and within your family. Learn what it means to live as salt and light (preserving truth and illuminating the gospel) in a fallen world, not through self-righteousness but through humble obedience and grace. Discover how your good works, done in faith and motivated by love for God, point others to your Father in heaven and open doors for gospel conversations. This study equips believers to live distinctively, reflect Christ authentically, and engage their local community with the hope of the gospel in practical, tangible ways.', 'Mission & Service', ARRAY['light', 'witness', 'community'], 1),
  ('888e8400-e29b-41d4-a716-446655440002', 'Sharing Your Testimony', 'Discover the power and importance of sharing your personal testimony—the story of how God saved you through faith in Jesus Christ and what He has done in your life since then. Learn how a clear testimony includes your life before Christ, how you came to understand the gospel and repent, and the transformation God has worked in you by His grace (not by your own effort). Understand how your testimony glorifies God, encourages other believers, and opens doors to share the full gospel message with clarity. This study helps you craft a gospel-centered testimony that points to Christ, avoids making yourself the hero, and demonstrates the life-changing power of the good news.', 'Mission & Service', ARRAY['testimony', 'evangelism', 'faith'], 2),
  ('888e8400-e29b-41d4-a716-446655440003', 'Serving the Poor and Needy', 'Explore the biblical mandate to care for the poor, orphans, widows, and marginalized, rooted in God''s compassion and justice (Deuteronomy 15:11, James 1:27). Learn how serving the needy flows from a heart transformed by the gospel—we serve because Christ first served us in our spiritual poverty. Understand the difference between the social gospel (which reduces Christianity to good works) and gospel-driven compassion (which meets physical needs while always pointing to the greater need for spiritual salvation). Discover practical ways to sacrificially give, serve with dignity, and show Christ''s love through acts of mercy, recognizing that true justice and mercy are grounded in the character of God and the redemptive work of Jesus.', 'Mission & Service', ARRAY['service', 'poor', 'justice'], 3),
  ('888e8400-e29b-41d4-a716-446655440004', 'Evangelism Made Simple', 'Learn practical, biblical methods for sharing the gospel with clarity, boldness, and love, trusting that the Holy Spirit convicts hearts and saves sinners (John 16:8, Romans 1:16). Understand the essential elements of the gospel message—God''s holiness, human sin, Christ''s substitutionary death and resurrection, and the call to repent and believe—and how to communicate them winsomely in everyday conversations. Discover how to overcome fear, anticipate objections, and trust in the power of God''s Word rather than human eloquence or manipulation. This study equips you to share Christ faithfully in natural contexts, through relationships, and with genuine love for the lost, always depending on God''s sovereignty in salvation.', 'Mission & Service', ARRAY['evangelism', 'gospel', 'mission'], 4),
  ('888e8400-e29b-41d4-a716-446655440005', 'Praying for the Nations', 'Discover the biblical call to pray for the nations, participating in God''s global mission to gather worshipers from every tribe, tongue, and nation (Revelation 7:9). Learn how intercessory prayer for unreached peoples, persecuted believers, and gospel advancement aligns with God''s sovereign plan to save sinners worldwide through the proclamation of Christ. Understand how faithful prayer supports missionaries, opens doors for the gospel, and advances God''s kingdom in places where the name of Jesus is not yet known. This study inspires believers to develop a global vision for missions, pray strategically for specific needs, and trust God to accomplish His purposes among the nations for His glory and the spread of the gospel.', 'Mission & Service', ARRAY['prayer', 'missions', 'nations'], 5)
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
  ('111e8400-e29b-41d4-a716-446655440001', 'hi', 'यीशु मसीह कौन हैं?', 'यीशु मसीह की पहचान के बारे में बाइबिल की सच्चाई का पता लगाएं - पूर्णतः परमेश्वर और पूर्णतः मनुष्य, शाश्वत परमेश्वर का पुत्र जो हमारे उद्धार को पूरा करने के लिए देह बना। जानें कि पवित्रशास्त्र यीशु को प्रतिज्ञा किए गए मसीहा, एकमात्र उद्धारकर्ता के रूप में कैसे प्रकट करता है जो पापियों के लिए मरा और मृतकों में से जी उठा, और सारी सृष्टि पर सर्वोच्च प्रभु। समझें कि यीशु वास्तव में कौन हैं, यह पहचानना सच्चे मसीही विश्वास की नींव क्यों बनता है और उनका व्यक्तित्व और कार्य सुसमाचार संदेश के केंद्र में कैसे हैं। यह अध्ययन विश्वासियों को मसीह के देवत्व, मानवता और छुटकारे के मिशन की ऐतिहासिक, रूढ़िवादी समझ में स्थापित करता है।', 'विश्वास की नींव'),
  ('111e8400-e29b-41d4-a716-446655440002', 'hi', 'सुसमाचार क्या है?', 'सुसमाचार के मूल को खोजें - शुभ संदेश कि परमेश्वर ने यीशु मसीह के द्वारा पापियों को बचाया है। समझें कि सुसमाचार केवल अच्छी सलाह नहीं है बल्कि अच्छी खबर है: परमेश्वर की योजना मानव पाप को दंडित करने के लिए, मसीह को हमारे स्थान पर भेजकर, वह पवित्र जीवन जीने के लिए जो हम नहीं जी सके, क्रूस पर हमारे पापों को उठाने के लिए, हमारे लिए परमेश्वर के क्रोध को सहने के लिए, और मृत्यु को जीतकर जी उठने के लिए। जानें कि यह सुसमाचार पश्चाताप और विश्वास की मांग करता है - अपने पाप से फिरना और केवल मसीह पर भरोसा करना। यह अध्ययन स्पष्ट करता है कि उद्धार कर्मों से नहीं, बल्कि केवल विश्वास से अनुग्रह द्वारा है।', 'विश्वास की नींव'),
  ('111e8400-e29b-41d4-a716-446655440003', 'hi', 'अपने उद्धार में विश्वास', 'जानें कि सच्चे विश्वासी कैसे निश्चित रूप से जान सकते हैं कि उनके पास उद्धार है, जो मसीह के पूर्ण कार्य और परमेश्वर के वचन की अपरिवर्तनीय प्रतिज्ञाओं पर आधारित है - न कि उनके अपने प्रदर्शन, भावनाओं, या उतार-चढ़ाव वाली भावनाओं पर। समझें कि आश्वासन सुसमाचार की वस्तुनिष्ठ सच्चाई से आता है, पवित्र आत्मा की आंतरिक गवाही जो पुष्टि करती है कि आप परमेश्वर की संतान हैं (रोमियों 8:16), और सच्चे विश्वास का प्रमाण जो आपके जीवन में आत्मिक फल उत्पन्न करता है। यह अध्ययन बचाने वाले विश्वास और केवल बौद्धिक सहमति के बीच अंतर करता है, संदेहों को बाइबिलीय रूप से संबोधित करता है, और पुष्टि करता है कि जो वास्तव में फिर से जन्मे हैं, वे परमेश्वर की शक्ति द्वारा सुरक्षित रखे जाते हैं (1 पतरस 1:5, यूहन्ना 10:28-29) और अंत तक विश्वास में बने रहेंगे। आश्वासन के तीन आधारों की खोज करें: शास्त्र में परमेश्वर की प्रतिज्ञाएं (1 यूहन्ना 5:13), भीतर आत्मा की गवाही, और सच्चे परिवर्तन से बहने वाला परिवर्तित जीवन (2 कुरिन्थियों 5:17, 1 यूहन्ना 3:14)।', 'विश्वास की नींव'),
  ('111e8400-e29b-41d4-a716-446655440004', 'hi', 'बाइबिल क्यों पढ़ें?', 'पवित्रशास्त्र की केंद्रीयता की खोज करें - परमेश्वर का लिखित, त्रुटिहीन वचन - मसीही जीवन में। समझें कि बाइबल मानव ज्ञान या धार्मिक विचारों का संग्रह नहीं है, बल्कि परमेश्वर के आत्मा-प्रेरित प्रकाशन है (2 तीमुथियुस 3:16)। जानें कि पवित्रशास्त्र विश्वासियों को शिक्षित, सुधारता, मार्गदर्शन करता और परमेश्वर के चरित्र और इरादे को प्रकट करता है। बाइबल पढ़ना भोजन के समान है - आप इसके बिना आत्मिक रूप से भूखे रहेंगे। यह अध्ययन आपको नियमित, जानबूझकर बाइबल अध्ययन के लिए लैस करता है, आपके मन को नवीनीकृत करने, आपको सत्य में स्थापित करने, और आपको मसीह की समानता में बदलने के लिए।', 'विश्वास की नींव'),
  ('111e8400-e29b-41d4-a716-446655440005', 'hi', 'प्रार्थना का महत्व', 'प्रार्थना को परमेश्वर के साथ संवाद के रूप में, शक्ति के स्रोत के रूप में, और सच्ची आराधना के कार्य के रूप में खोजें। समझें कि प्रार्थना एक धार्मिक अनुष्ठान नहीं है, बल्कि पवित्र परमेश्वर के साथ विनम्र बातचीत है जो मसीह के माध्यम से उसकी उपस्थिति में पहुंच प्रदान करता है। सीखें कि प्रार्थना में कैसे निडर होकर आएं (इब्रानियों 4:16), अपने पापों को स्वीकार करें, अपनी आवश्यकताओं को व्यक्त करें, दूसरों के लिए मध्यस्थता करें, और परमेश्वर की महिमा करें। प्रभावी प्रार्थना की शक्ति उत्कृष्ट शब्दों में नहीं है, बल्कि विश्वास से भरे हृदय और परमेश्वर की प्रभुता में विश्वास में है। यह अध्ययन आपको गहरी, उद्देश्यपूर्ण प्रार्थना जीवन विकसित करने में मदद करता है जो परमेश्वर का सम्मान करता है।', 'विश्वास की नींव'),
  ('111e8400-e29b-41d4-a716-446655440006', 'hi', 'पवित्र आत्मा की भूमिका', 'पवित्र आत्मा के कार्य को समझें - परमेश्वर का तीसरा व्यक्ति, पिता और पुत्र के साथ समान - मसीही जीवन में। जानें कि पवित्र आत्मा उद्धार में कैसे कार्य करता है (पश्चाताप और विश्वास की ओर पापियों को आश्वस्त करना), पुनर्जन्म में (विश्वासियों को नया जीवन देना), पवित्रीकरण में (उन्हें बदलना), और सेवा में (सेवा के लिए उपहार और शक्ति प्रदान करना)। समझें कि कैसे आत्मा आपको सत्य में मार्गदर्शन करता है, मसीह की समानता में आकार देता है, और आपको परमेश्वर के राज्य के लिए प्रभावी सेवा के लिए सशक्त बनाता है। यह अध्ययन सही करता है मिथकों को और बाइबिल आधारित समझ स्थापित करता है।', 'विश्वास की नींव')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('111e8400-e29b-41d4-a716-446655440001', 'ml', 'യേശുക്രിസ്തു ആരാണ്?', 'യേശുക്രിസ്തുവിന്റെ സ്വത്വത്തെക്കുറിച്ചുള്ള ബൈബിളിലെ സത്യം പര്യവേക്ഷണം ചെയ്യുക - പൂർണ്ണമായും ദൈവവും പൂർണ്ണമായും മനുഷ്യനും - നമ്മുടെ രക്ഷ നിവർത്തിക്കാൻ ജഡമായി മാറിയ ദൈവത്തിന്റെ നിത്യപുത്രൻ. വേദപുസ്തകം യേശുവിനെ വാഗ്ദത്ത മിശിഹായായി, പാപികൾക്കുവേണ്ടി മരിച്ച് മരിച്ചവരിൽനിന്ന് ഉയിർത്തെഴുന്നേറ്റ ഏക രക്ഷകനായി, സർവ്വ സൃഷ്ടികൾക്കും മേലുള്ള പരമാധികാര കർത്താവായി എങ്ങനെ വെളിപ്പെടുത്തുന്നുവെന്ന് പഠിക്കുക. യേശു യഥാർത്ഥത്തിൽ ആരാണെന്ന് തിരിച്ചറിയുന്നത് എന്തുകൊണ്ട് യഥാർത്ഥ ക്രിസ്തീയ വിശ്വാസത്തിന്റെ അടിസ്ഥാനം രൂപീകരിക്കുന്നുവെന്നും അവന്റെ വ്യക്തിത്വവും പ്രവൃത്തിയും സുവിശേഷസന്ദേശത്തിന്റെ കേന്ദ്രബിന്ദുവാകുന്നതെങ്ങനെയെന്നും മനസ്സിലാക്കുക. ഈ പഠനം വിശ്വാസികളെ ക്രിസ്തുവിന്റെ ദൈവത്വത്തെയും മാനവികതയെയും വീണ്ടെടുപ്പ് ദൗത്യത്തെയും കുറിച്ചുള്ള ചരിത്രപരവും യാഥാസ്ഥിതികവുമായ ധാരണയിൽ സ്ഥാപിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('111e8400-e29b-41d4-a716-446655440002', 'ml', 'സുവിശേഷം എന്താണ്?', 'സുവിശേഷത്തിന്റെ കാതൽ പര്യവേക്ഷണം ചെയ്യുക - ദൈവം യേശുക്രിസ്തുവിലൂടെ പാപികളെ രക്ഷിച്ചു എന്ന സന്തോഷവാർത്ത. സുവിശേഷം കേവലം നല്ല ഉപദേശമല്ല, മറിച്ച് സുവാർത്തയാണെന്ന് മനസ്സിലാക്കുക: മാനുഷിക പാപത്തെ ശിക്ഷിക്കാനുള്ള ദൈവത്തിന്റെ പദ്ധതി, നമ്മുടെ സ്ഥാനത്ത് ക്രിസ്തുവിനെ അയച്ചുകൊണ്ട്, നമുക്ക് ജീവിക്കാൻ കഴിയാത്ത വിശുദ്ധമായ ജീവിതം ജീവിക്കാൻ, കുരിശിൽ നമ്മുടെ പാപങ്ങൾ വഹിക്കാൻ, നമുക്കുവേണ്ടി ദൈവത്തിന്റെ കോപം സഹിക്കാൻ, മരണത്തെ ജയിച്ച് ഉയിർത്തെഴുന്നേൽക്കാൻ. ഈ സുവിശേഷം മാനസാന്തരവും വിശ്വാസവും ആവശ്യപ്പെടുന്നുവെന്ന് പഠിക്കുക - നിങ്ങളുടെ പാപത്തിൽനിന്ന് തിരിയുകയും ക്രിസ്തുവിൽ മാത്രം വിശ്വസിക്കുകയും ചെയ്യുക. ഈ പഠനം രക്ഷ പ്രവൃത്തികളാലല്ല, മറിച്ച് വിശ്വാസത്താൽ മാത്രം കൃപയാൽ ആണെന്ന് വ്യക്തമാക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('111e8400-e29b-41d4-a716-446655440003', 'ml', 'നിങ്ങളുടെ രക്ഷയിലുള്ള വിശ്വാസം', 'യഥാർത്ഥ വിശ്വാസികൾക്ക് അവർക്ക് രക്ഷ ഉണ്ടെന്ന് എങ്ങനെ ഉറപ്പോടെ അറിയാമെന്ന് പഠിക്കുക, അത് ക്രിസ്തുവിന്റെ പൂർത്തിയായ പ്രവൃത്തിയിലും ദൈവവചനത്തിന്റെ മാറ്റമില്ലാത്ത വാഗ്ദാനങ്ങളിലും അധിഷ്ഠിതമാണ് - അവരുടെ സ്വന്തം പ്രകടനത്തിലോ വികാരങ്ങളിലോ ഏറ്റക്കുറച്ചിലുകളിലോ അല്ല. ഉറപ്പ് സുവിശേഷത്തിന്റെ വസ്തുനിഷ്ഠമായ സത്യത്തിൽ നിന്നും, നിങ്ങൾ ദൈവത്തിന്റെ മകനാണെന്ന് സ്ഥിരീകരിക്കുന്ന പരിശുദ്ധാത്മാവിന്റെ ആന്തരിക സാക്ഷ്യത്തിൽ നിന്നും (റോമർ 8:16), നിങ്ങളുടെ ജീവിതത്തിൽ ആത്മീയ ഫലം ഉൽപാദിപ്പിക്കുന്ന യഥാർത്ഥ വിശ്വാസത്തിന്റെ തെളിവിൽ നിന്നും എങ്ങനെ വരുന്നുവെന്ന് മനസ്സിലാക്കുക. ഈ പഠനം രക്ഷിക്കുന്ന വിശ്വാസവും കേവല ബൗദ്ധിക സമ്മതവും തമ്മിൽ വേർതിരിക്കുന്നു, സംശയങ്ങളെ ബൈബിൾപരമായി അഭിസംബോധന ചെയ്യുന്നു, യഥാർത്ഥമായി പുനർജനിച്ചവർ ദൈവശക്തിയാൽ സുരക്ഷിതരായി സൂക്ഷിക്കപ്പെടുന്നുവെന്നും (1 പത്രോസ് 1:5, യോഹന്നാൻ 10:28-29) അവസാനംവരെ വിശ്വാസത്തിൽ ഉറച്ചുനിൽക്കുമെന്നും സ്ഥിരീകരിക്കുന്നു. ഉറപ്പിന്റെ മൂന്ന് അടിസ്ഥാനങ്ങൾ കണ്ടെത്തുക: തിരുവെഴുത്തിലെ ദൈവവാഗ്ദാനങ്ങൾ (1 യോഹന്നാൻ 5:13), ഉള്ളിലുള്ള ആത്മാവിന്റെ സാക്ഷ്യം, യഥാർത്ഥ മാറ്റത്തിൽ നിന്ന് ഒഴുകുന്ന പരിവർത്തിത ജീവിതം (2 കൊരിന്ത്യർ 5:17, 1 യോഹന്നാൻ 3:14).', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('111e8400-e29b-41d4-a716-446655440004', 'ml', 'ബൈബിൾ എന്തിനു വായിക്കണം?', 'വേദപുസ്തകത്തിന്റെ കേന്ദ്രസ്ഥാനം പര്യവേക്ഷണം ചെയ്യുക - ദൈവത്തിന്റെ എഴുതപ്പെട്ട, പിശകില്ലാത്ത വചനം - ക്രിസ്തീയ ജീവിതത്തിൽ. ബൈബിൾ മാനുഷിക ജ്ഞാനത്തിന്റെയോ മതപരമായ ചിന്തകളുടെയോ സമാഹാരമല്ല, മറിച്ച് ദൈവത്തിന്റെ ആത്മാവുചിത പ്രത്യാദേശമാണെന്ന് (2 തിമൊഥെയൊസ് 3:16) മനസ്സിലാക്കുക. വേദപുസ്തകം വിശ്വാസികളെ ഉപദേശിക്കുകയും തിരുത്തുകയും നയിക്കുകയും ദൈവത്തിന്റെ സ്വഭാവവും ഉദ്ദേശ്യവും വെളിപ്പെടുത്തുകയും ചെയ്യുന്നുവെന്ന് പഠിക്കുക. ബൈബിൾ വായിക്കുന്നത് ഭക്ഷണം പോലെയാണ് - അതില്ലാതെ നിങ്ങൾ ആത്മീയമായി പട്ടിണി കിടക്കും. ഈ പഠനം നിങ്ങളുടെ മനസ്സ് പുതുക്കുന്നതിനും നിങ്ങളെ സത്യത്തിൽ സ്ഥാപിക്കുന്നതിനും നിങ്ങളെ ക്രിസ്തുവിന്റെ സാദൃശ്യത്തിലേക്ക് മാറ്റുന്നതിനും നിയമിത, ഉദ്ദേശിത ബൈബിൾ പഠനത്തിനായി നിങ്ങളെ സജ്ജമാക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('111e8400-e29b-41d4-a716-446655440005', 'ml', 'പ്രാർത്ഥനയുടെ പ്രാധാന്യം', 'പ്രാർത്ഥനയെ ദൈവവുമായുള്ള ആശയവിനിമയമായും ശക്തിയുടെ ഉറവിടമായും യഥാർത്ഥ ആരാധനയുടെ പ്രവൃത്തിയായും പര്യവേക്ഷണം ചെയ്യുക. പ്രാർത്ഥന ഒരു മതപരമായ ആചാരമല്ല, മറിച്ച് ക്രിസ്തുവിലൂടെ തന്റെ സാന്നിധ്യത്തിലേക്ക് പ്രവേശനം നൽകുന്ന വിശുദ്ധ ദൈവവുമായുള്ള വിനീതമായ സംഭാഷണമാണെന്ന് മനസ്സിലാക്കുക. പ്രാർത്ഥനയിൽ എങ്ങനെ ധൈര്യത്തോടെ വരാമെന്നും (എബ്രായർ 4:16), നിങ്ങളുടെ പാപങ്ങൾ ഏറ്റുപറയാനും നിങ്ങളുടെ ആവശ്യങ്ങൾ പ്രകടിപ്പിക്കാനും മറ്റുള്ളവർക്കുവേണ്ടി മധ്യസ്ഥത വഹിക്കാനും ദൈവത്തെ മഹത്വപ്പെടുത്താനും പഠിക്കുക. ഫലപ്രദമായ പ്രാർത്ഥനയുടെ ശക്തി മികച്ച വാക്കുകളിലല്ല, മറിച്ച് വിശ്വാസം നിറഞ്ഞ ഹൃദയത്തിലും ദൈവത്തിന്റെ പരമാധികാരത്തിലുള്ള ആശ്രയത്തിലുമാണ്. ഈ പഠനം ദൈവത്തെ ബഹുമാനിക്കുന്ന ആഴത്തിലുള്ള, ലക്ഷ്യബോധമുള്ള പ്രാർത്ഥനാ ജീവിതം വികസിപ്പിക്കാൻ നിങ്ങളെ സഹായിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('111e8400-e29b-41d4-a716-446655440006', 'ml', 'പരിശുദ്ധാത്മാവിന്റെ പങ്ക്', 'പരിശുദ്ധാത്മാവിന്റെ പ്രവൃത്തി മനസ്സിലാക്കുക - ദൈവത്തിന്റെ മൂന്നാമത്തെ വ്യക്തി, പിതാവിനോടും പുത്രനോടും തുല്യമായ - ക്രിസ്തീയ ജീവിതത്തിൽ. പരിശുദ്ധാത്മാവ് രക്ഷയിൽ (പാപികളെ മാനസാന്തരത്തിലേക്കും വിശ്വാസത്തിലേക്കും ബോധ്യപ്പെടുത്തുന്നു), പുനർജനനത്തിൽ (വിശ്വാസികൾക്ക് പുതിയ ജീവൻ നൽകുന്നു), വിശുദ്ധീകരണത്തിൽ (അവരെ പരിവർത്തനം ചെയ്യുന്നു), സേവനത്തിൽ (സേവനത്തിനുള്ള വരദാനങ്ങളും ശക്തിയും നൽകുന്നു) എങ്ങനെ പ്രവർത്തിക്കുന്നുവെന്ന് പഠിക്കുക. ആത്മാവ് നിങ്ങളെ സത്യത്തിലേക്ക് എങ്ങനെ നയിക്കുന്നുവെന്നും ക്രിസ്തുവിന്റെ സാദൃശ്യത്തിൽ രൂപപ്പെടുത്തുന്നുവെന്നും ദൈവരാജ്യത്തിനായുള്ള ഫലപ്രദമായ സേവനത്തിന് നിങ്ങളെ ശക്തീകരിക്കുന്നുവെന്നും മനസ്സിലാക്കുക. ഈ പഠനം തെറ്റിദ്ധാരണകൾ തിരുത്തുകയും ബൈബിളധിഷ്ഠിതമായ ധാരണ സ്ഥാപിക്കുകയും ചെയ്യുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Christian Life (मसीही जीवन / ക്രൈസ്തവ ജീവിതം)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('222e8400-e29b-41d4-a716-446655440001', 'hi', 'परमेश्वर के साथ दैनिक चलना', 'विश्वास के माध्यम से परमेश्वर के साथ आज्ञाकारिता और संगति में बढ़ने के लिए व्यावहारिक कदम, जो केवल मानव प्रयास से नहीं, बल्कि पवित्र आत्मा द्वारा सशक्त है।', 'मसीही जीवन'),
  ('222e8400-e29b-41d4-a716-446655440002', 'hi', 'प्रलोभन पर विजय', 'केवल इच्छाशक्ति से नहीं, बल्कि पवित्र आत्मा की शक्ति, पवित्रशास्त्र और परमेश्वर की प्रतिज्ञाओं के माध्यम से पाप का विरोध कैसे करें।', 'मसीही जीवन'),
  ('222e8400-e29b-41d4-a716-446655440003', 'hi', 'क्षमा और सुलह', 'दूसरों को क्षमा करने के बाइबिल के आह्वान को खोजें जैसे परमेश्वर ने मसीह में आपको क्षमा किया है (इफिसियों 4:32)। जानें कि मसीही क्षमा भावनाओं या अपराधी के पश्चाताप पर आधारित नहीं है, बल्कि सुसमाचार के माध्यम से हमें प्राप्त अनुग्रह से प्रवाहित होती है। सच्ची बाइबिल क्षमा और सांसारिक सहिष्णुता या पाप को सक्षम बनाने के बीच अंतर को समझें। यह अध्ययन सिखाता है कि कैसे अनुग्रह बढ़ाएं, जहां संभव हो सुलह का पीछा करें, और सत्य या न्याय से समझौता किए बिना दूसरों के साथ शांति में रहें। जानें कि क्षमा सुसमाचार की परिवर्तनकारी शक्ति को कैसे प्रदर्शित करती है और परमेश्वर के चरित्र को प्रतिबिंबित करती है, विश्वासियों को कड़वाहट से मुक्त करती है और मसीह-समान प्रेम और विनम्रता में स्थापित पुनर्स्थापित रिश्तों को सक्षम बनाती है।', 'मसीही जीवन'),
  ('222e8400-e29b-41d4-a716-446655440004', 'hi', 'संगति का महत्व', 'समझें कि बाइबिल की संगति वैकल्पिक नहीं बल्कि मसीही जीवन के लिए आवश्यक क्यों है। जानें कि परमेश्वर ने विश्वासियों को स्थानीय कलीसिया के भीतर समुदाय में रहने के लिए कैसे डिज़ाइन किया, जहां वे प्रोत्साहन, जवाबदेही, शिक्षण और पारस्परिक देखभाल प्राप्त करते हैं (इब्रानियों 10:24-25)। खोजें कि कैसे प्रामाणिक मसीही संगति मसीह में साझा विश्वास में निहित है, प्रेम, सत्य-बोलने, पाप की स्वीकारोक्ति, प्रार्थना और एक दूसरे के बोझ उठाने की विशेषता है (गलातियों 6:2)। यह अध्ययन आधुनिक संस्कृति की व्यक्तिवादी मानसिकता को चुनौती देता है और विश्वासियों को मसीह के शरीर के प्रति प्रतिबद्ध होने के लिए बुलाता है, जहां आत्मिक विकास पोषित होता है, आत्मिक वरदान प्रयोग किए जाते हैं, और दृश्य एकता और प्रेम के माध्यम से सुसमाचार गवाही मजबूत होती है।', 'मसीही जीवन'),
  ('222e8400-e29b-41d4-a716-446655440005', 'hi', 'देना और उदारता', 'बाइबिल की उदारता को परमेश्वर के अनुग्रह की खुशी की प्रतिक्रिया के रूप में समझना, पक्ष या समृद्धि कमाने की आवश्यकता के रूप में नहीं।', 'मसीही जीवन'),
  ('222e8400-e29b-41d4-a716-446655440006', 'hi', 'पवित्र जीवन जीना', 'विचार, वचन और कर्म में पवित्रता के लिए परमेश्वर का आह्वान - आत्मा की शक्ति के माध्यम से प्राप्त किया जाता है, कानूनी स्व-प्रयास से नहीं।', 'मसीही जीवन')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('222e8400-e29b-41d4-a716-446655440001', 'ml', 'ദൈവത്തോടൊപ്പം ദിവസേന നടക്കുക', 'വിശ്വാസത്തിലൂടെ ദൈവവുമായുള്ള അനുസരണത്തിലും കൂട്ടായ്മയിലും വളരുന്നതിനുള്ള പ്രായോഗിക നടപടികൾ, കേവലം മാനുഷിക പ്രയത്നത്താലല്ല, മറിച്ച് പരിശുദ്ധാത്മാവിനാൽ ശക്തീകരിക്കപ്പെട്ടത്.', 'ക്രൈസ്തവ ജീവിതം'),
  ('222e8400-e29b-41d4-a716-446655440002', 'ml', 'പ്രലോഭനത്തെ അതിജീവിക്കുക', 'കേവലം ഇച്ഛാശക്തിയാലല്ല, മറിച്ച് പരിശുദ്ധാത്മാവിന്റെ ശക്തിയിലൂടെയും വേദപുസ്തകത്തിലൂടെയും ദൈവത്തിന്റെ വാഗ്ദാനങ്ങളിലൂടെയും പാപത്തെ എതിർക്കുന്നത് എങ്ങനെയെന്ന്.', 'ക്രൈസ്തവ ജീവിതം'),
  ('222e8400-e29b-41d4-a716-446655440003', 'ml', 'ക്ഷമയും അനുരഞ്ജനവും', 'ദൈവം ക്രിസ്തുവിൽ നിങ്ങളോട് ക്ഷമിച്ചതുപോലെ മറ്റുള്ളവരോട് ക്ഷമിക്കാനുള്ള ബൈബിളിലെ ആഹ്വാനം പര്യവേക്ഷണം ചെയ്യുക (എഫെസ്യർ 4:32). ക്രിസ്തീയ ക്ഷമ വികാരങ്ങളെയോ കുറ്റവാളിയുടെ മാനസാന്തരത്തെയോ അടിസ്ഥാനമാക്കിയല്ല, മറിച്ച് സുവിശേഷത്തിലൂടെ നമുക്ക് ലഭിച്ച കൃപയിൽ നിന്ന് ഒഴുകുന്നുവെന്ന് പഠിക്കുക. യഥാർത്ഥ ബൈബിളിലെ ക്ഷമയും ലൗകിക സഹിഷ്ണുതയും അല്ലെങ്കിൽ പാപം സാധ്യമാക്കുന്നതും തമ്മിലുള്ള വ്യത്യാസം മനസ്സിലാക്കുക. ഈ പഠനം കൃപ എങ്ങനെ നൽകണമെന്നും സാധ്യമായിടത്ത് അനുരഞ്ജനം തേടണമെന്നും സത്യമോ നീതിയോ വിട്ടുവീഴ്ച ചെയ്യാതെ മറ്റുള്ളവരുമായി സമാധാനത്തോടെ ജീവിക്കണമെന്നും പഠിപ്പിക്കുന്നു. ക്ഷമ സുവിശേഷത്തിന്റെ പരിവർത്തന ശക്തിയെ എങ്ങനെ പ്രകടമാക്കുന്നുവെന്നും ദൈവത്തിന്റെ സ്വഭാവത്തെ പ്രതിഫലിപ്പിക്കുന്നുവെന്നും വിശ്വാസികളെ കയ്പിൽ നിന്ന് മോചിപ്പിക്കുന്നുവെന്നും ക്രിസ്തുവിനെപ്പോലെയുള്ള സ്നേഹത്തിലും വിനയത്തിലും സ്ഥാപിതമായ പുനഃസ്ഥാപിത ബന്ധങ്ങൾ സാധ്യമാക്കുന്നുവെന്നും പര്യവേക്ഷണം ചെയ്യുക.', 'ക്രൈസ്തവ ജീവിതം'),
  ('222e8400-e29b-41d4-a716-446655440004', 'ml', 'സംഗമത്തിന്റെ പ്രാധാന്യം', 'ബൈബിളിലെ കൂട്ടായ്മ ഐച്ഛികമല്ല, മറിച്ച് ക്രിസ്തീയ ജീവിതത്തിന് അത്യാവശ്യമാണെന്ന് മനസ്സിലാക്കുക. പ്രാദേശിക സഭയ്ക്കുള്ളിൽ വിശ്വാസികളെ സമൂഹത്തിൽ ജീവിക്കാൻ ദൈവം എങ്ങനെ രൂപകല്പന ചെയ്തുവെന്ന് പഠിക്കുക, അവിടെ അവർ പ്രോത്സാഹനവും ഉത്തരവാദിത്തവും പഠിപ്പിക്കലും പരസ്പര പരിചരണവും സ്വീകരിക്കുന്നു (എബ്രായർ 10:24-25). യഥാർത്ഥ ക്രിസ്തീയ കൂട്ടായ്മ ക്രിസ്തുവിലുള്ള പങ്കിട്ട വിശ്വാസത്തിൽ വേരൂന്നിയതാണെന്നും സ്നേഹം, സത്യം സംസാരിക്കൽ, പാപങ്ങളുടെ ഏറ്റുപറച്ചിൽ, പ്രാർത്ഥന, പരസ്പരം ഭാരങ്ങൾ വഹിക്കൽ എന്നിവയാൽ സവിശേഷമാണെന്നും പര്യവേക്ഷണം ചെയ്യുക (ഗലാത്യർ 6:2). ഈ പഠനം ആധുനിക സംസ്കാരത്തിന്റെ വ്യക്തിത്വ മാനസികതയെ വെല്ലുവിളിക്കുകയും വിശ്വാസികളെ ക്രിസ്തുവിന്റെ ശരീരത്തോട് പ്രതിജ്ഞാബദ്ധരാകാൻ ആഹ്വാനം ചെയ്യുകയും ചെയ്യുന്നു, അവിടെ ആത്മീയ വളർച്ച പരിപോഷിപ്പിക്കപ്പെടുകയും ആത്മീയ വരദാനങ്ങൾ പ്രയോഗിക്കപ്പെടുകയും ദൃശ്യമായ ഐക്യത്തിലൂടെയും സ്നേഹത്തിലൂടെയും സുവിശേഷ സാക്ഷ്യം ശക്തിപ്പെടുത്തുകയും ചെയ്യുന്നു.', 'ക്രൈസ്തവ ജീവിതം'),
  ('222e8400-e29b-41d4-a716-446655440005', 'ml', 'നൽകലും ഔദാര്യവും', 'ബൈബിളിലെ ഔദാര്യം ദൈവകൃപയോടുള്ള സന്തോഷകരമായ പ്രതികരണമായി മനസ്സിലാക്കുക, അനുഗ്രഹമോ സമൃദ്ധിയോ നേടുന്നതിനുള്ള ആവശ്യകതയായിട്ടല്ല.', 'ക്രൈസ്തവ ജീവിതം'),
  ('222e8400-e29b-41d4-a716-446655440006', 'ml', 'പരിശുദ്ധമായ ജീവിതം നയിക്കുക', 'ചിന്തയിലും വാക്കിലും പ്രവൃത്തിയിലും പരിശുദ്ധിക്കായുള്ള ദൈവത്തിന്റെ ആഹ്വാനം - ആത്മാവിന്റെ ശക്തിയിലൂടെ പിന്തുടരുന്നത്, നിയമാനുസൃതമായ സ്വയം-പ്രയത്നത്തിലൂടെയല്ല.', 'ക്രൈസ്തവ ജീവിതം')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Church & Community (कलीसिया और समुदाय / സഭയും സമൂഹവും)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('333e8400-e29b-41d4-a716-446655440001', 'hi', 'कलीसिया क्या है?', 'कलीसिया के बाइबिल सिद्धांत को मसीह के शरीर के रूप में खोजें - सभी सच्चे विश्वासियों की सभा जिन्हें दुनिया से परमेश्वर की आराधना करने, सुसमाचार घोषित करने और मुखिया मसीह की आज्ञाकारिता में जीने के लिए बुलाया गया है। जानें कि कलीसिया केवल एक इमारत या संस्था नहीं है, बल्कि एक आत्मिक जीव है जो मसीह में विश्वास से एकजुट है और पवित्र आत्मा द्वारा वास किया गया है। कलीसिया के उद्देश्यों को समझें: आराधना, शिष्यत्व, संगति, सुसमाचार प्रचार और सेवा। यह अध्ययन सार्वभौमिक कलीसिया (समय के पार सभी विश्वासी) और स्थानीय कलीसिया (एकत्रित मंडलियां) के बीच अंतर करता है, एक स्थानीय निकाय के प्रति प्रतिबद्धता के महत्व पर जोर देता है जहां विश्वासी सुसज्जित, चरवाही और जवाबदेह ठहराए जाते हैं जब वे एक साथ मसीह-समानता में बढ़ते हैं।', 'कलीसिया और समुदाय'),
  ('333e8400-e29b-41d4-a716-446655440002', 'hi', 'संगति क्यों मायने रखती है', 'स्थानीय कलीसिया के भीतर मसीही संगति के गैर-परक्राम्य महत्व को खोजें। जानें कि पवित्रशास्त्र विश्वासियों को एक साथ इकट्ठा होने से मना करने की आज्ञा क्यों देता है (इब्रानियों 10:25), क्योंकि आत्मिक विकास, जवाबदेही, प्रोत्साहन और झूठी शिक्षा से सुरक्षा के लिए अन्य मसीहियों के साथ प्रतिबद्ध रिश्तों की आवश्यकता होती है। संगति को आकस्मिक सामाजिकता से अधिक के रूप में समझें - यह मसीह में साझा जीवन है, जो पारस्परिक प्रेम, सत्य-बोलने, स्वीकारोक्ति, प्रार्थना और आत्मिक वरदानों के प्रयोग से विशेषता है। यह अध्ययन सांस्कृतिक व्यक्तिवाद को चुनौती देता है और विश्वासियों को मसीह के शरीर के भीतर गहरे, जानबूझकर रिश्तों के लिए बुलाता है, जहां लोहा लोहे को तेज करता है (नीतिवचन 27:17) और सुसमाचार दृश्य समुदाय में जीया जाता है।', 'कलीसिया और समुदाय'),
  ('333e8400-e29b-41d4-a716-446655440003', 'hi', 'कलीसिया में सेवा', 'बाइबिल की सच्चाई सीखें कि हर विश्वासी को परमेश्वर द्वारा दिए गए आत्मिक वरदानों का उपयोग करते हुए मसीह के शरीर में सेवा करने के लिए बुलाया गया है। समझें कि सेवा पेशेवर पादरियों के लिए आरक्षित नहीं है, बल्कि सभी मसीहियों का विशेषाधिकार और जिम्मेदारी है, जो कलीसिया के निर्माण के लिए पवित्र आत्मा द्वारा सशक्त है (1 पतरस 4:10-11)। जानें कि अपने आत्मिक वरदानों की पहचान कैसे करें, विनम्रता और वफादारी के साथ सेवा करें, और स्थानीय कलीसिया के स्वास्थ्य और मिशन में योगदान दें। यह अध्ययन इस बात पर जोर देता है कि मसीही सेवा अनुग्रह से प्रवाहित होती है, कर्म-धार्मिकता से नहीं - यह परमेश्वर की दया की कृतज्ञ प्रतिक्रिया है, उसकी महिमा और दूसरों की भलाई के लिए की गई, मसीह और उसकी कलीसिया के प्रेम में निहित।', 'कलीसिया और समुदाय'),
  ('333e8400-e29b-41d4-a716-446655440004', 'hi', 'मसीह में एकता', 'कलीसिया के भीतर एकता का पीछा करने के बाइबिल के आह्वान को खोजें, सुसमाचार की सच्चाई में आधारित और पवित्र आत्मा द्वारा सशक्त। जानें कि मसीही एकता केवल सहमति या सहिष्णुता नहीं है, बल्कि मसीह में साझा विश्वास, पवित्रशास्त्र के प्रति समर्पण और पारस्परिक प्रेम में निहित आत्मिक एकता है (यूहन्ना 17:20-23)। समझें कि सैद्धांतिक सत्य को बनाए रखते हुए एकता कैसे बनाए रखें, विभाजनकारी कानूनीवाद और समझौता करने वाले बहुलवाद दोनों से बचें। यह अध्ययन सिखाता है कि प्रेम में एक दूसरे के साथ कैसे सहन करें, बाइबिल के अनुसार संघर्षों को हल करें, और देखने वाली दुनिया को विश्वासियों के बीच दृश्य प्रेम और सद्भाव के माध्यम से सुसमाचार की प्रामाणिकता प्रदर्शित करें, सब परमेश्वर की महिमा और कलीसिया की गवाही के लिए।', 'कलीसिया और समुदाय'),
  ('333e8400-e29b-41d4-a716-446655440005', 'hi', 'आत्मिक वरदान और उनका उपयोग', 'आत्मिक वरदानों पर बाइबिल की शिक्षा की खोज करें - पवित्र आत्मा द्वारा हर विश्वासी को कलीसिया के निर्माण और परमेश्वर की महिमा के लिए दी गई क्षमताएं (1 कुरिन्थियों 12:7)। जानें कि अपने आत्मिक वरदानों की पहचान कैसे करें, वफादार सेवा के माध्यम से उन्हें विकसित करें, और मसीह के शरीर को मजबूत करने के लिए प्रेम और विनम्रता में उनका उपयोग करें। आत्मिक वरदानों के उद्देश्य को समझें: व्यक्तिगत प्रतिष्ठा या आत्म-पूर्ति नहीं, बल्कि दूसरों को विश्वास और परिपक्वता में बनाना (इफिसियों 4:11-13)। यह अध्ययन आत्मिक वरदानों की उपेक्षा और शानदार अभिव्यक्तियों की तलाश दोनों से बचाता है, कलीसिया के भीतर उपहार की सभी अभिव्यक्तियों में प्रबंधन, सेवा और प्रेम की सर्वोच्चता के बाइबिल सिद्धांतों में आपको स्थापित करता है।', 'कलीसिया और समुदाय')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('333e8400-e29b-41d4-a716-446655440001', 'ml', 'സഭ എന്താണ്?', 'ക്രിസ്തുവിന്റെ ശരീരം എന്ന നിലയിൽ സഭയുടെ ബൈബിളിലെ ഉപദേശം പര്യവേക്ഷണം ചെയ്യുക - ദൈവത്തെ ആരാധിക്കാനും സുവിശേഷം പ്രഖ്യാപിക്കാനും തലവനായ ക്രിസ്തുവിനോട് അനുസരണത്തിൽ ജീവിക്കാനും ലോകത്തിൽ നിന്ന് വിളിക്കപ്പെട്ട എല്ലാ യഥാർത്ഥ വിശ്വാസികളുടെയും സഭ. സഭ കേവലം ഒരു കെട്ടിടമോ സ്ഥാപനമോ അല്ല, മറിച്ച് ക്രിസ്തുവിലുള്ള വിശ്വാസത്താൽ ഐക്യപ്പെട്ടതും പരിശുദ്ധാത്മാവിനാൽ വസിക്കുന്നതുമായ ഒരു ആത്മീയ ജീവിയാണെന്ന് പഠിക്കുക. സഭയുടെ ഉദ്ദേശ്യങ്ങൾ മനസ്സിലാക്കുക: ആരാധന, ശിഷ്യത്വം, കൂട്ടായ്മ, സുവിശേഷവൽക്കരണം, സേവനം. ഈ പഠനം സാർവത്രിക സഭ (കാലം മുഴുവനുമുള്ള എല്ലാ വിശ്വാസികളും) ഉം പ്രാദേശിക സഭ (കൂടിച്ചേർന്ന സഭകൾ) ഉം തമ്മിൽ വേർതിരിക്കുന്നു, വിശ്വാസികൾ ഒരുമിച്ച് ക്രിസ്തുവിന്റെ സാദൃശ്യത്തിൽ വളരുമ്പോൾ സജ്ജീകരിക്കപ്പെടുകയും ഇടയനാകുകയും ഉത്തരവാദിത്തമുള്ളവരാകുകയും ചെയ്യുന്ന പ്രാദേശിക ശരീരത്തോടുള്ള പ്രതിബദ്ധതയുടെ പ്രാധാന്യം ഊന്നിപ്പറയുന്നു.', 'സഭയും സമൂഹവും'),
  ('333e8400-e29b-41d4-a716-446655440002', 'ml', 'സംഗമം എന്തുകൊണ്ട് പ്രധാനമാണ്', 'പ്രാദേശിക സഭയ്ക്കുള്ളിലെ ക്രിസ്തീയ കൂട്ടായ്മയുടെ വിട്ടുവീഴ്ച ചെയ്യാനാവാത്ത പ്രാധാന്യം കണ്ടെത്തുക. വിശ്വാസികൾ ഒരുമിച്ചു കൂടുന്നത് ഉപേക്ഷിക്കരുതെന്ന് വേദപുസ്തകം എന്തുകൊണ്ട് കൽപ്പിക്കുന്നുവെന്ന് പഠിക്കുക (എബ്രായർ 10:25), കാരണം ആത്മീയ വളർച്ച, ഉത്തരവാദിത്തം, പ്രോത്സാഹനം, തെറ്റായ പഠിപ്പിക്കലിൽ നിന്നുള്ള സംരക്ഷണം എന്നിവയ്ക്ക് മറ്റ് ക്രിസ്ത്യാനികളുമായി പ്രതിബദ്ധമായ ബന്ധങ്ങൾ ആവശ്യമാണ്. സാധാരണ സാമൂഹികവൽക്കരണത്തേക്കാൾ കൂടുതലായി കൂട്ടായ്മയെ മനസ്സിലാക്കുക - ഇത് ക്രിസ്തുവിലെ പങ്കിട്ട ജീവിതമാണ്, പരസ്പര സ്നേഹം, സത്യം പറയൽ, ഏറ്റുപറച്ചിൽ, പ്രാർത്ഥന, ആത്മീയ വരദാനങ്ങളുടെ പ്രയോഗം എന്നിവയാൽ സവിശേഷമാണ്. ഈ പഠനം സാംസ്കാരിക വ്യക്തിത്വത്തെ വെല്ലുവിളിക്കുകയും ക്രിസ്തുവിന്റെ ശരീരത്തിനുള്ളിൽ ആഴത്തിലുള്ളതും ഉദ്ദേശിച്ചതുമായ ബന്ധങ്ങളിലേക്ക് വിശ്വാസികളെ വിളിക്കുകയും ചെയ്യുന്നു, അവിടെ ഇരുമ്പ് ഇരുമ്പിനെ മൂർച്ചയാക്കുകയും (സദൃശവാക്യങ്ങൾ 27:17) ദൃശ്യമായ സമൂഹത്തിൽ സുവിശേഷം ജീവിക്കുകയും ചെയ്യുന്നു.', 'സഭയും സമൂഹവും'),
  ('333e8400-e29b-41d4-a716-446655440003', 'ml', 'സഭയിൽ സേവനം', 'ദൈവം നൽകിയ ആത്മീയ വരദാനങ്ങൾ ഉപയോഗിച്ച് ക്രിസ്തുവിന്റെ ശരീരത്തിൽ സേവിക്കാൻ ഓരോ വിശ്വാസിയും വിളിക്കപ്പെട്ടിരിക്കുന്നു എന്ന ബൈബിളിലെ സത്യം പഠിക്കുക. സേവനം പ്രൊഫഷണൽ വൈദികർക്ക് മാത്രമായി സംവരണം ചെയ്തിട്ടില്ല, മറിച്ച് സഭയെ പടുത്തുയർത്താൻ പരിശുദ്ധാത്മാവിനാൽ ശക്തീകരിക്കപ്പെട്ട എല്ലാ ക്രിസ്ത്യാനികളുടെയും പദവിയും ഉത്തരവാദിത്തവുമാണെന്ന് മനസ്സിലാക്കുക (1 പത്രോസ് 4:10-11). നിങ്ങളുടെ ആത്മീയ വരദാനങ്ങൾ എങ്ങനെ തിരിച്ചറിയാമെന്നും വിനയത്തോടും വിശ്വസ്തതയോടും കൂടി സേവിക്കാമെന്നും പ്രാദേശിക സഭയുടെ ആരോഗ്യത്തിനും ദൗത്യത്തിനും എങ്ങനെ സംഭാവന നൽകാമെന്നും കണ്ടെത്തുക. ഈ പഠനം ക്രിസ്തീയ സേവനം കൃപയിൽ നിന്നാണ് ഒഴുകുന്നതെന്നും പ്രവൃത്തി-നീതിയിൽ നിന്നല്ലെന്നും ഊന്നിപ്പറയുന്നു - ഇത് ദൈവകൃപയോടുള്ള നന്ദിയുള്ള പ്രതികരണമാണ്, അവന്റെ മഹത്വത്തിനും മറ്റുള്ളവരുടെ നന്മയ്ക്കും വേണ്ടി ചെയ്യുന്നത്, ക്രിസ്തുവിനോടും അവന്റെ സഭയോടുമുള്ള സ്നേഹത്തിൽ വേരൂന്നിയത്.', 'സഭയും സമൂഹവും'),
  ('333e8400-e29b-41d4-a716-446655440004', 'ml', 'ക്രിസ്തുവിൽ ഐക്യം', 'സഭയ്ക്കുള്ളിൽ ഐക്യം പിന്തുടരാനുള്ള ബൈബിളിലെ ആഹ്വാനം പര്യവേക്ഷണം ചെയ്യുക, സുവിശേഷത്തിന്റെ സത്യത്തിൽ അടിസ്ഥാനമാക്കിയതും പരിശുദ്ധാത്മാവിനാൽ ശക്തീകരിക്കപ്പെട്ടതും. ക്രിസ്തീയ ഐക്യം കേവലം യോജിപ്പോ സഹിഷ്ണുതയോ അല്ല, മറിച്ച് ക്രിസ്തുവിലുള്ള പങ്കിട്ട വിശ്വാസത്തിലും വേദപുസ്തകത്തോടുള്ള ഭക്തിയിലും പരസ്പര സ്നേഹത്തിലും വേരൂന്നിയ ആത്മീയ ഏകതയാണെന്ന് പഠിക്കുക (യോഹന്നാൻ 17:20-23). സിദ്ധാന്തപരമായ സത്യം ഉയർത്തിപ്പിടിച്ചുകൊണ്ട് എങ്ങനെ ഐക്യം നിലനിർത്താമെന്നും വിഭജനകരമായ നിയമവാദത്തെയും വിട്ടുവീഴ്ചാപരമായ ബഹുസ്വരതയെയും ഒഴിവാക്കാമെന്നും മനസ്സിലാക്കുക. ഈ പഠനം സ്നേഹത്തോടെ പരസ്പരം സഹിക്കാനും സംഘർഷങ്ങൾ ബൈബിളനുസൃതമായി പരിഹരിക്കാനും നിരീക്ഷിക്കുന്ന ലോകത്തിന് വിശ്വാസികൾക്കിടയിലെ ദൃശ്യമായ സ്നേഹത്തിലൂടെയും യോജിപ്പിലൂടെയും സുവിശേഷത്തിന്റെ ആധികാരികത പ്രകടമാക്കാനും പഠിപ്പിക്കുന്നു, എല്ലാം ദൈവത്തിന്റെ മഹത്വത്തിനും സഭയുടെ സാക്ഷ്യത്തിനും വേണ്ടി.', 'സഭയും സമൂഹവും'),
  ('333e8400-e29b-41d4-a716-446655440005', 'ml', 'ആത്മീയ വരദാനങ്ങളും അവയുടെ ഉപയോഗവും', 'ആത്മീയ വരദാനങ്ങളെക്കുറിച്ചുള്ള ബൈബിളിലെ പഠിപ്പിക്കൽ കണ്ടെത്തുക - സഭയുടെ ആത്മീയവളർച്ചയ്ക്കും ദൈവത്തിന്റെ മഹത്വത്തിനുമായി പരിശുദ്ധാത്മാവ് ഓരോ വിശ്വാസിക്കും നൽകുന്ന കഴിവുകൾ (1 കൊരിന്ത്യർ 12:7). നിങ്ങളുടെ ആത്മീയ വരദാനങ്ങൾ എങ്ങനെ തിരിച്ചറിയാമെന്നും വിശ്വസ്ത സേവനത്തിലൂടെ അവ വികസിപ്പിക്കാമെന്നും ക്രിസ്തുവിന്റെ ശരീരത്തെ ശക്തിപ്പെടുത്താൻ സ്നേഹത്തിലും വിനയത്തിലും അവ ഉപയോഗിക്കാമെന്നും പഠിക്കുക. ആത്മീയ വരദാനങ്ങളുടെ ഉദ്ദേശ്യം മനസ്സിലാക്കുക: വ്യക്തിഗത പ്രശസ്തിയോ സ്വയം പൂർത്തീകരണമോ അല്ല, മറിച്ച് മറ്റുള്ളവരെ വിശ്വാസത്തിലും പക്വതയിലും പടുത്തുയർത്തുക (എഫേസ്യർ 4:11-13). ഈ പഠനം ആത്മീയ വരദാനങ്ങൾ അവഗണിക്കുന്നതിൽ നിന്നും അത്ഭുതകരമായ പ്രകടനങ്ങൾ തേടുന്നതിൽ നിന്നും സംരക്ഷിക്കുകയും സഭയ്ക്കുള്ളിലെ വരദാനങ്ങളുടെ എല്ലാ പ്രകടനങ്ങളിലും മെനഞ്ഞെടുപ്പ്, സേവനം, സ്നേഹത്തിന്റെ പരമോന്നതത എന്നിവയുടെ ബൈബിളിലെ തത്ത്വങ്ങളിൽ നിങ്ങളെ സ്ഥാപിക്കുകയും ചെയ്യുന്നു.', 'സഭയും സമൂഹവും')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Discipleship & Growth (शिष्यत्व और विकास / ശിഷ്യത്വവും വളർച്ചയും)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('444e8400-e29b-41d4-a716-446655440001', 'hi', 'शिष्यत्व क्या है?', 'शिष्यत्व के बाइबिल अर्थ को यीशु मसीह का अनुसरण करने, उससे सीखने और उसकी छवि के अनुरूप होने की आजीवन प्रक्रिया के रूप में खोजें। समझें कि शिष्यत्व मसीहियों के लिए वैकल्पिक नहीं है - यह सामान्य मसीही जीवन है, जो मसीह की आज्ञाओं के पालन, पवित्र आत्मा पर निर्भरता और ईश्वरीयता में विकास की विशेषता है (मत्ती 28:19-20)। जानें कि शिष्यत्व में स्वयं को मरना, प्रतिदिन अपना क्रूस उठाना और सब से ऊपर मसीह को प्राथमिकता देना शामिल है (लूका 9:23)। यह अध्ययन स्पष्ट करता है कि शिष्यत्व आत्म-सुधार या नैतिक प्रयास नहीं है, बल्कि मसीह के साथ संघ में निहित, उसके अनुग्रह से निरंतर, और उसकी महिमा और अन्य शिष्यों को बनाने के मिशन की ओर निर्देशित आत्मा-सशक्त परिवर्तन है।', 'शिष्यत्व और विकास'),
  ('444e8400-e29b-41d4-a716-446655440002', 'hi', 'यीशु का अनुसरण करने की कीमत', 'गंभीर लेकिन महिमामय वास्तविकता को समझें कि यीशु का अनुसरण करने के लिए कीमत गिनने और प्रभु के रूप में सब कुछ उसे समर्पित करने की आवश्यकता है। जानें कि यीशु शिष्यों को स्वयं को इनकार करने, अपना क्रूस उठाने और उसके लिए अपना जीवन खोने के लिए कैसे बुलाता है (मरकुस 8:34-35)। खोजें कि शिष्यत्व में त्याग, पीड़ा, अस्वीकृति और सांसारिक सुखों की हानि शामिल हो सकती है - लेकिन यह मसीह को जानने का अत्यधिक आनंद और अनन्त जीवन की प्रतिज्ञा भी लाता है। यह अध्ययन सस्ते अनुग्रह और सांस्कृतिक मसीहियत से बचाता है, विश्वासियों को यीशु के प्रति पूर्ण हृदय से समर्पण के लिए बुलाता है, जहां आज्ञाकारिता प्रेम से प्रवाहित होती है, त्याग आनंददायक है, और शिष्यत्व की कीमत स्वयं मसीह के खजाने से कहीं अधिक है।', 'शिष्यत्व और विकास'),
  ('444e8400-e29b-41d4-a716-446655440003', 'hi', 'फल लाना', 'सच्चे विश्वास और हम में आत्मा के कार्य के प्रमाण के रूप में आत्मिक फल लाने का क्या अर्थ है, यह जानना, उद्धार कमाने के साधन के रूप में नहीं।', 'शिष्यत्व और विकास'),
  ('444e8400-e29b-41d4-a716-446655440004', 'hi', 'महान आज्ञा', 'यीशु की अपने शिष्यों को अंतिम आज्ञा को खोजें: "इसलिए जाओ, सभी राष्ट्रों के शिष्य बनाओ, उन्हें बपतिस्मा दो और उन्हें वह सब कुछ मानना सिखाओ जो मैंने तुम्हें आज्ञा दी है" (मत्ती 28:19-20)। जानें कि महान आज्ञा केवल मिशनरियों या पादरियों के लिए नहीं है, बल्कि हर विश्वासी के लिए है जो हर जनजाति, भाषा और राष्ट्र से लोगों को इकट्ठा करने की परमेश्वर की छुटकारे की योजना में भागीदार हैं। आवश्यक तत्वों को समझें: सुसमाचार के साथ जाना, शिष्य बनाना (केवल धर्मान्तरित नहीं), वाचा सदस्यता के संकेत के रूप में बपतिस्मा देना, और मसीह की आज्ञाकारिता सिखाना। यह अध्ययन मसीह के अधिकार में विश्वास में आधारित, आत्मा की उपस्थिति से सशक्त, और परमेश्वर की महिमा और खोए हुओं के उद्धार के लिए प्रेम से प्रेरित वफादार सुसमाचार प्रचार और शिष्यत्व को प्रेरित करता है।', 'शिष्यत्व और विकास'),
  ('444e8400-e29b-41d4-a716-446655440005', 'hi', 'दूसरों का मार्गदर्शन', 'आत्मिक मार्गदर्शन के बाइबिल मॉडल को सीखें, जहां परिपक्व विश्वासी युवा मसीहियों में शिक्षण, ईश्वरीयता का मॉडलिंग, और प्रोत्साहन और जवाबदेही प्रदान करके निवेश करते हैं (2 तीमुथियुस 2:2)। समझें कि मार्गदर्शन श्रेष्ठता या पूर्णता के बारे में नहीं है, बल्कि विनम्रता से प्राप्त अनुग्रह को साझा करना, दूसरों को मसीह की ओर इशारा करना, और उन्हें विश्वास और आज्ञाकारिता में बढ़ने में मदद करना है। पवित्रशास्त्र अध्ययन, प्रार्थना, ईमानदार बातचीत और जानबूझकर शिष्यत्व संबंधों के माध्यम से दूसरों को सलाह देने के व्यावहारिक तरीकों की खोज करें। यह अध्ययन इस बात पर जोर देता है कि मार्गदर्शन एक विशेषाधिकार और जिम्मेदारी दोनों है, जो आपके अपने जीवन में परमेश्वर के कार्य के प्रवाह से बहती है और परमेश्वर की महिमा के लिए पीढ़ियों में वफादार शिष्यों के गुणन में योगदान देती है।', 'शिष्यत्व और विकास')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('444e8400-e29b-41d4-a716-446655440001', 'ml', 'ശിഷ്യത്വം എന്താണ്?', 'യേശുക്രിസ്തുവിനെ അനുഗമിക്കുകയും അവനിൽ നിന്ന് പഠിക്കുകയും അവന്റെ പ്രതിരൂപത്തിൽ മാറുകയും ചെയ്യുന്ന ആജീവനാന്ത പ്രക്രിയയെന്ന നിലയിൽ ശിഷ്യത്വത്തിന്റെ ബൈബിളിലെ അർത്ഥം പര്യവേക്ഷണം ചെയ്യുക. ശിഷ്യത്വം ക്രിസ്ത്യാനികൾക്ക് ഐച്ഛികമല്ലെന്ന് മനസ്സിലാക്കുക - ഇത് സാധാരണ ക്രിസ്തീയ ജീവിതമാണ്, ക്രിസ്തുവിന്റെ കൽപ്പനകളോടുള്ള അനുസരണം, പരിശുദ്ധാത്മാവിനോടുള്ള ആശ്രയത്വം, ദൈവഭക്തിയിലെ വളർച്ച എന്നിവയാൽ സവിശേഷമാണ് (മത്തായി 28:19-20). ശിഷ്യത്വത്തിൽ സ്വയം മരിക്കുക, നിത്യം നിങ്ങളുടെ കുരിശ് വഹിക്കുക, എല്ലാറ്റിനും മുകളിൽ ക്രിസ്തുവിന് മുൻഗണന നൽകുക എന്നിവ ഉൾപ്പെടുന്നുവെന്ന് പഠിക്കുക (ലൂക്കോസ് 9:23). ഈ പഠനം ശിഷ്യത്വം സ്വയം മെച്ചപ്പെടുത്തലോ ധാർമ്മിക പ്രയത്നമോ അല്ല, മറിച്ച് ക്രിസ്തുവുമായുള്ള ഐക്യത്തിൽ വേരൂന്നിയതും അവന്റെ കൃപയാൽ സുസ്ഥിരമാക്കപ്പെട്ടതും അവന്റെ മഹത്വത്തിലേക്കും മറ്റ് ശിഷ്യന്മാരെ ഉണ്ടാക്കുന്ന ദൗത്യത്തിലേക്കും നയിക്കപ്പെടുന്നതുമായ ആത്മാവിനാൽ ശക്തീകരിക്കപ്പെട്ട പരിവർത്തനമാണെന്ന് വ്യക്തമാക്കുന്നു.', 'ശിഷ്യത്വവും വളർച്ചയും'),
  ('444e8400-e29b-41d4-a716-446655440002', 'ml', 'യേശുവിനെ അനുഗമിക്കുന്നതിന്റെ വില', 'യേശുവിനെ അനുഗമിക്കുന്നതിന് വില കണക്കാക്കുകയും എല്ലാം കർത്താവെന്ന നിലയിൽ അവനു സമർപ്പിക്കുകയും ചെയ്യേണ്ടതുണ്ടെന്ന ഗൗരവമേറിയതും എന്നാൽ മഹത്വമുള്ളതുമായ യാഥാർത്ഥ്യം മനസ്സിലാക്കുക. യേശു ശിഷ്യന്മാരെ സ്വയം നിഷേധിക്കാനും അവരുടെ കുരിശ് വഹിക്കാനും അവന്റെ നിമിത്തം തങ്ങളുടെ ജീവൻ നഷ്ടപ്പെടുത്താനും എങ്ങനെ വിളിക്കുന്നുവെന്ന് പഠിക്കുക (മർക്കൊസ് 8:34-35). ശിഷ്യത്വത്തിൽ ത്യാഗം, കഷ്ടത, നിരാകരണം, ലൗകിക സുഖങ്ങളുടെ നഷ്ടം എന്നിവ ഉൾപ്പെട്ടേക്കാമെന്ന് - എന്നാൽ അത് ക്രിസ്തുവിനെ അറിയുന്നതിന്റെ അതിശയകരമായ സന്തോഷവും നിത്യജീവന്റെ വാഗ്ദാനവും കൊണ്ടുവരുന്നുവെന്ന് കണ്ടെത്തുക. ഈ പഠനം വിലകുറഞ്ഞ കൃപയ്ക്കും സാംസ്കാരിക ക്രിസ്തുമതത്തിനും എതിരായി സംരക്ഷിക്കുകയും യേശുവിനോടുള്ള പൂർണ്ണഹൃദയത്തോടെയുള്ള ഭക്തിയിലേക്ക് വിശ്വാസികളെ വിളിക്കുകയും ചെയ്യുന്നു, അവിടെ അനുസരണം സ്നേഹത്തിൽ നിന്ന് ഒഴുകുന്നു, ത്യാഗം സന്തോഷകരമാണ്, ശിഷ്യത്വത്തിന്റെ വില ക്രിസ്തുവെന്ന നിധിയേക്കാൾ വളരെ കൂടുതലാണ്.', 'ശിഷ്യത്വവും വളർച്ചയും'),
  ('444e8400-e29b-41d4-a716-446655440003', 'ml', 'ഫലം കായ്ക്കൽ', 'യഥാർത്ഥ വിശ്വാസത്തിന്റെയും നമ്മിലെ ആത്മാവിന്റെ പ്രവർത്തിയുടെയും തെളിവായി ആത്മീയ ഫലം കായ്ക്കുക എന്നതിന്റെ അർത്ഥം പര്യവേക്ഷണം ചെയ്യുക, രക്ഷ സമ്പാദിക്കുന്നതിനുള്ള മാർഗമായിട്ടല്ല.', 'ശിഷ്യത്വവും വളർച്ചയും'),
  ('444e8400-e29b-41d4-a716-446655440004', 'ml', 'മഹാനിയോഗം', 'യേശു തന്റെ ശിഷ്യന്മാർക്ക് നൽകിയ അവസാന കൽപ്പന പര്യവേക്ഷണം ചെയ്യുക: "അതുകൊണ്ട് പോയി എല്ലാ ജനതകളെയും ശിഷ്യന്മാരാക്കുവിൻ, അവരെ സ്നാനം കഴിപ്പിച്ച് ഞാൻ നിങ്ങളോട് കൽപ്പിച്ചതെല്ലാം അനുസരിക്കാൻ പഠിപ്പിക്കുവിൻ" (മത്തായി 28:19-20). മഹാനിയോഗം മിഷണറിമാർക്കോ പാസ്റ്റർമാർക്കോ മാത്രമല്ല, മറിച്ച് എല്ലാ ഗോത്രങ്ങളിൽ നിന്നും ഭാഷകളിൽ നിന്നും ജനതകളിൽ നിന്നും ജനങ്ങളെ ശേഖരിക്കാനുള്ള ദൈവത്തിന്റെ വീണ്ടെടുപ്പ് പദ്ധതിയിൽ പങ്കാളികളായ ഓരോ വിശ്വാസിക്കുമാണെന്ന് പഠിക്കുക. അവശ്യ ഘടകങ്ങൾ മനസ്സിലാക്കുക: സുവിശേഷവുമായി പോകുക, ശിഷ്യന്മാരെ ഉണ്ടാക്കുക (കേവലം മതപരിവർത്തനം ചെയ്യപ്പെട്ടവരെയല്ല), ഉടമ്പടി അംഗത്വത്തിന്റെ അടയാളമായി സ്നാനം നൽകുക, ക്രിസ്തുവിനോടുള്ള അനുസരണം പഠിപ്പിക്കുക. ഈ പഠനം ക്രിസ്തുവിന്റെ അധികാരത്തിലുള്ള ആത്മവിശ്വാസത്തിൽ അടിസ്ഥാനമാക്കിയതും ആത്മാവിന്റെ സാന്നിധ്യത്താൽ ശക്തീകരിക്കപ്പെട്ടതും ദൈവത്തിന്റെ മഹത്വത്തോടും നഷ്ടപ്പെട്ടവരുടെ രക്ഷയോടുമുള്ള സ്നേഹത്താൽ പ്രചോദിതമായതുമായ വിശ്വസ്ത സുവിശേഷവൽക്കരണവും ശിഷ്യത്വവും പ്രചോദിപ്പിക്കുന്നു.', 'ശിഷ്യത്വവും വളർച്ചയും'),
  ('444e8400-e29b-41d4-a716-446655440005', 'ml', 'മറ്റുള്ളവരെ നയിക്കുക', 'ആത്മീയ മാർഗനിർദേശത്തിന്റെ ബൈബിളിലെ മാതൃക പഠിക്കുക, അവിടെ പക്വമായ വിശ്വാസികൾ യുവ ക്രിസ്ത്യാനികളിൽ പഠിപ്പിക്കുകയും ദൈവഭക്തി മാതൃകയാക്കുകയും പ്രോത്സാഹനവും ഉത്തരവാദിത്തവും നൽകി നിക്ഷേപിക്കുകയും ചെയ്യുന്നു (2 തിമൊഥെയൊസ് 2:2). മാർഗനിർദേശം ശ്രേഷ്ഠതയെക്കുറിച്ചോ പൂർണതയെക്കുറിച്ചോ അല്ലെന്ന് മനസ്സിലാക്കുക, മറിച്ച് നിങ്ങൾക്ക് ലഭിച്ച കൃപ വിനയത്തോടെ പങ്കുവെക്കുകയും മറ്റുള്ളവരെ ക്രിസ്തുവിലേക്ക് ചൂണ്ടിക്കാണിക്കുകയും അവരെ വിശ്വാസത്തിലും അനുസരണത്തിലും വളരാൻ സഹായിക്കുകയും ചെയ്യുക. വേദപുസ്തക പഠനം, പ്രാർത്ഥന, സത്യസന്ധമായ സംഭാഷണം, ഉദ്ദേശപൂർവമുള്ള ശിഷ്യത്വ ബന്ധങ്ങൾ എന്നിവയിലൂടെ മറ്റുള്ളവരെ എങ്ങനെ നയിക്കാമെന്ന് പ്രായോഗിക മാർഗങ്ങൾ കണ്ടെത്തുക. ഈ പഠനം മാർഗനിർദേശം ഒരു പദവിയും ഉത്തരവാദിത്തവുമാണെന്നും നിങ്ങളുടെ സ്വന്തം ജീവിതത്തിൽ ദൈവത്തിന്റെ പ്രവർത്തിയുടെ ഓവർഫ്ലോയിൽ നിന്ന് ഒഴുകുന്നതാണെന്നും ദൈവമഹത്വത്തിനായി തലമുറകളിലുടനീളം വിശ്വസ്ത ശിഷ്യന്മാരുടെ ഗുണനത്തിന് സംഭാവന നൽകുന്നുവെന്നും ഊന്നിപ്പറയുന്നു.', 'ശിഷ്യത്വവും വളർച്ചയും')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Spiritual Disciplines (आत्मिक अनुशासन / ആത്മീയ അനുശാസനം)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('555e8400-e29b-41d4-a716-446655440001', 'hi', 'दैनिक भक्ति', 'परमेश्वर के साथ दैनिक भक्ति समय के आवश्यक अभ्यास की खोज करें - पवित्रशास्त्र पढ़ने, प्रार्थना करने और प्रभु के साथ संगति के लिए नियमित क्षण निर्धारित करना। जानें कि दैनिक भक्ति परमेश्वर का पक्ष पाने के लिए कानूनी अनुष्ठान नहीं हैं, बल्कि अनुग्रह के महत्वपूर्ण साधन हैं जो आपकी आत्मा को पोषित करते हैं, परमेश्वर के साथ आपके रिश्ते को गहरा करते हैं, और मसीह के साथ आपकी चाल को बनाए रखते हैं। समझें कि परमेश्वर के वचन और प्रार्थना में लगातार समय विश्वास को कैसे मजबूत करता है, मार्गदर्शन प्रदान करता है, आपके मन को नवीनीकृत करता है, और आपको आत्मिक लड़ाइयों के लिए सुसज्जित करता है (इफिसियों 6:10-18)। यह अध्ययन भक्ति की स्थायी लय स्थापित करने के लिए व्यावहारिक मार्गदर्शन प्रदान करता है, इस बात पर जोर देते हुए कि लक्ष्य केवल धार्मिक कर्तव्य नहीं है बल्कि परमेश्वर में आनंद लेना, पवित्रता में बढ़ना और रोज मसीह में बने रहना है।', 'आत्मिक अनुशासन'),
  ('555e8400-e29b-41d4-a716-446655440002', 'hi', 'उपवास और प्रार्थना', 'उपवास और प्रार्थना को परमेश्वर पर ध्यान केंद्रित करने के लिए आत्मिक अनुशासन के रूप में खोजना, परमेश्वर में हेरफेर करने या उसका पक्ष पाने के साधन के रूप में नहीं।', 'आत्मिक अनुशासन'),
  ('555e8400-e29b-41d4-a716-446655440003', 'hi', 'जीवनशैली के रूप में आराधना', 'सीखना कि आराधना गीतों से अधिक है - यह मसीह के माध्यम से परमेश्वर के प्रति कृतज्ञ आज्ञाकारिता में सारा जीवन जीना है।', 'आत्मिक अनुशासन'),
  ('555e8400-e29b-41d4-a716-446655440004', 'hi', 'परमेश्वर के वचन पर मनन', 'परमेश्वर के वचन पर मनन के बाइबिल अभ्यास को सीखें - खाली-दिमाग पूर्वी रहस्यवाद नहीं, बल्कि दैवीय सत्य को समझने, आंतरिक बनाने और लागू करने के लिए पवित्रशास्त्र पर केंद्रित, प्रार्थनापूर्ण चिंतन। खोजें कि मनन में पवित्रशास्त्र को धीरे-धीरे पढ़ना, इसके अर्थ पर विचार करना, इसके माध्यम से प्रार्थना करना और पवित्र आत्मा को आपके हृदय और मन को प्रबुद्ध और परिवर्तित करने की अनुमति देना शामिल है (भजन 1:2-3)। समझें कि परमेश्वर के वचन पर मनन विश्वास को कैसे मजबूत करता है, सोच को नवीनीकृत करता है, पाप को उजागर करता है, और आपको मसीह की छवि के अनुरूप बनाता है। यह अध्ययन आपको सतही बाइबिल पढ़ने से पवित्रशास्त्र के साथ गहरी सगाई की ओर ले जाने के लिए सुसज्जित करता है, जहां परमेश्वर का सत्य आपकी आत्मा में जड़ें लेता है और स्थायी आत्मिक फल और मसीह-समान चरित्र उत्पन्न करता है।', 'आत्मिक अनुशासन'),
  ('555e8400-e29b-41d4-a716-446655440005', 'hi', 'परमेश्वर के साथ चलने की डायरी', 'आत्मिक डायरी लेखन के अभ्यास को परमेश्वर की वफादारी को रिकॉर्ड करने, आपके आत्मिक विकास को ट्रैक करने और लिखित चिंतन के माध्यम से मसीह के साथ अपनी चाल को संसाधित करने के साधन के रूप में खोजें। जानें कि डायरी में प्रार्थनाओं को रिकॉर्ड करना, प्रार्थनाओं के उत्तर, पवित्रशास्त्र से अंतर्दृष्टि, पाप की स्वीकारोक्ति, कृतज्ञता की अभिव्यक्ति और आपके जीवन में परमेश्वर के प्रावधान पर प्रतिबिंब शामिल हो सकता है। समझें कि डायरी साहित्यिक कौशल या प्रदर्शन के बारे में नहीं है, बल्कि परमेश्वर के साथ ईमानदार संगति और उसके सामने जानबूझकर आत्म-परीक्षा के बारे में है। यह अध्ययन दिखाता है कि कैसे डायरी परमेश्वर के कार्य की अधिक जागरूकता, गहरी कृतज्ञता और स्पष्ट आत्मिक विवेक को बढ़ावा देती है, परमेश्वर के अनुग्रह की व्यक्तिगत गवाही और चल रहे पवित्रीकरण और उसकी भलाई की स्मृति के उपकरण के रूप में सेवा करती है।', 'आत्मिक अनुशासन')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('555e8400-e29b-41d4-a716-446655440001', 'ml', 'ദിവസേനയുള്ള ഭക്തി', 'ദൈവവുമായുള്ള ദിവസേനയുള്ള ഭക്തി സമയത്തിന്റെ അത്യാവശ്യ സമ്പ്രദായം കണ്ടെത്തുക - വേദപുസ്തകം വായിക്കാനും പ്രാർത്ഥിക്കാനും കർത്താവുമായി കൂട്ടായ്മ നടത്താനും പതിവ് നിമിഷങ്ങൾ നീക്കിവയ്ക്കുക. ദൈവകൃപ നേടുന്നതിനുള്ള നിയമപരമായ ആചാരങ്ങളല്ല, മറിച്ച് നിങ്ങളുടെ ആത്മാവിനെ പോഷിപ്പിക്കുന്നതും ദൈവവുമായുള്ള നിങ്ങളുടെ ബന്ധം ആഴപ്പെടുത്തുന്നതും ക്രിസ്തുവുമായുള്ള നിങ്ങളുടെ നടത്തം നിലനിർത്തുന്നതുമായ കൃപയുടെ സുപ്രധാന മാർഗങ്ങളാണ് ദൈനംദിന ഭക്തി എന്ന് പഠിക്കുക. ദൈവവചനത്തിലും പ്രാർത്ഥനയിലുമുള്ള സ്ഥിരമായ സമയം എങ്ങനെ വിശ്വാസത്തെ ശക്തിപ്പെടുത്തുന്നുവെന്നും മാർഗനിർദേശം നൽകുന്നുവെന്നും നിങ്ങളുടെ മനസ്സ് പുതുക്കുന്നുവെന്നും ആത്മീയ പോരാട്ടങ്ങൾക്കായി നിങ്ങളെ സജ്ജമാക്കുന്നുവെന്നും മനസ്സിലാക്കുക (എഫെസ്യർ 6:10-18). ഈ പഠനം ഭക്തിയുടെ സുസ്ഥിരമായ താളം സ്ഥാപിക്കുന്നതിനുള്ള പ്രായോഗിക മാർഗനിർദേശം നൽകുന്നു, ലക്ഷ്യം കേവലം മതപരമായ കടമയല്ല, മറിച്ച് ദൈവത്തിൽ ആനന്ദിക്കുകയും വിശുദ്ധതയിൽ വളരുകയും ദിവസേന ക്രിസ്തുവിൽ വസിക്കുകയും ചെയ്യുക എന്നതാണെന്ന് ഊന്നിപ്പറയുന്നു.', 'ആത്മീയ അനുശാസനം'),
  ('555e8400-e29b-41d4-a716-446655440002', 'ml', 'ഉപവാസവും പ്രാർത്ഥനയും', 'ദൈവത്തിൽ ശ്രദ്ധ കേന്ദ്രീകരിക്കുന്നതിനുള്ള ആത്മീയ അനുശാസനങ്ങളായി ഉപവാസവും പ്രാർത്ഥനയും കണ്ടെത്തുക, ദൈവത്തെ കൈകാര്യം ചെയ്യാനോ അവന്റെ പ്രീതി നേടാനോ ഉള്ള മാർഗമായിട്ടല്ല.', 'ആത്മീയ അനുശാസനം'),
  ('555e8400-e29b-41d4-a716-446655440003', 'ml', 'ജീവിതരീതിയെന്ന നിലയിൽ ആരാധന', 'ആരാധന പാട്ടുകളേക്കാൾ കൂടുതലാണെന്ന് പഠിക്കുക - ഇത് ക്രിസ്തുവിലൂടെ ദൈവത്തോടുള്ള നന്ദിയുള്ള അനുസരണത്തിൽ എല്ലാ ജീവിതവും ജീവിക്കുകയാണ്.', 'ആത്മീയ അനുശാസനം'),
  ('555e8400-e29b-41d4-a716-446655440004', 'ml', 'ദൈവവചനത്തിൽ ധ്യാനിക്കൽ', 'ദൈവവചനത്തിൽ ധ്യാനിക്കുന്നതിന്റെ ബൈബിളിലെ സമ്പ്രദായം പഠിക്കുക - ശൂന്യമായ മനസ്സുള്ള പൗരസ്ത്യ മിസ്റ്റിസിസമല്ല, മറിച്ച് ദൈവീക സത്യം മനസ്സിലാക്കാനും ആന്തരികമാക്കാനും പ്രയോഗിക്കാനും വേദപുസ്തകത്തിൽ കേന്ദ്രീകൃതവും പ്രാർത്ഥനാപൂർവകവുമായ പ്രതിഫലനം. ധ്യാനത്തിൽ വേദപുസ്തകം സാവധാനം വായിക്കുക, അതിന്റെ അർത്ഥം ചിന്തിക്കുക, അതിലൂടെ പ്രാർത്ഥിക്കുക, നിങ്ങളുടെ ഹൃദയത്തെയും മനസ്സിനെയും പ്രകാശിപ്പിക്കാനും രൂപാന്തരപ്പെടുത്താനും പരിശുദ്ധാത്മാവിനെ അനുവദിക്കുക എന്നിവ ഉൾപ്പെടുന്നുവെന്ന് കണ്ടെത്തുക (സങ്കീർത്തനം 1:2-3). ദൈവവചനത്തെക്കുറിച്ചുള്ള ധ്യാനം വിശ്വാസത്തെ എങ്ങനെ ശക്തിപ്പെടുത്തുന്നുവെന്നും ചിന്തയെ പുതുക്കുന്നുവെന്നും പാപത്തെ തുറന്നുകാട്ടുന്നുവെന്നും നിങ്ങളെ ക്രിസ്തുവിന്റെ പ്രതിരൂപത്തിലേക്ക് മാറ്റുന്നുവെന്നും മനസ്സിലാക്കുക. ഈ പഠനം ഉപരിപ്ലവമായ ബൈബിൾ വായനയിൽ നിന്ന് വേദപുസ്തകവുമായുള്ള ആഴത്തിലുള്ള ഇടപെടലിലേക്ക് നിങ്ങളെ നയിക്കാൻ സജ്ജമാക്കുന്നു, അവിടെ ദൈവത്തിന്റെ സത്യം നിങ്ങളുടെ ആത്മാവിൽ വേരൂന്നുകയും ശാശ്വതമായ ആത്മീയ ഫലവും ക്രിസ്തുവിനെപ്പോലെയുള്ള സ്വഭാവവും ഉത്പാദിപ്പിക്കുകയും ചെയ്യുന്നു.', 'ആത്മീയ അനുശാസനം'),
  ('555e8400-e29b-41d4-a716-446655440005', 'ml', 'ദൈവവുമായുള്ള നിങ്ങളുടെ നടത്തം ജേർണലിംഗ് ചെയ്യുക', 'ദൈവത്തിന്റെ വിശ്വസ്തത രേഖപ്പെടുത്തുന്നതിനും നിങ്ങളുടെ ആത്മീയ വളർച്ച ട്രാക്ക് ചെയ്യുന്നതിനും എഴുതപ്പെട്ട പ്രതിഫലനത്തിലൂടെ ക്രിസ്തുവുമായുള്ള നിങ്ങളുടെ നടത്തം പ്രോസസ്സ് ചെയ്യുന്നതിനുമുള്ള ഒരു മാർഗമായി ആത്മീയ ജേർണലിംഗിന്റെ സമ്പ്രദായം പര്യവേക്ഷണം ചെയ്യുക. ജേർണലിംഗിൽ പ്രാർത്ഥനകൾ, പ്രാർത്ഥനകൾക്കുള്ള ഉത്തരങ്ങൾ, വേദപുസ്തകത്തിൽ നിന്നുള്ള ഉൾക്കാഴ്ചകൾ, പാപത്തിന്റെ ഏറ്റുപറച്ചിൽ, നന്ദിയുടെ പ്രകടനങ്ങൾ, നിങ്ങളുടെ ജീവിതത്തിൽ ദൈവത്തിന്റെ പ്രൊവിഡൻസിനെക്കുറിച്ചുള്ള പ്രതിഫലനങ്ങൾ എന്നിവ രേഖപ്പെടുത്താൻ കഴിയുമെന്ന് പഠിക്കുക. ജേർണലിംഗ് സാഹിത്യ വൈദഗ്ധ്യത്തെക്കുറിച്ചോ പ്രകടനത്തെക്കുറിച്ചോ അല്ലെന്ന് മനസ്സിലാക്കുക, മറിച്ച് ദൈവവുമായുള്ള സത്യസന്ധമായ കൂട്ടായ്മയെക്കുറിച്ചും അവന്റെ മുമ്പിൽ ഉദ്ദേശപൂർവമായ ആത്മപരിശോധനയെക്കുറിച്ചുമാണ്. ജേർണലിംഗ് ദൈവത്തിന്റെ പ്രവർത്തനത്തെക്കുറിച്ചുള്ള കൂടുതൽ അവബോധം, ആഴത്തിലുള്ള നന്ദി, വ്യക്തമായ ആത്മീയ വിവേചനം എന്നിവ എങ്ങനെ വളർത്തുന്നുവെന്ന് ഈ പഠനം കാണിക്കുന്നു, ദൈവകൃപയുടെ വ്യക്തിഗത സാക്ഷ്യമായും തുടർച്ചയായ വിശുദ്ധീകരണത്തിനും അവന്റെ നന്മയുടെ സ്മരണയ്ക്കുമുള്ള ഉപകരണമായും സേവിക്കുന്നു.', 'ആത്മീയ അനുശാസനം')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Apologetics & Defense of Faith (धर्मशास्त्र और विश्वास की रक्षा / ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('666e8400-e29b-41d4-a716-446655440001', 'hi', 'हम एक ईश्वर में विश्वास क्यों करते हैं', 'एकेश्वरवाद के बाइबिल सिद्धांत को खोजें - सत्य कि केवल एक सच्चा परमेश्वर है, शाश्वत, स्व-अस्तित्व और सारी सृष्टि पर संप्रभु (व्यवस्थाविवरण 6:4; यशायाह 44:6)। जानें कि पवित्रशास्त्र लगातार परमेश्वर को आराधना के योग्य एकमात्र देवता के रूप में कैसे प्रकट करता है, आसपास की संस्कृतियों के बहुदेववाद और आधुनिक बहुलवादी दावों के विपरीत। समझें कि मसीही एकेश्वरवाद त्रिएकत्ववादी है: तीन व्यक्तियों में एक परमेश्वर - पिता, पुत्र और पवित्र आत्मा - विशिष्ट लेकिन सार में एकजुट। यह अध्ययन आपको झूठे धर्मों, मूर्तिपूजा और सापेक्षवाद के खिलाफ बाइबिल के परमेश्वर की विशिष्टता की रक्षा करने के लिए सुसज्जित करता है, आपके विश्वास को पवित्रशास्त्र की स्पष्ट गवाही में आधारित करता है और आपको परमेश्वर की एकवचन महिमा और महिमा की सच्चाई को स्पष्ट करने के लिए तैयार करता है।', 'धर्मशास्त्र और विश्वास की रक्षा'),
  ('666e8400-e29b-41d4-a716-446655440002', 'hi', 'यीशु की विशिष्टता', 'खोजें कि यीशु मसीह उद्धार का एकमात्र मार्ग क्यों है, जैसा कि उन्होंने स्वयं घोषित किया: "मैं मार्ग और सत्य और जीवन हूं। कोई भी पिता के पास नहीं आता सिवाय मेरे द्वारा" (यूहन्ना 14:6)। जानें कि यीशु की अद्वितीय पहचान परमेश्वर के अवतार के रूप में, उनका निष्पाप जीवन, प्रतिस्थापनात्मक मृत्यु और शारीरिक पुनरुत्थान उन्हें परमेश्वर और मानवता के बीच एकमात्र मध्यस्थ कैसे बनाता है (1 तीमुथियुस 2:5)। समझें कि धार्मिक बहुलवाद - यह विचार कि सभी मार्ग परमेश्वर की ओर ले जाते हैं - पवित्रशास्त्र और सुसमाचार दोनों का खंडन क्यों करता है। यह अध्ययन आपको बाइबिल सत्य में आधारित और खोए हुओं के लिए प्रेम और परमेश्वर की महिमा के लिए उत्साह से प्रेरित, बहुलवादी दुनिया में कृपापूर्वक लेकिन दृढ़ता से मसीह के अनन्य दावों की घोषणा करने के लिए सुसज्जित करता है।', 'धर्मशास्त्र और विश्वास की रक्षा'),
  ('666e8400-e29b-41d4-a716-446655440003', 'hi', 'क्या बाइबिल विश्वसनीय है?', 'प्रेरित, त्रुटिहीन परमेश्वर के वचन के रूप में बाइबिल की विश्वसनीयता और भरोसेमंदता के लिए सम्मोहक साक्ष्य की जांच करें। जानें कि कैसे पांडुलिपि साक्ष्य, पुरातात्विक खोजें, पूर्ण भविष्यवाणी, आंतरिक स्थिरता और पवित्र आत्मा की गवाही सभी पवित्रशास्त्र की दैवीय उत्पत्ति और अधिकार की पुष्टि करती हैं। समझें कि बाइबिल की विश्वसनीयता मानव राय या विद्वानों की सहमति पर आधारित नहीं है, बल्कि सत्य के परमेश्वर के चरित्र पर जो झूठ नहीं बोल सकता। यह अध्ययन आपको संशयवादियों की आपत्तियों का उत्तर देने, परमेश्वर के वचन में अपने विश्वास को मजबूत करने, और सिद्धांत और जीवन के सभी मामलों में विश्वास और अभ्यास के लिए अंतिम अधिकार के रूप में पवित्रशास्त्र की नींव पर दृढ़ रहने के लिए सुसज्जित करता है।', 'धर्मशास्त्र और विश्वास की रक्षा'),
  ('666e8400-e29b-41d4-a716-446655440004', 'hi', 'अन्य धर्मों से सामान्य प्रश्नों का जवाब', 'अन्य धर्मों के लोगों के साथ सम्मानपूर्वक और बाइबिल के अनुसार कैसे जुड़ें, सत्य और अनुग्रह दोनों के साथ ईसाई धर्म के बारे में उनके प्रश्नों का उत्तर दें (1 पतरस 3:15-16)। हिंदू धर्म, इस्लाम, बौद्ध धर्म और अन्य धर्मों से सामान्य आपत्तियों को कैसे समझें और पवित्रशास्त्र में निहित स्पष्ट सुसमाचार-केंद्रित उत्तरों के साथ जवाब दें। विश्वास की रक्षा (धर्मशास्त्र) और मसीह-समान प्रेम और विनम्रता प्रदर्शित करने के बीच संतुलन को समझें। यह अध्ययन आपको सुसमाचार की विशिष्टता को स्पष्ट करने, झूठे धर्मों की अपर्याप्तता को उजागर करने और दूसरों को एकमात्र उद्धारकर्ता यीशु की ओर इशारा करने के लिए तैयार करता है - सभी कोमलता, सम्मान और उन लोगों की आत्माओं के लिए वास्तविक चिंता की मुद्रा बनाए रखते हुए जो अभी तक मसीह को नहीं जानते।', 'धर्मशास्त्र और विश्वास की रक्षा'),
  ('666e8400-e29b-41d4-a716-446655440005', 'hi', 'उत्पीड़न में दृढ़ रहना', 'मसीह के लिए उत्पीड़न और विरोध सहने के लिए बाइबिल प्रोत्साहन और व्यावहारिक ज्ञान की खोज करें। जानें कि कैसे यीशु ने वादा किया कि उनके अनुयायियों को क्लेश का सामना करना पड़ेगा (यूहन्ना 16:33), फिर भी उन्होंने अपनी उपस्थिति, शक्ति और अंतिम विजय का भी वादा किया। समझें कि उत्पीड़न परमेश्वर की अनुपस्थिति का संकेत नहीं है बल्कि अक्सर सच्चे शिष्यत्व का चिह्न है (2 तीमुथियुस 3:12)। यह अध्ययन सिखाता है कि पीड़ा के माध्यम से विश्वास में कैसे दृढ़ रहें, समझौता करने या मसीह को नकारने के प्रलोभन का विरोध करें, और उसकी पीड़ाओं में साझा करने में आनंद पाएं (1 पतरस 4:12-14)। पवित्रशास्त्र की प्रतिज्ञाओं में आधारित, पवित्र आत्मा द्वारा निर्वाह, और मसीह के प्रति वफादार रहने वालों की प्रतीक्षा करने वाले शाश्वत पुरस्कार में आश्वस्त आशा के साथ कठिनाई सहने के लिए सुसज्जित हों।', 'धर्मशास्त्र और विश्वास की रक्षा')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('666e8400-e29b-41d4-a716-446655440001', 'ml', 'നമ്മൾ ഒരു ദൈവത്തിൽ വിശ്വസിക്കുന്നത് എന്തുകൊണ്ട്', 'ഏകദൈവാരാധനയുടെ ബൈബിളിലെ ഉപദേശം പര്യവേക്ഷണം ചെയ്യുക - ഒരേയൊരു യഥാർത്ഥ ദൈവമേയുള്ളൂ, നിത്യൻ, സ്വയംനിലയുള്ളവൻ, എല്ലാ സൃഷ്ടികൾക്കും മേലുള്ള പരമാധികാരി (ആവർത്തനം 6:4; യെശയ്യാവ് 44:6). ചുറ്റുമുള്ള സംസ്കാരങ്ങളുടെ ബഹുദൈവാരാധനയ്ക്കും ആധുനിക ബഹുസ്വരവാദ അവകാശവാദങ്ങൾക്കും വിപരീതമായി, ആരാധനയ്ക്ക് യോഗ്യനായ ഏക ദൈവമായി വേദപുസ്തകം ദൈവത്തെ എങ്ങനെ സ്ഥിരമായി വെളിപ്പെടുത്തുന്നുവെന്ന് പഠിക്കുക. ക്രിസ്തീയ ഏകദൈവാരാധന ത്രിത്വപരമാണെന്ന് മനസ്സിലാക്കുക: മൂന്നു വ്യക്തികളിൽ ഒരു ദൈവം - പിതാവ്, പുത്രൻ, പരിശുദ്ധാത്മാവ് - വ്യത്യസ്തരായെങ്കിലും സത്തയിൽ ഐക്യപ്പെട്ടിരിക്കുന്നു. ഈ പഠനം തെറ്റായ മതങ്ങൾക്കും വിഗ്രഹാരാധനയ്ക്കും ആപേക്ഷികവാദത്തിനും എതിരായി ബൈബിളിലെ ദൈവത്തിന്റെ അനന്യതയെ പ്രതിരോധിക്കാൻ നിങ്ങളെ സജ്ജമാക്കുകയും നിങ്ങളുടെ വിശ്വാസത്തെ വേദപുസ്തകത്തിന്റെ വ്യക്തമായ സാക്ഷ്യത്തിൽ അടിസ്ഥാനമാക്കുകയും ദൈവത്തിന്റെ ഏകവചന മഹത്വത്തിന്റെയും മഹത്വത്തിന്റെയും സത്യം വ്യക്തമാക്കാൻ നിങ്ങളെ തയ്യാറാക്കുകയും ചെയ്യുന്നു.', 'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും'),
  ('666e8400-e29b-41d4-a716-446655440002', 'ml', 'യേശുവിന്റെ അനന്യത', 'യേശുക്രിസ്തു എന്തുകൊണ്ടാണ് രക്ഷയുടെ ഏക മാർഗമെന്ന് കണ്ടെത്തുക, അവൻ തന്നെ പ്രഖ്യാപിച്ചതുപോലെ: "ഞാൻ വഴിയും സത്യവും ജീവനുമാകുന്നു. എന്നിലൂടെയല്ലാതെ ആരും പിതാവിന്റെ അടുക്കൽ വരുന്നില്ല" (യോഹന്നാൻ 14:6). ദൈവത്തിന്റെ അവതാരമെന്ന നിലയിൽ യേശുവിന്റെ അനന്യമായ സ്വത്വം, അവന്റെ പാപരഹിത ജീവിതം, പകരക്കാരനായ മരണം, ശരീര പുനരുത്ഥാനം എന്നിവ ദൈവത്തിനും മനുഷ്യരാശിക്കും ഇടയിലുള്ള ഏക മദ്ധ്യസ്ഥനായി അവനെ എങ്ങനെ മാറ്റുന്നുവെന്ന് പഠിക്കുക (1 തിമൊഥെയൊസ് 2:5). എല്ലാ വഴികളും ദൈവത്തിലേക്ക് നയിക്കുന്നു എന്ന ആശയമായ മതപരമായ ബഹുസ്വരത വേദപുസ്തകത്തെയും സുവിശേഷത്തെയും എന്തുകൊണ്ട് വൈരുദ്ധ്യപ്പെടുത്തുന്നുവെന്ന് മനസ്സിലാക്കുക. ഈ പഠനം ബൈബിളിലെ സത്യത്തിൽ അടിസ്ഥാനമാക്കിയതും നഷ്ടപ്പെട്ടവരോടുള്ള സ്നേഹത്താലും ദൈവമഹത്വത്തോടുള്ള തീക്ഷ്ണതയാലും പ്രചോദിതമായതുമായ ബഹുസ്വര ലോകത്ത് കൃപയോടെയും എന്നാൽ ഉറച്ചും ക്രിസ്തുവിന്റെ പ്രത്യേക അവകാശവാദങ്ങൾ പ്രഖ്യാപിക്കാൻ നിങ്ങളെ സജ്ജമാക്കുന്നു.', 'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും'),
  ('666e8400-e29b-41d4-a716-446655440003', 'ml', 'ബൈബിൾ വിശ്വാസയോഗ്യമാണോ?', 'പ്രചോദിതവും പിശകില്ലാത്തതുമായ ദൈവവചനം എന്ന നിലയിൽ ബൈബിളിന്റെ വിശ്വാസ്യതയ്ക്കും വിശ്വാസയോഗ്യതയ്ക്കുമുള്ള ആകർഷകമായ തെളിവുകൾ പരിശോധിക്കുക. കൈയെഴുത്തുപ്രതി തെളിവുകൾ, പുരാവസ്തു കണ്ടെത്തലുകൾ, പൂർത്തീകരിക്കപ്പെട്ട പ്രവചനം, ആന്തരിക സ്ഥിരത, പരിശുദ്ധാത്മാവിന്റെ സാക്ഷ്യം എന്നിവയെല്ലാം വേദപുസ്തകത്തിന്റെ ദൈവിക ഉത്ഭവത്തെയും അധികാരത്തെയും എങ്ങനെ സ്ഥിരീകരിക്കുന്നുവെന്ന് പഠിക്കുക. ബൈബിളിന്റെ വിശ്വാസ്യത മനുഷ്യരുടെ അഭിപ്രായത്തിലോ പണ്ഡിത സമവായത്തിലോ അടിസ്ഥാനമാക്കിയതല്ല, മറിച്ച് നുണ പറയാൻ കഴിയാത്ത സത്യത്തിന്റെ ദൈവത്തിന്റെ സ്വഭാവത്തിലാണെന്ന് മനസ്സിലാക്കുക. ഈ പഠനം സംശയവാദികളുടെ എതിർപ്പുകൾക്ക് ഉത്തരം നൽകാനും ദൈവവചനത്തിലുള്ള നിങ്ങളുടെ ആത്മവിശ്വാസം ശക്തിപ്പെടുത്താനും സിദ്ധാന്തത്തിന്റെയും ജീവിതത്തിന്റെയും എല്ലാ കാര്യങ്ങളിലും വിശ്വാസത്തിനും പ്രയോഗത്തിനുമുള്ള അന്തിമ അധികാരമായി വേദപുസ്തകത്തിന്റെ അടിത്തറയിൽ ഉറച്ചുനിൽക്കാനും നിങ്ങളെ സജ്ജമാക്കുന്നു.', 'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും'),
  ('666e8400-e29b-41d4-a716-446655440004', 'ml', 'മറ്റു വിശ്വാസങ്ങളിൽ നിന്നുള്ള സാധാരണ ചോദ്യങ്ങൾക്ക് പ്രതികരിക്കുക', 'മറ്റ് വിശ്വാസങ്ങളുള്ള ആളുകളുമായി എങ്ങനെ ബഹുമാനപൂർവകമായും ബൈബിളനുസൃതമായും ഇടപഴകാമെന്നും സത്യവും കൃപയും ഉപയോഗിച്ച് ക്രിസ്തുമതത്തെക്കുറിച്ചുള്ള അവരുടെ ചോദ്യങ്ങൾക്ക് ഉത്തരം നൽകാമെന്നും പഠിക്കുക (1 പത്രോസ് 3:15-16). ഹിന്ദുമതം, ഇസ്ലാം, ബുദ്ധമതം, മറ്റ് മതങ്ങൾ എന്നിവയിൽ നിന്നുള്ള പൊതുവായ എതിർപ്പുകൾ എങ്ങനെ മനസ്സിലാക്കാമെന്നും വേദപുസ്തകത്തിൽ വേരൂന്നിയ സ്പഷ്ടമായ സുവിശേഷ-കേന്ദ്രീകൃത ഉത്തരങ്ങളുമായി പ്രതികരിക്കാമെന്നും കണ്ടെത്തുക. വിശ്വാസത്തെ പ്രതിരോധിക്കുന്നതിനും (ക്ഷമാപണം) ക്രിസ്തുവിനെപ്പോലെയുള്ള സ്നേഹവും വിനയവും പ്രകടിപ്പിക്കുന്നതിനും ഇടയിലുള്ള സന്തുലിതാവസ്ഥ മനസ്സിലാക്കുക. ഈ പഠനം സുവിശേഷത്തിന്റെ അനന്യത വ്യക്തമാക്കാനും തെറ്റായ മതങ്ങളുടെ അപര്യാപ്തത തുറന്നുകാട്ടാനും മറ്റുള്ളവരെ ഏക രക്ഷകനായ യേശുവിലേക്ക് ചൂണ്ടിക്കാണിക്കാനും നിങ്ങളെ തയ്യാറാക്കുന്നു - എല്ലാം സൗമ്യത, ബഹുമാനം, ക്രിസ്തുവിനെ ഇതുവരെ അറിയാത്തവരുടെ ആത്മാക്കളോടുള്ള യഥാർത്ഥ ഉത്കണ്ഠ എന്നിവയുടെ മനോഭാവം നിലനിർത്തുമ്പോൾ.', 'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും'),
  ('666e8400-e29b-41d4-a716-446655440005', 'ml', 'ഉപദ്രവത്തിൽ ഉറച്ചുനിൽക്കുക', 'ക്രിസ്തുവിനുവേണ്ടി പീഡനവും എതിർപ്പും സഹിക്കുന്നതിനുള്ള ബൈബിളിലെ പ്രോത്സാഹനവും പ്രായോഗിക ജ്ഞാനവും കണ്ടെത്തുക. യേശു തന്റെ അനുയായികൾ കഷ്ടത നേരിടുമെന്ന് വാഗ്ദാനം ചെയ്തതെങ്ങനെയെന്നും (യോഹന്നാൻ 16:33) എന്നാൽ തന്റെ സാന്നിധ്യവും ശക്തിയും ആത്യന്തിക വിജയവും വാഗ്ദാനം ചെയ്തതെങ്ങനെയെന്നും പഠിക്കുക. പീഡനം ദൈവത്തിന്റെ അഭാവത്തിന്റെ അടയാളമല്ല, മറിച്ച് പലപ്പോഴും യഥാർത്ഥ ശിഷ്യത്വത്തിന്റെ അടയാളമാണെന്ന് മനസ്സിലാക്കുക (2 തിമൊഥെയൊസ് 3:12). ഈ പഠനം കഷ്ടതയിലൂടെ വിശ്വാസത്തിൽ എങ്ങനെ ഉറച്ചുനിൽക്കാമെന്നും വിട്ടുവീഴ്ചയ്ക്കോ ക്രിസ്തുവിനെ നിഷേധിക്കാനോ ഉള്ള പ്രലോഭനത്തെ എതിർക്കാമെന്നും അവന്റെ കഷ്ടപ്പാടുകളിൽ പങ്കുചേരുന്നതിൽ സന്തോഷം കണ്ടെത്താമെന്നും പഠിപ്പിക്കുന്നു (1 പത്രോസ് 4:12-14). വേദപുസ്തകത്തിന്റെ വാഗ്ദാനങ്ങളിൽ അടിസ്ഥാനമാക്കി, പരിശുദ്ധാത്മാവിനാൽ പുലർത്തപ്പെട്ടവരും ക്രിസ്തുവിനോട് വിശ്വസ്തരായിരിക്കുന്നവർക്കായി കാത്തിരിക്കുന്ന നിത്യ പ്രതിഫലത്തിൽ ആത്മവിശ്വാസമുള്ളവരുമായ പ്രതീക്ഷയോടെ കഷ്ടത സഹിക്കാൻ സജ്ജരാകുക.', 'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Family & Relationships (परिवार और रिश्ते / കുടുംബവും ബന്ധങ്ങളും)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('777e8400-e29b-41d4-a716-446655440001', 'hi', 'विवाह और विश्वास', 'विवाह के लिए बाइबिल दृष्टि को एक पुरुष और एक महिला के बीच वाचा संघ के रूप में खोजें, जिसे मसीह के अपनी कलीसिया के साथ संबंध को प्रतिबिंबित करने के लिए परमेश्वर द्वारा डिज़ाइन किया गया है (इफिसियों 5:22-33)। जानें कि कैसे मसीह-केंद्रित विवाह परमेश्वर के वचन के प्रति पारस्परिक समर्पण, मसीह के बाद बलिदान प्रेम और परमेश्वर के बनाए गए क्रम का सम्मान करने वाली भूमिकाओं पर निर्मित है। समझें कि सुसमाचार विवाह को स्व-केंद्रित साझेदारी से निःस्वार्थ, वाचा वफादारी में कैसे बदल देता है। यह अध्ययन संचार, संघर्ष समाधान, अंतरंगता और आत्मिक नेतृत्व जैसे व्यावहारिक क्षेत्रों को संबोधित करता है, सभी पवित्रशास्त्र में आधारित। खोजें कि विवाह अंततः व्यक्तिगत खुशी के बारे में नहीं है बल्कि परमेश्वर की महिमा करने, सुसमाचार प्रदर्शित करने और मसीह और उसके राज्य की सेवा में एक साथ भागीदारी करने के बारे में है।', 'परिवार और रिश्ते'),
  ('777e8400-e29b-41d4-a716-446655440002', 'hi', 'बच्चों को मसीह में पालना', 'माता-पिता के लिए बाइबिल के आदेश को सीखें कि वे अपने बच्चों को प्रभु के भय और निर्देश में पालें (इफिसियों 6:4), उन्हें उनके शुरुआती वर्षों से परमेश्वर को जानने, प्यार करने और आज्ञा मानने के लिए प्रशिक्षित करें। खोजें कि मसीही पालन-पोषण केवल व्यवहार संशोधन या नैतिक निर्देश के बारे में नहीं है, बल्कि बच्चों को सुसमाचार की आवश्यकता और यीशु मसीह के अनुग्रह की ओर इशारा करने के बारे में है। अनुशासन और अनुग्रह, निर्देश और प्रार्थना, अधिकार और प्रेम के बीच संतुलन को समझें। यह अध्ययन माता-पिता को एक घर बनाने के लिए सुसज्जित करता है जहां परमेश्वर का वचन केंद्रीय है, प्रार्थना आदतन है, और सुसमाचार लगातार मॉडल और सिखाया जाता है, बच्चों को अपने स्वयं के रूप में मसीह में विश्वास को गले लगाने और उनके जीवन भर उसकी महिमा के लिए वफादारी से जीने के लिए तैयार करना।', 'परिवार और रिश्ते'),
  ('777e8400-e29b-41d4-a716-446655440003', 'hi', 'माता-पिता का सम्मान', 'पांचवीं आज्ञा के पिता और माता को सम्मान देने के आह्वान को खोजें (निर्गमन 20:12), यह समझते हुए कि यह आज्ञा परिवार के क्रम के लिए परमेश्वर के डिजाइन और आज्ञाकारिता से आने वाली आशीष को कैसे प्रकट करती है। जानें कि व्यवहार में बाइबिल सम्मान कैसा दिखता है: सम्मान, कृतज्ञता, देखभाल और ईश्वरीय अधिकार के प्रति समर्पण - यह भी पहचानते हुए कि अंतिम आज्ञाकारिता केवल परमेश्वर की है। समझें कि कैसे माता-पिता का सम्मान जीवन भर फैलता है, बचपन की आज्ञाकारिता से लेकर वयस्क देखभाल और सम्मान तक। यह अध्ययन कठिन स्थितियों जैसे अनादर या दुर्व्यवहार करने वाले माता-पिता को संबोधित करता है, दिखाता है कि बाइबिल सीमाओं को बनाए रखते हुए कैसे सम्मान किया जाए। खोजें कि कैसे माता-पिता का सम्मान परमेश्वर की महिमा करता है, परिवारों को मजबूत करता है और रिश्तों में सुसमाचार की परिवर्तनकारी शक्ति को प्रदर्शित करता है।', 'परिवार और रिश्ते'),
  ('777e8400-e29b-41d4-a716-446655440004', 'hi', 'स्वस्थ मित्रता', 'मसीह-केंद्रित मित्रता बनाने के लिए बाइबिल सिद्धांतों की खोज करें जो आत्मिक विकास, जवाबदेही और पारस्परिक निर्माण को प्रोत्साहित करें। जानें कि कैसे पवित्रशास्त्र अधर्मी मित्रता के खिलाफ चेतावनी देता है जो समझौता (1 कुरिन्थियों 15:33) की ओर ले जाती है जबकि परमेश्वर के प्रेम और पवित्रता की खोज में निहित मित्रता की सराहना करता है (नीतिवचन 27:17)। स्वस्थ मसीही मित्रता के गुणों को समझें: वफादारी, ईमानदारी, प्रोत्साहन, जवाबदेही और मसीह के प्रति साझा प्रतिबद्धता। यह अध्ययन बुद्धिमानी से दोस्तों को चुनने, ईश्वरीय सीमाओं को बनाए रखने और उन रिश्तों में निवेश करने के लिए व्यावहारिक मार्गदर्शन प्रदान करता है जो एक दूसरे को यीशु की ओर इशारा करते हैं। जानें कि कैसे सच्ची मित्रता मसीह के प्रेम को दर्शाती है और मसीही जीवन में अनुग्रह के साधन के रूप में कार्य करती है।', 'परिवार और रिश्ते'),
  ('777e8400-e29b-41d4-a716-446655440005', 'hi', 'संघर्षों को बाइबिल के अनुसार हल करना', 'संघर्षों और असहमतियों को हल करने के लिए बाइबिल प्रक्रिया सीखें जो परमेश्वर का सम्मान करती है और रिश्तों को संरक्षित करती है। खोजें कि कैसे यीशु ने पाप का सामना करने और सुलह का पीछा करने के लिए कदम बताए (मत्ती 18:15-17), विनम्रता, ईमानदारी और प्रेम में बोले गए सत्य के प्रति प्रतिबद्धता पर जोर देते हुए। समझें कि संघर्ष के मूल कारणों की पहचान कैसे करें (अक्सर अभिमान और स्वार्थ, याकूब 4:1-2), पहले अपने पाप को स्वीकार करें, क्षमा मांगें और अनुग्रह बढ़ाएं। यह अध्ययन सिखाता है कि कठिन बातचीत को कैसे नेविगेट करें, सत्य से समझौता किए बिना शांति का पीछा करें, और जब आवश्यक हो तो कलीसिया को शामिल करें। बाइबिल शांतिनिर्माण में बढ़ें जो सुसमाचार को दर्शाता है, परमेश्वर की महिमा करता है, और मसीह-समान प्रेम, विनम्रता और अनुग्रह के माध्यम से टूटे रिश्तों को बहाल करता है।', 'परिवार और रिश्ते')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('777e8400-e29b-41d4-a716-446655440001', 'ml', 'വിവാഹവും വിശ്വാസവും', 'ക്രിസ്തുവിന് തന്റെ സഭയുമായുള്ള ബന്ധത്തെ പ്രതിഫലിപ്പിക്കാൻ ദൈവം രൂപകല്പന ചെയ്ത ഒരു പുരുഷനും ഒരു സ്ത്രീയും തമ്മിലുള്ള ഉടമ്പടി ഐക്യമെന്ന നിലയിൽ വിവാഹത്തിനായുള്ള ബൈബിളിലെ കാഴ്ചപ്പാട് പര്യവേക്ഷണം ചെയ്യുക (എഫെസ്യർ 5:22-33). ക്രിസ്തുകേന്ദ്രീകൃത വിവാഹം ദൈവവചനത്തോടുള്ള പരസ്പര സമർപ്പണത്തിലും ക്രിസ്തുവിനെ മാതൃകയാക്കിയ ത്യാഗപരമായ സ്നേഹത്തിലും ദൈവത്തിന്റെ സൃഷ്ടിച്ച ക്രമത്തെ ബഹുമാനിക്കുന്ന റോളുകളിലും എങ്ങനെ പണിതിരിക്കുന്നുവെന്ന് പഠിക്കുക. സുവിശേഷം വിവാഹത്തെ സ്വകേന്ദ്രീകൃത പങ്കാളിത്തത്തിൽ നിന്ന് നിസ്വാർത്ഥമായ ഉടമ്പടി വിശ്വസ്തതയിലേക്ക് എങ്ങനെ മാറ്റുന്നുവെന്ന് മനസ്സിലാക്കുക. ഈ പഠനം ആശയവിനിമയം, സംഘർഷ പരിഹാരം, അടുപ്പം, ആത്മീയ നേതൃത്വം തുടങ്ങിയ പ്രായോഗിക മേഖലകളെ അഭിസംബോധന ചെയ്യുന്നു, എല്ലാം വേദപുസ്തകത്തിൽ അടിസ്ഥാനമാക്കിയതാണ്. വിവാഹം ആത്യന്തികമായി വ്യക്തിഗത സന്തോഷത്തെക്കുറിച്ചല്ല, മറിച്ച് ദൈവത്തെ മഹത്വപ്പെടുത്തുന്നതിനെക്കുറിച്ചും സുവിശേഷം പ്രദർശിപ്പിക്കുന്നതിനെക്കുറിച്ചും ക്രിസ്തുവിനോടും അവന്റെ രാജ്യത്തോടുമുള്ള സേവനത്തിൽ ഒരുമിച്ച് പങ്കാളികളാകുന്നതിനെക്കുറിച്ചുമാണെന്ന് കണ്ടെത്തുക.', 'കുടുംബവും ബന്ധങ്ങളും'),
  ('777e8400-e29b-41d4-a716-446655440002', 'ml', 'കുട്ടികളെ ക്രിസ്തുവിൽ വളർത്തുക', 'മാതാപിതാക്കൾക്ക് അവരുടെ കുട്ടികളെ കർത്താവിന്റെ ഭയത്തിലും നിർദ്ദേശത്തിലും വളർത്താനുള്ള ബൈബിളിലെ കൽപ്പന പഠിക്കുക (എഫേസ്യർ 6:4), അവരുടെ ആദ്യ വർഷങ്ങൾ മുതൽ ദൈവത്തെ അറിയാനും സ്നേഹിക്കാനും അനുസരിക്കാനും അവരെ പരിശീലിപ്പിക്കുക. ക്രിസ്തീയ രക്ഷാകർതൃത്വം കേവലം പെരുമാറ്റ പരിഷ്ക്കരണത്തെക്കുറിച്ചോ ധാർമ്മിക നിർദ്ദേശത്തെക്കുറിച്ചോ അല്ല, മറിച്ച് കുട്ടികളെ സുവിശേഷത്തിന്റെ ആവശ്യകതയിലേക്കും യേശുക്രിസ്തുവിന്റെ കൃപയിലേക്കും ചൂണ്ടിക്കാണിക്കുന്നതിനെക്കുറിച്ചുമാണെന്ന് കണ്ടെത്തുക. അച്ചടക്കവും കൃപയും, നിർദ്ദേശവും പ്രാർത്ഥനയും, അധികാരവും സ്നേഹവും തമ്മിലുള്ള സന്തുലിതാവസ്ഥ മനസ്സിലാക്കുക. ഈ പഠനം ദൈവവചനം കേന്ദ്രീകൃതവും പ്രാർത്ഥന സ്ഥിരവും സുവിശേഷം സ്ഥിരമായി മാതൃകയാക്കുകയും പഠിപ്പിക്കുകയും ചെയ്യുന്ന ഒരു വീട് സൃഷ്ടിക്കാൻ മാതാപിതാക്കളെ സജ്ജമാക്കുന്നു, കുട്ടികളെ ക്രിസ്തുവിലുള്ള വിശ്വാസത്തെ സ്വന്തമായി സ്വീകരിക്കാനും അവരുടെ ജീവിതകാലം മുഴുവൻ അവന്റെ മഹത്വത്തിനായി വിശ്വസ്തതയോടെ ജീവിക്കാനും തയ്യാറാക്കുന്നു.', 'കുടുംബവും ബന്ധങ്ങളും'),
  ('777e8400-e29b-41d4-a716-446655440003', 'ml', 'മാതാപിതാക്കളെ ബഹുമാനിക്കുക', 'അമ്മയെയും അച്ഛനെയും ബഹുമാനിക്കാനുള്ള അഞ്ചാം കൽപ്പനയുടെ ആഹ്വാനം പര്യവേക്ഷണം ചെയ്യുക (പുറപ്പാട് 20:12), ഈ കൽപ്പന കുടുംബക്രമത്തിനായുള്ള ദൈവത്തിന്റെ രൂപകല്പനയെയും അനുസരണത്തിൽ നിന്ന് വരുന്ന അനുഗ്രഹത്തെയും എങ്ങനെ വെളിപ്പെടുത്തുന്നുവെന്ന് മനസ്സിലാക്കുക. പ്രായോഗികമായി ബൈബിളിലെ ബഹുമാനം എങ്ങനെയുണ്ടെന്ന് പഠിക്കുക: ബഹുമാനം, നന്ദി, പരിചരണം, ദൈവികമായ അധികാരത്തോടുള്ള കീഴ്വഴക്കം - ആത്യന്തിക അനുസരണം ദൈവത്തിനു മാത്രമേയുള്ളൂവെന്നും തിരിച്ചറിയുക. മാതാപിതാക്കളെ ബഹുമാനിക്കുന്നത് ജീവിതത്തിലുടനീളം എങ്ങനെ വ്യാപിക്കുന്നുവെന്ന് മനസ്സിലാക്കുക, ബാല്യകാല അനുസരണം മുതൽ മുതിർന്ന പരിചരണവും ബഹുമാനവും വരെ. ഈ പഠനം അനാദരവ് കാണിക്കുന്നതോ ദുരുപയോഗം ചെയ്യുന്നതോ ആയ മാതാപിതാക്കൾ പോലുള്ള ബുദ്ധിമുട്ടുള്ള സാഹചര്യങ്ങളെ അഭിസംബോധന ചെയ്യുന്നു, ബൈബിളിലെ അതിരുകൾ നിലനിർത്തിക്കൊണ്ട് എങ്ങനെ ബഹുമാനിക്കാമെന്ന് കാണിക്കുന്നു. മാതാപിതാക്കളെ ബഹുമാനിക്കുന്നത് എങ്ങനെ ദൈവത്തെ മഹത്വപ്പെടുത്തുന്നുവെന്നും കുടുംബങ്ങളെ ശക്തിപ്പെടുത്തുന്നുവെന്നും ബന്ധങ്ങളിൽ സുവിശേഷത്തിന്റെ പരിവർത്തന ശക്തി പ്രകടമാക്കുന്നുവെന്നും കണ്ടെത്തുക.', 'കുടുംബവും ബന്ധങ്ങളും'),
  ('777e8400-e29b-41d4-a716-446655440004', 'ml', 'ആരോഗ്യകരമായ സൗഹൃദങ്ങൾ', 'ആത്മീയ വളർച്ചയെയും ഉത്തരവാദിത്തത്തെയും പരസ്പര ആത്മവികസനത്തെയും പ്രോത്സാഹിപ്പിക്കുന്ന ക്രിസ്തുകേന്ദ്രീകൃത സൗഹൃദങ്ങൾ കെട്ടിപ്പടുക്കുന്നതിനുള്ള ബൈബിളിലെ തത്ത്വങ്ങൾ കണ്ടെത്തുക. വിട്ടുവീഴ്ചയിലേക്ക് നയിക്കുന്ന അദൈവിക സൗഹൃദങ്ങൾക്കെതിരെ വേദപുസ്തകം എങ്ങനെ മുന്നറിയിപ്പ് നൽകുന്നുവെന്നും (1 കൊരിന്ത്യർ 15:33) ദൈവത്തോടുള്ള സ്നേഹത്തിലും വിശുദ്ധിയുടെ അന്വേഷണത്തിലും വേരൂന്നിയ സൗഹൃദങ്ങളെ അനുശംസിക്കുന്നുവെന്നും (സദൃശവാക്യങ്ങൾ 27:17) പഠിക്കുക. ആരോഗ്യകരമായ ക്രിസ്തീയ സൗഹൃദത്തിന്റെ ഗുണങ്ങൾ മനസ്സിലാക്കുക: വിശ്വസ്തത, സത്യസന്ധത, പ്രോത്സാഹനം, ഉത്തരവാദിത്തം, ക്രിസ്തുവിനോടുള്ള പങ്കിട്ട പ്രതിബദ്ധത. ഈ പഠനം ജ്ഞാനത്തോടെ സുഹൃത്തുക്കളെ തിരഞ്ഞെടുക്കുന്നതിനും ദൈവീക അതിരുകൾ നിലനിർത്തുന്നതിനും പരസ്പരം യേശുവിലേക്ക് ചൂണ്ടിക്കാണിക്കുന്ന ബന്ധങ്ങളിൽ നിക്ഷേപിക്കുന്നതിനുമുള്ള പ്രായോഗിക മാർഗനിർദേശം നൽകുന്നു. യഥാർത്ഥ സൗഹൃദം ക്രിസ്തുവിന്റെ സ്നേഹത്തെ എങ്ങനെ പ്രതിഫലിപ്പിക്കുന്നുവെന്നും ക്രിസ്തീയ ജീവിതത്തിൽ കൃപയുടെ മാർഗമായി പ്രവർത്തിക്കുന്നുവെന്നും പര്യവേക്ഷണം ചെയ്യുക.', 'കുടുംബവും ബന്ധങ്ങളും'),
  ('777e8400-e29b-41d4-a716-446655440005', 'ml', 'സംഘർഷങ്ങൾ ബൈബിൾ അനുസരിച്ച് പരിഹരിക്കുക', 'ദൈവത്തെ ബഹുമാനിക്കുകയും ബന്ധങ്ങൾ സംരക്ഷിക്കുകയും ചെയ്യുന്ന വിധത്തിൽ സംഘർഷങ്ങളും അഭിപ്രായവ്യത്യാസങ്ങളും പരിഹരിക്കുന്നതിനുള്ള ബൈബിളിലെ പ്രക്രിയ പഠിക്കുക. യേശു പാപത്തെ അഭിമുഖീകരിക്കാനും അനുരഞ്ജനം പിന്തുടരാനുമുള്ള നടപടികൾ എങ്ങനെ വിശദീകരിച്ചുവെന്ന് കണ്ടെത്തുക (മത്തായി 18:15-17), വിനയം, സത്യസന്ധത, സ്നേഹത്തിൽ സംസാരിക്കുന്ന സത്യത്തോടുള്ള പ്രതിബദ്ധത എന്നിവ ഊന്നിപ്പറയുന്നു. സംഘർഷത്തിന്റെ അടിസ്ഥാന കാരണങ്ങൾ എങ്ങനെ തിരിച്ചറിയാമെന്നും (പലപ്പോഴും അഹങ്കാരവും സ്വാർത്ഥതയും, യാക്കോബ് 4:1-2), നിങ്ങളുടെ സ്വന്തം പാപം ആദ്യം ഏറ്റുപറയാമെന്നും ക്ഷമ തേടാമെന്നും കൃപ നൽകാമെന്നും മനസ്സിലാക്കുക. ഈ പഠനം ബുദ്ധിമുട്ടുള്ള സംഭാഷണങ്ങൾ എങ്ങനെ നാവിഗേറ്റ് ചെയ്യാമെന്നും സത്യവുമായി വിട്ടുവീഴ്ച ചെയ്യാതെ സമാധാനം പിന്തുടരാമെന്നും ആവശ്യമുള്ളപ്പോൾ സഭയെ ഉൾപ്പെടുത്താമെന്നും പഠിപ്പിക്കുന്നു. സുവിശേഷത്തെ പ്രതിഫലിപ്പിക്കുകയും ദൈവത്തെ മഹത്വപ്പെടുത്തുകയും ക്രിസ്തുവിനെപ്പോലെയുള്ള സ്നേഹം, വിനയം, കൃപ എന്നിവയിലൂടെ തകർന്ന ബന്ധങ്ങൾ പുനഃസ്ഥാപിക്കുകയും ചെയ്യുന്ന ബൈബിളനുസൃത സമാധാനനിർമാണത്തിൽ വളരുക.', 'കുടുംബവും ബന്ധങ്ങളും')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ========================
-- Category: Mission & Service (मिशन और सेवा / മിഷനും സേവനവും)
-- ========================

-- Hindi Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('888e8400-e29b-41d4-a716-446655440001', 'hi', 'अपने समुदाय में ज्योति बनना', 'विश्वासियों के लिए "दुनिया की ज्योति" होने के यीशु के आह्वान को खोजें (मत्ती 5:14-16), जीवन के हर क्षेत्र में उनके चरित्र और सत्य को प्रतिबिंबित करते हुए - काम पर, अपने पड़ोस में, स्कूल में और अपने परिवार के भीतर। जानें कि गिरी हुई दुनिया में नमक और ज्योति (सत्य को संरक्षित करना और सुसमाचार को रोशन करना) के रूप में जीने का क्या अर्थ है, आत्म-धार्मिकता के माध्यम से नहीं बल्कि विनम्र आज्ञाकारिता और अनुग्रह के माध्यम से। खोजें कि कैसे आपके अच्छे कार्य, विश्वास में किए गए और परमेश्वर के प्रेम से प्रेरित, दूसरों को स्वर्ग में आपके पिता की ओर इशारा करते हैं और सुसमाचार बातचीत के लिए दरवाजे खोलते हैं। यह अध्ययन विश्वासियों को विशिष्ट रूप से जीने, मसीह को प्रामाणिक रूप से प्रतिबिंबित करने और व्यावहारिक, मूर्त तरीकों से सुसमाचार की आशा के साथ अपने स्थानीय समुदाय को संलग्न करने के लिए सुसज्जित करता है।', 'मिशन और सेवा'),
  ('888e8400-e29b-41d4-a716-446655440002', 'hi', 'अपनी गवाही साझा करना', 'अपनी व्यक्तिगत गवाही साझा करने की शक्ति और महत्व को खोजें - कहानी कि कैसे परमेश्वर ने यीशु मसीह में विश्वास के माध्यम से आपको बचाया और तब से उसने आपके जीवन में क्या किया है। जानें कि एक स्पष्ट गवाही में मसीह से पहले आपका जीवन, आप सुसमाचार को कैसे समझने और पश्चाताप करने आए, और परिवर्तन जो परमेश्वर ने अपने अनुग्रह से आप में काम किया है (आपके अपने प्रयास से नहीं) शामिल है। समझें कि आपकी गवाही परमेश्वर की महिमा कैसे करती है, अन्य विश्वासियों को प्रोत्साहित करती है, और स्पष्टता के साथ पूर्ण सुसमाचार संदेश साझा करने के लिए दरवाजे कैसे खोलती है। यह अध्ययन आपको सुसमाचार-केंद्रित गवाही तैयार करने में मदद करता है जो मसीह की ओर इशारा करती है, खुद को नायक बनाने से बचती है, और अच्छी खबर की जीवन-परिवर्तनकारी शक्ति को प्रदर्शित करती है।', 'मिशन और सेवा'),
  ('888e8400-e29b-41d4-a716-446655440003', 'hi', 'गरीबों और ज़रूरतमंदों की सेवा', 'गरीबों, अनाथों, विधवाओं और हाशिए पर पड़े लोगों की देखभाल के लिए बाइबिल के आदेश को खोजें, परमेश्वर की करुणा और न्याय में निहित (व्यवस्थाविवरण 15:11, याकूब 1:27)। जानें कि ज़रूरतमंदों की सेवा सुसमाचार द्वारा परिवर्तित हृदय से कैसे प्रवाहित होती है - हम सेवा करते हैं क्योंकि मसीह ने पहले हमारी आत्मिक गरीबी में हमारी सेवा की। सामाजिक सुसमाचार (जो ईसाई धर्म को अच्छे कार्यों तक कम कर देता है) और सुसमाचार-संचालित करुणा (जो शारीरिक आवश्यकताओं को पूरा करता है जबकि हमेशा आत्मिक उद्धार की अधिक आवश्यकता की ओर इशारा करता है) के बीच अंतर को समझें। त्याग से देने, गरिमा के साथ सेवा करने और दया के कार्यों के माध्यम से मसीह का प्रेम दिखाने के व्यावहारिक तरीकों की खोज करें, यह पहचानते हुए कि सच्चा न्याय और दया परमेश्वर के चरित्र और यीशु के छुटकारे के कार्य में आधारित हैं।', 'मिशन और सेवा'),
  ('888e8400-e29b-41d4-a716-446655440004', 'hi', 'सरल बनाया गया प्रचार', 'स्पष्टता, साहस और प्रेम के साथ सुसमाचार साझा करने के लिए व्यावहारिक, बाइबिल तरीके सीखें, यह विश्वास करते हुए कि पवित्र आत्मा हृदयों को दोषी ठहराता है और पापियों को बचाता है (यूहन्ना 16:8, रोमियों 1:16)। सुसमाचार संदेश के आवश्यक तत्वों को समझें - परमेश्वर की पवित्रता, मानव पाप, मसीह की प्रतिस्थापनात्मक मृत्यु और पुनरुत्थान, और पश्चाताप करने और विश्वास करने का आह्वान - और रोज़मर्रा की बातचीत में उन्हें आकर्षक रूप से कैसे संप्रेषित करें। जानें कि भय पर कैसे काबू पाएं, आपत्तियों का अनुमान लगाएं, और मानव वाक्पटुता या हेरफेर के बजाय परमेश्वर के वचन की शक्ति पर भरोसा करें। यह अध्ययन आपको प्राकृतिक संदर्भों में, रिश्तों के माध्यम से, और खोए हुओं के लिए वास्तविक प्रेम के साथ, हमेशा उद्धार में परमेश्वर की संप्रभुता पर निर्भर रहते हुए, वफादारी से मसीह को साझा करने के लिए सुसज्जित करता है।', 'मिशन और सेवा'),
  ('888e8400-e29b-41d4-a716-446655440005', 'hi', 'राष्ट्रों के लिए प्रार्थना', 'राष्ट्रों के लिए प्रार्थना करने के बाइबिल आह्वान की खोज करें, हर जनजाति, भाषा और राष्ट्र से उपासकों को इकट्ठा करने के परमेश्वर के वैश्विक मिशन में भाग लेते हुए (प्रकाशितवाक्य 7:9)। जानें कि अप्राप्त लोगों, सताए गए विश्वासियों और सुसमाचार प्रगति के लिए मध्यस्थता प्रार्थना परमेश्वर की संप्रभु योजना के साथ कैसे संरेखित होती है कि वह मसीह की घोषणा के माध्यम से दुनिया भर में पापियों को बचाए। समझें कि कैसे वफादार प्रार्थना मिशनरियों का समर्थन करती है, सुसमाचार के लिए दरवाजे खोलती है, और उन स्थानों में परमेश्वर के राज्य को आगे बढ़ाती है जहां यीशु का नाम अभी तक ज्ञात नहीं है। यह अध्ययन विश्वासियों को मिशन के लिए वैश्विक दृष्टि विकसित करने, विशिष्ट आवश्यकताओं के लिए रणनीतिक रूप से प्रार्थना करने और परमेश्वर पर भरोसा करने के लिए प्रेरित करता है कि वह अपनी महिमा और सुसमाचार के प्रसार के लिए राष्ट्रों के बीच अपने उद्देश्यों को पूरा करे।', 'मिशन और सेवा')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category)
VALUES
  ('888e8400-e29b-41d4-a716-446655440001', 'ml', 'നിങ്ങളുടെ സമൂഹത്തിൽ വെളിച്ചമായിരിക്കുക', 'വിശ്വാസികൾ "ലോകത്തിന്റെ വെളിച്ചം" ആകാനുള്ള യേശുവിന്റെ ആഹ്വാനം പര്യവേക്ഷണം ചെയ്യുക (മത്തായി 5:14-16), ജീവിതത്തിന്റെ എല്ലാ മേഖലകളിലും അവന്റെ സ്വഭാവവും സത്യവും പ്രതിഫലിപ്പിക്കുക - ജോലിയിൽ, നിങ്ങളുടെ അയൽപക്കത്ത്, സ്കൂളിൽ, നിങ്ങളുടെ കുടുംബത്തിനുള്ളിൽ. വീണുപോയ ലോകത്ത് ഉപ്പും വെളിച്ചവും (സത്യം സംരക്ഷിക്കുകയും സുവിശേഷം പ്രകാശിപ്പിക്കുകയും) ആയി ജീവിക്കുക എന്നതിന്റെ അർത്ഥം പഠിക്കുക, സ്വയം-നീതിയിലൂടെയല്ല, മറിച്ച് വിനീതമായ അനുസരണത്തിലൂടെയും കൃപയിലൂടെയും. നിങ്ങളുടെ നല്ല പ്രവൃത്തികൾ, വിശ്വാസത്തിൽ ചെയ്യുകയും ദൈവസ്നേഹത്താൽ പ്രചോദിതമാകുകയും ചെയ്യുന്നത്, എങ്ങനെ മറ്റുള്ളവരെ സ്വർഗ്ഗത്തിലെ നിങ്ങളുടെ പിതാവിലേക്ക് ചൂണ്ടിക്കാണിക്കുകയും സുവിശേഷ സംഭാഷണങ്ങൾക്കായി വാതിലുകൾ തുറക്കുകയും ചെയ്യുന്നുവെന്ന് കണ്ടെത്തുക. ഈ പഠനം വിശിഷ്ടമായി ജീവിക്കാനും ക്രിസ്തുവിനെ ആധികാരികമായി പ്രതിഫലിപ്പിക്കാനും പ്രായോഗികവും മൂർത്തവുമായ രീതികളിൽ സുവിശേഷത്തിന്റെ പ്രതീക്ഷയുമായി അവരുടെ പ്രാദേശിക സമൂഹവുമായി ഇടപഴകാനും വിശ്വാസികളെ സജ്ജമാക്കുന്നു.', 'മിഷനും സേവനവും'),
  ('888e8400-e29b-41d4-a716-446655440002', 'ml', 'നിങ്ങളുടെ സാക്ഷ്യം പങ്കുവെക്കുക', 'നിങ്ങളുടെ വ്യക്തിഗത സാക്ഷ്യം പങ്കുവെക്കുന്നതിന്റെ ശക്തിയും പ്രാധാന്യവും കണ്ടെത്തുക - യേശുക്രിസ്തുവിലുള്ള വിശ്വാസത്തിലൂടെ ദൈവം നിങ്ങളെ എങ്ങനെ രക്ഷിച്ചുവെന്നും അതിനുശേഷം അവൻ നിങ്ങളുടെ ജീവിതത്തിൽ എന്ത് ചെയ്തുവെന്നുമുള്ള കഥ. വ്യക്തമായ സാക്ഷ്യത്തിൽ ക്രിസ്തുവിന് മുമ്പുള്ള നിങ്ങളുടെ ജീവിതം, സുവിശേഷം എങ്ങനെ മനസ്സിലാക്കാനും മാനസാന്തരപ്പെടാനും നിങ്ങൾ എത്തി, ദൈവം തന്റെ കൃപയാൽ നിങ്ങളിൽ പ്രവർത്തിച്ച പരിവർത്തനം (നിങ്ങളുടെ സ്വന്തം പ്രയത്നത്താലല്ല) എന്നിവ എങ്ങനെ ഉൾപ്പെടുന്നുവെന്ന് പഠിക്കുക. നിങ്ങളുടെ സാക്ഷ്യം ദൈവത്തെ എങ്ങനെ മഹത്വപ്പെടുത്തുന്നുവെന്നും മറ്റ് വിശ്വാസികളെ പ്രോത്സാഹിപ്പിക്കുന്നുവെന്നും വ്യക്തതയോടെ പൂർണ്ണ സുവിശേഷസന്ദേശം പങ്കുവെക്കാനുള്ള വാതിലുകൾ തുറക്കുന്നുവെന്നും മനസ്സിലാക്കുക. ഈ പഠനം ക്രിസ്തുവിലേക്ക് ചൂണ്ടിക്കാണിക്കുന്നതും സ്വയം നായകനാക്കുന്നത് ഒഴിവാക്കുന്നതും സുവാർത്തയുടെ ജീവിതമാറ്റം ശക്തി പ്രകടമാക്കുന്നതുമായ സുവിശേഷകേന്ദ്രീകൃത സാക്ഷ്യം തയ്യാറാക്കാൻ നിങ്ങളെ സഹായിക്കുന്നു.', 'മിഷനും സേവനവും'),
  ('888e8400-e29b-41d4-a716-446655440003', 'ml', 'ദരിദ്രർക്കും അവശരായവർക്കും സേവനം ചെയ്യുക', 'ദൈവത്തിന്റെ കരുണയിലും നീതിയിലും വേരൂന്നിയ ദരിദ്രർ, അനാഥർ, വിധവകൾ, പാർശ്വവത്കരിക്കപ്പെട്ടവർ എന്നിവരെ പരിപാലിക്കാനുള്ള ബൈബിളിലെ കൽപ്പന പര്യവേക്ഷണം ചെയ്യുക (ആവർത്തനം 15:11, യാക്കോബ് 1:27). ആവശ്യക്കാരെ സേവിക്കുന്നത് സുവിശേഷത്താൽ പരിവർത്തനം ചെയ്യപ്പെട്ട ഹൃദയത്തിൽ നിന്ന് എങ്ങനെ ഒഴുകുന്നുവെന്ന് പഠിക്കുക - നമ്മുടെ ആത്മീയ ദാരിദ്ര്യത്തിൽ ക്രിസ്തു ആദ്യം നമ്മെ സേവിച്ചതിനാൽ നാം സേവിക്കുന്നു. സാമൂഹിക സുവിശേഷം (ക്രിസ്തുമതത്തെ നല്ല പ്രവൃത്തികളിലേക്ക് കുറയ്ക്കുന്നത്) ഉം സുവിശേഷപ്രചോദിത കരുണ (ശാരീരിക ആവശ്യങ്ങൾ നിറവേറ്റുമ്പോൾ എല്ലായ്പ്പോഴും ആത്മീയ രക്ഷയുടെ വലിയ ആവശ്യകതയിലേക്ക് ചൂണ്ടിക്കാണിക്കുന്നത്) തമ്മിലുള്ള വ്യത്യാസം മനസ്സിലാക്കുക. ത്യാഗപരമായി നൽകുന്നതിനും മാന്യതയോടെ സേവിക്കുന്നതിനും കാരുണ്യ പ്രവൃത്തികളിലൂടെ ക്രിസ്തുവിന്റെ സ്നേഹം കാണിക്കുന്നതിനുമുള്ള പ്രായോഗിക മാർഗങ്ങൾ കണ്ടെത്തുക, യഥാർത്ഥ നീതിയും കാരുണ്യവും ദൈവത്തിന്റെ സ്വഭാവത്തിലും യേശുവിന്റെ വീണ്ടെടുപ്പ് പ്രവൃത്തിയിലും അധിഷ്ഠിതമാണെന്ന് തിരിച്ചറിയുക.', 'മിഷനും സേവനവും'),
  ('888e8400-e29b-41d4-a716-446655440004', 'ml', 'ലളിതമാക്കിയ സുവിശേഷവൽക്കരണം', 'പരിശുദ്ധാത്മാവ് ഹൃദയങ്ങളെ ബോധ്യപ്പെടുത്തുകയും പാപികളെ രക്ഷിക്കുകയും ചെയ്യുന്നുവെന്ന് വിശ്വസിച്ചുകൊണ്ട്, വ്യക്തത, ധൈര്യം, സ്നേഹം എന്നിവയോടെ സുവിശേഷം പങ്കുവെക്കുന്നതിനുള്ള പ്രായോഗികവും ബൈബിളധിഷ്ഠിതവുമായ രീതികൾ പഠിക്കുക (യോഹന്നാൻ 16:8, റോമർ 1:16). സുവിശേഷസന്ദേശത്തിന്റെ അത്യാവശ്യ ഘടകങ്ങൾ മനസ്സിലാക്കുക - ദൈവത്തിന്റെ വിശുദ്ധി, മാനുഷിക പാപം, ക്രിസ്തുവിന്റെ പകരക്കാരനായ മരണവും പുനരുത്ഥാനവും, മാനസാന്തരപ്പെടാനും വിശ്വസിക്കാനുമുള്ള ആഹ്വാനം - ദൈനംദിന സംഭാഷണങ്ങളിൽ അവ എങ്ങനെ ആകർഷകമായി ആശയവിനിമയം നടത്താമെന്ന്. ഭയത്തെ എങ്ങനെ മറികടക്കാമെന്നും എതിർപ്പുകൾ മുൻകൂട്ടി കാണാമെന്നും മനുഷ്യ വാഗ്മിയോ കൈകാര്യമോ ചെയ്യുന്നതിനുപകരം ദൈവവചനത്തിന്റെ ശക്തിയിൽ വിശ്വസിക്കാമെന്നും കണ്ടെത്തുക. ഈ പഠനം സ്വാഭാവിക സന്ദർഭങ്ങളിൽ, ബന്ധങ്ങളിലൂടെ, നഷ്ടപ്പെട്ടവരോടുള്ള യഥാർത്ഥ സ്നേഹത്തോടെ, എല്ലായ്പ്പോഴും രക്ഷയിൽ ദൈവത്തിന്റെ പരമാധികാരത്തെ ആശ്രയിച്ചുകൊണ്ട് ക്രിസ്തുവിനെ വിശ്വസ്തതയോടെ പങ്കുവെക്കാൻ നിങ്ങളെ സജ്ജമാക്കുന്നു.', 'മിഷനും സേവനവും'),
  ('888e8400-e29b-41d4-a716-446655440005', 'ml', 'രാഷ്ട്രങ്ങൾക്കായി പ്രാർത്ഥിക്കുക', 'ഓരോ ഗോത്രം, ഭാഷ, രാഷ്ട്രം എന്നിവയിൽ നിന്നും ആരാധകരെ ശേഖരിക്കാനുള്ള ദൈവത്തിന്റെ ആഗോള ദൗത്യത്തിൽ പങ്കെടുക്കുന്ന രാഷ്ട്രങ്ങൾക്കായി പ്രാർത്ഥിക്കാനുള്ള ബൈബിളിലെ ആഹ്വാനം കണ്ടെത്തുക (വെളിപാട് 7:9). എത്താത്ത ആളുകൾക്കും പീഡിപ്പിക്കപ്പെടുന്ന വിശ്വാസികൾക്കും സുവിശേഷ പുരോഗതിക്കും വേണ്ടിയുള്ള മദ്ധ്യസ്ഥ പ്രാർത്ഥന ക്രിസ്തുവിന്റെ പ്രഖ്യാപനത്തിലൂടെ ലോകമെമ്പാടും പാപികളെ രക്ഷിക്കാനുള്ള ദൈവത്തിന്റെ പരമാധികാര പദ്ധതിയുമായി എങ്ങനെ യോജിക്കുന്നുവെന്ന് പഠിക്കുക. വിശ്വസ്ത പ്രാർത്ഥന മിഷണറിമാരെ എങ്ങനെ പിന്തുണയ്ക്കുന്നുവെന്നും സുവിശേഷത്തിനായി വാതിലുകൾ തുറക്കുന്നുവെന്നും യേശുവിന്റെ നാമം ഇതുവരെ അറിയപ്പെടാത്ത സ്ഥലങ്ങളിൽ ദൈവരാജ്യം മുന്നോട്ട് കൊണ്ടുപോകുന്നുവെന്നും മനസ്സിലാക്കുക. ഈ പഠനം മിഷനുകൾക്കായി ആഗോള കാഴ്ചപ്പാട് വികസിപ്പിക്കാനും നിർദ്ദിഷ്ട ആവശ്യങ്ങൾക്കായി തന്ത്രപരമായി പ്രാർത്ഥിക്കാനും തന്റെ മഹത്വത്തിനും സുവിശേഷ വ്യാപനത്തിനുമായി രാഷ്ട്രങ്ങൾക്കിടയിൽ തന്റെ ഉദ്ദേശ്യങ്ങൾ നിറവേറ്റാൻ ദൈവത്തെ വിശ്വസിക്കാനും വിശ്വാസികളെ പ്രചോദിപ്പിക്കുന്നു.', 'മിഷനും സേവനവും')
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
   'Examine compelling philosophical and biblical evidence for God''s existence through the cosmological argument (the universe requires a first cause), the teleological argument (design in creation points to a Designer), and the moral argument (objective moral values require a moral Lawgiver). Explore how creation itself declares God''s glory (Psalm 19:1, Romans 1:20), and how human conscience and reason testify to His reality. Discover how these arguments complement Scripture''s straightforward declaration: "The fool says in his heart, ''There is no God''" (Psalm 14:1), equipping you to give a reason for the hope within you (1 Peter 3:15).',
   'Theology & Philosophy',
   ARRAY['existence of god', 'apologetics', 'philosophy', 'cosmology', 'evidence'],
   56, 50, 'question'),

  -- 2. Why Does God Allow Evil and Suffering?
  ('AAA00000-e29b-41d4-a716-446655440002',
   'Why Does God Allow Evil and Suffering?',
   'Wrestle with one of faith''s most difficult questions by understanding God''s perfect sovereignty over all things while affirming human moral responsibility for sin (Genesis 3, Romans 5:12). Discover how evil and suffering entered the world through humanity''s rebellion, not God''s design, and how God in His sovereignty uses even evil for His redemptive purposes (Genesis 50:20, Romans 8:28). Explore the biblical tension between God''s goodness, human free will, and the reality of a fallen world groaning for redemption (Romans 8:18-25). Learn to trust God''s character even when His ways are beyond our understanding (Isaiah 55:8-9), knowing He demonstrated His love supremely through Christ''s suffering on our behalf (Romans 5:8).',
   'Theology & Philosophy',
   ARRAY['problem of evil', 'theodicy', 'suffering', 'free will', 'sovereignty'],
   57, 50, 'question'),

  -- 3. Is Jesus the Only Way to Salvation?
  ('AAA00000-e29b-41d4-a716-446655440003',
   'Is Jesus the Only Way to Salvation?',
   'Examine Jesus'' own exclusive claims: "I am the way, and the truth, and the life. No one comes to the Father except through me" (John 14:6), and Peter''s declaration that "there is salvation in no one else, for there is no other name under heaven given among men by which we must be saved" (Acts 4:12). Understand why religious pluralism contradicts biblical teaching about sin, judgment, and the uniqueness of Christ''s atoning sacrifice. Discover how to respond to cultural pluralism with both unwavering conviction about gospel truth and Christlike compassion for those who have not yet believed (Jude 1:22-23). Learn to proclaim the exclusive claims of Christ while demonstrating the inclusive love that sent Him to die for sinners from every tribe, tongue, and nation (Revelation 5:9).',
   'Theology & Philosophy',
   ARRAY['salvation', 'exclusivity', 'jesus', 'pluralism', 'soteriology'],
   58, 50, 'question'),

  -- 4. What About Those Who Never Hear the Gospel?
  ('AAA00000-e29b-41d4-a716-446655440004',
   'What About Those Who Never Hear the Gospel?',
   'Understand God''s general revelation through creation and conscience (Romans 1:18-20, 2:14-15), which leaves all humanity "without excuse" before God''s judgment, while recognizing that saving faith comes only through hearing the gospel of Christ (Romans 10:13-17). Affirm God''s perfect justice—He will judge all people righteously according to the light they have received—while maintaining the biblical necessity of explicit faith in Jesus for salvation. Resist speculation beyond Scripture while trusting the character of the Judge of all the earth who always does right (Genesis 18:25). Let this question drive you to urgent obedience in the Great Commission (Matthew 28:18-20), knowing that God has elect people among every nation who will respond to the gospel when they hear it (Acts 18:10).',
   'Theology & Philosophy',
   ARRAY['unreached', 'general revelation', 'justice', 'missions', 'romans 1-2'],
   59, 50, 'question'),

  -- 5. What is the Trinity?
  ('AAA00000-e29b-41d4-a716-446655440005',
   'What is the Trinity?',
   'Explore the biblical doctrine that God eternally exists as one divine being in three distinct persons—Father, Son, and Holy Spirit—each fully God, yet there is only one God (Deuteronomy 6:4, Matthew 28:19, 2 Corinthians 13:14). See how Scripture reveals the Father as God (John 6:27), the Son as God (John 1:1, Colossians 2:9), and the Spirit as God (Acts 5:3-4), while maintaining absolute monotheism. Understand how the Trinity is essential to salvation: the Father sends, the Son accomplishes redemption through His death and resurrection, and the Spirit applies salvation to believers. Reject false teachings like modalism (one person wearing different masks) and subordinationism (the Son or Spirit as lesser gods), while humbly acknowledging this mystery exceeds full human comprehension (Deuteronomy 29:29).',
   'Theology & Philosophy',
   ARRAY['trinity', 'god', 'theology', 'monotheism', 'godhead'],
   60, 50, 'question'),

  -- 6. Why Doesn't God Answer My Prayers?
  ('AAA00000-e29b-41d4-a716-446655440006',
   'Why Doesn''t God Answer My Prayers?',
   'Learn that God always hears and answers His children''s prayers, but His answers align with His perfect wisdom and sovereign will, not always our timing or desires (1 John 5:14-15, James 4:3). Understand biblical reasons prayers may seem unanswered: unconfessed sin (Psalm 66:18), lack of faith (James 1:6-7), selfish motives (James 4:3), or God''s better plan that we cannot yet see (Isaiah 55:8-9). Discover the purpose of persistent prayer—not to change God''s mind but to change our hearts and deepen our dependence on Him (Luke 18:1-8). Trust that God''s "no" or "wait" is as loving as His "yes," knowing He works all things for the good of those who love Him (Romans 8:28) and will give us what we need according to His riches in glory (Philippians 4:19).',
   'Theology & Philosophy',
   ARRAY['prayer', 'unanswered prayer', 'gods will', 'faith', 'persistence'],
   61, 50, 'question'),

  -- 7. Predestination vs. Free Will
  ('AAA00000-e29b-41d4-a716-446655440007',
   'Predestination vs. Free Will',
   'Navigate the biblical tension between God''s sovereign predestination (Ephesians 1:4-5, Romans 8:29-30) and human responsibility to believe and repent (Acts 17:30, John 3:16-18). Understand that Scripture unashamedly affirms both truths without explaining how they fit together: God chose His elect before the foundation of the world, yet people are genuinely responsible for their response to the gospel. Explore the Reformed emphasis on God''s absolute sovereignty in salvation and the Arminian emphasis on human free will and resistible grace, recognizing sincere believers hold both views. Avoid extreme errors—hyper-Calvinism that denies human responsibility, or semi-Pelagianism that diminishes God''s sovereignty. Rest in God''s mysterious wisdom (Romans 11:33-36) while urgently proclaiming the gospel to all, knowing God uses human means to accomplish His sovereign purposes (Romans 10:14-17).',
   'Theology & Philosophy',
   ARRAY['predestination', 'free will', 'sovereignty', 'election', 'calvinism'],
   62, 50, 'topic'),

  -- 8. Why Are There So Many Christian Denominations?
  ('AAA00000-e29b-41d4-a716-446655440008',
   'Why Are There So Many Christian Denominations?',
   'Understand church history from the early church through the Reformation and modern denominational development, learning how cultural, theological, and practical differences led to the formation of various traditions. Distinguish between essential doctrines that define orthodox Christianity (the gospel, the Trinity, the authority of Scripture, salvation by grace through faith) and non-essential matters where sincere believers may differ (baptism mode, church government, spiritual gifts, end-times views). Apply the ancient maxim: "In essentials, unity; in non-essentials, liberty; in all things, charity." Grieve unnecessary division caused by pride, personality conflicts, or trivial disputes, while recognizing some separations were necessary to preserve gospel truth (Galatians 1:6-9). Pursue genuine unity based on shared commitment to Christ and His Word (Ephesians 4:1-6), not superficial ecumenism that compromises biblical truth.',
   'Theology & Philosophy',
   ARRAY['denominations', 'church history', 'unity', 'doctrine', 'ecclesiology'],
   63, 50, 'topic'),

  -- 9. What is My Purpose in Life?
  ('AAA00000-e29b-41d4-a716-446655440009',
   'What is My Purpose in Life?',
   'Discover that your ultimate purpose is to glorify God and enjoy Him forever (1 Corinthians 10:31, Psalm 73:25-26), a truth that transforms every aspect of life with eternal meaning. Understand that this purpose is fulfilled through faith in Christ for salvation and obedient service flowing from that salvation (Ephesians 2:8-10). Learn how God has uniquely designed you with specific gifts, passions, and circumstances to serve His kingdom purposes in your generation (Psalm 139:13-16, Esther 4:14). Reject the world''s empty pursuit of self-fulfillment, success, or pleasure as ultimate purposes, recognizing these leave the soul unsatisfied (Ecclesiastes 2:1-11). Embrace the joy of knowing Christ and making Him known (Philippians 3:7-11), living each day with eternity in view and confident that your labor in the Lord is never in vain (1 Corinthians 15:58).',
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
   'ब्रह्मांडीय तर्क (ब्रह्मांड को एक प्रथम कारण की आवश्यकता है), उद्देश्यपूर्ण तर्क (सृष्टि में डिज़ाइन एक डिज़ाइनर की ओर इशारा करता है), और नैतिक तर्क (वस्तुनिष्ठ नैतिक मूल्यों को एक नैतिक विधायक की आवश्यकता है) के माध्यम से परमेश्वर के अस्तित्व के लिए आकर्षक दार्शनिक और बाइबिलीय साक्ष्य की जांच करें। खोजें कि कैसे सृष्टि स्वयं परमेश्वर की महिमा की घोषणा करती है (भजन संहिता 19:1, रोमियों 1:20), और कैसे मानव विवेक और तर्क उसकी वास्तविकता की गवाही देते हैं। जानें कि ये तर्क शास्त्र की सीधी घोषणा को कैसे पूरक करते हैं: "मूर्ख अपने मन में कहता है, ''कोई परमेश्वर नहीं है''" (भजन संहिता 14:1), जो आपको अपने भीतर की आशा का कारण देने के लिए सुसज्जित करता है (1 पतरस 3:15)।'),

  ('AAA00000-e29b-41d4-a716-446655440002', 'hi',
   'धर्मशास्त्र और दर्शन',
   'परमेश्वर बुराई और पीड़ा क्यों होने देता है?',
   'विश्वास के सबसे कठिन प्रश्नों में से एक से जूझें, सभी चीजों पर परमेश्वर की पूर्ण संप्रभुता को समझते हुए, जबकि पाप के लिए मानव नैतिक जिम्मेदारी की पुष्टि करते हुए (उत्पत्ति 3, रोमियों 5:12)। जानें कि कैसे बुराई और पीड़ा मानवता के विद्रोह के माध्यम से संसार में प्रवेश की, न कि परमेश्वर की डिज़ाइन से, और कैसे परमेश्वर अपनी संप्रभुता में अपने मुक्तिदायक उद्देश्यों के लिए बुराई का भी उपयोग करता है (उत्पत्ति 50:20, रोमियों 8:28)। परमेश्वर की भलाई, मानव स्वतंत्र इच्छा, और एक पतित दुनिया की वास्तविकता के बीच बाइबिलीय तनाव की खोज करें जो छुटकारे के लिए कराह रही है (रोमियों 8:18-25)। परमेश्वर के चरित्र पर भरोसा करना सीखें, भले ही उसके मार्ग हमारी समझ से परे हों (यशायाह 55:8-9), यह जानते हुए कि उसने हमारी ओर से मसीह की पीड़ा के माध्यम से अपने प्रेम को सर्वोत्तम रूप से प्रदर्शित किया (रोमियों 5:8)।'),

  ('AAA00000-e29b-41d4-a716-446655440003', 'hi',
   'धर्मशास्त्र और दर्शन',
   'क्या यीशु ही उद्धार का एकमात्र रास्ता है?',
   'यीशु के अपने विशेष दावों की जांच करें: "मार्ग और सत्य और जीवन मैं ही हूं; बिना मेरे द्वारा कोई पिता के पास नहीं पहुंच सकता" (यूहन्ना 14:6), और पतरस की घोषणा कि "किसी दूसरे के द्वारा उद्धार नहीं; क्योंकि स्वर्ग के नीचे मनुष्यों में और कोई दूसरा नाम नहीं दिया गया, जिसके द्वारा हम उद्धार पा सकें" (प्रेरितों के काम 4:12)। समझें कि धार्मिक बहुलवाद पाप, न्याय, और मसीह के प्रायश्चित बलिदान की विशिष्टता के बारे में बाइबिल की शिक्षा का खंडन क्यों करता है। जानें कि कैसे सांस्कृतिक बहुलवाद का जवाब सुसमाचार सत्य के बारे में अटल विश्वास और उन लोगों के लिए मसीह-समान करुणा दोनों के साथ दिया जाए जिन्होंने अभी तक विश्वास नहीं किया है (यहूदा 1:22-23)। मसीह के विशेष दावों की घोषणा करना सीखें, जबकि उस समावेशी प्रेम का प्रदर्शन करते हुए जिसने उन्हें हर जनजाति, भाषा और राष्ट्र के पापियों के लिए मरने के लिए भेजा (प्रकाशितवाक्य 5:9)।'),

  ('AAA00000-e29b-41d4-a716-446655440004', 'hi',
   'धर्मशास्त्र और दर्शन',
   'उनके बारे में क्या जो कभी सुसमाचार नहीं सुनते?',
   'सृष्टि और विवेक के माध्यम से परमेश्वर के सामान्य प्रकाशन को समझें (रोमियों 1:18-20, 2:14-15), जो सभी मानवता को परमेश्वर के न्याय के सामने "बिना बहाने" छोड़ देता है, जबकि यह पहचानते हुए कि बचाने वाला विश्वास केवल मसीह के सुसमाचार को सुनने के माध्यम से आता है (रोमियों 10:13-17)। परमेश्वर के पूर्ण न्याय की पुष्टि करें - वह सभी लोगों का धर्मी न्याय उस प्रकाश के अनुसार करेगा जो उन्हें प्राप्त हुआ है - जबकि उद्धार के लिए यीशु में स्पष्ट विश्वास की बाइबिलीय आवश्यकता को बनाए रखते हुए। शास्त्र से परे अटकलों का विरोध करें जबकि सारी पृथ्वी के न्यायाधीश के चरित्र पर भरोसा करें जो हमेशा सही करता है (उत्पत्ति 18:25)। इस प्रश्न को आपको महान आयोग में तत्काल आज्ञाकारिता की ओर प्रेरित करने दें (मत्ती 28:18-20), यह जानते हुए कि परमेश्वर के पास हर राष्ट्र के बीच चुने हुए लोग हैं जो सुसमाचार सुनने पर प्रतिक्रिया देंगे (प्रेरितों के काम 18:10)।'),

  ('AAA00000-e29b-41d4-a716-446655440005', 'hi',
   'धर्मशास्त्र और दर्शन',
   'त्रिएकता क्या है?',
   'बाइबिलीय सिद्धांत की खोज करें कि परमेश्वर तीन विशिष्ट व्यक्तियों - पिता, पुत्र और पवित्र आत्मा - में एक दिव्य अस्तित्व के रूप में अनंत काल से मौजूद है, प्रत्येक पूर्णतः परमेश्वर, फिर भी केवल एक ही परमेश्वर है (व्यवस्थाविवरण 6:4, मत्ती 28:19, 2 कुरिन्थियों 13:14)। देखें कि कैसे शास्त्र पिता को परमेश्वर के रूप में (यूहन्ना 6:27), पुत्र को परमेश्वर के रूप में (यूहन्ना 1:1, कुलुस्सियों 2:9), और आत्मा को परमेश्वर के रूप में (प्रेरितों के काम 5:3-4) प्रकट करता है, जबकि पूर्ण एकेश्वरवाद को बनाए रखता है। समझें कि त्रिएकता उद्धार के लिए कैसे आवश्यक है: पिता भेजता है, पुत्र अपनी मृत्यु और पुनरुत्थान के माध्यम से मुक्ति पूरी करता है, और आत्मा विश्वासियों पर उद्धार लागू करता है। झूठी शिक्षाओं को अस्वीकार करें जैसे मोडलिज़्म (विभिन्न मुखौटे पहने एक व्यक्ति) और अधीनतावाद (पुत्र या आत्मा को कम देवताओं के रूप में), जबकि विनम्रतापूर्वक स्वीकार करते हुए कि यह रहस्य पूर्ण मानव समझ से परे है (व्यवस्थाविवरण 29:29)।'),

  ('AAA00000-e29b-41d4-a716-446655440006', 'hi',
   'धर्मशास्त्र और दर्शन',
   'परमेश्वर मेरी प्रार्थनाओं का उत्तर क्यों नहीं देता?',
   'जानें कि परमेश्वर हमेशा अपने बच्चों की प्रार्थनाओं को सुनता है और उत्तर देता है, लेकिन उसके उत्तर उसकी पूर्ण बुद्धि और संप्रभु इच्छा के साथ संरेखित होते हैं, हमेशा हमारे समय या इच्छाओं के अनुसार नहीं (1 यूहन्ना 5:14-15, याकूब 4:3)। समझें कि प्रार्थनाएं अनुत्तरित क्यों लग सकती हैं: अस्वीकृत पाप (भजन संहिता 66:18), विश्वास की कमी (याकूब 1:6-7), स्वार्थी उद्देश्य (याकूब 4:3), या परमेश्वर की बेहतर योजना जिसे हम अभी तक नहीं देख सकते (यशायाह 55:8-9)। लगातार प्रार्थना के उद्देश्य को जानें - परमेश्वर का मन बदलने के लिए नहीं बल्कि हमारे दिलों को बदलने और उस पर हमारी निर्भरता को गहरा करने के लिए (लूका 18:1-8)। भरोसा करें कि परमेश्वर का "नहीं" या "प्रतीक्षा करो" उसके "हां" जितना ही प्रेमपूर्ण है, यह जानते हुए कि वह उन लोगों की भलाई के लिए सभी चीजों को काम करता है जो उससे प्रेम करते हैं (रोमियों 8:28) और वह हमें उसकी महिमा में अपने धन के अनुसार हमारी आवश्यकता देगा (फिलिप्पियों 4:19)।'),

  ('AAA00000-e29b-41d4-a716-446655440007', 'hi',
   'धर्मशास्त्र और दर्शन',
   'पूर्वनियति बनाम स्वतंत्र इच्छा',
   'परमेश्वर की संप्रभु पूर्वनियति (इफिसियों 1:4-5, रोमियों 8:29-30) और विश्वास करने और पश्चाताप करने के लिए मानव जिम्मेदारी (प्रेरितों के काम 17:30, यूहन्ना 3:16-18) के बीच बाइबिलीय तनाव को नेविगेट करें। समझें कि शास्त्र निडरता से दोनों सत्यों की पुष्टि करता है बिना यह समझाए कि वे एक साथ कैसे फिट होते हैं: परमेश्वर ने दुनिया की नींव से पहले अपने चुने हुए लोगों को चुना, फिर भी लोग सुसमाचार के प्रति अपनी प्रतिक्रिया के लिए वास्तव में जिम्मेदार हैं। सुधारवादी जोर की खोज करें उद्धार में परमेश्वर की पूर्ण संप्रभुता पर और आर्मिनियन जोर मानव स्वतंत्र इच्छा और प्रतिरोधी अनुग्रह पर, यह पहचानते हुए कि ईमानदार विश्वासी दोनों विचारों को रखते हैं। चरम त्रुटियों से बचें - अति-कैल्विनवाद जो मानव जिम्मेदारी को नकारता है, या अर्ध-पेलागियनवाद जो परमेश्वर की संप्रभुता को कम करता है। परमेश्वर की रहस्यमय बुद्धि में विश्राम करें (रोमियों 11:33-36) जबकि तत्कालता से सभी को सुसमाचार की घोषणा करें, यह जानते हुए कि परमेश्वर अपने संप्रभु उद्देश्यों को पूरा करने के लिए मानव साधनों का उपयोग करता है (रोमियों 10:14-17)।'),

  ('AAA00000-e29b-41d4-a716-446655440008', 'hi',
   'धर्मशास्त्र और दर्शन',
   'इतने सारे ईसाई संप्रदाय क्यों हैं?',
   'प्रारंभिक कलीसिया से सुधार और आधुनिक संप्रदायों के विकास तक कलीसिया के इतिहास को समझें, यह सीखते हुए कि सांस्कृतिक, धर्मशास्त्रीय और व्यावहारिक अंतरों ने विभिन्न परंपराओं के गठन को कैसे प्रेरित किया। आवश्यक सिद्धांतों के बीच अंतर करें जो रूढ़िवादी ईसाई धर्म को परिभाषित करते हैं (सुसमाचार, त्रिएकता, शास्त्र का अधिकार, विश्वास के माध्यम से अनुग्रह द्वारा उद्धार) और गैर-आवश्यक मामलों में जहां ईमानदार विश्वासी भिन्न हो सकते हैं (बपतिस्मा की विधि, कलीसिया सरकार, आत्मिक वरदान, अंत समय के दृष्टिकोण)। प्राचीन कहावत लागू करें: "आवश्यक चीजों में, एकता; गैर-आवश्यक चीजों में, स्वतंत्रता; सभी चीजों में, दान।" अनावश्यक विभाजन के लिए शोक करें जो गर्व, व्यक्तित्व संघर्ष, या तुच्छ विवादों के कारण हुआ, जबकि यह पहचानते हुए कि कुछ अलगाव सुसमाचार सत्य को संरक्षित करने के लिए आवश्यक थे (गलातियों 1:6-9)। मसीह और उसके वचन के लिए साझा प्रतिबद्धता के आधार पर वास्तविक एकता का पीछा करें (इफिसियों 4:1-6), न कि सतही सर्वव्यापकता जो बाइबिलीय सत्य से समझौता करती है।'),

  ('AAA00000-e29b-41d4-a716-446655440009', 'hi',
   'धर्मशास्त्र और दर्शन',
   'मेरे जीवन का उद्देश्य क्या है?',
   'जानें कि आपका अंतिम उद्देश्य परमेश्वर की महिमा करना और हमेशा के लिए उसका आनंद लेना है (1 कुरिन्थियों 10:31, भजन संहिता 73:25-26), एक सत्य जो जीवन के हर पहलू को शाश्वत अर्थ के साथ परिवर्तित करता है। समझें कि यह उद्देश्य उद्धार के लिए मसीह में विश्वास और उस उद्धार से बहने वाली आज्ञाकारी सेवा के माध्यम से पूरा होता है (इफिसियों 2:8-10)। जानें कि परमेश्वर ने आपको विशिष्ट वरदानों, जुनून और परिस्थितियों के साथ अद्वितीय रूप से डिज़ाइन किया है ताकि आप अपनी पीढ़ी में उसके राज्य के उद्देश्यों की सेवा कर सकें (भजन संहिता 139:13-16, एस्तेर 4:14)। अंतिम उद्देश्यों के रूप में आत्म-पूर्ति, सफलता, या आनंद की दुनिया की खोखली खोज को अस्वीकार करें, यह पहचानते हुए कि ये आत्मा को असंतुष्ट छोड़ देते हैं (सभोपदेशक 2:1-11)। मसीह को जानने और उसे ज्ञात करने की खुशी को अपनाएं (फिलिप्पियों 3:7-11), प्रत्येक दिन को अनंत काल को ध्यान में रखते हुए जिएं और आश्वस्त रहें कि प्रभु में आपका श्रम कभी व्यर्थ नहीं होता (1 कुरिन्थियों 15:58)।')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam Translations
INSERT INTO recommended_topics_translations (topic_id, language_code, category, title, description)
VALUES
  ('AAA00000-e29b-41d4-a716-446655440001', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'ദൈവം ഉണ്ടോ?',
   'പ്രപഞ്ച വാദം (പ്രപഞ്ചത്തിന് ഒരു പ്രഥമ കാരണം ആവശ്യമാണ്), ലക്ഷ്യ വാദം (സൃഷ്ടിയിലെ രൂപകൽപ്പന ഒരു രൂപകല്പകനെ സൂചിപ്പിക്കുന്നു), ധാർമ്മിക വാദം (വസ്തുനിഷ്ഠമായ ധാർമ്മിക മൂല്യങ്ങൾക്ക് ഒരു ധാർമ്മിക നിയമദാതാവിനെ ആവശ്യമാണ്) എന്നിവയിലൂടെ ദൈവത്തിന്റെ അസ്തിത്വത്തിനുള്ള ശ്രദ്ധേയമായ ദാർശനികവും ബൈബിൾപരവുമായ തെളിവുകൾ പരിശോധിക്കുക. സൃഷ്ടി തന്നെ ദൈവത്തിന്റെ മഹത്വം എങ്ങനെ പ്രഖ്യാപിക്കുന്നുവെന്നും (സങ്കീർത്തനം 19:1, റോമർ 1:20), മനുഷ്യ മനസ്സാക്ഷിയും യുക്തിയും അവന്റെ യാഥാർത്ഥ്യത്തിന് എങ്ങനെ സാക്ഷ്യം വഹിക്കുന്നുവെന്നും കണ്ടെത്തുക. ഈ വാദങ്ങൾ തിരുവെഴുത്തിന്റെ നേരായ പ്രഖ്യാപനത്തെ എങ്ങനെ പൂരകമാക്കുന്നുവെന്ന് കണ്ടെത്തുക: "ദൈവമില്ലെന്ന് ഭോഷൻ തന്റെ ഹൃദയത്തിൽ പറയുന്നു" (സങ്കീർത്തനം 14:1), നിങ്ങളിലെ പ്രത്യാശയ്ക്ക് ഒരു കാരണം നൽകാൻ നിങ്ങളെ സജ്ജമാക്കുന്നു (1 പത്രോസ് 3:15).'),

  ('AAA00000-e29b-41d4-a716-446655440002', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'ദൈവം തിന്മയും കഷ്ടപ്പാടും അനുവദിക്കുന്നത് എന്തുകൊണ്ട്?',
   'വിശ്വാസത്തിന്റെ ഏറ്റവും ബുദ്ധിമുട്ടുള്ള ചോദ്യങ്ങളിലൊന്നുമായി മല്ലിടുക, എല്ലാ കാര്യങ്ങളുടെയും മേൽ ദൈവത്തിന്റെ പൂർണ്ണ പരമാധികാരം മനസ്സിലാക്കുന്നതോടൊപ്പം പാപത്തിനുള്ള മനുഷ്യ ധാർമ്മിക ഉത്തരവാദിത്തം സ്ഥിരീകരിക്കുന്നു (ഉല്പത്തി 3, റോമർ 5:12). തിന്മയും കഷ്ടപ്പാടും ദൈവത്തിന്റെ രൂപകൽപ്പനയിലൂടെയല്ല, മനുഷ്യരാശിയുടെ മത്സരത്തിലൂടെയാണ് ലോകത്തിലേക്ക് പ്രവേശിച്ചതെന്നും, ദൈവം തന്റെ പരമാധികാരത്തിൽ തന്റെ വീണ്ടെടുപ്പ് ലക്ഷ്യങ്ങൾക്കായി തിന്മയെപ്പോലും എങ്ങനെ ഉപയോഗിക്കുന്നുവെന്നും കണ്ടെത്തുക (ഉല്പത്തി 50:20, റോമർ 8:28). ദൈവത്തിന്റെ നന്മ, മനുഷ്യ സ്വതന്ത്ര ഇച്ഛാശക്തി, വീണ്ടെടുപ്പിനായി ഞരങ്ങുന്ന വീണുപോയ ലോകത്തിന്റെ യാഥാർത്ഥ്യം എന്നിവയ്ക്കിടയിലുള്ള ബൈബിൾ പിരിമുറുക്കം പര്യവേക്ഷണം ചെയ്യുക (റോമർ 8:18-25). ദൈവത്തിന്റെ വഴികൾ നമ്മുടെ ധാരണയ്ക്കപ്പുറമാണെങ്കിലും അവന്റെ സ്വഭാവത്തിൽ വിശ്വസിക്കാൻ പഠിക്കുക (യെശയ്യാവ് 55:8-9), നമ്മുടെ പേരിൽ ക്രിസ്തുവിന്റെ കഷ്ടപ്പാടിലൂടെ അവൻ തന്റെ സ്നേഹം പരമമായി പ്രദർശിപ്പിച്ചുവെന്ന് അറിയുന്നു (റോമർ 5:8).'),

  ('AAA00000-e29b-41d4-a716-446655440003', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'രക്ഷയ്ക്കുള്ള ഏക മാർഗം യേശുവാണോ?',
   'യേശുവിന്റെ തന്നെ പ്രത്യേക അവകാശവാദങ്ങൾ പരിശോധിക്കുക: "ഞാൻ തന്നെയാണ് വഴിയും സത്യവും ജീവനും; എന്നിലൂടെയല്ലാതെ ആരും പിതാവിന്റെ അടുക്കൽ വരുന്നില്ല" (യോഹന്നാൻ 14:6), പത്രോസിന്റെ പ്രഖ്യാപനം "മറ്റാരിലും രക്ഷയില്ല; കാരണം സ്വർഗ്ഗത്തിൻ കീഴിൽ മനുഷ്യരുടെ ഇടയിൽ നാം രക്ഷപ്പെടേണ്ടതിന് മറ്റൊരു നാമം നൽകപ്പെട്ടിട്ടില്ല" (പ്രവൃത്തികൾ 4:12). പാപം, ന്യായവിധി, ക്രിസ്തുവിന്റെ പ്രായശ്ചിത്ത ബലിയുടെ അനന്യത എന്നിവയെക്കുറിച്ചുള്ള ബൈബിൾ പഠിപ്പിക്കലുമായി മത ബഹുസ്വരത എന്തുകൊണ്ട് വിരുദ്ധമാണെന്ന് മനസ്സിലാക്കുക. സുവിശേഷ സത്യത്തെക്കുറിച്ചുള്ള അചഞ്ചലമായ ബോധ്യത്തോടും ഇതുവരെ വിശ്വസിക്കാത്തവരോടുള്ള ക്രിസ്തുസമാനമായ അനുകമ്പയോടും കൂടി സാംസ്കാരിക ബഹുസ്വരതയോട് എങ്ങനെ പ്രതികരിക്കാമെന്ന് കണ്ടെത്തുക (യൂദാ 1:22-23). ക്രിസ്തുവിന്റെ പ്രത്യേക അവകാശവാദങ്ങൾ പ്രഖ്യാപിക്കാനും എല്ലാ ഗോത്രങ്ങളിൽ നിന്നും ഭാഷകളിൽ നിന്നും രാഷ്ട്രങ്ങളിൽ നിന്നുമുള്ള പാപികൾക്കുവേണ്ടി മരിക്കാൻ അവനെ അയച്ച സമാവേശപരമായ സ്നേഹം പ്രദർശിപ്പിക്കാനും പഠിക്കുക (വെളിപാട് 5:9).'),

  ('AAA00000-e29b-41d4-a716-446655440004', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'സുവിശേഷം കേൾക്കാത്തവരെ കുറിച്ച് എന്ത്?',
   'സൃഷ്ടിയിലൂടെയും മനസ്സാക്ഷിയിലൂടെയും ദൈവത്തിന്റെ പൊതു വെളിപാട് മനസ്സിലാക്കുക (റോമർ 1:18-20, 2:14-15), അത് എല്ലാ മനുഷ്യരാശിയെയും ദൈവത്തിന്റെ ന്യായവിധിക്ക് മുമ്പാകെ "ഒഴികഴിവില്ലാതെ" വിടുന്നു, അതേസമയം രക്ഷിക്കുന്ന വിശ്വാസം ക്രിസ്തുവിന്റെ സുവിശേഷം കേൾക്കുന്നതിലൂടെ മാത്രമേ വരുന്നുള്ളൂവെന്ന് തിരിച്ചറിയുന്നു (റോമർ 10:13-17). ദൈവത്തിന്റെ പൂർണ്ണ നീതി സ്ഥിരീകരിക്കുക - അവൻ എല്ലാ മനുഷ്യരെയും അവർക്ക് ലഭിച്ച പ്രകാശത്തിന് അനുസൃതമായി നീതിപൂർവ്വം വിധിക്കും - അതേസമയം രക്ഷയ്ക്കായി യേശുവിലുള്ള വ്യക്തമായ വിശ്വാസത്തിന്റെ ബൈബിൾ ആവശ്യകത നിലനിർത്തുന്നു. തിരുവെഴുത്തിനപ്പുറമുള്ള ഊഹാപോഹങ്ങളെ ചെറുക്കുക, അതേസമയം എല്ലാ ഭൂമിയുടെയും ന്യായാധിപതിയുടെ സ്വഭാവത്തിൽ വിശ്വസിക്കുക, അവൻ എപ്പോഴും ശരിയായത് ചെയ്യുന്നു (ഉല്പത്തി 18:25). മഹാകമ്മീഷനിൽ അടിയന്തിര അനുസരണത്തിലേക്ക് ഈ ചോദ്യം നിങ്ങളെ നയിക്കട്ടെ (മത്തായി 28:18-20), എല്ലാ രാഷ്ട്രങ്ങളിലും ദൈവത്തിന് തിരഞ്ഞെടുക്കപ്പെട്ട ആളുകളുണ്ടെന്ന് അറിയുന്നു, അവർ സുവിശേഷം കേൾക്കുമ്പോൾ പ്രതികരിക്കും (പ്രവൃത്തികൾ 18:10).'),

  ('AAA00000-e29b-41d4-a716-446655440005', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'ത്രിത്വം എന്താണ്?',
   'ദൈവം മൂന്ന് വ്യത്യസ്ത വ്യക്തികളായ പിതാവ്, പുത്രൻ, പരിശുദ്ധാത്മാവ് എന്നിവയിൽ നിത്യമായി ഒരു ദൈവിക അസ്തിത്വമായി നിലനിൽക്കുന്നു - ഓരോരുത്തരും പൂർണ്ണമായും ദൈവം, എന്നാൽ ഒരു ദൈവം മാത്രം ഉണ്ട് എന്ന ബൈബിൾ സിദ്ധാന്തം പര്യവേക്ഷണം ചെയ്യുക (ആവർത്തനം 6:4, മത്തായി 28:19, 2 കൊരിന്ത്യർ 13:14). തിരുവെഴുത്ത് പിതാവിനെ ദൈവമായി (യോഹന്നാൻ 6:27), പുത്രനെ ദൈവമായി (യോഹന്നാൻ 1:1, കൊലോസ്യർ 2:9), ആത്മാവിനെ ദൈവമായി (പ്രവൃത്തികൾ 5:3-4) എങ്ങനെ വെളിപ്പെടുത്തുന്നുവെന്ന് കാണുക, അതേസമയം കേവലമായ ഏകദൈവാരാധന നിലനിർത്തുന്നു. രക്ഷയ്ക്ക് ത്രിത്വം എങ്ങനെ അനിവാര്യമാണെന്ന് മനസ്സിലാക്കുക: പിതാവ് അയയ്ക്കുന്നു, പുത്രൻ തന്റെ മരണത്തിലൂടെയും പുനരുത്ഥാനത്തിലൂടെയും വീണ്ടെടുപ്പ് പൂർത്തീകരിക്കുന്നു, ആത്മാവ് വിശ്വാസികൾക്ക് രക്ഷ പ്രയോഗിക്കുന്നു. മോഡലിസം (വ്യത്യസ്ത മുഖംമൂടികൾ ധരിക്കുന്ന ഒരു വ്യക്തി), കീഴാളത്വം (പുത്രനോ ആത്മാവോ കുറഞ്ഞ ദൈവങ്ങളായി) തുടങ്ങിയ തെറ്റായ പഠിപ്പിക്കലുകൾ നിരസിക്കുക, അതേസമയം ഈ രഹസ്യം പൂർണ്ണ മാനുഷിക ധാരണയ്ക്കപ്പുറമാണെന്ന് വിനീതമായി അംഗീകരിക്കുക (ആവർത്തനം 29:29).'),

  ('AAA00000-e29b-41d4-a716-446655440006', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'എന്തുകൊണ്ട് ദൈവം എന്റെ പ്രാർത്ഥനകൾക്ക് ഉത്തരം നൽകുന്നില്ല?',
   'ദൈവം എപ്പോഴും തന്റെ മക്കളുടെ പ്രാർത്ഥനകൾ കേൾക്കുകയും ഉത്തരം നൽകുകയും ചെയ്യുന്നുവെന്ന് പഠിക്കുക, എന്നാൽ അവന്റെ ഉത്തരങ്ങൾ അവന്റെ പൂർണ്ണ ജ്ഞാനവും പരമാധികാര ഇച്ഛയുമായി പൊരുത്തപ്പെടുന്നു, എല്ലായ്പ്പോഴും നമ്മുടെ സമയമോ ആഗ്രഹങ്ങളോ അല്ല (1 യോഹന്നാൻ 5:14-15, യാക്കോബ് 4:3). പ്രാർത്ഥനകൾക്ക് ഉത്തരം ലഭിക്കാത്തതായി തോന്നുന്നതിന് ബൈബിൾപരമായ കാരണങ്ങൾ മനസ്സിലാക്കുക: ഏറ്റുപറയാത്ത പാപം (സങ്കീർത്തനം 66:18), വിശ്വാസമില്ലായ്മ (യാക്കോബ് 1:6-7), സ്വാർത്ഥ ഉദ്ദേശങ്ങൾ (യാക്കോബ് 4:3), അല്ലെങ്കിൽ ദൈവത്തിന്റെ മികച്ച പദ്ധതി നമുക്ക് ഇതുവരെ കാണാൻ കഴിയില്ല (യെശയ്യാവ് 55:8-9). നിരന്തരമായ പ്രാർത്ഥനയുടെ ലക്ഷ്യം കണ്ടെത്തുക - ദൈവത്തിന്റെ മനസ്സ് മാറ്റാനല്ല, മറിച്ച് നമ്മുടെ ഹൃദയങ്ങളെ മാറ്റാനും അവനിലുള്ള നമ്മുടെ ആശ്രിതത്വം ആഴത്തിലാക്കാനും (ലൂക്കോസ് 18:1-8). ദൈവത്തിന്റെ "ഇല്ല" അല്ലെങ്കിൽ "കാത്തിരിക്കുക" അവന്റെ "അതെ" പോലെ തന്നെ സ്നേഹപൂർവ്വമാണെന്ന് വിശ്വസിക്കുക, അവനെ സ്നേഹിക്കുന്നവരുടെ നന്മയ്ക്കായി അവൻ എല്ലാ കാര്യങ്ങളും പ്രവർത്തിക്കുന്നുവെന്ന് അറിയുന്നു (റോമർ 8:28), അവൻ തന്റെ മഹത്വത്തിലെ സമ്പത്തിന് അനുസൃതമായി നമുക്ക് ആവശ്യമുള്ളത് നൽകുമെന്ന് (ഫിലിപ്പിയർ 4:19).'),

  ('AAA00000-e29b-41d4-a716-446655440007', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'മുൻനിർണയം vs. സ്വതന്ത്ര ഇച്ഛാശക്തി',
   'ദൈവത്തിന്റെ പരമാധികാര മുൻനിർണയം (എഫെസ്യർ 1:4-5, റോമർ 8:29-30) വിശ്വസിക്കാനും മാനസാന്തരപ്പെടാനുമുള്ള മനുഷ്യ ഉത്തരവാദിത്വം (പ്രവൃത്തികൾ 17:30, യോഹന്നാൻ 3:16-18) എന്നിവയ്ക്കിടയിലുള്ള ബൈബിൾ പിരിമുറുക്കം നാവിഗേറ്റ് ചെയ്യുക. അവ എങ്ങനെ ഒരുമിച്ച് യോജിക്കുന്നുവെന്ന് വിശദീകരിക്കാതെ തന്നെ തിരുവെഴുത്ത് നിർഭയമായി രണ്ട് സത്യങ്ങളും സ്ഥിരീകരിക്കുന്നുവെന്ന് മനസ്സിലാക്കുക: ലോകസ്ഥാപനത്തിനു മുമ്പ് ദൈവം തന്റെ തിരഞ്ഞെടുക്കപ്പെട്ടവരെ തിരഞ്ഞെടുത്തു, എന്നാൽ സുവിശേഷത്തോടുള്ള അവരുടെ പ്രതികരണത്തിന് ആളുകൾ യഥാർത്ഥമായി ഉത്തരവാദികളാണ്. രക്ഷയിൽ ദൈവത്തിന്റെ കേവല പരമാധികാരത്തെക്കുറിച്ചുള്ള പരിഷ്കൃത ഊന്നലും മനുഷ്യ സ്വതന്ത്ര ഇച്ഛാശക്തിയെയും പ്രതിരോധിക്കാവുന്ന കൃപയെയും കുറിച്ചുള്ള ആർമിനിയൻ ഊന്നലും പര്യവേക്ഷണം ചെയ്യുക, ആത്മാർത്ഥരായ വിശ്വാസികൾ രണ്ട് വീക്ഷണങ്ങളും പുലർത്തുന്നുവെന്ന് തിരിച്ചറിയുന്നു. അതിരുകടന്ന പിശകുകൾ ഒഴിവാക്കുക - മനുഷ്യ ഉത്തരവാദിത്തം നിഷേധിക്കുന്ന ഹൈപ്പർ-കാൽവിനിസം, അല്ലെങ്കിൽ ദൈവത്തിന്റെ പരമാധികാരം കുറയ്ക്കുന്ന സെമി-പെലാജിയാനിസം. ദൈവത്തിന്റെ നിഗൂഢമായ ജ്ഞാനത്തിൽ വിശ്രമിക്കുക (റോമർ 11:33-36), അതേസമയം അടിയന്തിരമായി എല്ലാവർക്കും സുവിശേഷം പ്രഖ്യാപിക്കുക, ദൈവം തന്റെ പരമാധികാര ലക്ഷ്യങ്ങൾ നിറവേറ്റാൻ മാനുഷിക മാർഗങ്ങൾ ഉപയോഗിക്കുന്നുവെന്ന് അറിയുന്നു (റോമർ 10:14-17).'),

  ('AAA00000-e29b-41d4-a716-446655440008', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'എന്തുകൊണ്ട് ഇത്ര അധികം ക്രൈസ്തവ വിഭാഗങ്ങൾ?',
   'ആദിമ സഭയിൽ നിന്ന് നവീകരണത്തിലൂടെയും ആധുനിക വിഭാഗ വികസനത്തിലൂടെയും സഭാ ചരിത്രം മനസ്സിലാക്കുക, സാംസ്കാരിക, ദൈവശാസ്ത്ര, പ്രായോഗിക വ്യത്യാസങ്ങൾ വിവിധ പാരമ്പര്യങ്ങളുടെ രൂപീകരണത്തിലേക്ക് എങ്ങനെ നയിച്ചുവെന്ന് പഠിക്കുക. യാഥാസ്ഥിതിക ക്രിസ്തുമതത്തെ നിർവ്വചിക്കുന്ന അവശ്യ സിദ്ധാന്തങ്ങൾ (സുവിശേഷം, ത്രിത്വം, തിരുവെഴുത്തിന്റെ അധികാരം, വിശ്വാസത്തിലൂടെ കൃപയാൽ രക്ഷ) ആത്മാർത്ഥരായ വിശ്വാസികൾ വ്യത്യാസപ്പെടാൻ സാധ്യതയുള്ള അവശ്യമല്ലാത്ത കാര്യങ്ങൾ (സ്നാന രീതി, സഭാ ഭരണം, ആത്മീയ വരദാനങ്ങൾ, അന്ത്യകാല വീക്ഷണങ്ങൾ) എന്നിവയ്ക്കിടയിൽ വ്യത്യാസപ്പെടുത്തുക. പുരാതന പഴഞ്ചൊല്ല് പ്രയോഗിക്കുക: "അവശ്യകാര്യങ്ങളിൽ, ഐക്യം; അവശ്യമല്ലാത്തവയിൽ, സ്വാതന്ത്ര്യം; എല്ലാ കാര്യങ്ങളിലും, സ്നേഹം." അഹങ്കാരം, വ്യക്തിത്വ സംഘട്ടനങ്ങൾ, അല്ലെങ്കിൽ നിസ്സാര തർക്കങ്ങൾ എന്നിവ കാരണമുണ്ടായ അനാവശ്യമായ വിഭജനത്തിൽ ദുഃഖിക്കുക, അതേസമയം സുവിശേഷ സത്യം സംരക്ഷിക്കുന്നതിന് ചില വേർപിരിയലുകൾ ആവശ്യമാണെന്ന് തിരിച്ചറിയുന്നു (ഗലാത്യർ 1:6-9). ക്രിസ്തുവിലും അവന്റെ വചനത്തിലും പങ്കിട്ട പ്രതിബദ്ധതയെ അടിസ്ഥാനമാക്കിയുള്ള യഥാർത്ഥ ഐക്യം പിന്തുടരുക (എഫെസ്യർ 4:1-6), ബൈബിൾ സത്യവുമായി വിട്ടുവീഴ്ച ചെയ്യുന്ന ഉപരിപ്ലവമായ എക്യുമെനിസമല്ല.'),

  ('AAA00000-e29b-41d4-a716-446655440009', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'എന്റെ ജീവിതത്തിന്റെ ലക്ഷ്യം എന്താണ്?',
   'നിങ്ങളുടെ ആത്യന്തിക ലക്ഷ്യം ദൈവത്തെ മഹത്വപ്പെടുത്തുകയും എന്നെന്നേക്കുമായി അവനെ ആസ്വദിക്കുകയും ചെയ്യുക എന്നതാണെന്ന് കണ്ടെത്തുക (1 കൊരിന്ത്യർ 10:31, സങ്കീർത്തനം 73:25-26), ജീവിതത്തിന്റെ എല്ലാ വശങ്ങളെയും ശാശ്വത അർത്ഥത്തോടെ പരിവർത്തനം ചെയ്യുന്ന ഒരു സത്യം. രക്ഷയ്ക്കുവേണ്ടി ക്രിസ്തുവിലുള്ള വിശ്വാസത്തിലൂടെയും ആ രക്ഷയിൽ നിന്ന് ഒഴുകുന്ന അനുസരണപൂർണ്ണമായ സേവനത്തിലൂടെയും ഈ ലക്ഷ്യം പൂർത്തീകരിക്കപ്പെടുന്നുവെന്ന് മനസ്സിലാക്കുക (എഫെസ്യർ 2:8-10). നിങ്ങളുടെ തലമുറയിൽ അവന്റെ രാജ്യ ലക്ഷ്യങ്ങൾ സേവിക്കാൻ ദൈവം പ്രത്യേക വരദാനങ്ങൾ, അഭിനിവേശങ്ങൾ, സാഹചര്യങ്ങൾ എന്നിവ ഉപയോഗിച്ച് നിങ്ങളെ എങ്ങനെ അതുല്യമായി രൂപകൽപ്പന ചെയ്തിട്ടുണ്ടെന്ന് പഠിക്കുക (സങ്കീർത്തനം 139:13-16, എസ്തേർ 4:14). ആത്മീയമായ ലക്ഷ്യങ്ങളായി സ്വയം-സാക്ഷാത്കാരം, വിജയം, അല്ലെങ്കിൽ ആനന്ദം എന്നിവയുടെ ലോകത്തിന്റെ ശൂന്യമായ അന്വേഷണം നിരസിക്കുക, ഇവ ആത്മാവിനെ അതൃപ്തനാക്കുന്നുവെന്ന് തിരിച്ചറിയുക (സഭാപ്രസംഗി 2:1-11). ക്രിസ്തുവിനെ അറിയുന്നതിന്റെയും അവനെ അറിയിക്കുന്നതിന്റെയും ആനന്ദം സ്വീകരിക്കുക (ഫിലിപ്പിയർ 3:7-11), നിത്യത മനസ്സിൽ വെച്ചുകൊണ്ട് ഓരോ ദിവസവും ജീവിക്കുക, കർത്താവിലുള്ള നിങ്ങളുടെ പ്രയത്നം ഒരിക്കലും വ്യർത്ഥമാകില്ലെന്ന് ആത്മവിശ്വാസത്തോടെ (1 കൊരിന്ത്യർ 15:58).')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- ADDITIONAL TOPICS: Hope & Future and Apologetics
-- Added: 2026-01-22
-- Purpose: Missing topics referenced by Faith & Reason learning path

INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value, input_type)
VALUES
  -- Foundations of Faith
  ('111e8400-e29b-41d4-a716-446655440007',
   'Your Identity in Christ',
   'Discover the radical transformation that occurs at salvation: you are justified by faith alone (Romans 5:1), a brand-new creation in Christ (2 Corinthians 5:17), adopted as God''s beloved child with full inheritance rights (Galatians 4:4-7), completely forgiven of all sins past, present, and future (Colossians 2:13-14), and permanently indwelt by the Holy Spirit (1 Corinthians 6:19). Learn that your identity is no longer defined by your past failures, present struggles, or what others think, but solely by what God has done for you in Christ. Reject the lies of condemnation and insecurity, and walk in the freedom and confidence of knowing you are chosen, holy, and dearly loved (Colossians 3:12).',
   'Foundations of Faith',
   ARRAY['identity', 'new creation', 'child of god', 'freedom'],
   67, 50, 'topic'),
  ('111e8400-e29b-41d4-a716-446655440008',
   'Understanding God''s Grace',
   'Explore the transforming power of grace—God''s unmerited favor freely given to undeserving sinners through Jesus Christ (Ephesians 2:8-9). Understand that grace is not God overlooking sin but God satisfying His justice through Christ''s substitutionary death, enabling Him to forgive guilty sinners while remaining perfectly just (Romans 3:23-26). Learn how grace saves us completely apart from our works (Titus 3:5), yet paradoxically empowers us for holy living and good works that flow from gratitude, not obligation (Titus 2:11-12). Reject legalism that adds human requirements to the gospel and antinomianism that uses grace as a license to sin (Galatians 5:13, Jude 1:4). Discover the freedom of living under grace: accepted by God not because of what we do, but because of what Christ has done (Romans 6:14).',
   'Foundations of Faith',
   ARRAY['grace', 'salvation', 'freedom', 'legalism'],
   68, 50, 'topic'),

  -- Christian Life
  ('222e8400-e29b-41d4-a716-446655440007',
   'Spiritual Warfare',
   'Recognize that every believer is engaged in a real spiritual battle against Satan, demons, and the world system opposed to God (Ephesians 6:12, 1 Peter 5:8)—but reject unbiblical ideas like territorial spirits theology, binding and loosing demons without biblical warrant, or charismatic excess that focuses on demon-seeing and deliverance ministry. Learn to put on the full armor of God—truth, righteousness, the gospel, faith, salvation, the Word, and prayer (Ephesians 6:13-18)—not to earn victory but to stand firm in the victory Christ has already won at the cross (Colossians 2:15). Understand that our enemy is a created, defeated foe, NOT an equal opposing force to God, seeking to deceive, discourage, and destroy believers through lies, temptation, and accusation (Revelation 12:10). Walk in the delegated authority you have in Christ (Romans 8:37, 1 John 4:4), resisting the devil primarily through submission to God, truth, faith in Scripture, and prayer—not through elaborate spiritual warfare techniques (James 4:7, 1 Peter 5:9). Fight from victory, not for victory—the war is won at the cross, but battles remain until Christ returns.',
   'Christian Life',
   ARRAY['spiritual warfare', 'armor of god', 'victory', 'enemy'],
   69, 50, 'topic'),
  ('222e8400-e29b-41d4-a716-446655440008',
   'Dealing with Doubt and Fear',
   'Learn biblical strategies for overcoming doubt and fear that plague even mature believers. Combat doubt by saturating your mind with Scripture''s objective truth rather than relying on subjective feelings (Psalm 119:11, Romans 10:17), remembering God''s past faithfulness in your life and in history (Psalm 77:11-12), and bringing your questions honestly to God who welcomes sincere seekers (Mark 9:24). Overcome fear by meditating on God''s perfect love that casts out fear (1 John 4:18), His sovereign control over all circumstances (Matthew 10:29-31), and His promises to never leave or forsake you (Hebrews 13:5-6). Replace anxious thoughts with prayer and thanksgiving, allowing God''s peace to guard your heart and mind (Philippians 4:6-7). Remember that faith is not the absence of doubt or fear but trusting God despite them, choosing to believe His Word over your feelings.',
   'Christian Life',
   ARRAY['doubt', 'fear', 'faith', 'trust'],
   70, 50, 'topic'),

  -- Church & Community
  ('333e8400-e29b-41d4-a716-446655440006',
   'Baptism and Communion',
   'Understand the meaning and significance of the two ordinances (or sacraments) Jesus gave to the church: baptism and the Lord''s Supper. Learn that baptism is the outward public declaration of an inward reality—identifying with Christ''s death, burial, and resurrection (Romans 6:3-4) and marking entrance into the visible church community. Baptism is a symbolic act of obedience for those already saved by faith; it does NOT itself save or regenerate—salvation comes through faith in Christ alone, not through water baptism (Ephesians 2:8-9). Reject baptismal regeneration (the false teaching that baptism saves) while recognizing baptism as a crucial step of obedience that publicly identifies believers with Christ. Explore different views on baptism mode (immersion vs. sprinkling) and recipients (believers only vs. infant baptism), while maintaining unity on its symbolic, non-saving nature. Discover the Lord''s Supper as a regular reminder of Christ''s broken body and shed blood for our sins (1 Corinthians 11:23-26), a time of self-examination and confession (1 Corinthians 11:28), and a proclamation of His death until He returns—NOT a re-sacrifice of Christ or means of obtaining grace. Practice these ordinances not as rituals that earn God''s favor or impart saving grace but as grateful responses to the finished work of Christ, strengthening faith and church unity.',
   'Church & Community',
   ARRAY['baptism', 'communion', 'lords supper', 'ordinances'],
   71, 50, 'topic'),

  -- Spiritual Disciplines
  ('555e8400-e29b-41d4-a716-446655440006',
   'How to Study the Bible',
   'Develop practical skills for reading, understanding, and applying God''s Word effectively in daily life. Learn the importance of observation (what does the text say?), interpretation (what does it mean in its original context?), and application (how does it apply to my life today?). Practice sound hermeneutical principles: read Scripture in context, interpret difficult passages in light of clear ones, let Scripture interpret Scripture, and recognize different literary genres (narrative, poetry, prophecy, epistle). Discover tools like cross-references, study Bibles, and concordances that aid understanding. Avoid common mistakes like eisegesis (reading your ideas into the text), taking verses out of context, or spiritualizing clear historical narratives. Make Bible study a daily discipline, approaching Scripture prayerfully, humbly, and expectantly, knowing the Holy Spirit illuminates truth for those who earnestly seek it (John 16:13, 2 Timothy 2:15).',
   'Spiritual Disciplines',
   ARRAY['bible study', 'hermeneutics', 'scripture', 'application'],
   72, 50, 'topic'),
  ('555e8400-e29b-41d4-a716-446655440007',
   'Discerning God''s Will',
   'Learn to discern God''s will primarily through His revealed Word, the Bible, which contains all the guidance we need for faith and godly living (2 Timothy 3:16-17, Psalm 119:105). Understand that God guides believers today through Scripture, prayer, the Holy Spirit''s conviction, circumstances, and godly counsel—never through new revelation or subjective impressions that contradict Scripture. Test all guidance against the unchanging standard of God''s Word (Acts 17:11, 1 Thessalonians 5:21). Recognize that God''s moral will (how to live righteously) is clearly revealed in Scripture, while His specific will for individual decisions often involves sanctified wisdom and freedom within biblical boundaries (Romans 12:1-2). Reject the idea that God has one perfect choice you must discover for every decision; instead, make wise choices that honor God within the principles He has revealed. Trust that God sovereignly directs your steps even as you make responsible decisions according to biblical wisdom (Proverbs 3:5-6, Psalm 37:23).',
   'Spiritual Disciplines',
   ARRAY['gods will', 'guidance', 'discernment', 'scripture'],
   73, 50, 'topic'),

  -- Faith and Science (Apologetics)
  ('666e8400-e29b-41d4-a716-446655440006',
   'Faith and Science',
   'Explore how biblical faith and true science are not enemies but complementary ways of understanding God''s reality—Scripture reveals who created and why, while science investigates how creation operates. Understand that the scientific method itself arose from a Christian worldview that assumed an orderly, intelligible universe created by a rational God (Genesis 1:1, Psalm 19:1). Examine evidence for God in creation: the fine-tuning of physical constants, the specified complexity of DNA, the information content of biological systems, and the mathematical precision of natural laws—all pointing to intelligent design rather than purposeless chance (Romans 1:20). Address apparent conflicts between science and faith, recognizing that many stem from philosophical naturalism imposed on scientific findings, not from the findings themselves. Reject both scientism (science alone provides truth) and anti-intellectualism (faith requires rejecting reason). Embrace faith grounded in evidence and reason while acknowledging that ultimate reality transcends what science can measure (Hebrews 11:1, Colossians 2:3).',
   'Apologetics & Defense of Faith',
   ARRAY['faith', 'science', 'creation', 'evidence'],
   74, 50, 'topic'),

  -- Family & Relationships
  ('777e8400-e29b-41d4-a716-446655440006',
   'Singleness and Contentment',
   'Discover God''s perspective on singleness as a gift, not a burden or second-class status (1 Corinthians 7:7-8, 32-35). Learn from Jesus and Paul, both single, who lived fully for God''s purposes without romantic relationships. Find contentment in your current season by cultivating your relationship with Christ as your ultimate satisfaction (Philippians 4:11-13, Psalm 73:25), serving God with undivided devotion, and using your unique freedom for kingdom purposes. Resist cultural idolatry that makes marriage and romance the key to fulfillment, while also wisely preparing for possible future marriage. Navigate the tension between trusting God''s sovereignty over your relational status and taking appropriate steps toward marriage if you desire it. Whether single for a season or for life, embrace the truth that your completeness is in Christ alone (Colossians 2:10), not in another person, and that God works all things—including singleness—for the good of those who love Him (Romans 8:28).',
   'Family & Relationships',
   ARRAY['singleness', 'contentment', 'waiting', 'purpose'],
   75, 50, 'topic'),

  -- Mission & Service
  ('888e8400-e29b-41d4-a716-446655440006',
   'Workplace as Mission',
   'Understand that your workplace is not just where you earn a paycheck but a strategic mission field where God has placed you to be salt and light (Matthew 5:13-16). Learn to honor Christ through excellent work done as unto the Lord, not merely to please human bosses (Colossians 3:23-24, Ephesians 6:5-8). Demonstrate Christian character through integrity, diligence, humility, honesty, and respect for authority—letting your conduct preach louder than your words. Look for natural opportunities to share the gospel with coworkers, while respecting workplace boundaries and avoiding obnoxious or manipulative evangelism. Navigate ethical dilemmas by obeying God rather than men when the two conflict (Acts 5:29), even if it costs you professionally. View your vocation as a calling from God where you serve others and contribute to human flourishing, not just a means to fund "real" ministry. Remember that for most believers, the workplace is their primary sphere of ministry, and faithful presence there glorifies God and advances His kingdom (1 Peter 2:12).',
   'Mission & Service',
   ARRAY['workplace', 'mission', 'salt and light', 'witness'],
   76, 50, 'topic'),

  -- Discipleship & Growth
  ('444e8400-e29b-41d4-a716-446655440006',
   'Living by Faith, Not Feelings',
   'Learn the crucial distinction between living by faith (trusting God''s objective truth) and living by feelings (trusting subjective emotions). Understand that biblical faith is not an irrational leap or wishful thinking but confident trust in the proven character and promises of God revealed in Scripture (Hebrews 11:1, Romans 10:17). Recognize that feelings are real but unreliable guides—they fluctuate based on circumstances, hormones, sleep, and countless other factors, whereas God''s Word stands forever unchanging (Isaiah 40:8, Matthew 24:35). Practice walking by faith when you don''t feel God''s presence, when prayers seem unanswered, when circumstances appear hopeless, or when doubts assail your mind (2 Corinthians 5:7, Habakkuk 3:17-19). Build faith through meditating on Scripture, remembering God''s past faithfulness, and choosing daily to believe what God says about Himself, your identity, and your future, regardless of how you feel. Trust that persevering faith honors God far more than emotional highs, and that He rewards those who diligently seek Him (Hebrews 11:6).',
   'Discipleship & Growth',
   ARRAY['faith', 'feelings', 'trust', 'perseverance'],
   77, 50, 'topic'),

  -- Hope & Future
  ('999e8400-e29b-41d4-a716-446655440001',
   'The Return of Christ',
   'Explore the blessed hope of Jesus Christ''s personal, visible, bodily, glorious return to earth (Titus 2:13, Acts 1:11, Revelation 1:7)—an event as certain as His first coming and a core doctrine of the Christian faith. Jesus will return in the same physical, resurrected body in which He ascended to heaven (Acts 1:11), rejecting any spiritualized or symbolic interpretations of His second coming. Understand that Christ will return to judge the living and the dead (2 Timothy 4:1), resurrect believers to eternal life and unbelievers to eternal condemnation (John 5:28-29), destroy this present evil age, and establish His eternal kingdom (Revelation 21-22). Learn how this hope should shape daily living: pursuing holiness in anticipation of seeing Him face to face (1 John 3:2-3), living with eternal perspective rather than worldly values (Colossians 3:1-4), enduring suffering with patient hope (Romans 8:18), and urgently sharing the gospel before His return (2 Peter 3:9-10). Avoid speculation about dates and times Jesus said we cannot know (Matthew 24:36), while remaining watchful and ready at all times (Matthew 24:42-44). Whether Christ returns in your lifetime or you go to meet Him through death, live each day with joyful anticipation of His appearing (Philippians 1:21-23).',
   'Hope & Future',
   ARRAY['second coming', 'return of christ', 'hope', 'eschatology'],
   78, 50, 'topic'),
  ('999e8400-e29b-41d4-a716-446655440002',
   'Heaven and Eternal Life',
   'Discover what the Bible actually teaches about heaven—not harps and clouds, but the glorious eternal state of those who die in Christ. Learn that believers who die immediately enter God''s presence in a conscious, joyful intermediate state (2 Corinthians 5:8, Philippians 1:23), awaiting the resurrection of the body at Christ''s return (1 Thessalonians 4:13-18). Understand the eternal state: resurrected believers will live forever in glorified bodies on the new earth, where God dwells with His people in perfect fellowship, free from sin, suffering, death, and decay (Revelation 21:1-5, 1 Corinthians 15:42-44). Explore what heaven will be like: worshiping God face to face, reigning with Christ, enjoying restored creation, and experiencing unimaginable joy in the presence of our Savior (Psalm 16:11, Revelation 22:3-5). Reject unbiblical ideas of earning heaven through good works, universalism (everyone goes to heaven), or soul sleep. Let the hope of eternal life with Christ motivate holy living, sacrificial service, and bold witness, knowing this world is not our home and the best is yet to come (Hebrews 11:13-16, 2 Peter 3:11-14).',
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
   'उद्धार के समय होने वाले कट्टरपंथी परिवर्तन को जानें: आप केवल विश्वास से धर्मी ठहराए गए हैं (रोमियों 5:1), मसीह में एक बिल्कुल नई सृष्टि हैं (2 कुरिन्थियों 5:17), पूर्ण उत्तराधिकार अधिकारों के साथ परमेश्वर के प्रिय बच्चे के रूप में गोद लिए गए हैं (गलातियों 4:4-7), भूत, वर्तमान और भविष्य के सभी पापों से पूरी तरह से क्षमा किए गए हैं (कुलुस्सियों 2:13-14), और पवित्र आत्मा द्वारा स्थायी रूप से निवास किए गए हैं (1 कुरिन्थियों 6:19)। जानें कि आपकी पहचान अब आपकी पिछली विफलताओं, वर्तमान संघर्षों, या दूसरों की सोच से परिभाषित नहीं होती है, बल्कि केवल इस बात से परिभाषित होती है कि परमेश्वर ने मसीह में आपके लिए क्या किया है। निंदा और असुरक्षा के झूठ को अस्वीकार करें, और यह जानते हुए स्वतंत्रता और आत्मविश्वास में चलें कि आप चुने हुए, पवित्र और अत्यंत प्रिय हैं (कुलुस्सियों 3:12)।'),
  ('111e8400-e29b-41d4-a716-446655440008', 'hi',
   'विश्वास की नींव',
   'परमेश्वर की कृपा को समझना',
   'कृपा की परिवर्तनकारी शक्ति की खोज करें - यीशु मसीह के माध्यम से अयोग्य पापियों को स्वतंत्र रूप से दिया गया परमेश्वर का अयोग्य अनुग्रह (इफिसियों 2:8-9)। समझें कि कृपा परमेश्वर द्वारा पाप को अनदेखा करना नहीं है, बल्कि मसीह की प्रतिस्थापन मृत्यु के माध्यम से अपनी न्याय को संतुष्ट करना है, जिससे वह दोषी पापियों को क्षमा कर सके जबकि पूरी तरह से न्यायी बने रहें (रोमियों 3:23-26)। जानें कि कृपा हमें हमारे कार्यों से पूरी तरह से अलग बचाती है (तीतुस 3:5), फिर भी विरोधाभासी रूप से हमें पवित्र जीवन और अच्छे कार्यों के लिए सशक्त बनाती है जो कृतज्ञता से बहते हैं, दायित्व से नहीं (तीतुस 2:11-12)। कानूनवाद को अस्वीकार करें जो सुसमाचार में मानव आवश्यकताओं को जोड़ता है और स्वच्छंदतावाद जो कृपा का उपयोग पाप के लाइसेंस के रूप में करता है (गलातियों 5:13, यहूदा 1:4)। कृपा के तहत जीने की स्वतंत्रता की खोज करें: परमेश्वर द्वारा स्वीकार किए गए हम क्या करते हैं इसके कारण नहीं, बल्कि मसीह ने क्या किया है इसके कारण (रोमियों 6:14)।'),

  -- Christian Life
  ('222e8400-e29b-41d4-a716-446655440007', 'hi',
   'मसीही जीवन',
   'आत्मिक युद्ध',
   'पहचानें कि प्रत्येक विश्वासी शैतान, दुष्टात्माओं, और परमेश्वर के विरोधी दुनिया की प्रणाली के खिलाफ एक वास्तविक आत्मिक युद्ध में लगा हुआ है (इफिसियों 6:12, 1 पतरस 5:8)—लेकिन क्षेत्रीय आत्माओं के धर्मशास्त्र, बाइबिलीय वारंट के बिना दुष्टात्माओं को बांधने और छोड़ने, या करिश्माई अतिरेक जो दुष्टात्माओं को देखने और मुक्ति सेवकाई पर केंद्रित है, जैसे अबाइबिलीय विचारों को अस्वीकार करें। परमेश्वर का पूरा हथियार पहनना सीखें - सत्य, धार्मिकता, सुसमाचार, विश्वास, उद्धार, वचन, और प्रार्थना (इफिसियों 6:13-18) - विजय कमाने के लिए नहीं बल्कि उस विजय में मजबूत खड़े रहने के लिए जो मसीह ने पहले से ही क्रूस पर जीती है (कुलुस्सियों 2:15)। समझें कि हमारा शत्रु एक सृजित, पराजित दुश्मन है, परमेश्वर के लिए एक समान विरोधी शक्ति नहीं—शैतान और दुष्टात्माएं पतित प्राणी हैं जिन्होंने विद्रोह किया, न कि मसीह के समान शाश्वत या सर्वशक्तिमान देवता। उस सौंपे गए अधिकार में चलें जो आपको मसीह में है (रोमियों 8:37, 1 यूहन्ना 4:4), मुख्य रूप से परमेश्वर के प्रति समर्पण, सत्य, शास्त्र में विश्वास, और प्रार्थना के माध्यम से शैतान का विरोध करें—विस्तृत आत्मिक युद्ध तकनीकों के माध्यम से नहीं (याकूब 4:7, 1 पतरस 5:9)।'),
  ('222e8400-e29b-41d4-a716-446655440008', 'hi',
   'मसीही जीवन',
   'संदेह और भय से निपटना',
   'परिपक्व विश्वासियों को भी परेशान करने वाले संदेह और भय पर काबू पाने के लिए बाइबिलीय रणनीतियों को जानें। अपने मन को शास्त्र के वस्तुनिष्ठ सत्य से संतृप्त करके संदेह से लड़ें, न कि व्यक्तिपरक भावनाओं पर निर्भर रहकर (भजन संहिता 119:11, रोमियों 10:17), अपने जीवन में और इतिहास में परमेश्वर की पिछली विश्वासयोग्यता को याद करते हुए (भजन संहिता 77:11-12), और अपने प्रश्नों को ईमानदारी से परमेश्वर के पास लाते हुए जो ईमानदार खोजकर्ताओं का स्वागत करता है (मरकुस 9:24)। भय पर काबू पाएं परमेश्वर के पूर्ण प्रेम पर ध्यान करके जो भय को दूर करता है (1 यूहन्ना 4:18), सभी परिस्थितियों पर उसके संप्रभु नियंत्रण (मत्ती 10:29-31), और उसकी प्रतिज्ञाओं को कभी नहीं छोड़ने या त्यागने के लिए (इब्रानियों 13:5-6)। चिंतित विचारों को प्रार्थना और धन्यवाद से बदलें, परमेश्वर की शांति को अपने दिल और दिमाग की रक्षा करने दें (फिलिप्पियों 4:6-7)। याद रखें कि विश्वास संदेह या भय की अनुपस्थिति नहीं है, बल्कि उनके बावजूद परमेश्वर पर भरोसा करना है, अपनी भावनाओं पर उसके वचन को विश्वास करना चुनना है।'),

  -- Church & Community
  ('333e8400-e29b-41d4-a716-446655440006', 'hi',
   'कलीसिया और समुदाय',
   'बपतिस्मा और प्रभु भोज',
   'यीशु ने कलीसिया को दिए गए दो अनुष्ठानों (या संस्कारों) का अर्थ और महत्व समझें: बपतिस्मा और प्रभु भोज। जानें कि बपतिस्मा एक आंतरिक वास्तविकता की बाहरी सार्वजनिक घोषणा है - मसीह की मृत्यु, दफनाने और पुनरुत्थान के साथ पहचान (रोमियों 6:3-4) और दृश्य कलीसिया समुदाय में प्रवेश को चिह्नित करना। बपतिस्मा उन लोगों के लिए आज्ञाकारिता का प्रतीकात्मक कार्य है जो पहले से ही विश्वास द्वारा बचाए गए हैं; यह स्वयं बचाता या पुनर्जन्म नहीं करता - उद्धार केवल मसीह में विश्वास के माध्यम से आता है, न कि जल बपतिस्मा के माध्यम से (इफिसियों 2:8-9)। बपतिस्मा पुनर्जनन (झूठी शिक्षा कि बपतिस्मा बचाता है) को अस्वीकार करें जबकि बपतिस्मा को आज्ञाकारिता के एक महत्वपूर्ण कदम के रूप में पहचानें जो सार्वजनिक रूप से विश्वासियों को मसीह के साथ पहचानता है। बपतिस्मा की विधि (डुबकी बनाम छिड़काव) और प्राप्तकर्ताओं (केवल विश्वासी बनाम शिशु बपतिस्मा) पर विभिन्न विचारों की खोज करें, जबकि इसके प्रतीकात्मक, गैर-बचत स्वभाव पर एकता बनाए रखें। प्रभु भोज को हमारे पापों के लिए मसीह के टूटे हुए शरीर और बहाए गए रक्त की नियमित याद के रूप में जानें (1 कुरिन्थियों 11:23-26), आत्म-परीक्षा और कबूलनामे का समय (1 कुरिन्थियों 11:28), और उसकी मृत्यु की घोषणा जब तक वह वापस नहीं आता - मसीह का पुन: बलिदान या अनुग्रह प्राप्त करने का साधन नहीं। इन अनुष्ठानों का अभ्यास करें, न कि उन अनुष्ठानों के रूप में जो परमेश्वर का अनुग्रह अर्जित करते हैं या बचाने वाला अनुग्रह प्रदान करते हैं, बल्कि मसीह के पूर्ण कार्य के प्रति कृतज्ञ प्रतिक्रियाओं के रूप में, विश्वास और कलीसिया एकता को मजबूत करते हुए।'),

  -- Spiritual Disciplines
  ('555e8400-e29b-41d4-a716-446655440006', 'hi',
   'आत्मिक अनुशासन',
   'बाइबल का अध्ययन कैसे करें',
   'दैनिक जीवन में परमेश्वर के वचन को प्रभावी ढंग से पढ़ने, समझने और लागू करने के लिए व्यावहारिक कौशल विकसित करें। अवलोकन (पाठ क्या कहता है?), व्याख्या (इसका मूल संदर्भ में क्या अर्थ है?), और अनुप्रयोग (यह आज मेरे जीवन पर कैसे लागू होता है?) के महत्व को जानें। ध्वनि व्याख्या सिद्धांतों का अभ्यास करें: शास्त्र को संदर्भ में पढ़ें, स्पष्ट अंशों के प्रकाश में कठिन अंशों की व्याख्या करें, शास्त्र को शास्त्र की व्याख्या करने दें, और विभिन्न साहित्यिक शैलियों (कथा, कविता, भविष्यवाणी, पत्री) को पहचानें। समझ में सहायता करने वाले उपकरण जैसे क्रॉस-रेफरेंस, अध्ययन बाइबल, और कॉनकॉर्डेंस की खोज करें। सामान्य गलतियों से बचें जैसे आइसेजेसिस (पाठ में अपने विचारों को पढ़ना), छंदों को संदर्भ से बाहर लेना, या स्पष्ट ऐतिहासिक कथाओं को आध्यात्मिक बनाना। बाइबल अध्ययन को एक दैनिक अनुशासन बनाएं, शास्त्र के पास प्रार्थना, विनम्रता, और अपेक्षा के साथ आते हुए, यह जानते हुए कि पवित्र आत्मा उन लोगों के लिए सत्य को प्रकाशित करता है जो ईमानदारी से इसे खोजते हैं (यूहन्ना 16:13, 2 तीमुथियुस 2:15)।'),
  ('555e8400-e29b-41d4-a716-446655440007', 'hi',
   'आत्मिक अनुशासन',
   'परमेश्वर की इच्छा को समझना',
   'परमेश्वर की इच्छा को मुख्य रूप से उसके प्रकट वचन, बाइबल के माध्यम से समझना सीखें, जिसमें विश्वास और धर्मी जीवन के लिए हमें आवश्यक सभी मार्गदर्शन शामिल हैं (2 तीमुथियुस 3:16-17, भजन संहिता 119:105)। समझें कि परमेश्वर आज विश्वासियों को शास्त्र, प्रार्थना, पवित्र आत्मा की सजगता, परिस्थितियों, और धार्मिक सलाह के माध्यम से मार्गदर्शन करता है - कभी भी नए प्रकाशन या व्यक्तिपरक छापों के माध्यम से नहीं जो शास्त्र का खंडन करते हैं। सभी मार्गदर्शन को परमेश्वर के वचन के अपरिवर्तनीय मानक के खिलाफ परखें (प्रेरितों के काम 17:11, 1 थिस्सलुनीकियों 5:21)। पहचानें कि परमेश्वर की नैतिक इच्छा (धर्मी जीवन कैसे जिएं) शास्त्र में स्पष्ट रूप से प्रकट है, जबकि व्यक्तिगत निर्णयों के लिए उसकी विशिष्ट इच्छा अक्सर बाइबिलीय सीमाओं के भीतर पवित्र बुद्धि और स्वतंत्रता शामिल है (रोमियों 12:1-2)। इस विचार को अस्वीकार करें कि परमेश्वर के पास हर निर्णय के लिए एक सही विकल्प है जिसे आपको खोजना चाहिए; इसके बजाय, बुद्धिमान विकल्प बनाएं जो उसके द्वारा प्रकट किए गए सिद्धांतों के भीतर परमेश्वर का सम्मान करते हैं। भरोसा रखें कि परमेश्वर संप्रभुता से आपके कदमों को निर्देशित करता है, भले ही आप बाइबिलीय बुद्धि के अनुसार जिम्मेदार निर्णय लेते हैं (नीतिवचन 3:5-6, भजन संहिता 37:23)।'),

  -- Apologetics
  ('666e8400-e29b-41d4-a716-446655440006', 'hi',
   'धर्मशास्त्र और विश्वास की रक्षा',
   'विश्वास और विज्ञान',
   'जानें कि बाइबिलीय विश्वास और सच्चा विज्ञान शत्रु नहीं हैं बल्कि परमेश्वर की वास्तविकता को समझने के पूरक तरीके हैं - शास्त्र बताता है कि किसने बनाया और क्यों, जबकि विज्ञान जांच करता है कि सृष्टि कैसे संचालित होती है। समझें कि वैज्ञानिक विधि स्वयं एक ईसाई विश्वदृष्टि से उत्पन्न हुई जो एक तर्कसंगत परमेश्वर द्वारा बनाए गए एक व्यवस्थित, बोधगम्य ब्रह्मांड को मानती थी (उत्पत्ति 1:1, भजन संहिता 19:1)। सृष्टि में परमेश्वर के प्रमाणों की जांच करें: भौतिक स्थिरांकों की सूक्ष्म-ट्यूनिंग, डीएनए की निर्दिष्ट जटिलता, जैविक प्रणालियों की सूचना सामग्री, और प्राकृतिक कानूनों की गणितीय सटीकता - सभी उद्देश्यहीन संयोग के बजाय बुद्धिमान डिजाइन की ओर इशारा करते हैं (रोमियों 1:20)। विज्ञान और विश्वास के बीच स्पष्ट संघर्षों को संबोधित करें, यह पहचानते हुए कि कई वैज्ञानिक निष्कर्षों पर लगाए गए दार्शनिक प्रकृतिवाद से उत्पन्न होते हैं, न कि निष्कर्षों से ही। वैज्ञानिकता (विज्ञान अकेला सत्य प्रदान करता है) और विरोधी बुद्धिवाद (विश्वास को तर्क को अस्वीकार करने की आवश्यकता है) दोनों को अस्वीकार करें। साक्ष्य और तर्क में निहित विश्वास को अपनाएं जबकि यह स्वीकार करते हुए कि अंतिम वास्तविकता उस से परे है जो विज्ञान माप सकता है (इब्रानियों 11:1, कुलुस्सियों 2:3)।'),

  -- Family & Relationships
  ('777e8400-e29b-41d4-a716-446655440006', 'hi',
   'परिवार और रिश्ते',
   'एकलता और संतोष',
   'एकलता पर परमेश्वर के दृष्टिकोण को एक उपहार के रूप में जानें, न कि एक बोझ या दूसरे दर्जे की स्थिति (1 कुरिन्थियों 7:7-8, 32-35)। यीशु और पौलुस से सीखें, दोनों अविवाहित, जिन्होंने रोमांटिक रिश्तों के बिना परमेश्वर के उद्देश्यों के लिए पूरी तरह से जिया। अपने वर्तमान मौसम में संतोष पाएं मसीह के साथ अपने रिश्ते को अपनी अंतिम संतुष्टि के रूप में विकसित करके (फिलिप्पियों 4:11-13, भजन संहिता 73:25), अविभाजित भक्ति के साथ परमेश्वर की सेवा करके, और राज्य के उद्देश्यों के लिए अपनी अनूठी स्वतंत्रता का उपयोग करके। सांस्कृतिक मूर्तिपूजा का विरोध करें जो विवाह और रोमांस को पूर्ति की कुंजी बनाती है, जबकि संभावित भविष्य के विवाह के लिए बुद्धिमानी से तैयारी करें। अपनी संबंधपरक स्थिति पर परमेश्वर की संप्रभुता पर भरोसा करने और विवाह की ओर उचित कदम उठाने के बीच तनाव को नेविगेट करें यदि आप इसकी इच्छा रखते हैं। चाहे एक मौसम के लिए अविवाहित हों या जीवन भर के लिए, इस सत्य को अपनाएं कि आपकी पूर्णता केवल मसीह में है (कुलुस्सियों 2:10), किसी अन्य व्यक्ति में नहीं, और परमेश्वर सभी चीजों को - एकलता सहित - उन लोगों की भलाई के लिए काम करता है जो उससे प्रेम करते हैं (रोमियों 8:28)।'),

  -- Mission & Service
  ('888e8400-e29b-41d4-a716-446655440006', 'hi',
   'मिशन और सेवा',
   'कार्यस्थल मिशन के रूप में',
   'समझें कि आपका कार्यस्थल केवल वह नहीं है जहां आप पेचेक कमाते हैं, बल्कि एक रणनीतिक मिशन क्षेत्र है जहां परमेश्वर ने आपको नमक और प्रकाश बनने के लिए रखा है (मत्ती 5:13-16)। प्रभु के लिए किए गए उत्कृष्ट कार्य के माध्यम से मसीह का सम्मान करना सीखें, न केवल मानव बॉस को खुश करने के लिए (कुलुस्सियों 3:23-24, इफिसियों 6:5-8)। ईमानदारी, परिश्रम, विनम्रता, ईमानदारी, और अधिकार के लिए सम्मान के माध्यम से ईसाई चरित्र का प्रदर्शन करें - अपने आचरण को अपने शब्दों से अधिक जोर से प्रचार करने दें। सहकर्मियों के साथ सुसमाचार साझा करने के लिए प्राकृतिक अवसरों की तलाश करें, जबकि कार्यस्थल की सीमाओं का सम्मान करें और आक्रामक या जोड़-तोड़ वाले प्रचार से बचें। नैतिक दुविधाओं को परमेश्वर की आज्ञा मानकर नेविगेट करें, न कि मनुष्यों की जब दोनों संघर्ष करते हैं (प्रेरितों के काम 5:29), भले ही यह आपको पेशेवर रूप से खर्च करे। अपने व्यवसाय को परमेश्वर से एक बुलावा के रूप में देखें जहां आप दूसरों की सेवा करते हैं और मानव विकास में योगदान करते हैं, न केवल "वास्तविक" मंत्रालय को फंड करने का एक साधन। याद रखें कि अधिकांश विश्वासियों के लिए, कार्यस्थल उनके मंत्रालय का प्राथमिक क्षेत्र है, और वहां विश्वासयोग्य उपस्थिति परमेश्वर की महिमा करती है और उसके राज्य को आगे बढ़ाती है (1 पतरस 2:12)।'),

  -- Discipleship & Growth
  ('444e8400-e29b-41d4-a716-446655440006', 'hi',
   'शिष्यत्व और विकास',
   'विश्वास से जीना, भावनाओं से नहीं',
   'विश्वास से जीने (परमेश्वर की वस्तुनिष्ठ सत्य पर भरोसा करना) और भावनाओं से जीने (व्यक्तिपरक भावनाओं पर भरोसा करना) के बीच महत्वपूर्ण अंतर सीखें। समझें कि बाइबिलीय विश्वास एक तर्कहीन छलांग या इच्छाधारी सोच नहीं है, बल्कि शास्त्र में प्रकट परमेश्वर के सिद्ध चरित्र और प्रतिज्ञाओं में आत्मविश्वासपूर्ण विश्वास है (इब्रानियों 11:1, रोमियों 10:17)। पहचानें कि भावनाएं वास्तविक हैं लेकिन अविश्वसनीय मार्गदर्शक हैं - वे परिस्थितियों, हार्मोन, नींद, और अनगिनत अन्य कारकों के आधार पर उतार-चढ़ाव करती हैं, जबकि परमेश्वर का वचन हमेशा अपरिवर्तित रहता है (यशायाह 40:8, मत्ती 24:35)। विश्वास से चलने का अभ्यास करें जब आप परमेश्वर की उपस्थिति महसूस नहीं करते, जब प्रार्थनाएं अनुत्तरित लगती हैं, जब परिस्थितियां निराशाजनक दिखाई देती हैं, या जब संदेह आपके दिमाग पर हमला करते हैं (2 कुरिन्थियों 5:7, हबक्कूक 3:17-19)। शास्त्र पर ध्यान करके, परमेश्वर की पिछली विश्वासयोग्यता को याद करके, और दैनिक रूप से यह विश्वास करना चुनकर विश्वास बनाएं कि परमेश्वर अपने बारे में, आपकी पहचान, और आपके भविष्य के बारे में क्या कहता है, भले ही आप कैसा महसूस करते हैं। भरोसा रखें कि दृढ़ विश्वास भावनात्मक ऊंचाइयों की तुलना में परमेश्वर का बहुत अधिक सम्मान करता है, और वह उन लोगों को पुरस्कृत करता है जो उसे मेहनती से खोजते हैं (इब्रानियों 11:6)।'),

  -- Hope & Future
  ('999e8400-e29b-41d4-a716-446655440001', 'hi',
   'आशा और भविष्य',
   'मसीह की वापसी',
   'यीशु मसीह के पृथ्वी पर व्यक्तिगत, दृश्य, शारीरिक, महिमामय लौटने की धन्य आशा की खोज करें (तीतुस 2:13, प्रेरितों के काम 1:11, प्रकाशितवाक्य 1:7) - एक घटना उसके पहले आने के रूप में निश्चित है और ईसाई विश्वास का एक मुख्य सिद्धांत है। यीशु उसी भौतिक, पुनरुत्थित शरीर में लौटेगा जिसमें वह स्वर्ग में चढ़ा (प्रेरितों के काम 1:11), उसके दूसरे आगमन की किसी भी आध्यात्मिक या प्रतीकात्मक व्याख्याओं को अस्वीकार करते हुए। समझें कि मसीह जीवितों और मृतकों का न्याय करने के लिए लौटेगा (2 तीमुथियुस 4:1), विश्वासियों को अनंत जीवन में और अविश्वासियों को अनंत निंदा में पुनरुत्थान करेगा (यूहन्ना 5:28-29), इस वर्तमान बुरे युग को नष्ट करेगा, और अपने अनंत राज्य की स्थापना करेगा (प्रकाशितवाक्य 21-22)। जानें कि यह आशा दैनिक जीवन को कैसे आकार देनी चाहिए: उसे आमने-सामने देखने की प्रत्याशा में पवित्रता का पीछा करना (1 यूहन्ना 3:2-3), सांसारिक मूल्यों के बजाय अनंत दृष्टिकोण के साथ जीना (कुलुस्सियों 3:1-4), धैर्य की आशा के साथ पीड़ा सहना (रोमियों 8:18), और उसके लौटने से पहले तत्कालता से सुसमाचार साझा करना (2 पतरस 3:9-10)। तिथियों और समय के बारे में अटकलों से बचें जो यीशु ने कहा कि हम नहीं जान सकते (मत्ती 24:36), जबकि हर समय सतर्क और तैयार रहें (मत्ती 24:42-44)। चाहे मसीह आपके जीवनकाल में लौटे या आप मृत्यु के माध्यम से उससे मिलने जाएं, हर दिन उसके प्रकट होने की खुशी की प्रत्याशा के साथ जिएं (फिलिप्पियों 1:21-23)।'),
  ('999e8400-e29b-41d4-a716-446655440002', 'hi',
   'आशा और भविष्य',
   'स्वर्ग और अनंत जीवन',
   'जानें कि बाइबल वास्तव में स्वर्ग के बारे में क्या सिखाती है - वीणा और बादल नहीं, बल्कि मसीह में मरने वालों की महिमामय अनंत स्थिति। जानें कि विश्वासी जो मरते हैं वे तुरंत एक चेतन, आनंदमय मध्यवर्ती स्थिति में परमेश्वर की उपस्थिति में प्रवेश करते हैं (2 कुरिन्थियों 5:8, फिलिप्पियों 1:23), मसीह की वापसी पर शरीर के पुनरुत्थान की प्रतीक्षा करते हुए (1 थिस्सलुनीकियों 4:13-18)। अनंत स्थिति को समझें: पुनरुत्थित विश्वासी नई पृथ्वी पर महिमामय शरीरों में हमेशा के लिए रहेंगे, जहां परमेश्वर अपने लोगों के साथ पूर्ण संगति में रहता है, पाप, पीड़ा, मृत्यु और क्षय से मुक्त (प्रकाशितवाक्य 21:1-5, 1 कुरिन्थियों 15:42-44)। स्वर्ग कैसा होगा इसकी खोज करें: परमेश्वर की आमने-सामने आराधना, मसीह के साथ राज करना, पुनर्स्थापित सृष्टि का आनंद लेना, और हमारे उद्धारकर्ता की उपस्थिति में अकल्पनीय आनंद का अनुभव करना (भजन संहिता 16:11, प्रकाशितवाक्य 22:3-5)। अच्छे कार्यों के माध्यम से स्वर्ग अर्जित करने, सार्वभौमिकता (हर कोई स्वर्ग में जाता है), या आत्मा की नींद के गैर-बाइबिलीय विचारों को अस्वीकार करें। मसीह के साथ अनंत जीवन की आशा को पवित्र जीवन, बलिदानी सेवा, और साहसी गवाही को प्रेरित करने दें, यह जानते हुए कि यह दुनिया हमारा घर नहीं है और सबसे अच्छा अभी आना बाकी है (इब्रानियों 11:13-16, 2 पतरस 3:11-14)।')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Malayalam translations
INSERT INTO recommended_topics_translations (topic_id, language_code, category, title, description)
VALUES
  -- Foundations of Faith
  ('111e8400-e29b-41d4-a716-446655440007', 'ml',
   'വിശ്വാസത്തിന്റെ അടിത്തറകൾ',
   'ക്രിസ്തുവിലുള്ള നിങ്ങളുടെ സ്വത്വം',
   'രക്ഷയുടെ സമയത്ത് സംഭവിക്കുന്ന സമൂലമായ പരിവർത്തനം കണ്ടെത്തുക: നിങ്ങൾ വിശ്വാസത്താൽ മാത്രം നീതീകരിക്കപ്പെട്ടവരാണ് (റോമർ 5:1), ക്രിസ്തുവിൽ തികച്ചും പുതിയ ഒരു സൃഷ്ടിയാണ് (2 കൊരിന്ത്യർ 5:17), പൂർണ്ണ അവകാശ അവകാശങ്ങളോടെ ദൈവത്തിന്റെ പ്രിയപ്പെട്ട മകനായി/മകളായി ദത്തെടുക്കപ്പെട്ടിരിക്കുന്നു (ഗലാത്യർ 4:4-7), ഭൂതകാലം, വർത്തമാനം, ഭാവി എന്നിവയിലെ എല്ലാ പാപങ്ങളിൽ നിന്നും പൂർണ്ണമായി ക്ഷമിക്കപ്പെട്ടിരിക്കുന്നു (കൊലോസ്യർ 2:13-14), പരിശുദ്ധാത്മാവിനാൽ സ്ഥിരമായി വസിക്കപ്പെട്ടിരിക്കുന്നു (1 കൊരിന്ത്യർ 6:19). നിങ്ങളുടെ സ്വത്വം ഇപ്പോൾ നിങ്ങളുടെ മുൻകാല പരാജയങ്ങൾ, നിലവിലെ പോരാട്ടങ്ങൾ, അല്ലെങ്കിൽ മറ്റുള്ളവർ എന്താണ് ചിന്തിക്കുന്നത് എന്നതിനാൽ നിർവ്വചിക്കപ്പെടുന്നില്ല, മറിച്ച് ദൈവം ക്രിസ്തുവിൽ നിങ്ങൾക്കായി ചെയ്തതിനാൽ മാത്രം നിർവ്വചിക്കപ്പെടുന്നുവെന്ന് പഠിക്കുക. അപലപനത്തിന്റെയും അരക്ഷിതാവസ്ഥയുടെയും നുണകളെ നിരാകരിക്കുക, നിങ്ങൾ തിരഞ്ഞെടുക്കപ്പെട്ടവരും വിശുദ്ധരും വളരെ സ്നേഹിക്കപ്പെട്ടവരുമാണെന്ന് അറിഞ്ഞുകൊണ്ട് സ്വാതന്ത്ര്യത്തിലും ആത്മവിശ്വാസത്തിലും നടക്കുക (കൊലോസ്യർ 3:12).'),
  ('111e8400-e29b-41d4-a716-446655440008', 'ml',
   'വിശ്വാസത്തിന്റെ അടിത്തറകൾ',
   'ദൈവത്തിന്റെ കൃപ മനസ്സിലാക്കുക',
   'കൃപയുടെ രൂപാന്തരപ്പെടുത്തുന്ന ശക്തി പര്യവേക്ഷണം ചെയ്യുക - യേശുക്രിസ്തുവിലൂടെ അയോഗ്യരായ പാപികൾക്ക് സൗജന്യമായി നൽകപ്പെടുന്ന ദൈവത്തിന്റെ അയോഗ്യമായ അനുഗ്രഹം (എഫെസ്യർ 2:8-9). കൃപ എന്നത് ദൈവം പാപത്തെ അവഗണിക്കുന്നതല്ല, മറിച്ച് ക്രിസ്തുവിന്റെ പകരക്കാരനായ മരണത്തിലൂടെ തന്റെ നീതി നിറവേറ്റുന്നതാണെന്ന് മനസ്സിലാക്കുക, അത് കുറ്റക്കാരായ പാപികളെ ക്ഷമിക്കാൻ അവനെ പ്രാപ്തനാക്കുന്നു, അതേസമയം പൂർണ്ണമായും നീതിമാനായി തുടരുന്നു (റോമർ 3:23-26). കൃപ നമ്മുടെ പ്രവൃത്തികളിൽ നിന്ന് പൂർണ്ണമായും അകന്ന് നമ്മെ രക്ഷിക്കുന്നുവെന്ന് (തീത്തോസ് 3:5) പഠിക്കുക, എന്നാൽ വിരോധാഭാസമായി നമ്മെ വിശുദ്ധ ജീവിതത്തിനും കടമയിൽ നിന്നല്ല, കൃതജ്ഞതയിൽ നിന്ന് ഒഴുകുന്ന നല്ല പ്രവൃത്തികൾക്കും ശാക്തീകരിക്കുന്നു (തീത്തോസ് 2:11-12). സുവിശേഷത്തിലേക്ക് മനുഷ്യ ആവശ്യങ്ങൾ ചേർക്കുന്ന നിയമവാദത്തെയും പാപത്തിനുള്ള ലൈസൻസായി കൃപ ഉപയോഗിക്കുന്ന അനിയന്ത്രിതത്വത്തെയും നിരാകരിക്കുക (ഗലാത്യർ 5:13, യൂദാ 1:4). കൃപയുടെ കീഴിൽ ജീവിക്കുന്നതിന്റെ സ്വാതന്ത്ര്യം കണ്ടെത്തുക: ദൈവത്താൽ അംഗീകരിക്കപ്പെടുന്നത് നാം ചെയ്യുന്നതിനാലല്ല, മറിച്ച് ക്രിസ്തു ചെയ്തതിനാൽ (റോമർ 6:14).'),

  -- Christian Life
  ('222e8400-e29b-41d4-a716-446655440007', 'ml',
   'ക്രൈസ്തവ ജീവിതം',
   'ആത്മീയ യുദ്ധം',
   'ഓരോ വിശ്വാസിയും സാത്താൻ, പിശാചുക്കൾ, ദൈവത്തോട് എതിരായ ലോകവ്യവസ്ഥ എന്നിവക്കെതിരായ ഒരു യഥാർത്ഥ ആത്മീയ യുദ്ധത്തിൽ ഏർപ്പെട്ടിരിക്കുന്നുവെന്ന് തിരിച്ചറിയുക (എഫെസ്യർ 6:12, 1 പത്രോസ് 5:8)—എന്നാൽ പ്രദേശിക പിശാചുക്കളുടെ ദൈവശാസ്ത്രം, ബൈബിൾപരമായ അനുമതിയില്ലാതെ പിശാചുക്കളെ ബന്ധിക്കുകയും അഴിക്കുകയും ചെയ്യുന്നത്, അല്ലെങ്കിൽ പിശാചുക്കളെ കാണുന്നതിലും വിടുതൽ ശുശ്രൂഷയിലും ശ്രദ്ധ കേന്ദ്രീകരിക്കുന്ന കരിസ്മാറ്റിക് അതിരുകടന്നത് പോലുള്ള അബൈബിളിക ആശയങ്ങൾ നിരസിക്കുക. ദൈവത്തിന്റെ പൂർണ്ണ കവചം ധരിക്കാൻ പഠിക്കുക - സത്യം, നീതി, സുവിശേഷം, വിശ്വാസം, രക്ഷ, വചനം, പ്രാർത്ഥന (എഫെസ്യർ 6:13-18) - വിജയം നേടാനല്ല, മറിച്ച് ക്രിസ്തു ക്രൂശിൽ ഇതിനകം നേടിയിരിക്കുന്ന വിജയത്തിൽ ഉറച്ചു നിൽക്കാൻ (കൊലോസ്യർ 2:15). നമ്മുടെ ശത്രു ഒരു സൃഷ്ടിക്കപ്പെട്ട, പരാജയപ്പെട്ട ശത്രുവാണെന്ന് മനസ്സിലാക്കുക, ദൈവത്തിനു തുല്യമായ എതിർ ശക്തിയല്ല—സാത്താനും പിശാചുക്കളും മത്സരിച്ച വീണുപോയ സൃഷ്ടികളാണ്, ക്രിസ്തുവിനെപ്പോലെ ശാശ്വതമോ സർവ്വശക്തമോ ആയ ദേവതകളല്ല. നിങ്ങൾക്ക് ക്രിസ്തുവിൽ ഉള്ള സമർപ്പിത അധികാരത്തിൽ നടക്കുക (റോമർ 8:37, 1 യോഹന്നാൻ 4:4), പ്രധാനമായും ദൈവത്തോടുള്ള സമർപ്പണം, സത്യം, തിരുവെഴുത്തിലുള്ള വിശ്വാസം, പ്രാർത്ഥന എന്നിവയിലൂടെ പിശാചിനെ എതിർക്കുക—വിശദമായ ആത്മീയ യുദ്ധ സാങ്കേതിക വിദ്യകളിലൂടെയല്ല (യാക്കോബ് 4:7, 1 പത്രോസ് 5:9).'),
  ('222e8400-e29b-41d4-a716-446655440008', 'ml',
   'ക്രൈസ്തവ ജീവിതം',
   'സംശയവും ഭയവും കൈകാര്യം ചെയ്യുക',
   'മുതിർന്ന വിശ്വാസികളെപ്പോലും ബാധിക്കുന്ന സംശയത്തെയും ഭയത്തെയും അതിജീവിക്കുന്നതിനുള്ള ബൈബിൾപരമായ തന്ത്രങ്ങൾ പഠിക്കുക. ആത്മനിഷ്ഠമായ വികാരങ്ങളെ ആശ്രയിക്കുന്നതിനുപകരം തിരുവെഴുത്തിന്റെ വസ്തുനിഷ്ഠമായ സത്യം കൊണ്ട് നിങ്ങളുടെ മനസ്സിനെ പൂരിതമാക്കി സംശയത്തെ പോരാടുക (സങ്കീർത്തനം 119:11, റോമർ 10:17), നിങ്ങളുടെ ജീവിതത്തിലും ചരിത്രത്തിലും ദൈവത്തിന്റെ മുൻകാല വിശ്വസ്തത ഓർത്തുകൊണ്ട് (സങ്കീർത്തനം 77:11-12), നിങ്ങളുടെ ചോദ്യങ്ങൾ സത്യസന്ധമായി ദൈവത്തിന്റെ അടുക്കൽ കൊണ്ടുവരുന്നതിലൂടെ, അവൻ ആത്മാർത്ഥരായ അന്വേഷകരെ സ്വാഗതം ചെയ്യുന്നു (മർക്കോസ് 9:24). ഭയത്തെ ഇല്ലാതാക്കുന്ന ദൈവത്തിന്റെ പൂർണ്ണ സ്നേഹത്തിൽ ധ്യാനിച്ചുകൊണ്ട് (1 യോഹന്നാൻ 4:18), എല്ലാ സാഹചര്യങ്ങളുടെയും മേൽ അവന്റെ പരമാധികാര നിയന്ത്രണം (മത്തായി 10:29-31), നിങ്ങളെ ഒരിക്കലും ഉപേക്ഷിക്കാനോ ഉപേക്ഷിക്കാനോ അവന്റെ വാഗ്ദാനങ്ങൾ (എബ്രായർ 13:5-6) എന്നിവയിലൂടെ ഭയത്തെ അതിജീവിക്കുക. ഉത്കണ്ഠാകുലമായ ചിന്തകളെ പ്രാർത്ഥനയും കൃതജ്ഞതയും കൊണ്ട് മാറ്റിസ്ഥാപിക്കുക, ദൈവത്തിന്റെ സമാധാനം നിങ്ങളുടെ ഹൃദയത്തെയും മനസ്സിനെയും സംരക്ഷിക്കട്ടെ (ഫിലിപ്പിയർ 4:6-7). വിശ്വാസം എന്നത് സംശയത്തിന്റെയോ ഭയത്തിന്റെയോ അഭാവമല്ല, മറിച്ച് അവയെ അവഗണിച്ചുകൊണ്ട് ദൈവത്തിൽ വിശ്വസിക്കുക, നിങ്ങളുടെ വികാരങ്ങൾക്കുമേലെ അവന്റെ വചനം വിശ്വസിക്കാൻ തിരഞ്ഞെടുക്കുക എന്നതാണ് എന്ന് ഓർക്കുക.'),

  -- Church & Community
  ('333e8400-e29b-41d4-a716-446655440006', 'ml',
   'സഭയും സമൂഹവും',
   'സ്നാനവും കർത്താവിന്റെ അത്താഴവും',
   'യേശു സഭയ്ക്ക് നൽകിയ രണ്ട് കൽപ്പനകളുടെ (അല്ലെങ്കിൽ കൂദാശകളുടെ) അർത്ഥവും പ്രാധാന്യവും മനസ്സിലാക്കുക: സ്നാനവും കർത്താവിന്റെ അത്താഴവും. സ്നാനം ആന്തരിക യാഥാർത്ഥ്യത്തിന്റെ ബാഹ്യ പൊതു പ്രഖ്യാപനമാണെന്ന് പഠിക്കുക - ക്രിസ്തുവിന്റെ മരണം, അടക്കം, പുനരുത്ഥാനം എന്നിവയുമായി തിരിച്ചറിയൽ (റോമർ 6:3-4), ദൃശ്യമായ സഭാ സമൂഹത്തിലേക്കുള്ള പ്രവേശനം അടയാളപ്പെടുത്തുന്നു. സ്നാനം വിശ്വാസത്താൽ ഇതിനകം രക്ഷിക്കപ്പെട്ടവർക്കുള്ള അനുസരണത്തിന്റെ ഒരു പ്രതീകാത്മക പ്രവൃത്തിയാണ്; അത് തന്നെ രക്ഷിക്കുകയോ പുനർജനിപ്പിക്കുകയോ ചെയ്യുന്നില്ല - രക്ഷ ക്രിസ്തുവിലുള്ള വിശ്വാസത്തിലൂടെ മാത്രമാണ് വരുന്നത്, ജല സ്നാനത്തിലൂടെയല്ല (എഫെസ്യർ 2:8-9). സ്നാന പുനർജനനത്തെ (സ്നാനം രക്ഷിക്കുന്നു എന്ന തെറ്റായ പഠിപ്പിക്കൽ) നിരാകരിക്കുക, അതേസമയം സ്നാനത്തെ അനുസരണത്തിന്റെ നിർണായകമായ ഒരു ഘട്ടമായി തിരിച്ചറിയുക, അത് വിശ്വാസികളെ ക്രിസ്തുവുമായി പരസ്യമായി തിരിച്ചറിയുന്നു. സ്നാന രീതി (മുങ്ങൽ vs. തളിക്കൽ) സ്വീകർത്താക്കൾ (വിശ്വാസികൾ മാത്രം vs. ശിശു സ്നാനം) എന്നിവയെക്കുറിച്ചുള്ള വിവിധ വീക്ഷണങ്ങൾ പര്യവേക്ഷണം ചെയ്യുക, അതേസമയം അതിന്റെ പ്രതീകാത്മക, രക്ഷിക്കാത്ത സ്വഭാവത്തിൽ ഐക്യം നിലനിർത്തുക. കർത്താവിന്റെ അത്താഴം നമ്മുടെ പാപങ്ങൾക്കായി ക്രിസ്തുവിന്റെ തകർന്ന ശരീരത്തിന്റെയും ചൊരിഞ്ഞ രക്തത്തിന്റെയും പതിവ് ഓർമ്മപ്പെടുത്തലായി കണ്ടെത്തുക (1 കൊരിന്ത്യർ 11:23-26), ആത്മപരിശോധനയുടെയും കുറ്റസമ്മതത്തിന്റെയും സമയം (1 കൊരിന്ത്യർ 11:28), അവൻ മടങ്ങിവരുന്നതുവരെ അവന്റെ മരണത്തിന്റെ പ്രഖ്യാപനം - ക്രിസ്തുവിന്റെ പുനർബലിയോ കൃപ നേടാനുള്ള മാർഗമോ അല്ല. ഈ കൽപ്പനകൾ ദൈവത്തിന്റെ അനുഗ്രഹം നേടുന്നതോ രക്ഷിക്കുന്ന കൃപ നൽകുന്നതോ ആയ ആചാരങ്ങളായി അല്ല, മറിച്ച് ക്രിസ്തുവിന്റെ പൂർത്തീകരിച്ച പ്രവൃത്തിയോടുള്ള കൃതജ്ഞതാപൂർവ്വമായ പ്രതികരണങ്ങളായി ആചരിക്കുക, വിശ്വാസവും സഭാ ഐക്യവും ശക്തിപ്പെടുത്തുന്നു.'),

  -- Spiritual Disciplines
  ('555e8400-e29b-41d4-a716-446655440006', 'ml',
   'ആത്മീയ അനുശാസനം',
   'ബൈബിൾ എങ്ങനെ പഠിക്കാം',
   'ദൈനംദിന ജീവിതത്തിൽ ദൈവത്തിന്റെ വചനം ഫലപ്രദമായി വായിക്കാനും മനസ്സിലാക്കാനും പ്രയോഗിക്കാനുമുള്ള പ്രായോഗിക കഴിവുകൾ വികസിപ്പിക്കുക. നിരീക്ഷണം (വാചകം എന്താണ് പറയുന്നത്?), വ്യാഖ്യാനം (അതിന്റെ യഥാർത്ഥ സന്ദർഭത്തിൽ അതിന്റെ അർത്ഥമെന്താണ്?), പ്രയോഗം (അത് ഇന്ന് എന്റെ ജീവിതത്തിന് എങ്ങനെ ബാധകമാകുന്നു?) എന്നിവയുടെ പ്രാധാന്യം പഠിക്കുക. നല്ല വ്യാഖ്യാന തത്വങ്ങൾ പരിശീലിക്കുക: തിരുവെഴുത്ത് സന്ദർഭത്തിൽ വായിക്കുക, വ്യക്തമായ വാക്യങ്ങളുടെ വെളിച്ചത്തിൽ ബുദ്ധിമുട്ടുള്ള വാക്യങ്ങൾ വ്യാഖ്യാനിക്കുക, തിരുവെഴുത്ത് തിരുവെഴുത്തിനെ വ്യാഖ്യാനിക്കട്ടെ, വ്യത്യസ്ത സാഹിത്യ വിഭാഗങ്ങൾ (ആഖ്യാനം, കവിത, പ്രവചനം, ലേഖനം) തിരിച്ചറിയുക. ധാരണയ്ക്ക് സഹായിക്കുന്ന ഉപകരണങ്ങൾ കണ്ടെത്തുക - ക്രോസ് റഫറൻസുകൾ, പഠന ബൈബിളുകൾ, കോൺകോർഡൻസുകൾ. സാധാരണ തെറ്റുകൾ ഒഴിവാക്കുക - ഐസെജെസിസ് (വാചകത്തിലേക്ക് നിങ്ങളുടെ ആശയങ്ങൾ വായിക്കൽ), വാക്യങ്ങൾ സന്ദർഭത്തിൽ നിന്ന് പുറത്തെടുക്കൽ, വ്യക്തമായ ചരിത്ര ആഖ്യാനങ്ങൾ ആത്മീയമാക്കൽ. ബൈബിൾ പഠനം ദൈനംദിന അനുശാസനമാക്കുക, തിരുവെഴുത്തിനെ പ്രാർത്ഥനയോടെ, വിനയത്തോടെ, പ്രതീക്ഷയോടെ സമീപിക്കുക, ആത്മാർത്ഥമായി അന്വേഷിക്കുന്നവർക്ക് പരിശുദ്ധാത്മാവ് സത്യം പ്രകാശിപ്പിക്കുന്നുവെന്ന് അറിഞ്ഞുകൊണ്ട് (യോഹന്നാൻ 16:13, 2 തിമൊഥെയൊസ് 2:15).'),
  ('555e8400-e29b-41d4-a716-446655440007', 'ml',
   'ആത്മീയ അനുശാസനം',
   'ദൈവഹിതം തിരിച്ചറിയുക',
   'ദൈവഹിതം പ്രധാനമായും അവന്റെ വെളിപ്പെടുത്തിയ വചനമായ ബൈബിൾ വഴിയാണ് തിരിച്ചറിയേണ്ടതെന്ന് പഠിക്കുക, അതിൽ വിശ്വാസത്തിനും ദൈവികമായ ജീവിതത്തിനും ആവശ്യമായ എല്ലാ മാർഗനിർദേശങ്ങളും അടങ്ങിയിരിക്കുന്നു (2 തിമൊഥെയൊസ് 3:16-17, സങ്കീർത്തനം 119:105). ദൈവം ഇന്ന് വിശ്വാസികളെ തിരുവെഴുത്ത്, പ്രാർത്ഥന, പരിശുദ്ധാത്മാവിന്റെ ബോധ്യം, സാഹചര്യങ്ങൾ, ഭക്തിപൂർണ്ണമായ ഉപദേശം എന്നിവയിലൂടെയാണ് മാർഗനിർദേശം നൽകുന്നതെന്ന് മനസ്സിലാക്കുക - തിരുവെഴുത്തിനെ വിരുദ്ധമാക്കുന്ന പുതിയ വെളിപാടോ ആത്മനിഷ്ഠമായ മതിപ്പുകളോ വഴിയല്ല. എല്ലാ മാർഗനിർദേശവും ദൈവവചനത്തിന്റെ മാറ്റമില്ലാത്ത മാനദണ്ഡത്തിനെതിരെ പരീക്ഷിക്കുക (പ്രവൃത്തികൾ 17:11, 1 തെസ്സലൊനീക്യർ 5:21). ദൈവത്തിന്റെ ധാർമ്മിക ഹിതം (നീതിമത്തായി എങ്ങനെ ജീവിക്കണം) തിരുവെഴുത്തിൽ വ്യക്തമായി വെളിപ്പെടുത്തിയിരിക്കുന്നുവെന്ന് തിരിച്ചറിയുക, അതേസമയം വ്യക്തിഗത തീരുമാനങ്ങൾക്കായുള്ള അവന്റെ പ്രത്യേക ഹിതം പലപ്പോഴും ബൈബിൾപരമായ അതിരുകൾക്കുള്ളിൽ പവിത്രീകരിക്കപ്പെട്ട ജ്ഞാനവും സ്വാതന്ത്ര്യവും ഉൾക്കൊള്ളുന്നു (റോമർ 12:1-2). ഓരോ തീരുമാനത്തിനും നിങ്ങൾ കണ്ടെത്തേണ്ട ഒരു തികഞ്ഞ തിരഞ്ഞെടുപ്പ് ദൈവത്തിനുണ്ട് എന്ന ആശയം നിരാകരിക്കുക; പകരം, അവൻ വെളിപ്പെടുത്തിയ തത്വങ്ങൾക്കുള്ളിൽ ദൈവത്തെ ബഹുമാനിക്കുന്ന ബുദ്ധിപരമായ തിരഞ്ഞെടുപ്പുകൾ നടത്തുക. നിങ്ങളുടെ ബന്ധപരമായ നിലയിൽ ദൈവം പരമാധികാരപൂർവ്വം നിങ്ങളുടെ ചുവടുകൾ നയിക്കുന്നുവെന്ന് വിശ്വസിക്കുക, നിങ്ങൾ ബൈബിൾപരമായ ജ്ഞാനം അനുസരിച്ച് ഉത്തരവാദിത്തമുള്ള തീരുമാനങ്ങൾ എടുക്കുമ്പോഴും (സദൃശവാക്യങ്ങൾ 3:5-6, സങ്കീർത്തനം 37:23).'),

  -- Apologetics
  ('666e8400-e29b-41d4-a716-446655440006', 'ml',
   'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും',
   'വിശ്വാസവും ശാസ്ത്രവും',
   'ബൈബിൾപരമായ വിശ്വാസവും യഥാർത്ഥ ശാസ്ത്രവും ശത്രുക്കളല്ല, മറിച്ച് ദൈവത്തിന്റെ യാഥാർത്ഥ്യം മനസ്സിലാക്കുന്നതിനുള്ള പൂരക മാർഗങ്ങളാണെന്ന് പര്യവേക്ഷണം ചെയ്യുക - തിരുവെഴുത്ത് ആരാണ് സൃഷ്ടിച്ചതെന്നും എന്തുകൊണ്ട് എന്നും വെളിപ്പെടുത്തുന്നു, അതേസമയം ശാസ്ത്രം സൃഷ്ടി എങ്ങനെ പ്രവർത്തിക്കുന്നുവെന്ന് അന്വേഷിക്കുന്നു. വൈജ്ഞാനിക രീതി തന്നെ ഒരു യുക്തിസഹമായ ദൈവം സൃഷ്ടിച്ച ഒരു ക്രമീകൃത, മനസ്സിലാക്കാവുന്ന പ്രപഞ്ചത്തെ അനുമാനിച്ച ഒരു ക്രിസ്ത്യൻ ലോകവീക്ഷണത്തിൽ നിന്ന് ഉടലെടുത്തുവെന്ന് മനസ്സിലാക്കുക (ഉല്പത്തി 1:1, സങ്കീർത്തനം 19:1). സൃഷ്ടിയിൽ ദൈവത്തിനുള്ള തെളിവുകൾ പരിശോധിക്കുക: ഭൗതിക സ്ഥിരാങ്കങ്ങളുടെ സൂക്ഷ്മ-ട്യൂണിംഗ്, DNA യുടെ നിർദ്ദിഷ്ട സങ്കീർണ്ണത, ജൈവ സംവിധാനങ്ങളുടെ വിവര ഉള്ളടക്കം, സ്വാഭാവിക നിയമങ്ങളുടെ ഗണിതശാസ്ത്ര കൃത്യത - എല്ലാം ലക്ഷ്യമില്ലാത്ത യാദൃശ്ചികതയേക്കാൾ ബുദ്ധിപരമായ രൂപകൽപ്പനയെ സൂചിപ്പിക്കുന്നു (റോമർ 1:20). ശാസ്ത്രത്തിനും വിശ്വാസത്തിനും ഇടയിലുള്ള പ്രകടമായ സംഘർഷങ്ങളെ അഭിസംബോധന ചെയ്യുക, പലതും വൈജ്ഞാനിക കണ്ടെത്തലുകളിൽ അടിച്ചേൽപ്പിക്കപ്പെട്ട ദാർശനിക പ്രകൃതിവാദത്തിൽ നിന്നാണ് ഉണ്ടാകുന്നതെന്ന് തിരിച്ചറിയുന്നു, കണ്ടെത്തലുകളിൽ നിന്ന് തന്നെയല്ല. ശാസ്ത്രവാദം (ശാസ്ത്രം മാത്രം സത്യം നൽകുന്നു) ബുദ്ധി വിരോധവാദം (വിശ്വാസത്തിന് യുക്തി നിരസിക്കേണ്ടതുണ്ട്) എന്നിവ രണ്ടും നിരാകരിക്കുക. ആത്യന്തിക യാഥാർത്ഥ്യം ശാസ്ത്രത്തിന് അളക്കാൻ കഴിയുന്നതിനപ്പുറമാണെന്ന് അംഗീകരിക്കുന്നതോടൊപ്പം തെളിവുകളിലും യുക്തിയിലും അധിഷ്ഠിതമായ വിശ്വാസം സ്വീകരിക്കുക (എബ്രായർ 11:1, കൊലോസ്യർ 2:3).'),

  -- Family & Relationships
  ('777e8400-e29b-41d4-a716-446655440006', 'ml',
   'കുടുംബവും ബന്ധങ്ങളും',
   'ഏകാന്തതയും സംതൃപ്തിയും',
   'അവിവാഹിതത്വത്തെക്കുറിച്ചുള്ള ദൈവത്തിന്റെ കാഴ്ചപ്പാട് ഒരു ഭാരമോ രണ്ടാം നിര പദവിയോ അല്ല, മറിച്ച് ഒരു സമ്മാനമാണെന്ന് കണ്ടെത്തുക (1 കൊരിന്ത്യർ 7:7-8, 32-35). രണ്ടുപേരും അവിവാഹിതരായ യേശുവിൽ നിന്നും പൗലോസിൽ നിന്നും പഠിക്കുക, അവർ റൊമാൻറിക് ബന്ധങ്ങളില്ലാതെ ദൈവത്തിന്റെ ലക്ഷ്യങ്ങൾക്കായി പൂർണ്ണമായി ജീവിച്ചു. നിങ്ങളുടെ ആത്യന്തിക സംതൃപ്തിയായി ക്രിസ്തുവുമായുള്ള നിങ്ങളുടെ ബന്ധം വളർത്തിയെടുക്കുകയും (ഫിലിപ്പിയർ 4:11-13, സങ്കീർത്തനം 73:25), അവിഭക്ത ഭക്തിയോടെ ദൈവത്തെ സേവിക്കുകയും, രാജ്യ ലക്ഷ്യങ്ങൾക്കായി നിങ്ങളുടെ അതുല്യമായ സ്വാതന്ത്ര്യം ഉപയോഗിക്കുകയും ചെയ്തുകൊണ്ട് നിങ്ങളുടെ നിലവിലെ കാലഘട്ടത്തിൽ സംതൃപ്തി കണ്ടെത്തുക. വിവാഹവും പ്രണയവും പൂർത്തീകരണത്തിന്റെ താക്കോലാക്കുന്ന സാംസ്കാരിക വിഗ്രഹാരാധനയെ എതിർക്കുക, അതേസമയം സാധ്യമായ ഭാവി വിവാഹത്തിനായി ബുദ്ധിപൂർവ്വം തയ്യാറെടുക്കുക. നിങ്ങളുടെ ബന്ധപരമായ നിലയുടെ മേലുള്ള ദൈവത്തിന്റെ പരമാധികാരത്തിൽ വിശ്വസിക്കുന്നതിനും നിങ്ങൾ ആഗ്രഹിക്കുന്നുവെങ്കിൽ വിവാഹത്തിലേക്ക് ഉചിതമായ നടപടികൾ സ്വീകരിക്കുന്നതിനും ഇടയിലുള്ള പിരിമുറുക്കം നാവിഗേറ്റ് ചെയ്യുക. ഒരു കാലഘട്ടത്തേക്കോ ജീവിതകാലം മുഴുവൻ അവിവാഹിതനോ ആകട്ടെ, നിങ്ങളുടെ പൂർണ്ണത ക്രിസ്തുവിൽ മാത്രമാണെന്ന സത്യം സ്വീകരിക്കുക (കൊലോസ്യർ 2:10), മറ്റൊരാളിലല്ല, ദൈവം എല്ലാ കാര്യങ്ങളും - അവിവാഹിതത്വം ഉൾപ്പെടെ - തന്നെ സ്നേഹിക്കുന്നവരുടെ നന്മയ്ക്കായി പ്രവർത്തിക്കുന്നുവെന്ന് (റോമർ 8:28).'),

  -- Mission & Service
  ('888e8400-e29b-41d4-a716-446655440006', 'ml',
   'മിഷനും സേവനവും',
   'ജോലിസ്ഥലം മിഷനായി',
   'നിങ്ങളുടെ ജോലിസ്ഥലം നിങ്ങൾ ശമ്പളം നേടുന്ന സ്ഥലം മാത്രമല്ല, മറിച്ച് ഉപ്പും വെളിച്ചവുമാകാൻ ദൈവം നിങ്ങളെ സ്ഥാപിച്ച ഒരു തന്ത്രപരമായ മിഷൻ ഫീൽഡാണെന്ന് മനസ്സിലാക്കുക (മത്തായി 5:13-16). കർത്താവിനുവേണ്ടി ചെയ്യുന്ന ഉത്തമമായ പ്രവൃത്തിയിലൂടെ ക്രിസ്തുവിനെ ബഹുമാനിക്കാൻ പഠിക്കുക, മനുഷ്യ ബോസുകളെ മാത്രം സന്തോഷിപ്പിക്കാനല്ല (കൊലോസ്യർ 3:23-24, എഫെസ്യർ 6:5-8). സത്യസന്ധത, അധ്വാനം, വിനയം, സത്യസന്ധത, അധികാരത്തോടുള്ള ആദരവ് എന്നിവയിലൂടെ ക്രിസ്ത്യൻ സ്വഭാവം പ്രദർശിപ്പിക്കുക - നിങ്ങളുടെ ആചാരം നിങ്ങളുടെ വാക്കുകളേക്കാൾ ഉച്ചത്തിൽ പ്രസംഗിക്കട്ടെ. സഹപ്രവർത്തകരുമായി സുവിശേഷം പങ്കിടാനുള്ള സ്വാഭാവിക അവസരങ്ങൾ തിരയുക, അതേസമയം ജോലിസ്ഥല അതിരുകളെ ബഹുമാനിക്കുകയും ആക്രമണാത്മകമോ കൃത്രിമമോ ആയ സുവിശേഷ പ്രചാരണം ഒഴിവാക്കുകയും ചെയ്യുക. രണ്ടും വൈരുദ്ധ്യമുള്ളപ്പോൾ മനുഷ്യരെക്കാൾ ദൈവത്തെ അനുസരിച്ചുകൊണ്ട് നൈതിക ദ്വന്ദങ്ങളെ നാവിഗേറ്റ് ചെയ്യുക (പ്രവൃത്തികൾ 5:29), അത് നിങ്ങളെ പ്രൊഫഷണലായി ചെലവേറിയാലും. നിങ്ങളുടെ തൊഴിലിനെ ദൈവത്തിൽ നിന്നുള്ള ഒരു വിളിയായി കാണുക, അവിടെ നിങ്ങൾ മറ്റുള്ളവരെ സേവിക്കുകയും മാനുഷിക അഭിവൃദ്ധിയിലേക്ക് സംഭാവന ചെയ്യുകയും ചെയ്യുന്നു, "യഥാർത്ഥ" ശുശ്രൂഷയ്ക്ക് ഫണ്ട് നൽകാനുള്ള ഒരു മാർഗം മാത്രമല്ല. മിക്ക വിശ്വാസികൾക്കും, ജോലിസ്ഥലം അവരുടെ ശുശ്രൂഷയുടെ പ്രാഥമിക മേഖലയാണെന്ന് ഓർക്കുക, അവിടെയുള്ള വിശ്വസ്തമായ സാന്നിധ്യം ദൈവത്തെ മഹത്വപ്പെടുത്തുകയും അവന്റെ രാജ്യം മുന്നോട്ട് കൊണ്ടുപോകുകയും ചെയ്യുന്നു (1 പത്രോസ് 2:12).'),

  -- Discipleship & Growth
  ('444e8400-e29b-41d4-a716-446655440006', 'ml',
   'ശിഷ്യത്വവും വളർച്ചയും',
   'വിശ്വാസത്താൽ ജീവിക്കുക, വികാരങ്ങളാൽ അല്ല',
   'വിശ്വാസത്താൽ ജീവിക്കുന്നതും (ദൈവത്തിന്റെ വസ്തുനിഷ്ഠമായ സത്യത്തിൽ വിശ്വസിക്കുന്നത്) വികാരങ്ങളാൽ ജീവിക്കുന്നതും (ആത്മനിഷ്ഠമായ വികാരങ്ങളിൽ വിശ്വസിക്കുന്നത്) തമ്മിലുള്ള നിർണായകമായ വ്യത്യാസം പഠിക്കുക. ബൈബിൾപരമായ വിശ്വാസം ഒരു യുക്തിരഹിതമായ കുതിപ്പോ ആശാവാദമോ അല്ല, മറിച്ച് തിരുവെഴുത്തിൽ വെളിപ്പെടുത്തിയിരിക്കുന്ന ദൈവത്തിന്റെ തെളിയിക്കപ്പെട്ട സ്വഭാവത്തിലും വാഗ്ദാനങ്ങളിലുമുള്ള ആത്മവിശ്വാസപൂർണ്ണമായ വിശ്വാസമാണെന്ന് മനസ്സിലാക്കുക (എബ്രായർ 11:1, റോമർ 10:17). വികാരങ്ങൾ യഥാർത്ഥമാണെന്നാൽ അവിശ്വാസ്യമായ വഴികാട്ടികളാണെന്ന് തിരിച്ചറിയുക - അവ സാഹചര്യങ്ങൾ, ഹോർമോണുകൾ, ഉറക്കം, എണ്ണമറ്റ മറ്റ് ഘടകങ്ങൾ എന്നിവയെ അടിസ്ഥാനമാക്കി ഏറ്റക്കുറച്ചിലുകൾ സംഭവിക്കുന്നു, അതേസമയം ദൈവവചനം എന്നേക്കും മാറ്റമില്ലാതെ നിലനിൽക്കുന്നു (യെശയ്യാവ് 40:8, മത്തായി 24:35). നിങ്ങൾക്ക് ദൈവസാന്നിധ്യം അനുഭവപ്പെടാത്തപ്പോൾ, പ്രാർത്ഥനകൾക്ക് ഉത്തരമില്ലെന്ന് തോന്നുമ്പോൾ, സാഹചര്യങ്ങൾ നിരാശാജനകമായി കാണപ്പെടുമ്പോൾ, അല്ലെങ്കിൽ സംശയങ്ങൾ നിങ്ങളുടെ മനസ്സിനെ ആക്രമിക്കുമ്പോൾ വിശ്വാസത്താൽ നടക്കാൻ പരിശീലിക്കുക (2 കൊരിന്ത്യർ 5:7, ഹബക്കൂക്ക് 3:17-19). തിരുവെഴുത്തിൽ ധ്യാനിച്ചുകൊണ്ട്, ദൈവത്തിന്റെ മുൻകാല വിശ്വസ്തത ഓർത്തുകൊണ്ട്, നിങ്ങൾക്ക് എങ്ങനെ തോന്നുന്നുവെന്ന് പരിഗണിക്കാതെ തന്നെയെക്കുറിച്ചും നിങ്ങളുടെ സ്വത്വത്തെക്കുറിച്ചും നിങ്ങളുടെ ഭാവിയെക്കുറിച്ചും ദൈവം പറയുന്നത് വിശ്വസിക്കാൻ ദിവസേന തിരഞ്ഞെടുക്കുന്നതിലൂടെ വിശ്വാസം വളർത്തുക. വൈകാരിക ഉയർച്ചകളേക്കാൾ സഹിഷ്ണുതയുള്ള വിശ്വാസം ദൈവത്തെ വളരെയധികം ബഹുമാനിക്കുന്നുവെന്നും, അവനെ ആത്മാർത്ഥമായി അന്വേഷിക്കുന്നവരെ അവൻ പ്രതിഫലം നൽകുന്നുവെന്നും വിശ്വസിക്കുക (എബ്രായർ 11:6).'),

  -- Hope & Future
  ('999e8400-e29b-41d4-a716-446655440001', 'ml',
   'പ്രത്യാശയും ഭാവിയും',
   'ക്രിസ്തുവിന്റെ മടങ്ങിവരവ്',
   'യേശുക്രിസ്തുവിന്റെ ഭൂമിയിലേക്കുള്ള വ്യക്തിപരവും ദൃശ്യവും ശാരീരികവുമായ മഹത്തായ തിരിച്ചുവരവിന്റെ അനുഗ്രഹീത പ്രത്യാശ പര്യവേക്ഷണം ചെയ്യുക (തീത്തോസ് 2:13, പ്രവൃത്തികൾ 1:11, വെളിപാട് 1:7) - അവന്റെ ആദ്യത്തെ വരവ് പോലെ തന്നെ ഉറപ്പുള്ളതും ക്രിസ്ത്യൻ വിശ്വാസത്തിന്റെ ഒരു പ്രധാന സിദ്ധാന്തവുമായ ഒരു സംഭവം. യേശു സ്വർഗത്തിലേക്ക് ആരോഹണം ചെയ്ത അതേ ഭൗതികവും ഉയിർത്തെഴുന്നേറ്റതുമായ ശരീരത്തിൽ തിരിച്ചുവരുമെന്ന് (പ്രവൃത്തികൾ 1:11), അവന്റെ രണ്ടാം വരവിന്റെ ഏതെങ്കിലും ആത്മീയമോ പ്രതീകാത്മകമോ ആയ വ്യാഖ്യാനങ്ങൾ നിരസിച്ചുകൊണ്ട്. ക്രിസ്തു ജീവിച്ചിരിക്കുന്നവരെയും മരിച്ചവരെയും വിധിക്കാൻ മടങ്ങിവരുമെന്ന് (2 തിമൊഥെയൊസ് 4:1) മനസ്സിലാക്കുക, വിശ്വാസികളെ നിത്യജീവിതത്തിലേക്കും അവിശ്വാസികളെ നിത്യശിക്ഷയിലേക്കും ഉയിർപ്പിക്കുന്നു (യോഹന്നാൻ 5:28-29), ഈ നിലവിലെ ദുഷ്ട യുഗത്തെ നശിപ്പിക്കുകയും തന്റെ നിത്യ രാജ്യം സ്ഥാപിക്കുകയും ചെയ്യും (വെളിപാട് 21-22). ഈ പ്രത്യാശ ദൈനംദിന ജീവിതത്തെ എങ്ങനെ രൂപപ്പെടുത്തണമെന്ന് പഠിക്കുക: അവനെ മുഖാമുഖം കാണുന്നതിന്റെ പ്രതീക്ഷയിൽ വിശുദ്ധി പിന്തുടരുക (1 യോഹന്നാൻ 3:2-3), ലൗകിക മൂല്യങ്ങളേക്കാൾ നിത്യ കാഴ്ചപ്പാടോടെ ജീവിക്കുക (കൊലോസ്യർ 3:1-4), ക്ഷമയുള്ള പ്രത്യാശയോടെ കഷ്ടപ്പാടുകൾ സഹിക്കുക (റോമർ 8:18), അവന്റെ തിരിച്ചുവരവിനുമുമ്പ് അടിയന്തിരമായി സുവിശേഷം പങ്കിടുക (2 പത്രോസ് 3:9-10). തീയതികളെയും സമയത്തെയും കുറിച്ചുള്ള ഊഹാപോഹങ്ങൾ ഒഴിവാക്കുക, യേശു പറഞ്ഞത് നമുക്ക് അറിയാൻ കഴിയില്ലെന്ന് (മത്തായി 24:36), അതേസമയം എല്ലാ സമയത്തും ജാഗ്രതയുള്ളവരും തയ്യാറുള്ളവരുമായിരിക്കുക (മത്തായി 24:42-44). ക്രിസ്തു നിങ്ങളുടെ ജീവിതകാലത്ത് മടങ്ങിവരുന്നുവോ അല്ലെങ്കിൽ മരണത്തിലൂടെ നിങ്ങൾ അവനെ കാണാൻ പോകുന്നുവോ, അവന്റെ പ്രത്യക്ഷതയുടെ സന്തോഷകരമായ പ്രതീക്ഷയോടെ എല്ലാ ദിവസവും ജീവിക്കുക (ഫിലിപ്പിയർ 1:21-23).'),
  ('999e8400-e29b-41d4-a716-446655440002', 'ml',
   'പ്രത്യാശയും ഭാവിയും',
   'സ്വർഗവും നിത്യജീവനും',
   'സ്വർഗത്തെക്കുറിച്ച് ബൈബിൾ യഥാർത്ഥത്തിൽ എന്താണ് പഠിപ്പിക്കുന്നതെന്ന് കണ്ടെത്തുക - കിന്നരങ്ങളും മേഘങ്ങളുമല്ല, മറിച്ച് ക്രിസ്തുവിൽ മരിക്കുന്നവരുടെ മഹത്തായ നിത്യ സ്ഥിതി. മരിക്കുന്ന വിശ്വാസികൾ ഉടൻ തന്നെ ബോധപൂർവ്വമായതും സന്തോഷകരവുമായ ഒരു ഇടത്തരം അവസ്ഥയിൽ ദൈവസാന്നിധ്യത്തിലേക്ക് പ്രവേശിക്കുന്നുവെന്ന് (2 കൊരിന്ത്യർ 5:8, ഫിലിപ്പിയർ 1:23) പഠിക്കുക, ക്രിസ്തുവിന്റെ തിരിച്ചുവരവിൽ ശരീരത്തിന്റെ പുനരുത്ഥാനത്തിനായി കാത്തിരിക്കുന്നു (1 തെസ്സലൊനീക്യർ 4:13-18). നിത്യ സ്ഥിതി മനസ്സിലാക്കുക: ഉയിർത്തെഴുന്നേറ്റ വിശ്വാസികൾ മഹത്വമുള്ള ശരീരങ്ങളിൽ പുതിയ ഭൂമിയിൽ എന്നേക്കുമായി ജീവിക്കും, അവിടെ ദൈവം തന്റെ ജനത്തോടൊപ്പം പൂർണ്ണ കൂട്ടായ്മയിൽ വസിക്കുന്നു, പാപം, കഷ്ടപ്പാട്, മരണം, ക്ഷയം എന്നിവയിൽ നിന്ന് മുക്തമാണ് (വെളിപാട് 21:1-5, 1 കൊരിന്ത്യർ 15:42-44). സ്വർഗം എങ്ങനെയായിരിക്കുമെന്ന് പര്യവേക്ഷണം ചെയ്യുക: ദൈവത്തെ മുഖാമുഖം ആരാധിക്കുക, ക്രിസ്തുവിനോടൊപ്പം വാഴുക, പുനഃസ്ഥാപിച്ച സൃഷ്ടി ആസ്വദിക്കുക, നമ്മുടെ രക്ഷകന്റെ സാന്നിധ്യത്തിൽ സങ്കൽപ്പിക്കാനാവാത്ത സന്തോഷം അനുഭവിക്കുക (സങ്കീർത്തനം 16:11, വെളിപാട് 22:3-5). നല്ല പ്രവൃത്തികളിലൂടെ സ്വർഗം നേടുക, സാർവത്രികത (എല്ലാവരും സ്വർഗത്തിലേക്ക് പോകുന്നു), അല്ലെങ്കിൽ ആത്മാവിന്റെ ഉറക്കം എന്നിവയുടെ ബൈബിളേതര ആശയങ്ങൾ നിരാകരിക്കുക. ക്രിസ്തുവിനോടൊപ്പമുള്ള നിത്യജീവിതത്തിന്റെ പ്രത്യാശ വിശുദ്ധ ജീവിതം, ത്യാഗപരമായ സേവനം, ധൈര്യപൂർവ്വമുള്ള സാക്ഷ്യം എന്നിവയ്ക്ക് പ്രചോദനം നൽകട്ടെ, ഈ ലോകം നമ്മുടെ ഭവനമല്ലെന്നും ഏറ്റവും മികച്ചത് വരാനിരിക്കുന്നുവെന്നും അറിഞ്ഞുകൊണ്ട് (എബ്രായർ 11:13-16, 2 പത്രോസ് 3:11-14).')
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
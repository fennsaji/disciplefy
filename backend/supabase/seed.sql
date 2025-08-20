-- ============================================================================

BEGIN;

DELETE FROM recommended_topics;

-- ========================
-- Category: Foundations of Faith
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('111e8400-e29b-41d4-a716-446655440001', 'Who is Jesus Christ?', 'Understanding the identity of Jesus: Son of God, Savior, and Lord.', 'Foundations of Faith', ARRAY['jesus', 'son of god', 'savior', 'lord'], 1),
  ('111e8400-e29b-41d4-a716-446655440002', 'What is the Gospel?', 'Learning the good news of salvation through Jesus Christ.', 'Foundations of Faith', ARRAY['gospel', 'salvation', 'good news'], 2),
  ('111e8400-e29b-41d4-a716-446655440003', 'Assurance of Salvation', 'How believers can be confident in their salvation by faith in Christ.', 'Foundations of Faith', ARRAY['assurance', 'salvation', 'faith'], 3),
  ('111e8400-e29b-41d4-a716-446655440004', 'Why Read the Bible?', 'Understanding the importance of God’s Word for guidance and growth.', 'Foundations of Faith', ARRAY['bible', 'scripture', 'word of god'], 4),
  ('111e8400-e29b-41d4-a716-446655440005', 'Importance of Prayer', 'Discovering prayer as communication with God and a source of strength.', 'Foundations of Faith', ARRAY['prayer', 'communication with god', 'faith'], 5),
  ('111e8400-e29b-41d4-a716-446655440006', 'The Role of the Holy Spirit', 'Learning how the Holy Spirit guides, empowers, and transforms believers.', 'Foundations of Faith', ARRAY['holy spirit', 'guidance', 'empowerment'], 6)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Christian Life
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('222e8400-e29b-41d4-a716-446655440001', 'Walking with God Daily', 'Practical steps for building a consistent walk with God every day.', 'Christian Life', ARRAY['daily walk', 'faith', 'discipline'], 1),
  ('222e8400-e29b-41d4-a716-446655440002', 'Overcoming Temptation', 'How to resist sin and rely on God’s strength in moments of weakness.', 'Christian Life', ARRAY['temptation', 'sin', 'victory'], 2),
  ('222e8400-e29b-41d4-a716-446655440003', 'Forgiveness and Reconciliation', 'Learning to forgive others and seek peace in relationships.', 'Christian Life', ARRAY['forgiveness', 'reconciliation', 'peace'], 3),
  ('222e8400-e29b-41d4-a716-446655440004', 'The Importance of Fellowship', 'Why believers need community, encouragement, and accountability.', 'Christian Life', ARRAY['fellowship', 'community', 'church'], 4),
  ('222e8400-e29b-41d4-a716-446655440005', 'Giving and Generosity', 'Understanding biblical giving and living with a generous heart.', 'Christian Life', ARRAY['giving', 'tithing', 'generosity'], 5),
  ('222e8400-e29b-41d4-a716-446655440006', 'Living a Holy Life', 'God’s call to holiness in thought, word, and action.', 'Christian Life', ARRAY['holiness', 'purity', 'obedience'], 6)
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
  ('444e8400-e29b-41d4-a716-446655440004', 'The Great Commission', 'Understanding Jesus’ command to make disciples of all nations.', 'Discipleship & Growth', ARRAY['great commission', 'evangelism', 'discipleship'], 4),
  ('444e8400-e29b-41d4-a716-446655440005', 'Mentoring Others', 'How to guide and encourage others in their faith journey.', 'Discipleship & Growth', ARRAY['mentorship', 'discipleship', 'growth'], 5)
ON CONFLICT (id) DO NOTHING;

-- ========================
-- Category: Spiritual Disciplines
-- ========================
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('555e8400-e29b-41d4-a716-446655440001', 'Daily Devotions', 'Building the habit of daily time with God in prayer and the Word.', 'Spiritual Disciplines', ARRAY['devotion', 'quiet time', 'discipline'], 1),
  ('555e8400-e29b-41d4-a716-446655440002', 'Fasting and Prayer', 'Discovering the power of fasting and prayer in seeking God’s will.', 'Spiritual Disciplines', ARRAY['fasting', 'prayer', 'discipline'], 2),
  ('555e8400-e29b-41d4-a716-446655440003', 'Worship as a Lifestyle', 'Learning how worship is more than songs—it is a way of living.', 'Spiritual Disciplines', ARRAY['worship', 'lifestyle', 'obedience'], 3),
  ('555e8400-e29b-41d4-a716-446655440004', 'Meditation on God’s Word', 'How to reflect deeply on Scripture for transformation.', 'Spiritual Disciplines', ARRAY['meditation', 'scripture', 'word of god'], 4),
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
  ('777e8400-e29b-41d4-a716-446655440003', 'Honoring Parents', 'Understanding God’s command to honor father and mother.', 'Family & Relationships', ARRAY['parents', 'honor', 'obedience'], 3),
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
  ('888e8400-e29b-41d4-a716-446655440003', 'Serving the Poor and Needy', 'Understanding God’s heart for the poor and how to serve them.', 'Mission & Service', ARRAY['service', 'poor', 'justice'], 3),
  ('888e8400-e29b-41d4-a716-446655440004', 'Evangelism Made Simple', 'Practical steps to share the Gospel with boldness and love.', 'Mission & Service', ARRAY['evangelism', 'gospel', 'mission'], 4),
  ('888e8400-e29b-41d4-a716-446655440005', 'Praying for the Nations', 'Joining God’s mission through intercession for the world.', 'Mission & Service', ARRAY['prayer', 'missions', 'nations'], 5)
ON CONFLICT (id) DO NOTHING;

COMMIT;

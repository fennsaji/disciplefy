-- =====================================================
-- Migration: 18 New Learning Paths
-- =====================================================
-- Adds 18 new learning paths across all 6 categories:
--   Foundations (3): Understanding the Bible, Baptism & Lord's Supper, Who Is the Holy Spirit?
--   Growth (3): Theology of Suffering, Money & Generosity, Spiritual Warfare
--   Service & Mission (3): The Local Church, Evangelism in Everyday Life, Work as Worship
--   Apologetics (4): Historical Reliability, Responding to Cults, Christianity & Culture,
--               The Big Questions (basic apologetics)
--   Life & Relationships (3): Singleness/Dating/Marriage, Mental Health, Friendship & Community
--   Theology (3): Attributes of God, Law/Grace/Covenants, Sin/Repentance/Grace
-- =====================================================

BEGIN;

-- =====================================================
-- PART 1: NEW RECOMMENDED TOPICS
-- =====================================================

-- -------------------------------------------------------
-- BBB: Understanding the Bible topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('bbb00000-e29b-41d4-a716-446655440001', 'How We Got the Bible',
   'Discover how God preserved His Word through centuries of history. Explore how books of the Bible were written, collected, and recognized as Scripture by the early church — and understand what it means for the Bible to be inspired and inerrant. Build confidence that the Bible you hold is exactly what God intended for His people.',
   'Foundations of Faith', ARRAY['canon', 'bible', 'inspiration', 'inerrancy'], 201, 50),

  ('bbb00000-e29b-41d4-a716-446655440002', 'Understanding Biblical Genres',
   'The Bible is a library of different literary forms — history, poetry, prophecy, letters, and apocalyptic literature. Learn how to recognize each genre and apply appropriate interpretive principles so you read every passage the way its author intended. This skill transforms your Bible reading from surface-level to genuinely illuminating.',
   'Foundations of Faith', ARRAY['hermeneutics', 'genre', 'interpretation', 'bible reading'], 202, 50),

  ('bbb00000-e29b-41d4-a716-446655440003', 'The Old Testament Story',
   'Trace the grand narrative of the Old Testament from creation to exile and restoration. See how God''s plan of redemption unfolds through Abraham, Moses, David, and the prophets, all pointing forward to Christ. Understanding the Old Testament story gives you the context needed to read the whole Bible as one unified story.',
   'Foundations of Faith', ARRAY['old testament', 'redemption', 'covenant', 'history'], 203, 50),

  ('bbb00000-e29b-41d4-a716-446655440004', 'The New Testament Story',
   'Survey the New Testament — from the Gospels and Acts to the Epistles and Revelation — as one connected story of Christ''s coming, the Spirit''s outpouring, the church''s mission, and the world''s ultimate renewal. Grasp how every part of the New Testament calls believers to follow Jesus and proclaim the gospel to the ends of the earth.',
   'Foundations of Faith', ARRAY['new testament', 'jesus', 'church', 'mission'], 204, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- CCC: Baptism and the Lord's Supper topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('ccc00000-e29b-41d4-a716-446655440001', 'What Is Baptism?',
   'Explore the biblical meaning of baptism — an outward sign of inward transformation, a public declaration of faith in Christ''s death and resurrection. Study what the New Testament teaches about who should be baptized, what it represents, and why it matters for every follower of Jesus.',
   'Church & Community', ARRAY['baptism', 'ordinance', 'faith', 'church'], 211, 50),

  ('ccc00000-e29b-41d4-a716-446655440002', 'Why Be Baptized?',
   'Jesus commanded His disciples to be baptized, and the early church took this seriously. Learn the reasons behind baptism — obedience to Christ, identification with His death and resurrection, and entrance into the community of believers. This study addresses common questions and removes barriers that hold people back from taking this step.',
   'Church & Community', ARRAY['baptism', 'obedience', 'discipleship'], 212, 50),

  ('ccc00000-e29b-41d4-a716-446655440003', 'The Lord''s Supper: A Memorial and Proclamation',
   'The Lord''s Supper is one of the most sacred acts of Christian worship — a visible proclamation of Christ''s body broken and blood shed for sinners. Study its institution by Jesus at the Last Supper, its theological meaning, and how it unites believers in remembrance, anticipation, and community around the gospel.',
   'Church & Community', ARRAY['communion', 'lords supper', 'eucharist', 'gospel'], 213, 50),

  ('ccc00000-e29b-41d4-a716-446655440004', 'Participating Worthily',
   'Paul warns that taking the Lord''s Supper in an unworthy manner brings judgment, not blessing. This study unpacks what it means to examine yourself, discern the body, and come to the table with repentance, faith, and gratitude. Learn how to prepare your heart so that communion is a genuine encounter with the living Christ.',
   'Church & Community', ARRAY['communion', 'repentance', 'self-examination', 'worship'], 214, 50),

  ('ccc00000-e29b-41d4-a716-446655440005', 'Baptism, the Lord''s Supper, and Church Membership',
   'Both ordinances — baptism and the Lord''s Supper — are community practices, not private rituals. Explore how they connect to church membership, accountability, and the covenant life of the local congregation. Understand why the church, not the individual alone, is the proper context for these acts of worship.',
   'Church & Community', ARRAY['baptism', 'communion', 'church membership', 'community'], 215, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- DDD: Who Is the Holy Spirit? topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('ddd00000-e29b-41d4-a716-446655440001', 'The Holy Spirit in the Old Testament',
   'Before Pentecost, the Holy Spirit was actively at work in creation, in the lives of God''s servants, and in the inspiration of Scripture. Trace the Spirit''s presence through the Old Testament — empowering judges and prophets, indwelling the temple, and pointing forward to the promised outpouring of the new covenant age.',
   'Foundations of Faith', ARRAY['holy spirit', 'old testament', 'spirit of god'], 221, 50),

  ('ddd00000-e29b-41d4-a716-446655440002', 'The Holy Spirit and Salvation',
   'No one comes to Christ apart from the work of the Holy Spirit. Study how the Spirit convicts of sin, regenerates the heart, and seals the believer as God''s own. Understand the biblical doctrine of new birth — that salvation is not self-produced but divinely initiated — and how the Spirit assures us that we belong to God.',
   'Foundations of Faith', ARRAY['holy spirit', 'salvation', 'regeneration', 'conviction'], 222, 50),

  ('ddd00000-e29b-41d4-a716-446655440003', 'The Fruit of the Spirit',
   'Galatians 5 describes the beautiful character the Holy Spirit produces in believers: love, joy, peace, patience, kindness, goodness, faithfulness, gentleness, and self-control. This study explores each fruit, what it looks like in daily life, and how walking by the Spirit — rather than striving in self-effort — produces genuine Christlikeness.',
   'Christian Living', ARRAY['fruit of the spirit', 'character', 'christlikeness', 'galatians'], 223, 50),

  ('ddd00000-e29b-41d4-a716-446655440004', 'Being Filled with the Spirit',
   'Ephesians 5:18 commands believers to be filled with the Spirit — an ongoing, daily reality of yielded dependence on God. Learn what it means to walk in step with the Spirit, how this differs from spiritual gifts, and what practical patterns — prayer, Scripture, repentance, worship — open us to the Spirit''s full work in our lives.',
   'Spiritual Disciplines', ARRAY['holy spirit', 'filling', 'ephesians', 'dependence'], 224, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- EEE: Theology of Suffering topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('eee00000-e29b-41d4-a716-446655440001', 'Suffering in the Psalms: Learning to Lament',
   'The Psalms give God''s people permission to cry out in pain — to ask "How long, O Lord?" without shame. Study the lament psalms and learn a biblical pattern for processing suffering honestly: bringing raw emotion to God, remembering His faithfulness, and arriving at renewed trust. Lament is not faithlessness — it is faith in honest conversation.',
   'Christian Living', ARRAY['suffering', 'psalms', 'lament', 'prayer'], 231, 50),

  ('eee00000-e29b-41d4-a716-446655440002', 'Job and the Mystery of Suffering',
   'Job''s story confronts us with suffering''s deepest mystery: sometimes the righteous suffer most intensely. Explore what Job teaches about honest grief, the limits of human wisdom, the inadequacy of simple answers, and the strange comfort of encountering God Himself in the middle of the storm. God''s purposes are greater than we can see.',
   'Christian Living', ARRAY['suffering', 'job', 'mystery', 'sovereignty'], 232, 50),

  ('eee00000-e29b-41d4-a716-446655440003', 'The Cross and Our Suffering',
   'The cross is not just the solution to sin — it is God''s answer to suffering. Jesus entered into human pain, was abandoned, and died. This study shows how the cross transforms the meaning of suffering for believers: it is not punishment, but participation in Christ''s redemptive story. Our suffering is seen, known, and redeemed.',
   'Foundations of Faith', ARRAY['suffering', 'cross', 'jesus', 'redemption'], 233, 50),

  ('eee00000-e29b-41d4-a716-446655440004', 'Hope in Suffering: An Eternal Perspective',
   'Romans 8 promises that present sufferings are not worth comparing to the glory that will be revealed in us. Learn how an eternal perspective does not minimize present pain but transforms it — sustaining endurance, producing hope, and anchoring the soul in the unshakeable promises of God for those who are in Christ.',
   'Christian Living', ARRAY['suffering', 'hope', 'eternity', 'romans 8'], 234, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- FFF: Money, Generosity, and the Gospel topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('fff00000-e29b-41d4-a716-446655440001', 'What Does the Bible Say About Money?',
   'Jesus spoke about money more than almost any other topic — because how we handle wealth reveals the state of our heart. Survey the Bible''s comprehensive teaching on money: from Proverbs'' wisdom to Jesus'' warnings, from Paul''s contentment to the early church''s generosity. Money is a tool, not a master — learn to hold it accordingly.',
   'Christian Living', ARRAY['money', 'finances', 'wealth', 'heart'], 241, 50),

  ('fff00000-e29b-41d4-a716-446655440002', 'Contentment vs. Greed',
   'Paul declared that godliness with contentment is great gain — a radical counter-cultural claim. Study the biblical call to contentment, the danger of greed (which is idolatry), and how the gospel frees us from the relentless pursuit of more. Learn to find satisfaction in God rather than in accumulation.',
   'Christian Living', ARRAY['contentment', 'greed', 'covetousness', 'idolatry'], 242, 50),

  ('fff00000-e29b-41d4-a716-446655440003', 'Biblical Stewardship',
   'Everything belongs to God — we are managers, not owners, of what He has entrusted to us. Explore the biblical concept of stewardship applied to money, time, talents, and resources. This study reshapes how we think about budgeting, saving, spending, and giving as acts of worship rather than merely financial decisions.',
   'Christian Living', ARRAY['stewardship', 'money', 'giving', 'worship'], 243, 50),

  ('fff00000-e29b-41d4-a716-446655440004', 'Tithing and Giving',
   'Tithing has deep roots in Scripture — from Abraham to Malachi — and giving generously is a hallmark of New Testament discipleship. Examine what the Bible teaches about the tithe, freewill offerings, and cheerful generosity. Understand that giving is not merely a financial discipline but a spiritual one that declares trust in God''s provision.',
   'Christian Living', ARRAY['tithing', 'giving', 'generosity', 'offering'], 244, 50),

  ('fff00000-e29b-41d4-a716-446655440005', 'Work, Earning, and God''s Provision',
   'Work is not a curse but a calling. Even earning money is a form of stewardship and a means by which God provides for His people. Study the biblical theology of honest labor, fair wages, care for the poor, and the connection between how we earn and how we reflect God''s character in the marketplace.',
   'Christian Living', ARRAY['work', 'vocation', 'provision', 'stewardship'], 245, 50),

  ('fff00000-e29b-41d4-a716-446655440006', 'Eternal Investments',
   'Jesus urged His followers to store up treasure in heaven rather than on earth. This study explores what it means to invest for eternity — through generosity, kingdom-advancing work, discipleship, and sacrificial love. The things we do with our money and resources for God''s glory have consequences that outlast our earthly lives.',
   'Christian Living', ARRAY['eternity', 'giving', 'kingdom', 'investment'], 246, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- GGG: Spiritual Warfare new topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('ab100000-e29b-41d4-a716-446655440001', 'Who Is Satan and How Does He Operate?',
   'Scripture is neither silent about Satan nor obsessed with him — it gives us a clear, sober picture of our enemy. Study who Satan is, how he fell, what his tactics are (accusation, deception, temptation), and the limits of his power under God''s sovereign rule. Understanding the enemy is the first step to standing firm against him.',
   'Christian Living', ARRAY['satan', 'devil', 'spiritual warfare', 'deception'], 251, 50),

  ('ab100000-e29b-41d4-a716-446655440002', 'The Armor of God',
   'Ephesians 6 describes six pieces of spiritual armor that equip believers for the daily battle: truth, righteousness, the gospel, faith, salvation, and the Word of God. This study unpacks each piece practically — what it means to put it on, how it protects, and why every element points back to Jesus Christ as our ultimate warrior and defender.',
   'Spiritual Disciplines', ARRAY['armor of god', 'ephesians 6', 'prayer', 'warfare'], 252, 50),

  ('ab100000-e29b-41d4-a716-446655440003', 'Victory in Christ',
   'The decisive battle has already been won — at the cross and the empty tomb, Jesus disarmed the powers and authorities, making a public spectacle of them. Study what it means to live from victory rather than toward it, how the resurrection changes our position in spiritual warfare, and why believers can resist the devil with confident faith.',
   'Foundations of Faith', ARRAY['victory', 'resurrection', 'cross', 'spiritual warfare'], 253, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- HHH: The Local Church new topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('ab200000-e29b-41d4-a716-446655440001', 'Church Leadership and Authority',
   'The New Testament describes a structured community led by elders/pastors and deacons — servant-leaders who shepherd, teach, and protect the flock. Study the biblical qualifications for church leadership, the nature of spiritual authority, and how godly leadership differs from worldly power structures. Healthy churches have healthy leadership.',
   'Church & Community', ARRAY['church leadership', 'elders', 'pastors', 'authority'], 261, 50),

  ('ab200000-e29b-41d4-a716-446655440002', 'Church Discipline and Restoration',
   'One of the most misunderstood and neglected practices in modern Christianity, church discipline is actually an act of love — protecting the community and pursuing the restoration of a wandering member. Study Matthew 18 and 1 Corinthians 5, understand the goal of restoration over punishment, and see how discipline reflects the gospel''s seriousness about sin and grace.',
   'Church & Community', ARRAY['church discipline', 'restoration', 'accountability', 'community'], 262, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- III: Evangelism in Everyday Life new topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('ab300000-e29b-41d4-a716-446655440001', 'Overcoming Fear of Evangelism',
   'Most Christians want to share their faith but are paralyzed by fear — of rejection, of not knowing what to say, of damaging relationships. This study diagnoses where that fear comes from, applies gospel truth to it, and equips believers with the confidence that comes not from perfect words but from the Spirit''s power and God''s sovereign work in hearts.',
   'Mission & Evangelism', ARRAY['evangelism', 'fear', 'boldness', 'holy spirit'], 271, 50),

  ('ab300000-e29b-41d4-a716-446655440002', 'Answering Common Objections to Faith',
   'People raise real questions: "What about suffering?" "Isn''t Christianity exclusive?" "Can''t I be moral without God?" This study equips you to respond to the most common objections with gentleness and respect — not winning arguments but opening doors for the gospel. You don''t need all the answers; you need to point to the One who is the Answer.',
   'Mission & Evangelism', ARRAY['objections', 'apologetics', 'evangelism', 'questions'], 272, 50),

  ('ab300000-e29b-41d4-a716-446655440003', 'The Role of the Holy Spirit in Evangelism',
   'Evangelism is a partnership: we speak, God saves. Study how the Holy Spirit convicts, draws, and regenerates — why only God can open blind eyes — and how this truth frees us from the pressure of needing to "close the deal." Learn to pray with urgency, speak with boldness, and trust God with the results.',
   'Mission & Evangelism', ARRAY['holy spirit', 'evangelism', 'conviction', 'mission'], 273, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- JJJ: Work and Vocation as Worship new topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('ab400000-e29b-41d4-a716-446655440001', 'Work Before and After the Fall',
   'Work was given to humanity before sin entered the world — it is a gift, not a punishment. The Fall introduced frustration, futility, and thorns into our labor, but Christ''s redemption restores meaning to work. This study traces the biblical theology of work from Genesis to the New Creation, where our redeemed labor continues in a renewed world.',
   'Christian Living', ARRAY['work', 'vocation', 'creation', 'fall'], 281, 50),

  ('ab400000-e29b-41d4-a716-446655440002', 'Your Calling: More Than a Job',
   'Every believer has a primary calling — to follow Christ — and a secondary calling expressed through a particular vocation, role, and season of life. Study what it means to discern and live out your calling, how to hold your career in an open hand, and why the question is not "What do I do?" but "Who am I serving?"',
   'Christian Living', ARRAY['calling', 'vocation', 'purpose', 'discipleship'], 282, 50),

  ('ab400000-e29b-41d4-a716-446655440003', 'Excellence and Integrity at Work',
   'Colossians 3:23 commands believers to work at everything heartily, as for the Lord. Excellence is not workaholism — it is faithful stewardship of the time and talent God has entrusted to you. This study explores what integrity looks like in professional settings: honesty, diligence, fair dealing, and resisting the temptation to cut corners.',
   'Christian Living', ARRAY['integrity', 'excellence', 'work', 'stewardship'], 283, 50),

  ('ab400000-e29b-41d4-a716-446655440004', 'Being a Witness in the Workplace',
   'The workplace is one of the primary mission fields for most believers — a context where Christians can embody the gospel through character, conversation, and care for colleagues. Study how to be a credible witness at work without being preachy, how to navigate ethical tensions, and how to build genuine relationships that open doors for the gospel.',
   'Mission & Evangelism', ARRAY['witness', 'workplace', 'mission', 'character'], 284, 50),

  ('ab400000-e29b-41d4-a716-446655440005', 'Rest, Sabbath, and Rhythm',
   'God worked and then rested — and He commands His people to do the same. The Sabbath is not merely a rule but a rhythm of trust: declaring that God sustains the world, not our productivity. Study the theology of rest, how Sabbath points to Christ as our ultimate rest, and how regular rhythms of work and rest reflect the image of a working, resting God.',
   'Spiritual Disciplines', ARRAY['rest', 'sabbath', 'rhythm', 'trust'], 285, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- KKK: Historical Reliability of the Bible new topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('ab500000-e29b-41d4-a716-446655440001', 'Manuscript Evidence for the New Testament',
   'The New Testament is the most well-attested ancient document in history — with over 5,800 Greek manuscripts and thousands more in other languages. Study the science of textual criticism, understand why scholars trust the text we have, and see how the manuscript evidence for the New Testament far surpasses any other ancient work.',
   'Apologetics', ARRAY['manuscripts', 'new testament', 'textual criticism', 'reliability'], 291, 50),

  ('ab500000-e29b-41d4-a716-446655440002', 'Archaeological Confirmation of the Bible',
   'Archaeology has repeatedly confirmed biblical accounts that skeptics once dismissed as legendary — the walls of Jericho, the Pool of Siloam, Pontius Pilate''s inscription, and much more. Survey major archaeological discoveries that corroborate the biblical narrative and understand how these findings support the historical trustworthiness of Scripture.',
   'Apologetics', ARRAY['archaeology', 'bible', 'history', 'evidence'], 292, 50),

  ('ab500000-e29b-41d4-a716-446655440003', 'Old Testament Prophecies Fulfilled in Christ',
   'The Old Testament contains hundreds of specific prophecies fulfilled in the life, death, and resurrection of Jesus — written centuries before His birth. Study key messianic prophecies (Isaiah 53, Psalm 22, Micah 5, Daniel 9) and see how their precise fulfillment in Christ provides powerful evidence for the divine inspiration of Scripture.',
   'Apologetics', ARRAY['prophecy', 'messiah', 'fulfillment', 'old testament'], 293, 50),

  ('ab500000-e29b-41d4-a716-446655440004', 'The Resurrection as Historical Fact',
   'The resurrection of Jesus is the cornerstone of the Christian faith — and it is a claim to be investigated historically, not just believed by faith. Study the evidence: the empty tomb, post-resurrection appearances, the radical transformation of the disciples, and the explosive growth of the early church. The resurrection is the best explanation of the historical facts.',
   'Apologetics', ARRAY['resurrection', 'history', 'evidence', 'empty tomb'], 294, 50),

  ('ab500000-e29b-41d4-a716-446655440005', 'How the Canon Was Formed',
   'Why these 66 books and not others? The canon was not invented at Nicaea — it was recognized by the early church based on apostolicity, consistency with Scripture, and widespread use. Study the process by which God''s Word was confirmed, why books like the Gospel of Thomas were excluded, and what gives us confidence in the canon we have today.',
   'Apologetics', ARRAY['canon', 'bible', 'church history', 'reliability'], 295, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- LLL: Responding to Cults and False Teaching new topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('ab600000-e29b-41d4-a716-446655440001', 'What Makes a Teaching False?',
   'Not all teaching that uses biblical language is biblical teaching. Study the markers of false doctrine identified in Scripture — especially distortions of the person of Christ, the gospel of grace, and the authority of Scripture. Galatians, 2 Peter, and 1 John provide a robust toolkit for discerning true from false. Theological discernment is a mark of spiritual maturity.',
   'Apologetics', ARRAY['false teaching', 'discernment', 'heresy', 'doctrine'], 301, 50),

  ('ab600000-e29b-41d4-a716-446655440002', 'Recognizing Cultic Patterns',
   'Cults share common patterns regardless of their specific beliefs: extra-biblical authority, works-based salvation, isolation from outsiders, and a special group identity. Learn to recognize these patterns in groups like Jehovah''s Witnesses, Mormonism, and others — and equip yourself to engage their members with gospel truth and genuine love.',
   'Apologetics', ARRAY['cults', 'false religion', 'witnessing', 'discernment'], 302, 50),

  ('ab600000-e29b-41d4-a716-446655440003', 'Grace vs. Works-Based Religion',
   'Every false religion — including distorted forms of Christianity — ultimately requires human effort to earn divine favor. Study the radical uniqueness of the Christian gospel: salvation by grace alone through faith alone in Christ alone, apart from any human merit. This truth is the clearest line between genuine Christianity and every religious counterfeit.',
   'Foundations of Faith', ARRAY['grace', 'works', 'salvation', 'gospel'], 303, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- MMM: Christianity and Culture new topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('ab700000-e29b-41d4-a716-446655440001', 'How Christians Engage Culture',
   'Throughout history, Christians have approached culture in different ways — withdrawing from it, conforming to it, transforming it, or existing in creative tension with it. Study these models, examine them against Scripture, and develop a thoughtful framework for engaging culture with discernment, wisdom, and gospel intentionality.',
   'Christian Living', ARRAY['culture', 'engagement', 'world', 'kingdom'], 311, 50),

  ('ab700000-e29b-41d4-a716-446655440002', 'Media, Entertainment, and Discernment',
   'What we consume shapes who we become. Study biblical principles for evaluating media and entertainment — not a list of rules but a framework grounded in Philippians 4:8, Psalm 101, and Romans 12:2. Develop the habit of asking: What does this normalize? What does this form in me? How does this fit my identity as a child of God?',
   'Christian Living', ARRAY['media', 'discernment', 'entertainment', 'holiness'], 312, 50),

  ('ab700000-e29b-41d4-a716-446655440003', 'Sexuality and Biblical Ethics',
   'The Bible''s teaching on sexuality stands in sharp contrast to contemporary culture — not because Christianity is repressive but because God''s design is good. Study the biblical vision of sexuality rooted in creation, how the Fall distorted it, and how the gospel restores and redeems. Learn to hold biblical convictions with both clarity and compassion.',
   'Christian Living', ARRAY['sexuality', 'ethics', 'biblical ethics', 'culture'], 313, 50),

  ('ab700000-e29b-41d4-a716-446655440004', 'Justice, Mercy, and the Gospel',
   'The Bible is deeply concerned with justice — caring for the poor, the vulnerable, the oppressed. But biblical justice flows from the gospel, not ideology. Study what Scripture says about justice and mercy, how the church is called to serve the marginalized, and how to avoid the twin errors of ignoring injustice and replacing the gospel with social activism.',
   'Mission & Evangelism', ARRAY['justice', 'mercy', 'gospel', 'poverty'], 314, 50),

  ('ab700000-e29b-41d4-a716-446655440005', 'Speaking Truth in Love',
   'Ephesians 4:15 calls believers to speak the truth in love — holding both commitments without sacrificing one for the other. In a culture that often treats conviction as hate and love as affirmation, this is a delicate and crucial calling. Study how to engage controversial topics with biblical clarity, genuine care, and the winsome courage of the gospel.',
   'Christian Living', ARRAY['truth', 'love', 'culture', 'courage'], 315, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- NNN: Singleness, Dating, and Marriage new topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('ab800000-e29b-41d4-a716-446655440001', 'God''s Design for Marriage',
   'Marriage was designed by God before the Fall as a covenant between a man and woman that reflects Christ''s love for the church. Study the theological foundations of biblical marriage — its purpose, structure, and sacrificial nature. Understanding God''s design protects marriage from being reduced to a merely social institution or personal convenience.',
   'Family & Relationships', ARRAY['marriage', 'covenant', 'design', 'gospel'], 321, 50),

  ('ab800000-e29b-41d4-a716-446655440002', 'Purity Before Marriage',
   'Sexual purity is not an outdated rule but a reflection of the gospel — honoring God with our bodies, which He bought with a price. Study the biblical vision of purity, why it matters spiritually and relationally, and how to pursue it practically in a hyper-sexualized culture. Purity is not merely about restraint; it is about honoring God and future spouse.',
   'Family & Relationships', ARRAY['purity', 'sexuality', 'dating', 'holiness'], 322, 50),

  ('ab800000-e29b-41d4-a716-446655440003', 'Choosing a Spouse Wisely',
   'The decision of whom to marry is one of the most consequential choices of a lifetime. Study what Scripture says about qualities to seek in a spouse — shared faith, character, godliness — and how to navigate the process of discernment with wisdom, prayer, and accountability. The goal is not a perfect partner but a faithful covenant partner.',
   'Family & Relationships', ARRAY['marriage', 'dating', 'wisdom', 'discernment'], 323, 50),

  ('ab800000-e29b-41d4-a716-446655440004', 'When Marriage Is Hard',
   'Every marriage faces seasons of conflict, disappointment, and hardship. The gospel provides both the motivation and the resources to persevere — forgiveness, humility, sacrificial love, and the power of the Holy Spirit. Study what Scripture says about navigating marital difficulties, the seriousness of covenant, and when and how to seek help.',
   'Family & Relationships', ARRAY['marriage', 'conflict', 'forgiveness', 'perseverance'], 324, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- OOO: Mental Health, Emotions, and the Gospel new topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('ab900000-e29b-41d4-a716-446655440001', 'Emotions in the Bible: God Gave Us Feelings',
   'God is not emotionless, and neither are we — we are made in His image. Study how the Bible portrays a wide range of human emotions (joy, sorrow, anger, fear, longing) as part of what it means to be human. Explore how emotions are not enemies to suppress but signals to understand, and how the gospel addresses us as whole persons — body, mind, and heart.',
   'Christian Living', ARRAY['emotions', 'feelings', 'psychology', 'humanity'], 331, 50),

  ('ab900000-e29b-41d4-a716-446655440002', 'Anxiety, Worry, and the Peace of God',
   'Anxiety is one of the most common struggles of our age — and the Bible speaks directly to it. Study Philippians 4, Matthew 6, and 1 Peter 5 to understand the biblical response to anxiety: not dismissal but prayer, not denial but reorientation toward God''s sovereignty and love. The peace of God guards hearts in ways that surpass understanding.',
   'Christian Living', ARRAY['anxiety', 'worry', 'peace', 'prayer'], 332, 50),

  ('ab900000-e29b-41d4-a716-446655440003', 'Depression and the Soul',
   'Many biblical heroes — Elijah, David, Jeremiah — experienced profound darkness and despair. Scripture does not shame them for it. This study honestly addresses depression from a biblical perspective: acknowledging its reality, exploring its spiritual and physical dimensions, and pointing to the God who meets us in our lowest valley with sustaining grace.',
   'Christian Living', ARRAY['depression', 'suffering', 'soul care', 'hope'], 333, 50),

  ('ab900000-e29b-41d4-a716-446655440004', 'Grief, Lament, and Healing',
   'Grief is a holy and necessary response to loss — and the Bible gives us full permission to grieve. Study the biblical theology of lament, how Jesus wept at Lazarus'' tomb, and how the Psalms model bringing sorrow to God. Grief does not mean lack of faith; it means loving deeply in a world broken by sin and death. God is close to the brokenhearted.',
   'Christian Living', ARRAY['grief', 'lament', 'loss', 'healing'], 334, 50),

  ('ab900000-e29b-41d4-a716-446655440005', 'The Hope That Does Not Disappoint',
   'Romans 5 declares that hope does not put us to shame because God''s love has been poured into our hearts. This study anchors the struggling soul in the unshakeable hope of the gospel — not optimism based on circumstances but certainty grounded in who God is and what Christ has done. For the weary and despairing, this hope is the lifeline God provides.',
   'Christian Living', ARRAY['hope', 'romans 5', 'gospel', 'perseverance'], 335, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- PPP: Friendship and Christian Community new topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('aba00000-e29b-41d4-a716-446655440001', 'Spiritual Friendship in Scripture',
   'The Bible celebrates deep friendship — David and Jonathan, Ruth and Naomi, Paul and Timothy — as one of God''s great gifts. Study what biblical friendship looks like: mutual commitment, honest counsel, shared faith, and love that perseveres through difficulty. Learn why spiritual friendship is not a luxury but a necessity for the Christian life.',
   'Church & Community', ARRAY['friendship', 'community', 'accountability', 'love'], 341, 50),

  ('aba00000-e29b-41d4-a716-446655440002', 'Accountability and Mutual Encouragement',
   'Hebrews 10:24-25 calls believers to stir one another up to love and good works. This is the heart of Christian accountability — not surveillance but mutual encouragement in the faith. Study what healthy accountability looks like, how to have honest conversations, and how small groups and discipleship relationships form the backbone of a thriving Christian life.',
   'Church & Community', ARRAY['accountability', 'encouragement', 'discipleship', 'community'], 342, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- QQQ: Attributes of God new topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('abb00000-e29b-41d4-a716-446655440001', 'God Is Holy',
   'Holiness is the defining attribute of God — Isaiah''s vision of the seraphim crying "Holy, holy, holy" captures something essential about who He is. Study what it means for God to be absolutely pure, set apart, and morally perfect, and how His holiness shapes everything: our worship, our ethics, our understanding of sin, and our awe before Him.',
   'Foundations of Faith', ARRAY['holiness', 'god', 'attributes', 'worship'], 351, 50),

  ('abb00000-e29b-41d4-a716-446655440002', 'God Is Love and God Is Just',
   'These two attributes are often set against each other, but Scripture holds them together perfectly. God''s love is not sentimental tolerance — it is holy, costly love that does not overlook sin. His justice is not cold punishment — it is righteous love that demands wrong be made right. The cross is where both meet: God''s justice satisfied, God''s love poured out.',
   'Foundations of Faith', ARRAY['love', 'justice', 'atonement', 'god'], 352, 50),

  ('abb00000-e29b-41d4-a716-446655440003', 'God Is Sovereign and All-Knowing',
   'God''s sovereignty — His absolute rule over all creation — is one of the most comforting truths in Scripture for the believer. Study what it means for God to be all-knowing (omniscient) and all-powerful (omnipotent), how His sovereignty relates to human free will, and why trusting His governance of all things is the foundation of genuine peace.',
   'Foundations of Faith', ARRAY['sovereignty', 'omniscience', 'god', 'providence'], 353, 50),

  ('abb00000-e29b-41d4-a716-446655440004', 'God Is Eternal and Unchanging',
   'God exists outside of time, has no beginning and no end, and His character never changes — He is the same yesterday, today, and forever. Study the attributes of God''s eternity (eternal) and unchangeableness (immutability) and see why these truths matter deeply: His promises will never fail, His love will never diminish, and His purposes will always stand.',
   'Foundations of Faith', ARRAY['eternal', 'immutability', 'god', 'faithfulness'], 354, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- RRR: Law, Grace, and the Covenants new topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('abc00000-e29b-41d4-a716-446655440001', 'The Purpose of the Law',
   'God gave the Law not to save Israel but to reveal His character, expose sin, and point His people to their need for a Savior. Study the three uses of the Law in Scripture — to reveal God''s holiness, to restrain evil in society, and to guide the redeemed — and understand why Christians are not saved by the Law but are transformed by grace to fulfill its spirit.',
   'Foundations of Faith', ARRAY['law', 'torah', 'gospel', 'grace'], 361, 50),

  ('abc00000-e29b-41d4-a716-446655440002', 'The Covenants of God',
   'God''s relationship with humanity is structured through covenants — formal commitments of grace. Study the major biblical covenants: the covenants with Noah, Abraham, Moses, David, and the New Covenant in Christ. See how each covenant advances God''s redemptive plan and how they all find their fulfillment in Jesus, the mediator of a better covenant.',
   'Foundations of Faith', ARRAY['covenant', 'redemption', 'old testament', 'promise'], 362, 50),

  ('abc00000-e29b-41d4-a716-446655440003', 'The New Covenant in Christ',
   'Jeremiah prophesied a new covenant where God''s law would be written on hearts, not stone tablets — and Jesus inaugurated it at the Last Supper with His blood. Study what the New Covenant means: complete forgiveness, the indwelling Spirit, direct access to God, and a transformed heart. The New Covenant is history''s greatest upgrade — from shadow to substance.',
   'Foundations of Faith', ARRAY['new covenant', 'jesus', 'holy spirit', 'grace'], 363, 50),

  ('abc00000-e29b-41d4-a716-446655440004', 'Not Under Law But Under Grace',
   'Romans 6:14 declares that believers are not under law but under grace — a liberating truth that must be carefully understood. Study what Paul means, how grace does not lead to lawlessness but to transformed obedience, and why believers fulfill the law''s spirit through the love that the Spirit pours into our hearts. Grace is the power for holy living, not license for sin.',
   'Foundations of Faith', ARRAY['grace', 'law', 'romans', 'freedom'], 364, 50)
ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- SSS: Sin, Repentance, and Grace new topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('abd00000-e29b-41d4-a716-446655440001', 'The Nature and Wages of Sin',
   'Sin is not merely rule-breaking — it is the fundamental rebellion of the creature against the Creator, a rejection of God''s rightful authority and love. Study the biblical definition of sin, original sin and its effects on all humanity, and what Scripture means when it says the wages of sin is death. This knowledge is not meant to crush but to drive us to Christ.',
   'Foundations of Faith', ARRAY['sin', 'original sin', 'depravity', 'law'], 371, 50),

  ('abd00000-e29b-41d4-a716-446655440002', 'True Repentance vs. Mere Regret',
   '2 Corinthians 7:10 distinguishes godly sorrow that leads to repentance from worldly sorrow that leads to death. True repentance is not just feeling bad — it is a turning away from sin and toward God. Study the marks of genuine repentance, how it differs from regret, guilt management, or behavior modification, and why it is not a one-time event but the ongoing posture of the believer.',
   'Christian Living', ARRAY['repentance', 'confession', 'godly sorrow', 'change'], 372, 50)
ON CONFLICT (id) DO NOTHING;


-- =====================================================
-- PART 2: NEW LEARNING PATHS
-- =====================================================

-- ----------------------------
-- FOUNDATIONS
-- ----------------------------

-- Path 11: Understanding the Bible
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000011',
  'understanding-the-bible',
  'Understanding the Bible',
  'Learn how the Bible was written, preserved, and organized — and develop the skills to read it with confidence. Trace the grand story of Scripture from Genesis to Revelation and discover how every part points to Jesus Christ.',
  'menu_book', '#2563EB', 21, 'beginner', 'seeker', 'standard', true, 11, 'Foundations'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000011', '111e8400-e29b-41d4-a716-446655440004', 0, false),  -- Why Read the Bible?
  ('aaa00000-0000-0000-0000-000000000011', 'bbb00000-e29b-41d4-a716-446655440001', 1, false),  -- How We Got the Bible
  ('aaa00000-0000-0000-0000-000000000011', '666e8400-e29b-41d4-a716-446655440003', 2, true),   -- Is the Bible Reliable? (Milestone)
  ('aaa00000-0000-0000-0000-000000000011', 'bbb00000-e29b-41d4-a716-446655440002', 3, false),  -- Understanding Biblical Genres
  ('aaa00000-0000-0000-0000-000000000011', 'bbb00000-e29b-41d4-a716-446655440003', 4, false),  -- The Old Testament Story
  ('aaa00000-0000-0000-0000-000000000011', 'bbb00000-e29b-41d4-a716-446655440004', 5, false),  -- The New Testament Story
  ('aaa00000-0000-0000-0000-000000000011', '555e8400-e29b-41d4-a716-446655440006', 6, true),   -- How to Study the Bible (Milestone)
  ('aaa00000-0000-0000-0000-000000000011', '555e8400-e29b-41d4-a716-446655440004', 7, false)   -- Meditation on God's Word
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000011', 'hi', 'बाइबल को समझना', 'जानें कि बाइबल कैसे लिखी गई, संरक्षित की गई और व्यवस्थित की गई — और इसे आत्मविश्वास के साथ पढ़ने के कौशल विकसित करें।'),
  ('aaa00000-0000-0000-0000-000000000011', 'ml', 'ബൈബിൾ മനസ്സിലാക്കുക', 'ബൈബിൾ എങ്ങനെ എഴുതപ്പെട്ടു, സംരക്ഷിക്കപ്പെട്ടു, ക്രമീകരിക്കപ്പെട്ടു എന്ന് പഠിക്കുക — ആത്മവിശ്വാസത്തോടെ അത് വായിക്കാനുള്ള കഴിവ് വികസിപ്പിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- Path 12: Baptism and the Lord's Supper
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000012',
  'baptism-and-lords-supper',
  'Baptism & the Lord''s Supper',
  'Understand the two ordinances Jesus commanded His church to practice. Explore the meaning of baptism and communion, why they matter, and how they connect you to Christ and His body.',
  'water_drop', '#0EA5E9', 14, 'beginner', 'follower', 'standard', false, 12, 'Foundations'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000012', 'ccc00000-e29b-41d4-a716-446655440001', 0, false),  -- What Is Baptism?
  ('aaa00000-0000-0000-0000-000000000012', 'ccc00000-e29b-41d4-a716-446655440002', 1, false),  -- Why Be Baptized?
  ('aaa00000-0000-0000-0000-000000000012', '333e8400-e29b-41d4-a716-446655440006', 2, true),   -- Baptism and Communion (Milestone)
  ('aaa00000-0000-0000-0000-000000000012', 'ccc00000-e29b-41d4-a716-446655440003', 3, false),  -- The Lord's Supper
  ('aaa00000-0000-0000-0000-000000000012', 'ccc00000-e29b-41d4-a716-446655440004', 4, false),  -- Participating Worthily
  ('aaa00000-0000-0000-0000-000000000012', 'ccc00000-e29b-41d4-a716-446655440005', 5, true)    -- Baptism, Supper & Church Membership (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000012', 'hi', 'बपतिस्मा और प्रभु भोज', 'यीशु ने अपनी कलीसिया को जो दो अनुष्ठान करने की आज्ञा दी उन्हें समझें।'),
  ('aaa00000-0000-0000-0000-000000000012', 'ml', 'സ്നാനവും കർത്താവിന്റെ അത്താഴവും', 'യേശു തന്റെ സഭയ്ക്ക് കൽപ്പിച്ച രണ്ട് ആചാരങ്ങൾ മനസ്സിലാക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- Path 13: Who Is the Holy Spirit?
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000013',
  'who-is-the-holy-spirit',
  'Who Is the Holy Spirit?',
  'Move beyond vague ideas about the Spirit and discover who He truly is — the third person of the Trinity who convicts, regenerates, fills, and transforms believers. Learn what it means to walk in the Spirit daily.',
  'air', '#7C3AED', 14, 'beginner', 'follower', 'standard', false, 13, 'Foundations'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000013', '111e8400-e29b-41d4-a716-446655440006', 0, false),  -- The Role of the Holy Spirit
  ('aaa00000-0000-0000-0000-000000000013', 'ddd00000-e29b-41d4-a716-446655440001', 1, false),  -- Holy Spirit in the OT
  ('aaa00000-0000-0000-0000-000000000013', 'ddd00000-e29b-41d4-a716-446655440002', 2, true),   -- Holy Spirit and Salvation (Milestone)
  ('aaa00000-0000-0000-0000-000000000013', '333e8400-e29b-41d4-a716-446655440005', 3, false),  -- Spiritual Gifts
  ('aaa00000-0000-0000-0000-000000000013', 'ddd00000-e29b-41d4-a716-446655440003', 4, false),  -- Fruit of the Spirit
  ('aaa00000-0000-0000-0000-000000000013', 'ddd00000-e29b-41d4-a716-446655440004', 5, true),   -- Being Filled with the Spirit (Milestone)
  ('aaa00000-0000-0000-0000-000000000013', '222e8400-e29b-41d4-a716-446655440006', 6, false)   -- Living a Holy Life
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000013', 'hi', 'पवित्र आत्मा कौन है?', 'पवित्र आत्मा के बारे में अस्पष्ट विचारों से आगे बढ़ें और जानें कि वह वास्तव में कौन है।'),
  ('aaa00000-0000-0000-0000-000000000013', 'ml', 'പരിശുദ്ധാത്മാവ് ആരാണ്?', 'ആത്മാവിനെക്കുറിച്ചുള്ള അവ്യക്തമായ ആശയങ്ങൾക്കപ്പുറം പോയി അവൻ യഥാർത്ഥത്തിൽ ആരാണെന്ന് കണ്ടെത്തുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- ----------------------------
-- GROWTH
-- ----------------------------

-- Path 14: The Theology of Suffering
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000014',
  'theology-of-suffering',
  'The Theology of Suffering',
  'Wrestle honestly with one of life''s hardest questions: why does a good God allow suffering? Journey through Job, the Psalms, the cross, and Romans 8 to find not easy answers but deep, sustaining hope rooted in the character of God.',
  'healing', '#B45309', 21, 'intermediate', 'disciple', 'deep', false, 14, 'Growth'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000014', 'AAA00000-e29b-41d4-a716-446655440002', 0, false),  -- Why Evil and Suffering?
  ('aaa00000-0000-0000-0000-000000000014', 'eee00000-e29b-41d4-a716-446655440001', 1, false),  -- Suffering in the Psalms
  ('aaa00000-0000-0000-0000-000000000014', 'eee00000-e29b-41d4-a716-446655440002', 2, true),   -- Job (Milestone)
  ('aaa00000-0000-0000-0000-000000000014', 'eee00000-e29b-41d4-a716-446655440003', 3, false),  -- The Cross and Suffering
  ('aaa00000-0000-0000-0000-000000000014', '222e8400-e29b-41d4-a716-446655440008', 4, false),  -- Dealing with Doubt and Fear
  ('aaa00000-0000-0000-0000-000000000014', '666e8400-e29b-41d4-a716-446655440005', 5, false),  -- Standing Firm
  ('aaa00000-0000-0000-0000-000000000014', 'eee00000-e29b-41d4-a716-446655440004', 6, true)    -- Hope in Suffering (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000014', 'hi', 'दुख का धर्मशास्त्र', 'जीवन के सबसे कठिन प्रश्न से ईमानदारी से जूझें: एक अच्छा परमेश्वर दुख क्यों अनुमति देता है?'),
  ('aaa00000-0000-0000-0000-000000000014', 'ml', 'കഷ്ടത്തിന്റെ ദൈവശാസ്ത്രം', 'ജീവിതത്തിലെ ഏറ്റവും കഠിനമായ ചോദ്യവുമായി സത്യസന്ധമായി ഗുസ്തിപിടിക്കുക: ഒരു നല്ല ദൈവം കഷ്ടത അനുവദിക്കുന്നത് എന്തുകൊണ്ട്?')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- Path 15: Money, Generosity, and the Gospel
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000015',
  'money-generosity-gospel',
  'Money, Generosity & the Gospel',
  'Jesus spoke about money more than almost any other topic — because how we handle wealth reveals the state of our heart. Develop a biblical theology of money, contentment, stewardship, and radical generosity rooted in the gospel.',
  'volunteer_activism', '#059669', 18, 'intermediate', 'follower', 'standard', false, 15, 'Growth'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000015', 'fff00000-e29b-41d4-a716-446655440001', 0, false),  -- What Does the Bible Say About Money?
  ('aaa00000-0000-0000-0000-000000000015', 'fff00000-e29b-41d4-a716-446655440002', 1, false),  -- Contentment vs. Greed
  ('aaa00000-0000-0000-0000-000000000015', 'fff00000-e29b-41d4-a716-446655440003', 2, true),   -- Biblical Stewardship (Milestone)
  ('aaa00000-0000-0000-0000-000000000015', 'fff00000-e29b-41d4-a716-446655440004', 3, false),  -- Tithing and Giving
  ('aaa00000-0000-0000-0000-000000000015', '222e8400-e29b-41d4-a716-446655440005', 4, false),  -- Generosity
  ('aaa00000-0000-0000-0000-000000000015', 'fff00000-e29b-41d4-a716-446655440005', 5, false),  -- Work, Earning, and Provision
  ('aaa00000-0000-0000-0000-000000000015', 'fff00000-e29b-41d4-a716-446655440006', 6, true)    -- Eternal Investments (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000015', 'hi', 'पैसा, उदारता और सुसमाचार', 'यीशु ने लगभग किसी भी अन्य विषय की तुलना में धन के बारे में अधिक बात की — क्योंकि हम संपत्ति को कैसे संभालते हैं यह हमारे दिल की स्थिति को प्रकट करता है।'),
  ('aaa00000-0000-0000-0000-000000000015', 'ml', 'പണം, ഔദാര്യം, സുവിശേഷം', 'യേശു മറ്റേതൊരു വിഷയത്തെക്കാളും കൂടുതൽ പണത്തെക്കുറിച്ച് സംസാരിച്ചു — കാരണം നാം സ്വത്ത് കൈകാര്യം ചെയ്യുന്ന രീതി നമ്മുടെ ഹൃദയത്തിന്റെ അവസ്ഥ വെളിപ്പെടുത്തുന്നു.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- Path 16: Spiritual Warfare
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000016',
  'spiritual-warfare',
  'Spiritual Warfare',
  'The Christian life is not a playground but a battleground. Learn who your enemy is, how he operates, and how to stand firm using the full armor of God. Live from the victory Christ has already won at the cross.',
  'shield', '#DC2626', 18, 'intermediate', 'disciple', 'deep', false, 16, 'Growth'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000016', '222e8400-e29b-41d4-a716-446655440007', 0, false),  -- Spiritual Warfare
  ('aaa00000-0000-0000-0000-000000000016', 'ab100000-e29b-41d4-a716-446655440001', 1, false),  -- Who Is Satan?
  ('aaa00000-0000-0000-0000-000000000016', '222e8400-e29b-41d4-a716-446655440002', 2, false),  -- Overcoming Temptation
  ('aaa00000-0000-0000-0000-000000000016', 'ab100000-e29b-41d4-a716-446655440002', 3, true),   -- Armor of God (Milestone)
  ('aaa00000-0000-0000-0000-000000000016', '555e8400-e29b-41d4-a716-446655440002', 4, false),  -- Fasting and Prayer
  ('aaa00000-0000-0000-0000-000000000016', '666e8400-e29b-41d4-a716-446655440005', 5, false),  -- Standing Firm
  ('aaa00000-0000-0000-0000-000000000016', 'ab100000-e29b-41d4-a716-446655440003', 6, true)    -- Victory in Christ (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000016', 'hi', 'आत्मिक युद्ध', 'मसीही जीवन खेल का मैदान नहीं बल्कि युद्ध का मैदान है। जानें आपका शत्रु कौन है और परमेश्वर के सारे हथियार पहनकर दृढ़ कैसे रहें।'),
  ('aaa00000-0000-0000-0000-000000000016', 'ml', 'ആത്മീയ യുദ്ധം', 'ക്രിസ്തീയ ജീവിതം ഒരു കളിക്കളമല്ല, ഒരു യുദ്ധക്കളമാണ്. നിങ്ങളുടെ ശത്രു ആരാണെന്നും ദൈവത്തിന്റെ മുഴുവൻ ആയുധവർഗ്ഗം ഉപയോഗിച്ച് ഉറച്ചുനിൽക്കുന്നതെങ്ങനെയെന്നും പഠിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- ----------------------------
-- SERVICE & MISSION
-- ----------------------------

-- Path 17: The Local Church
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000017',
  'the-local-church',
  'The Local Church',
  'Discover why the local church is not optional for the Christian life but central to God''s redemptive plan. Understand its purpose, leadership, ordinances, and how belonging and contributing to a local church is a mark of mature discipleship.',
  'church', '#7C3AED', 21, 'beginner', 'follower', 'standard', false, 17, 'Service & Mission'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000017', '333e8400-e29b-41d4-a716-446655440001', 0, false),  -- What is the Church?
  ('aaa00000-0000-0000-0000-000000000017', '333e8400-e29b-41d4-a716-446655440002', 1, false),  -- Why Fellowship Matters
  ('aaa00000-0000-0000-0000-000000000017', 'ab200000-e29b-41d4-a716-446655440001', 2, false),  -- Church Leadership
  ('aaa00000-0000-0000-0000-000000000017', '333e8400-e29b-41d4-a716-446655440005', 3, true),   -- Spiritual Gifts (Milestone)
  ('aaa00000-0000-0000-0000-000000000017', '333e8400-e29b-41d4-a716-446655440003', 4, false),  -- Serving in the Church
  ('aaa00000-0000-0000-0000-000000000017', '333e8400-e29b-41d4-a716-446655440004', 5, false),  -- Unity
  ('aaa00000-0000-0000-0000-000000000017', '333e8400-e29b-41d4-a716-446655440006', 6, false),  -- Baptism and Communion
  ('aaa00000-0000-0000-0000-000000000017', 'ab200000-e29b-41d4-a716-446655440002', 7, true)    -- Church Discipline (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000017', 'hi', 'स्थानीय कलीसिया', 'जानें क्यों स्थानीय कलीसिया मसीही जीवन के लिए वैकल्पिक नहीं बल्कि परमेश्वर की मुक्ति योजना के केंद्र में है।'),
  ('aaa00000-0000-0000-0000-000000000017', 'ml', 'പ്രാദേശിക സഭ', 'ക്രിസ്തീയ ജീവിതത്തിന് പ്രാദേശിക സഭ ഐച്ഛികമല്ല, ദൈവത്തിന്റെ രക്ഷാ പദ്ധതിയുടെ കേന്ദ്രമാണ് എന്ന് കണ്ടെത്തുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- Path 18: Evangelism in Everyday Life
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000018',
  'evangelism-everyday-life',
  'Evangelism in Everyday Life',
  'Sharing the gospel is not just for pastors and missionaries — it is the calling of every believer. Overcome fear, learn to share your story and the gospel clearly, and discover how ordinary conversations can become eternal conversations.',
  'record_voice_over', '#EA580C', 14, 'beginner', 'follower', 'standard', true, 18, 'Service & Mission'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000018', '111e8400-e29b-41d4-a716-446655440002', 0, false),  -- What is the Gospel?
  ('aaa00000-0000-0000-0000-000000000018', '444e8400-e29b-41d4-a716-446655440004', 1, false),  -- The Great Commission
  ('aaa00000-0000-0000-0000-000000000018', 'ab300000-e29b-41d4-a716-446655440001', 2, false),  -- Overcoming Fear
  ('aaa00000-0000-0000-0000-000000000018', '888e8400-e29b-41d4-a716-446655440001', 3, false),  -- Being the Light
  ('aaa00000-0000-0000-0000-000000000018', '888e8400-e29b-41d4-a716-446655440002', 4, true),   -- Sharing Your Testimony (Milestone)
  ('aaa00000-0000-0000-0000-000000000018', '888e8400-e29b-41d4-a716-446655440004', 5, false),  -- Evangelism Made Simple
  ('aaa00000-0000-0000-0000-000000000018', 'ab300000-e29b-41d4-a716-446655440002', 6, false),  -- Answering Common Objections
  ('aaa00000-0000-0000-0000-000000000018', 'ab300000-e29b-41d4-a716-446655440003', 7, true)    -- Role of Holy Spirit in Evangelism (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000018', 'hi', 'रोजमर्रा की जिंदगी में प्रचार', 'सुसमाचार साझा करना केवल पादरियों और मिशनरियों के लिए नहीं है — यह हर विश्वासी की बुलाहट है।'),
  ('aaa00000-0000-0000-0000-000000000018', 'ml', 'ദൈനംദിന ജീവിതത്തിൽ സുവിശേഷ പ്രഘോഷണം', 'സുവിശേഷം പങ്കുവെക്കുക എന്നത് പാസ്റ്റർമാർക്കും മിഷണറിമാർക്കും മാത്രമല്ല — ഇത് ഓരോ വിശ്വാസിയുടെയും വിളിയാണ്.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- Path 19: Work and Vocation as Worship
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000019',
  'work-and-vocation-as-worship',
  'Work & Vocation as Worship',
  'Your Monday matters as much as your Sunday. Explore the biblical theology of work — from creation to the new creation — and learn how your daily vocation is a God-given calling to serve others, glorify God, and advance His kingdom.',
  'work', '#0D9488', 18, 'intermediate', 'follower', 'standard', false, 19, 'Service & Mission'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000019', 'ab400000-e29b-41d4-a716-446655440001', 0, false),  -- Work Before and After the Fall
  ('aaa00000-0000-0000-0000-000000000019', 'ab400000-e29b-41d4-a716-446655440002', 1, false),  -- Your Calling: More Than a Job
  ('aaa00000-0000-0000-0000-000000000019', 'ab400000-e29b-41d4-a716-446655440003', 2, true),   -- Excellence and Integrity (Milestone)
  ('aaa00000-0000-0000-0000-000000000019', '888e8400-e29b-41d4-a716-446655440006', 3, false),  -- Workplace as Mission
  ('aaa00000-0000-0000-0000-000000000019', 'ab400000-e29b-41d4-a716-446655440004', 4, false),  -- Being a Witness at Work
  ('aaa00000-0000-0000-0000-000000000019', 'fff00000-e29b-41d4-a716-446655440003', 5, false),  -- Biblical Stewardship
  ('aaa00000-0000-0000-0000-000000000019', 'ab400000-e29b-41d4-a716-446655440005', 6, true)    -- Rest, Sabbath, and Rhythm (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000019', 'hi', 'कार्य और व्यवसाय आराधना के रूप में', 'आपका सोमवार रविवार जितना ही महत्वपूर्ण है। बाइबल का कार्य का धर्मशास्त्र खोजें।'),
  ('aaa00000-0000-0000-0000-000000000019', 'ml', 'ആരാധനയായി ജോലിയും വൃത്തിയും', 'നിങ്ങളുടെ തിങ്കളാഴ്ച ഞായറാഴ്ചയോളം പ്രധാനമാണ്. ജോലിയുടെ ബൈബിൾ ദൈവശാസ്ത്രം കണ്ടെത്തുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- ----------------------------
-- APOLOGETICS
-- ----------------------------

-- Path 20: Historical Reliability of the Bible
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000020',
  'historical-reliability-bible',
  'Historical Reliability of the Bible',
  'Build a well-reasoned confidence in Scripture''s trustworthiness. Examine manuscript evidence, archaeology, fulfilled prophecy, and the historical evidence for the resurrection — and discover why the Bible stands uniquely as the most reliable document from the ancient world.',
  'history_edu', '#1D4ED8', 21, 'intermediate', 'disciple', 'deep', false, 20, 'Apologetics'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000020', '666e8400-e29b-41d4-a716-446655440003', 0, false),  -- Is the Bible Reliable?
  ('aaa00000-0000-0000-0000-000000000020', 'ab500000-e29b-41d4-a716-446655440001', 1, false),  -- Manuscript Evidence
  ('aaa00000-0000-0000-0000-000000000020', 'ab500000-e29b-41d4-a716-446655440002', 2, true),   -- Archaeology (Milestone)
  ('aaa00000-0000-0000-0000-000000000020', 'ab500000-e29b-41d4-a716-446655440003', 3, false),  -- OT Prophecies Fulfilled in Christ
  ('aaa00000-0000-0000-0000-000000000020', 'ab500000-e29b-41d4-a716-446655440004', 4, true),   -- Resurrection as History (Milestone)
  ('aaa00000-0000-0000-0000-000000000020', 'ab500000-e29b-41d4-a716-446655440005', 5, false),  -- How the Canon Was Formed
  ('aaa00000-0000-0000-0000-000000000020', 'AAA00000-e29b-41d4-a716-446655440001', 6, false)   -- Does God Exist?
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000020', 'hi', 'बाइबल की ऐतिहासिक विश्वसनीयता', 'शास्त्र की विश्वसनीयता में एक तर्कसंगत विश्वास बनाएं। पांडुलिपि साक्ष्य, पुरातत्व, भविष्यद्वाणी और पुनरुत्थान की जांच करें।'),
  ('aaa00000-0000-0000-0000-000000000020', 'ml', 'ബൈബിളിന്റെ ചരിത്രപരമായ വിശ്വാസ്യത', 'തിരുവെഴുത്തിന്റെ വിശ്വസ്തതയിൽ ന്യായബദ്ധമായ ആത്മവിശ്വാസം വളർത്തുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- Path 21: Responding to Cults and False Teaching
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000021',
  'responding-to-cults',
  'Responding to Cults & False Teaching',
  'Theological discernment is not optional — it protects you and the people you love. Learn to recognize false teaching and cultic patterns, understand key Christian doctrines that cults distort, and engage with love and biblical truth.',
  'gpp_bad', '#9333EA', 21, 'advanced', 'disciple', 'deep', false, 21, 'Apologetics'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000021', 'ab600000-e29b-41d4-a716-446655440001', 0, false),  -- What Makes Teaching False?
  ('aaa00000-0000-0000-0000-000000000021', 'ab600000-e29b-41d4-a716-446655440002', 1, false),  -- Recognizing Cultic Patterns
  ('aaa00000-0000-0000-0000-000000000021', '666e8400-e29b-41d4-a716-446655440001', 2, false),  -- Why We Believe in One God
  ('aaa00000-0000-0000-0000-000000000021', '666e8400-e29b-41d4-a716-446655440002', 3, true),   -- The Uniqueness of Jesus (Milestone)
  ('aaa00000-0000-0000-0000-000000000021', 'AAA00000-e29b-41d4-a716-446655440005', 4, false),  -- What is Trinity?
  ('aaa00000-0000-0000-0000-000000000021', 'ab600000-e29b-41d4-a716-446655440003', 5, false),  -- Grace vs. Works-Based Religion
  ('aaa00000-0000-0000-0000-000000000021', '666e8400-e29b-41d4-a716-446655440004', 6, true)    -- Responding to Common Questions (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000021', 'hi', 'पंथों और झूठी शिक्षाओं का जवाब देना', 'धार्मिक विवेक वैकल्पिक नहीं है। झूठी शिक्षा और पंथ के पैटर्न को पहचानना सीखें।'),
  ('aaa00000-0000-0000-0000-000000000021', 'ml', 'കൾട്ടുകളോടും തെറ്റായ ഉപദേശങ്ങളോടും പ്രതികരിക്കൽ', 'ദൈവശാസ്ത്രപരമായ വിവേചനം ഐച്ഛികമല്ല — അത് നിങ്ങളെയും നിങ്ങൾ സ്നേഹിക്കുന്നവരെയും സംരക്ഷിക്കുന്നു.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- Path 22: Christianity and Culture
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000022',
  'christianity-and-culture',
  'Christianity & Culture',
  'Christians are called to be in the world but not of it. Develop a thoughtful, gospel-centered framework for engaging contemporary culture — including media, sexuality, justice, and pluralism — with both conviction and compassion.',
  'language', '#0F766E', 21, 'advanced', 'leader', 'deep', false, 22, 'Apologetics'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000022', 'ab700000-e29b-41d4-a716-446655440001', 0, false),  -- How Christians Engage Culture
  ('aaa00000-0000-0000-0000-000000000022', 'ab700000-e29b-41d4-a716-446655440002', 1, false),  -- Media and Discernment
  ('aaa00000-0000-0000-0000-000000000022', '666e8400-e29b-41d4-a716-446655440006', 2, true),   -- Faith and Science (Milestone)
  ('aaa00000-0000-0000-0000-000000000022', 'ab700000-e29b-41d4-a716-446655440003', 3, false),  -- Sexuality and Biblical Ethics
  ('aaa00000-0000-0000-0000-000000000022', 'ab700000-e29b-41d4-a716-446655440004', 4, false),  -- Justice, Mercy, and the Gospel
  ('aaa00000-0000-0000-0000-000000000022', '666e8400-e29b-41d4-a716-446655440004', 5, false),  -- Responding to Common Questions
  ('aaa00000-0000-0000-0000-000000000022', 'ab700000-e29b-41d4-a716-446655440005', 6, true)    -- Speaking Truth in Love (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000022', 'hi', 'ईसाई धर्म और संस्कृति', 'मसीहियों को दुनिया में रहने के लिए बुलाया गया है लेकिन इसके अनुसार नहीं। समकालीन संस्कृति के साथ जुड़ने के लिए एक विचारशील ढांचा विकसित करें।'),
  ('aaa00000-0000-0000-0000-000000000022', 'ml', 'ക്രിസ്തുമതവും സംസ്കാരവും', 'ക്രിസ്ത്യാനികൾ ലോകത്തിൽ ആയിരിക്കാൻ വിളിക്കപ്പെട്ടിരിക്കുന്നു, പക്ഷേ അതിന്റേതായ ഭാഗമാകാൻ അല്ല.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- ----------------------------
-- LIFE & RELATIONSHIPS
-- ----------------------------

-- Path 23: Singleness, Dating, and Marriage
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000023',
  'singleness-dating-marriage',
  'Singleness, Dating & Marriage',
  'Whether single, dating, or married, God''s design for these seasons of life is beautiful and purposeful. Study what Scripture teaches about the gift of singleness, purity, biblical courtship, and the covenant of marriage as a picture of Christ and the church.',
  'favorite', '#DB2777', 25, 'beginner', 'follower', 'standard', false, 23, 'Life & Relationships'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000023', '777e8400-e29b-41d4-a716-446655440006', 0, false),  -- Singleness and Contentment
  ('aaa00000-0000-0000-0000-000000000023', 'ab800000-e29b-41d4-a716-446655440001', 1, false),  -- God's Design for Marriage
  ('aaa00000-0000-0000-0000-000000000023', 'ab800000-e29b-41d4-a716-446655440002', 2, true),   -- Purity Before Marriage (Milestone)
  ('aaa00000-0000-0000-0000-000000000023', 'ab800000-e29b-41d4-a716-446655440003', 3, false),  -- Choosing a Spouse Wisely
  ('aaa00000-0000-0000-0000-000000000023', '777e8400-e29b-41d4-a716-446655440001', 4, false),  -- Marriage and Faith
  ('aaa00000-0000-0000-0000-000000000023', '777e8400-e29b-41d4-a716-446655440005', 5, false),  -- Resolving Conflicts
  ('aaa00000-0000-0000-0000-000000000023', 'ab800000-e29b-41d4-a716-446655440004', 6, true)    -- When Marriage Is Hard (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000023', 'hi', 'अविवाहित जीवन, डेटिंग और विवाह', 'चाहे अविवाहित हों, डेटिंग कर रहे हों या विवाहित — परमेश्वर की इन जीवन के मौसमों के लिए योजना सुंदर और उद्देश्यपूर्ण है।'),
  ('aaa00000-0000-0000-0000-000000000023', 'ml', 'ഒറ്റയ്ക്ക്, ഡേറ്റിംഗ്, വിവാഹം', 'ഒറ്റയ്ക്കോ, ഡേറ്റ് ചെയ്യുന്നവരോ, വിവാഹിതരോ ആകട്ടെ — ഈ ജീവിത ഋതുക്കൾക്കായി ദൈവത്തിന്റെ രൂപകൽപ്പന സുന്ദരവും ഉദ്ദേശ്യപൂർണ്ണവുമാണ്.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- Path 24: Mental Health, Emotions, and the Gospel
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000024',
  'mental-health-emotions-gospel',
  'Mental Health, Emotions & the Gospel',
  'The gospel speaks to the whole person — body, mind, and soul. Learn what Scripture says about emotions, anxiety, depression, grief, and the journey toward wholeness. Find that God meets the struggling and brokenhearted with grace, not shame.',
  'psychology', '#7C3AED', 21, 'intermediate', 'follower', 'standard', false, 24, 'Life & Relationships'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000024', 'ab900000-e29b-41d4-a716-446655440001', 0, false),  -- Emotions in the Bible
  ('aaa00000-0000-0000-0000-000000000024', 'ab900000-e29b-41d4-a716-446655440002', 1, false),  -- Anxiety and Peace of God
  ('aaa00000-0000-0000-0000-000000000024', '222e8400-e29b-41d4-a716-446655440008', 2, true),   -- Dealing with Doubt and Fear (Milestone)
  ('aaa00000-0000-0000-0000-000000000024', 'ab900000-e29b-41d4-a716-446655440003', 3, false),  -- Depression and the Soul
  ('aaa00000-0000-0000-0000-000000000024', 'ab900000-e29b-41d4-a716-446655440004', 4, false),  -- Grief, Lament, and Healing
  ('aaa00000-0000-0000-0000-000000000024', '222e8400-e29b-41d4-a716-446655440003', 5, false),  -- Forgiveness
  ('aaa00000-0000-0000-0000-000000000024', 'ab900000-e29b-41d4-a716-446655440005', 6, true)    -- The Hope That Does Not Disappoint (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000024', 'hi', 'मानसिक स्वास्थ्य, भावनाएँ और सुसमाचार', 'सुसमाचार पूरे व्यक्ति से बोलता है — शरीर, मन और आत्मा। पवित्रशास्त्र भावनाओं, चिंता, अवसाद और पूर्णता की यात्रा के बारे में क्या कहता है सीखें।'),
  ('aaa00000-0000-0000-0000-000000000024', 'ml', 'മാനസിക ആരോഗ്യം, വികാരങ്ങൾ, സുവിശേഷം', 'സുവിശേഷം മുഴുവൻ വ്യക്തിയോടും സംസാരിക്കുന്നു — ശരീരം, മനസ്സ്, ആത്മാവ്. വികാരങ്ങൾ, ഉത്കണ്ഠ, വിഷാദം, സൗഖ്യത്തിലേക്കുള്ള യാത്ര എന്നിവയെക്കുറിച്ച് വേദഗ്രന്ഥം പഠിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- Path 25: Friendship and Christian Community
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000025',
  'friendship-and-christian-community',
  'Friendship & Christian Community',
  'God did not design the Christian life to be lived alone. Explore the biblical call to deep friendship, mutual accountability, and life-giving community — and discover what it looks like to be the kind of friend and church member Scripture calls you to be.',
  'group', '#0369A1', 14, 'beginner', 'follower', 'standard', false, 25, 'Life & Relationships'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000025', '333e8400-e29b-41d4-a716-446655440002', 0, false),  -- Why Fellowship Matters
  ('aaa00000-0000-0000-0000-000000000025', 'aba00000-e29b-41d4-a716-446655440001', 1, false),  -- Spiritual Friendship in Scripture
  ('aaa00000-0000-0000-0000-000000000025', '777e8400-e29b-41d4-a716-446655440004', 2, false),  -- Healthy Friendships
  ('aaa00000-0000-0000-0000-000000000025', 'aba00000-e29b-41d4-a716-446655440002', 3, true),   -- Accountability (Milestone)
  ('aaa00000-0000-0000-0000-000000000025', '222e8400-e29b-41d4-a716-446655440004', 4, false),  -- Fellowship
  ('aaa00000-0000-0000-0000-000000000025', '333e8400-e29b-41d4-a716-446655440004', 5, false),  -- Unity
  ('aaa00000-0000-0000-0000-000000000025', '777e8400-e29b-41d4-a716-446655440005', 6, true)    -- Resolving Conflicts (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000025', 'hi', 'मित्रता और मसीही समुदाय', 'परमेश्वर ने मसीही जीवन को अकेले जीने के लिए नहीं बनाया। गहरी मित्रता, पारस्परिक जवाबदेही और जीवनदायी समुदाय की बाइबिल की बुलाहट का अन्वेषण करें।'),
  ('aaa00000-0000-0000-0000-000000000025', 'ml', 'സൗഹൃദവും ക്രിസ്തീയ സമൂഹവും', 'ദൈവം ക്രിസ്തീയ ജീവിതം ഒറ്റയ്ക്ക് ജീവിക്കാൻ രൂപകൽപ്പന ചെയ്തിട്ടില്ല. ആഴമേറിയ സൗഹൃദം, പരസ്പര ഉത്തരവാദിത്തം, ജീവൻ നൽകുന്ന കൂട്ടായ്മ എന്നിവയ്ക്കുള്ള ബൈബിൾ വിളി പര്യവേക്ഷണം ചെയ്യുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- ----------------------------
-- THEOLOGY
-- ----------------------------

-- Path 26: The Attributes of God
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000026',
  'attributes-of-god',
  'The Attributes of God',
  'Knowing God rightly is the foundation of all Christian living, worship, and service. Study His holiness, love, justice, sovereignty, omniscience, eternity, and unchangeableness — and be transformed by a deeper knowledge of who He truly is.',
  'auto_awesome', '#6D28D9', 28, 'intermediate', 'disciple', 'deep', true, 26, 'Theology'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000026', '666e8400-e29b-41d4-a716-446655440001', 0, false),  -- Why We Believe in One God
  ('aaa00000-0000-0000-0000-000000000026', 'abb00000-e29b-41d4-a716-446655440001', 1, false),  -- God Is Holy
  ('aaa00000-0000-0000-0000-000000000026', 'abb00000-e29b-41d4-a716-446655440002', 2, true),   -- God Is Love and Just (Milestone)
  ('aaa00000-0000-0000-0000-000000000026', 'abb00000-e29b-41d4-a716-446655440003', 3, false),  -- God Is Sovereign
  ('aaa00000-0000-0000-0000-000000000026', 'abb00000-e29b-41d4-a716-446655440004', 4, false),  -- God Is Eternal
  ('aaa00000-0000-0000-0000-000000000026', 'AAA00000-e29b-41d4-a716-446655440005', 5, false),  -- What is Trinity?
  ('aaa00000-0000-0000-0000-000000000026', '111e8400-e29b-41d4-a716-446655440001', 6, false),  -- Who is Jesus Christ?
  ('aaa00000-0000-0000-0000-000000000026', '111e8400-e29b-41d4-a716-446655440006', 7, true)    -- Role of the Holy Spirit (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000026', 'hi', 'परमेश्वर के गुण', 'परमेश्वर को सही तरह जानना सभी मसीही जीवन, आराधना और सेवा की नींव है। उनकी पवित्रता, प्रेम, न्याय, संप्रभुता और शाश्वतता का अध्ययन करें।'),
  ('aaa00000-0000-0000-0000-000000000026', 'ml', 'ദൈവത്തിന്റെ ഗുണങ്ങൾ', 'ദൈവത്തെ ശരിയായി അറിയുക എന്നത് ക്രിസ്തീയ ജീവിതം, ആരാധന, സേവനം എന്നിവയുടെ അടിത്തറയാണ്. അവന്റെ വിശുദ്ധി, സ്നേഹം, നീതി, പരമാധികാരം, നിത്യത എന്നിവ പഠിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- Path 27: Law, Grace, and the Covenants
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000027',
  'law-grace-and-covenants',
  'Law, Grace & the Covenants',
  'Understand the grand structure of God''s redemptive plan through the covenants — from Abraham to the New Covenant in Christ. See how the law and grace work together rather than against each other, and how every covenant points to Jesus.',
  'gavel', '#0F766E', 28, 'advanced', 'disciple', 'deep', false, 27, 'Theology'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000027', 'abc00000-e29b-41d4-a716-446655440001', 0, false),  -- Purpose of the Law
  ('aaa00000-0000-0000-0000-000000000027', 'abc00000-e29b-41d4-a716-446655440002', 1, false),  -- The Covenants of God
  ('aaa00000-0000-0000-0000-000000000027', '111e8400-e29b-41d4-a716-446655440002', 2, true),   -- What is the Gospel? (Milestone)
  ('aaa00000-0000-0000-0000-000000000027', 'abc00000-e29b-41d4-a716-446655440003', 3, false),  -- The New Covenant in Christ
  ('aaa00000-0000-0000-0000-000000000027', '111e8400-e29b-41d4-a716-446655440008', 4, false),  -- Understanding God's Grace
  ('aaa00000-0000-0000-0000-000000000027', 'abc00000-e29b-41d4-a716-446655440004', 5, false),  -- Not Under Law But Under Grace
  ('aaa00000-0000-0000-0000-000000000027', '111e8400-e29b-41d4-a716-446655440007', 6, true)    -- Your Identity in Christ (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000027', 'hi', 'व्यवस्था, अनुग्रह और वाचाएँ', 'वाचाओं के माध्यम से परमेश्वर की मुक्ति योजना की भव्य संरचना को समझें। देखें कि व्यवस्था और अनुग्रह एक साथ काम करते हैं।'),
  ('aaa00000-0000-0000-0000-000000000027', 'ml', 'നിയമം, കൃപ, ഉടമ്പടികൾ', 'ഉടമ്പടികളിലൂടെ ദൈവത്തിന്റെ രക്ഷാ പദ്ധതിയുടെ ഗ്രാൻഡ് ഘടന മനസ്സിലാക്കുക. നിയമവും കൃപയും ഒരുമിച്ച് പ്രവർത്തിക്കുന്നത് കാണുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- Path 28: Sin, Repentance, and the Grace of God
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000028',
  'sin-repentance-and-grace',
  'Sin, Repentance & the Grace of God',
  'A clear understanding of sin and repentance is not meant to crush us but to drive us into the arms of a gracious God. Study the nature of sin, what true repentance looks like, and how God''s transforming grace exceeds every failure and covers every sin.',
  'restart_alt', '#BE185D', 21, 'beginner', 'seeker', 'standard', false, 28, 'Theology'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000028', 'abd00000-e29b-41d4-a716-446655440001', 0, false),  -- The Nature and Wages of Sin
  ('aaa00000-0000-0000-0000-000000000028', '111e8400-e29b-41d4-a716-446655440002', 1, false),  -- What is the Gospel?
  ('aaa00000-0000-0000-0000-000000000028', 'abd00000-e29b-41d4-a716-446655440002', 2, true),   -- True Repentance (Milestone)
  ('aaa00000-0000-0000-0000-000000000028', '222e8400-e29b-41d4-a716-446655440003', 3, false),  -- Forgiveness
  ('aaa00000-0000-0000-0000-000000000028', '111e8400-e29b-41d4-a716-446655440003', 4, false),  -- Assurance of Salvation
  ('aaa00000-0000-0000-0000-000000000028', '111e8400-e29b-41d4-a716-446655440008', 5, false),  -- Understanding God's Grace
  ('aaa00000-0000-0000-0000-000000000028', '222e8400-e29b-41d4-a716-446655440002', 6, false),  -- Overcoming Temptation
  ('aaa00000-0000-0000-0000-000000000028', '222e8400-e29b-41d4-a716-446655440006', 7, true)    -- Living a Holy Life (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000028', 'hi', 'पाप, पश्चाताप और परमेश्वर का अनुग्रह', 'पाप और पश्चाताप की स्पष्ट समझ हमें कुचलने के लिए नहीं बल्कि एक दयालु परमेश्वर की बाहों में ले जाने के लिए है।'),
  ('aaa00000-0000-0000-0000-000000000028', 'ml', 'പാപം, അനുതാപം, ദൈവകൃപ', 'പാപത്തെയും അനുതാപത്തെയും കുറിച്ചുള്ള വ്യക്തമായ ധാരണ നമ്മെ തകർക്കാനല്ല, ഒരു കൃപാലുവായ ദൈവത്തിന്റെ കൈകളിലേക്ക് നമ്മെ നയിക്കാനാണ്.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- =====================================================
-- PART 3: COMPUTE TOTAL XP FOR ALL NEW PATHS
-- =====================================================

SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000011');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000012');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000013');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000014');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000015');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000016');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000017');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000018');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000019');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000020');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000021');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000022');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000023');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000024');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000025');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000026');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000027');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000028');


-- =====================================================
-- PART 4: VERIFICATION
-- =====================================================

DO $$
DECLARE
  total_paths INTEGER;
  new_paths   INTEGER;
  new_topics  INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_paths FROM learning_paths WHERE is_active = true;
  SELECT COUNT(*) INTO new_paths  FROM learning_paths
    WHERE id::text >= 'aaa00000-0000-0000-0000-000000000011'
      AND id::text <= 'aaa00000-0000-0000-0000-000000000028';
  SELECT COUNT(*) INTO new_topics FROM recommended_topics
    WHERE id::text LIKE 'bbb%' OR id::text LIKE 'ccc%' OR id::text LIKE 'ddd%' OR id::text LIKE 'eee%'
       OR id::text LIKE 'fff%' OR id::text LIKE 'ab1%' OR id::text LIKE 'ab2%' OR id::text LIKE 'ab3%'
       OR id::text LIKE 'ab4%' OR id::text LIKE 'ab5%' OR id::text LIKE 'ab6%' OR id::text LIKE 'ab7%'
       OR id::text LIKE 'ab8%' OR id::text LIKE 'ab9%' OR id::text LIKE 'aba%' OR id::text LIKE 'abb%'
       OR id::text LIKE 'abc%' OR id::text LIKE 'abd%';

  RAISE NOTICE '=== New Learning Paths Migration Summary ===';
  RAISE NOTICE 'Total active learning paths: %', total_paths;
  RAISE NOTICE 'New learning paths added: %', new_paths;
  RAISE NOTICE 'New recommended topics created: %', new_topics;

  IF new_paths = 18 THEN
    RAISE NOTICE '✅ All 18 new learning paths created successfully';
  ELSE
    RAISE WARNING 'Expected 18 new paths, found %', new_paths;
  END IF;
END $$;


-- =====================================================
-- PART 5: BASIC APOLOGETICS PATH (The Big Questions)
-- =====================================================

-- =====================================================
-- PART 1: NEW TOPICS (abe prefix)
-- =====================================================

INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('abe00000-e29b-41d4-a716-446655440001',
   'Did Jesus Actually Exist?',
   'Some skeptics claim Jesus never existed — but this view is rejected by virtually all historians, including secular ones. Study the non-Christian historical sources that confirm Jesus'' existence: the Roman historian Tacitus, the Jewish historian Josephus, and others. The historical Jesus is one of the best-attested figures of the ancient world — the question is not whether He existed, but who He truly is.',
   'Apologetics', ARRAY['jesus', 'history', 'evidence', 'secular sources'], 401, 50),

  ('abe00000-e29b-41d4-a716-446655440002',
   'What Happens When We Die?',
   'Death is the one universal human experience — and every worldview must answer what lies beyond it. Study what the Bible teaches about death, the intermediate state, the resurrection of the body, judgment, heaven, and hell. Contrast the biblical view with secular and religious alternatives, and see why the Christian hope of bodily resurrection is both distinctive and deeply rooted in the gospel.',
   'Apologetics', ARRAY['death', 'afterlife', 'heaven', 'resurrection'], 402, 50),

  ('abe00000-e29b-41d4-a716-446655440003',
   'Can Science Disprove God?',
   'Many assume science and Christianity are at war — but this is a modern myth. Science describes how the universe works; it cannot address whether God exists or why anything exists at all. Study the limits of the scientific method, how the fine-tuning of the universe actually points toward a Creator, and why some of history''s greatest scientists (Galileo, Newton, Faraday, Collins) held deep Christian faith.',
   'Apologetics', ARRAY['science', 'god', 'creation', 'fine-tuning'], 403, 50),

  ('abe00000-e29b-41d4-a716-446655440004',
   'Why Are There So Many Religions?',
   'If Christianity is true, why has God allowed so many competing religions to exist? Study why religious diversity does not disprove Christianity — any more than medical diversity disproves medicine. Explore how world religions differ fundamentally on who God is, what humans need, and how salvation works, and why Jesus'' exclusive claims are not arrogant but truthful and compassionate.',
   'Apologetics', ARRAY['religions', 'pluralism', 'exclusivity', 'truth'], 404, 50)

ON CONFLICT (id) DO NOTHING;


-- =====================================================
-- PART 2: THE BIG QUESTIONS PATH
-- =====================================================

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, disciple_level,
  recommended_mode, is_featured, display_order, category
)
VALUES (
  'aaa00000-0000-0000-0000-000000000029',
  'the-big-questions',
  'The Big Questions',
  'Everyone asks them: Does God exist? Is Jesus real? Can we trust the Bible? What happens when we die? This beginner-friendly path tackles the most common questions about Christianity with honest, evidence-based answers rooted in Scripture and reason.',
  'help_outline',
  '#1D4ED8',
  18,
  'beginner',
  'seeker',
  'standard',
  true,
  29,
  'Apologetics'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000029', 'AAA00000-e29b-41d4-a716-446655440001', 0, false),  -- Does God Exist?
  ('aaa00000-0000-0000-0000-000000000029', 'abe00000-e29b-41d4-a716-446655440003', 1, false),  -- Can Science Disprove God?
  ('aaa00000-0000-0000-0000-000000000029', 'abe00000-e29b-41d4-a716-446655440001', 2, true),   -- Did Jesus Actually Exist? (Milestone)
  ('aaa00000-0000-0000-0000-000000000029', '666e8400-e29b-41d4-a716-446655440002', 3, false),  -- The Uniqueness of Jesus (Is Jesus God?)
  ('aaa00000-0000-0000-0000-000000000029', 'ab500000-e29b-41d4-a716-446655440004', 4, true),   -- The Resurrection as Historical Fact (Milestone)
  ('aaa00000-0000-0000-0000-000000000029', '666e8400-e29b-41d4-a716-446655440003', 5, false),  -- Is the Bible Reliable?
  ('aaa00000-0000-0000-0000-000000000029', 'AAA00000-e29b-41d4-a716-446655440003', 6, false),  -- Is Jesus the Only Way?
  ('aaa00000-0000-0000-0000-000000000029', 'abe00000-e29b-41d4-a716-446655440004', 7, false),  -- Why Are There So Many Religions?
  ('aaa00000-0000-0000-0000-000000000029', 'AAA00000-e29b-41d4-a716-446655440002', 8, false),  -- Why Does God Allow Suffering?
  ('aaa00000-0000-0000-0000-000000000029', 'abe00000-e29b-41d4-a716-446655440002', 9, true)    -- What Happens When We Die? (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000029', 'hi', 'बड़े सवाल',
   'हर कोई इन्हें पूछता है: क्या परमेश्वर है? क्या यीशु वास्तविक थे? क्या बाइबल पर भरोसा किया जा सकता है? मृत्यु के बाद क्या होता है? यह पथ सबसे सामान्य प्रश्नों के ईमानदार, साक्ष्य-आधारित उत्तर देता है।'),
  ('aaa00000-0000-0000-0000-000000000029', 'ml', 'വലിയ ചോദ്യങ്ങൾ',
   'എല്ലാവരും ചോദിക്കുന്നു: ദൈവം ഉണ്ടോ? യേശു യഥാർത്ഥമാണോ? ബൈബിൾ വിശ്വസിക്കാൻ കഴിയുമോ? മരണശേഷം എന്ത് സംഭവിക്കും? ഈ പാത ക്രിസ്തുമതത്തെക്കുറിച്ചുള്ള ഏറ്റവും സാധാരണമായ ചോദ്യങ്ങൾക്ക് സത്യസന്ധവും തെളിവ്-അടിസ്ഥാനത്തിലുള്ളതുമായ ഉത്തരങ്ങൾ നൽകുന്നു.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- =====================================================
-- PART 3: XP COMPUTATION
-- =====================================================

SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000029');


COMMIT;

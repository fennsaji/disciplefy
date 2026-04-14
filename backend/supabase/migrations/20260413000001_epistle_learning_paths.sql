-- =====================================================
-- Migration: 7 Epistle Learning Paths (combined letters)
-- =====================================================
-- Category: Epistles (new)
-- Paths (ordered by display_order 2-10):
--   P33: Romans (16 chapters)                — beginner/seeker      [2]
--   P38: Philippians (4 chapters)            — beginner/seeker      [3]
--   P36: James (5 chapters)                  — beginner/seeker      [4]
--   P35: Ephesians (6 chapters)              — beginner/seeker      [5]
--   P40: Peter's Letters (1-2 Peter, 8 ch)   — intermediate/follower [6]
--   P39: Galatians (6 chapters)              — intermediate/follower [7]
--   P37: John's Letters (1-3 John, 7 ch)     — intermediate/follower [8]
--   P30: Hebrews (13 chapters)               — intermediate/disciple [9]
--   P41: Corinthians (1-2 Cor, 29 ch)        — advanced/disciple    [10]
-- Topics: 6+5+7+4+6+8+29 = 65 new recommended_topics
-- Theological review: Paul the Apostle
-- =====================================================

BEGIN;

-- =====================================================
-- PART 1: RECOMMENDED TOPICS
-- =====================================================

-- -------------------------------------------------------
-- EPH: Ephesians (6 topics, one per chapter)
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('c0100000-e29b-41d4-a716-446655440001', 'Ephesians 1: Blessed in Christ',
   'Read Ephesians 1. Paul opens his letter with an explosion of praise for the spiritual blessings believers have in Christ — chosen before the world began, set apart to become God''s children, forgiven through Jesus'' death, and marked by the Holy Spirit. Every blessing flows from the Father''s eternal purpose, accomplished in the Son, and applied by the Spirit. This chapter lays the groundwork for everything Paul says next.',
   'Foundations of Faith', ARRAY['ephesians', 'blessings', 'predestination', 'holy spirit'], 401, 50),

  ('c0100000-e29b-41d4-a716-446655440002', 'Ephesians 2: From Death to Life',
   'Read Ephesians 2. Paul describes the human condition apart from Christ — dead in trespasses and sins, following the world, the flesh, and the devil. But God, rich in mercy, made us alive together with Christ. "By grace you have been saved through faith — and this is not your own doing; it is the gift of God." Jew and Gentile are reconciled into one new humanity, no longer strangers but fellow citizens of God''s household.',
   'Foundations of Faith', ARRAY['ephesians', 'grace', 'salvation', 'reconciliation'], 402, 50),

  ('c0100000-e29b-41d4-a716-446655440003', 'Ephesians 3: The Mystery Revealed',
   'Read Ephesians 3. Paul reveals the mystery hidden for ages: that Gentiles are equal partners with Israel in God''s family, members of the same body, sharing the same promise in Christ Jesus through the gospel. He then prays one of Scripture''s most powerful prayers — that believers would be made strong deep inside by the Spirit, standing firm in love, and filled up with everything God has for them.',
   'Foundations of Faith', ARRAY['ephesians', 'mystery', 'gentiles', 'prayer'], 403, 50),

  ('c0100000-e29b-41d4-a716-446655440004', 'Ephesians 4: Walking Worthy',
   'Read Ephesians 4. Paul transitions from doctrine to practice: "Walk worthy of the calling to which you have been called." He lists seven things that hold believers together — one body, one Spirit, one hope, one Lord, one faith, one baptism, one God and Father. Christ gave gifts to his church for building up the body. Believers are to take off the old way of living and put on the new life that looks like God.',
   'Foundations of Faith', ARRAY['ephesians', 'unity', 'spiritual gifts', 'sanctification'], 404, 50),

  ('c0100000-e29b-41d4-a716-446655440005', 'Ephesians 5: Children of Light',
   'Read Ephesians 5. Paul calls believers to imitate God as beloved children, walking in love as Christ loved us. They are to live as children of light — exposing the deeds of darkness rather than participating in them. The most powerful part is the picture of marriage as a reflection of Christ''s relationship with his church: Christ loved the church and gave himself up for her. This is the Bible''s clearest picture of what marriage means.',
   'Foundations of Faith', ARRAY['ephesians', 'love', 'marriage', 'light'], 405, 50),

  ('c0100000-e29b-41d4-a716-446655440006', 'Ephesians 6: The Armor of God',
   'Read Ephesians 6. Paul concludes with instructions for households and the famous call to spiritual warfare. The battle is not against flesh and blood but against spiritual forces of evil. Believers are to put on the full armor of God — the belt of truth, breastplate of righteousness, shoes of the gospel, shield of faith, helmet of salvation, and sword of the Spirit. Stand firm, and pray at all times in the Spirit.',
   'Foundations of Faith', ARRAY['ephesians', 'spiritual warfare', 'armor of god', 'prayer'], 406, 50)

ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- JAS: James (5 topics, one per chapter)
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('c0200000-e29b-41d4-a716-446655440001', 'James 1: Trials and True Faith',
   'Read James 1. James opens with a startling command: count it all joy when you meet trials, because testing produces steadfastness. He calls believers to ask God for wisdom in faith without doubting, warns against blaming God for temptation, and declares that every good gift comes from the Father of lights. The chapter ends with the call to be doers of the word and not hearers only — deceiving yourselves.',
   'Foundations of Faith', ARRAY['james', 'trials', 'faith', 'obedience'], 411, 50),

  ('c0200000-e29b-41d4-a716-446655440002', 'James 2: Faith and Works',
   'Read James 2. James confronts favoritism in the assembly — showing partiality to the rich while dishonoring the poor violates the royal law of love. He then delivers his most famous argument: faith without works is dead. Abraham was justified by works when he offered Isaac — not in contradiction to Paul''s teaching, but as evidence that genuine saving faith always produces visible fruit. A faith that does not act is no faith at all.',
   'Foundations of Faith', ARRAY['james', 'faith', 'works', 'partiality'], 412, 50),

  ('c0200000-e29b-41d4-a716-446655440003', 'James 3: Taming the Tongue',
   'Read James 3. The tongue is a small member but it sets the whole course of life on fire. James uses vivid imagery — bits, rudders, fire, poison — to show the devastating power of uncontrolled speech. No human being can tame the tongue. The chapter closes by contrasting earthly wisdom (marked by jealousy and selfish ambition) with heavenly wisdom (pure, peaceable, gentle, full of mercy and good fruits).',
   'Foundations of Faith', ARRAY['james', 'tongue', 'wisdom', 'speech'], 413, 50),

  ('c0200000-e29b-41d4-a716-446655440004', 'James 4: Humility Before God',
   'Read James 4. James diagnoses the source of quarrels: selfish desires that fight inside you. He calls believers to submit to God and resist the devil, to draw near to God in humility rather than pursuing friendship with the world. "God opposes the proud but gives grace to the humble." He warns against judging one another and against proudly planning the future without considering God''s will.',
   'Foundations of Faith', ARRAY['james', 'humility', 'submission', 'pride'], 414, 50),

  ('c0200000-e29b-41d4-a716-446655440005', 'James 5: Patient Endurance',
   'Read James 5. James warns the rich who have exploited workers, calls believers to patience like the farmer waiting for rain and like Job who endured, and urges straightforward speech without oaths. The letter closes with powerful instructions on prayer: the prayer of faith will save the sick, and the prayer of a righteous person has great power. Elijah prayed and the heavens withheld rain; he prayed again and the rain came.',
   'Foundations of Faith', ARRAY['james', 'patience', 'prayer', 'endurance'], 415, 50)

ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- 1JN–3JN: John's Letters (7 topics: 5 + 1 + 1)
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('c0300000-e29b-41d4-a716-446655440001', '1 John 1: Walking in the Light',
   'Read 1 John 1. John writes so that his readers may have fellowship with the apostles and with the Father and the Son. His message: God is light and in him is no darkness at all. If we walk in the light, we have fellowship with one another and the blood of Jesus cleanses us from all sin. If we say we have no sin, we deceive ourselves — but if we confess our sins, he is faithful and just to forgive us.',
   'Foundations of Faith', ARRAY['1 john', 'light', 'sin', 'confession'], 421, 50),

  ('c0300000-e29b-41d4-a716-446655440002', '1 John 2: Knowing the True from the False',
   'Read 1 John 2. Jesus Christ the righteous stands up for us before the Father and paid the price for our sins. John gives tests of genuine faith: keeping his commandments, walking as Jesus walked, loving fellow believers rather than the world. He warns that antichrists have gone out — those who deny that Jesus is the Christ. Believers have been anointed by the Holy One and know the truth. Abide in Christ.',
   'Foundations of Faith', ARRAY['1 john', 'antichrist', 'obedience', 'abiding'], 422, 50),

  ('c0300000-e29b-41d4-a716-446655440003', '1 John 3: The Love of God',
   'Read 1 John 3. "See what kind of love the Father has given to us, that we should be called children of God." The one who practices righteousness is righteous; the one who makes a practice of sinning is of the devil. Christ appeared to destroy the works of the devil. Love is the mark of genuine faith: "We know that we have passed out of death into life, because we love the brothers." Let us love not in word but in deed and truth.',
   'Foundations of Faith', ARRAY['1 john', 'love', 'righteousness', 'children of god'], 423, 50),

  ('c0300000-e29b-41d4-a716-446655440004', '1 John 4: Testing the Spirits',
   'Read 1 John 4. John commands believers to test the spirits: every spirit that confesses Jesus Christ has come in the flesh is from God. He declares that God is love — and he proved it by sending his Son to pay the price for our sins. "We love because he first loved us." Anyone who claims to love God but hates his brother is a liar. Perfect love casts out fear.',
   'Foundations of Faith', ARRAY['1 john', 'testing spirits', 'love', 'incarnation'], 424, 50),

  ('c0300000-e29b-41d4-a716-446655440005', '1 John 5: Assurance of Eternal Life',
   'Read 1 John 5. Everyone who believes that Jesus is the Christ has been born of God. Faith is the victory that overcomes the world. John presents three witnesses — the Spirit, the water, and the blood — and declares: "God gave us eternal life, and this life is in his Son." The letter closes with confident assurance: we can know that we have eternal life, we can pray with confidence, and the Son of God has come and has given us understanding.',
   'Foundations of Faith', ARRAY['1 john', 'assurance', 'eternal life', 'faith'], 425, 50),

  ('c0300000-e29b-41d4-a716-446655440006', '2 John: Truth and Love',
   'Read 2 John. The elder writes to the "elect lady and her children" — likely a local church — urging them to walk in truth and love one another as the Father has commanded. He warns against deceivers who deny that Jesus Christ has come in the flesh; such a person is the deceiver and the antichrist. Do not receive into your house or give any greeting to anyone who does not bring the teaching of Christ, lest you share in his wicked works.',
   'Foundations of Faith', ARRAY['2 john', 'truth', 'love', 'deceivers'], 426, 50),

  ('c0300000-e29b-41d4-a716-446655440007', '3 John: Faithful Hospitality',
   'Read 3 John. The elder writes to his beloved Gaius, commending him for his faithful hospitality toward traveling missionaries — even though they are strangers. In contrast, Diotrephes loves to put himself first, refuses to welcome the brothers, and puts out of the church those who do. John holds up Demetrius as a man well-spoken of by everyone. Imitate what is good, for whoever does good is from God.',
   'Foundations of Faith', ARRAY['3 john', 'hospitality', 'leadership', 'faithfulness'], 427, 50)

ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- PHP: Philippians (4 topics, one per chapter)
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('c0400000-e29b-41d4-a716-446655440001', 'Philippians 1: Joy in the Gospel',
   'Read Philippians 1. Paul writes from prison with overflowing joy, thanking God for the Philippians'' partnership in the gospel from the first day. He is confident that God who began a good work in them will bring it to completion. Whether he lives or dies, Christ will be honored — "to live is Christ, and to die is gain." He urges the church to stand firm in one spirit, striving side by side for the faith of the gospel.',
   'Foundations of Faith', ARRAY['philippians', 'joy', 'gospel', 'partnership'], 431, 50),

  ('c0400000-e29b-41d4-a716-446655440002', 'Philippians 2: The Mind of Christ',
   'Read Philippians 2. Paul calls believers to have the mind of Christ, who though he was in the form of God did not count equality with God a thing to be grasped, but emptied himself, taking the form of a servant, and humbled himself to the point of death on a cross. Therefore God has highly exalted him. Believers are to work out their salvation with fear and trembling, for it is God who works in them both to will and to work for his good pleasure. This does not mean earning salvation — it means living out what God has already done in you.',
   'Foundations of Faith', ARRAY['philippians', 'humility', 'christology', 'incarnation'], 432, 50),

  ('c0400000-e29b-41d4-a716-446655440003', 'Philippians 3: Pressing Toward the Goal',
   'Read Philippians 3. Paul counts everything as loss because of the surpassing worth of knowing Christ Jesus his Lord. His Jewish background was perfect by every standard — but he considers them rubbish in order to gain Christ and be found in him, not standing right with God by his own effort but through trusting in Christ. He has not yet arrived but presses on toward the goal for the prize of the upward call of God in Christ.',
   'Foundations of Faith', ARRAY['philippians', 'righteousness', 'faith', 'perseverance'], 433, 50),

  ('c0400000-e29b-41d4-a716-446655440004', 'Philippians 4: Rejoice Always',
   'Read Philippians 4. "Rejoice in the Lord always; again I will say, rejoice." Paul calls believers to let their reasonableness be known, to bring everything to God in prayer with thanksgiving, and to receive the peace of God that surpasses all understanding. He has learned the secret of contentment in every circumstance — "I can do all things through him who strengthens me." This is not a promise of unlimited human ability but of Christ-sustained endurance.',
   'Foundations of Faith', ARRAY['philippians', 'joy', 'contentment', 'peace'], 434, 50)

ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- GAL: Galatians (6 topics, one per chapter)
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('c0500000-e29b-41d4-a716-446655440001', 'Galatians 1: No Other Gospel',
   'Read Galatians 1. Paul is astonished that the Galatians are so quickly deserting the one who called them in the grace of Christ for a different gospel — which is no gospel at all. He declares: if anyone preaches a gospel contrary to the one you received, let him be accursed. Paul''s gospel came not from man but through a revelation of Jesus Christ. He recounts his former life in Judaism and his dramatic calling by God''s grace.',
   'Foundations of Faith', ARRAY['galatians', 'gospel', 'revelation', 'apostleship'], 441, 50),

  ('c0500000-e29b-41d4-a716-446655440002', 'Galatians 2: Justified by Faith',
   'Read Galatians 2. Paul recounts his confrontation with Peter at Antioch, where Peter withdrew from eating with Gentile believers under pressure from those who insisted on Jewish law. Paul opposed him to his face because the truth of the gospel was at stake. Paul declares: "We know that no one is made right with God by following rules, but only by trusting in Jesus Christ." Paul has been crucified with Christ; the life he now lives, he lives by faith in the Son of God.',
   'Foundations of Faith', ARRAY['galatians', 'justification', 'faith', 'law'], 442, 50),

  ('c0500000-e29b-41d4-a716-446655440003', 'Galatians 3: The Promise and the Law',
   'Read Galatians 3. Paul appeals to the Galatians'' own experience: did they receive the Spirit by works of the law or by hearing with faith? Abraham believed God and it was counted to him as righteousness. The law, which came 430 years after the promise, cannot cancel the promise. The law served as a guardian until Christ came, so that we might be justified by faith. In Christ there is neither Jew nor Greek, slave nor free, male nor female.',
   'Foundations of Faith', ARRAY['galatians', 'abraham', 'law', 'promise'], 443, 50),

  ('c0500000-e29b-41d4-a716-446655440004', 'Galatians 4: Sons and Heirs',
   'Read Galatians 4. When the fullness of time had come, God sent forth his Son, born of woman, born under the law, to redeem those under the law, so that we might receive adoption as sons. Because you are sons, God has sent the Spirit of his Son into your hearts, crying "Abba! Father!" You are no longer a slave but a son, and if a son then an heir through God. Paul pleads with the Galatians not to turn back to the old rules and rituals that could never save. The story of Hagar and Sarah shows the contrast between bondage under the law and freedom in Christ.',
   'Foundations of Faith', ARRAY['galatians', 'adoption', 'sonship', 'freedom'], 444, 50),

  ('c0500000-e29b-41d4-a716-446655440005', 'Galatians 5: Freedom in Christ',
   'Read Galatians 5. "For freedom Christ has set us free; stand firm therefore, and do not submit again to a yoke of slavery." Neither circumcision nor uncircumcision counts for anything, but only faith working through love. Paul lists the works of the flesh — sexual immorality, idolatry, enmity, jealousy — and contrasts them with the fruit of the Spirit: love, joy, peace, patience, kindness, goodness, faithfulness, gentleness, self-control. Walk by the Spirit.',
   'Foundations of Faith', ARRAY['galatians', 'freedom', 'fruit of the spirit', 'flesh'], 445, 50),

  ('c0500000-e29b-41d4-a716-446655440006', 'Galatians 6: Bearing One Another''s Burdens',
   'Read Galatians 6. Paul calls believers to bear one another''s burdens and so fulfill the law of Christ. He warns against self-deception and reminds them that God is not mocked: whatever one sows, that will he also reap. The one who sows to the Spirit will from the Spirit reap eternal life. Let us not grow weary of doing good. Paul closes with his defining declaration: "Far be it from me to boast except in the cross of our Lord Jesus Christ." What counts is a new creation.',
   'Foundations of Faith', ARRAY['galatians', 'community', 'sowing', 'new creation'], 446, 50)

ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- 1PE–2PE: Peter's Letters (8 topics: 5 + 3)
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('c0600000-e29b-41d4-a716-446655440001', '1 Peter 1: A Living Hope',
   'Read 1 Peter 1. Peter writes to scattered believers facing hardship, blessing God for causing them to be born again to a living hope through the resurrection of Jesus Christ. Their inheritance is one that can never perish, spoil, or fade. Though they are grieved by various trials, these test the genuineness of their faith — more precious than gold. Therefore set your hope fully on the grace that will be brought to you at the revelation of Jesus Christ.',
   'Foundations of Faith', ARRAY['1 peter', 'hope', 'trials', 'election'], 451, 50),

  ('c0600000-e29b-41d4-a716-446655440002', '1 Peter 2: A Holy People',
   'Read 1 Peter 2. Believers are living stones being built up as a spiritual house, a holy priesthood offering spiritual sacrifices acceptable to God through Jesus Christ. They are a chosen race, a royal priesthood, a holy nation, God''s own people — called out of darkness into his marvelous light. Peter instructs submission to human institutions for the Lord''s sake and holds up Christ as the example: when he suffered, he did not threaten but entrusted himself to the one who judges justly.',
   'Foundations of Faith', ARRAY['1 peter', 'priesthood', 'submission', 'suffering'], 452, 50),

  ('c0600000-e29b-41d4-a716-446655440003', '1 Peter 3: Suffering for Righteousness',
   'Read 1 Peter 3. Peter addresses wives and husbands in the context of a hostile culture, calling for inner beauty over outward adornment and for husbands to honor their wives as fellow heirs of grace. He then addresses suffering for righteousness: "Do not fear what they fear; do not be frightened." Christ himself suffered once for sins, the righteous for the unrighteous, to bring us to God. Always be prepared to give a reason for the hope that is in you, with gentleness and respect.',
   'Foundations of Faith', ARRAY['1 peter', 'suffering', 'marriage', 'apologetics'], 453, 50),

  ('c0600000-e29b-41d4-a716-446655440004', '1 Peter 4: Stewards of Grace',
   'Read 1 Peter 4. Since Christ suffered in the flesh, arm yourselves with the same way of thinking. The time for living according to the passions of the Gentiles has passed. "Above all, keep loving one another earnestly, since love covers a multitude of sins." Each believer has received a gift and is to use it as a good steward of God''s varied grace. Do not be surprised at the fiery trial — rejoice insofar as you share Christ''s sufferings.',
   'Foundations of Faith', ARRAY['1 peter', 'stewardship', 'love', 'suffering'], 454, 50),

  ('c0600000-e29b-41d4-a716-446655440005', '1 Peter 5: Stand Firm in Grace',
   'Read 1 Peter 5. Peter exhorts elders to shepherd the flock of God willingly, not for shameful gain but eagerly, not domineering but being examples. He calls all believers to clothe themselves with humility toward one another, for God opposes the proud but gives grace to the humble. "Humble yourselves under the mighty hand of God so that at the proper time he may exalt you, casting all your anxieties on him, because he cares for you." Resist the devil, firm in your faith.',
   'Foundations of Faith', ARRAY['1 peter', 'humility', 'leadership', 'spiritual warfare'], 455, 50),

  ('c0600000-e29b-41d4-a716-446655440006', '2 Peter 1: Growing in Godliness',
   'Read 2 Peter 1. Peter declares that God''s divine power has granted to us all things that pertain to life and godliness through the knowledge of him who called us by his own glory and excellence. Through these he has granted us precious and very great promises, so that through them we may share in God''s own nature — becoming people who reflect his holiness and love. Therefore make every effort to add to your faith goodness, knowledge, self-control, endurance, godliness, brotherly affection, and love.',
   'Foundations of Faith', ARRAY['2 peter', 'godliness', 'promises', 'growth'], 456, 50),

  ('c0600000-e29b-41d4-a716-446655440007', '2 Peter 2: False Teachers Exposed',
   'Read 2 Peter 2. Peter warns that false teachers will secretly bring in dangerous false teachings, even denying the Master who bought them. God did not spare the angels when they sinned, nor the ancient world when he brought the flood, nor Sodom and Gomorrah — but he rescued righteous Lot. The Lord knows how to rescue the godly from trials and to keep the unrighteous under punishment. These false teachers are like waterless springs and mists driven by a storm.',
   'Foundations of Faith', ARRAY['2 peter', 'false teachers', 'judgment', 'heresy'], 457, 50),

  ('c0600000-e29b-41d4-a716-446655440008', '2 Peter 3: The Day of the Lord',
   'Read 2 Peter 3. Scoffers will come in the last days, asking "Where is the promise of his coming?" But the Lord is not slow to fulfill his promise — he is patient toward you, not wishing that any should perish but that all should reach repentance. The day of the Lord will come like a thief, and the heavens will pass away with a roar. Since all these things are to be dissolved, what sort of people ought you to be? We await new heavens and a new earth in which righteousness dwells.',
   'Foundations of Faith', ARRAY['2 peter', 'second coming', 'patience', 'new creation'], 458, 50)

ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- 1CO–2CO: Corinthians (29 topics: 16 + 13)
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('c0700000-e29b-41d4-a716-446655440001', '1 Corinthians 1: Divisions in the Church',
   'Read 1 Corinthians 1. Paul appeals for unity: "Is Christ divided?" The Corinthians are quarreling over allegiance to Paul, Apollos, or Cephas. Paul redirects them to the message of the cross — foolishness to the perishing but the power of God to those being saved. God chose what is foolish in the world to shame the wise, so that no human being might boast in his presence. Christ Jesus is our wisdom, righteousness, sanctification, and redemption.',
   'Foundations of Faith', ARRAY['1 corinthians', 'unity', 'cross', 'wisdom'], 461, 50),

  ('c0700000-e29b-41d4-a716-446655440002', '1 Corinthians 2: God''s Wisdom vs. the World''s',
   'Read 1 Corinthians 2. Paul came not with eloquent wisdom but in weakness and fear, so that their faith would rest on God''s power rather than human wisdom. He reveals what no eye has seen or ear heard — God''s secret wisdom prepared for those who love him. The Spirit searches all things, even the depths of God. The natural person does not accept the things of the Spirit; they are spiritually discerned.',
   'Foundations of Faith', ARRAY['1 corinthians', 'wisdom', 'holy spirit', 'revelation'], 462, 50),

  ('c0700000-e29b-41d4-a716-446655440003', '1 Corinthians 3: Servants of Christ',
   'Read 1 Corinthians 3. The Corinthians are still infants in Christ, fed with milk, not solid food. Paul planted, Apollos watered, but God gave the growth. Ministers are servants through whom the Corinthians believed. The foundation is Jesus Christ — no one can lay another. Each person''s work will be tested by fire. Do you not know that you are God''s temple and that God''s Spirit dwells in you?',
   'Foundations of Faith', ARRAY['1 corinthians', 'ministry', 'foundation', 'temple'], 463, 50),

  ('c0700000-e29b-41d4-a716-446655440004', '1 Corinthians 4: Fools for Christ',
   'Read 1 Corinthians 4. Paul describes the apostles as servants of Christ and people trusted with God''s hidden truths. What matters most is that those who are trusted prove faithful — and the Lord is the one who judges. Paul compares the Corinthians'' comfort with the apostles'' hardship: "We have become a spectacle to the world." He warns the arrogant and urges them to imitate him as their father in Christ.',
   'Foundations of Faith', ARRAY['1 corinthians', 'stewardship', 'apostleship', 'humility'], 464, 50),

  ('c0700000-e29b-41d4-a716-446655440005', '1 Corinthians 5: Church Discipline',
   'Read 1 Corinthians 5. Paul confronts the church for tolerating a man living in sexual immorality that even pagans would condemn. He commands them to deliver this man to Satan for the destruction of the flesh, so that his spirit may be saved. A little leaven leavens the whole lump — purge the old leaven. Paul clarifies: he does not mean total separation from the immoral of this world, but from anyone who bears the name of brother while practicing sin.',
   'Foundations of Faith', ARRAY['1 corinthians', 'discipline', 'holiness', 'church'], 465, 50),

  ('c0700000-e29b-41d4-a716-446655440006', '1 Corinthians 6: Flee Sexual Immorality',
   'Read 1 Corinthians 6. Paul rebukes the Corinthians for suing one another before unbelievers. The unrighteous will not inherit the kingdom of God — and such were some of you, but you were washed, sanctified, and justified. "All things are lawful for me" — but not all things are helpful. The body is not meant for sexual immorality but for the Lord. Your body is a temple of the Holy Spirit. You are not your own; you were bought with a price. Glorify God in your body.',
   'Foundations of Faith', ARRAY['1 corinthians', 'purity', 'body', 'temple'], 466, 50),

  ('c0700000-e29b-41d4-a716-446655440007', '1 Corinthians 7: Marriage and Singleness',
   'Read 1 Corinthians 7. Paul addresses questions about marriage and singleness. Each has his own gift from God. The married should not seek divorce; the unmarried may marry without sin. Paul''s guiding principle: "Let each person lead the life that the Lord has assigned to him." In light of the present distress, he commends singleness for undivided devotion to the Lord — but marriage is no sin. The form of this world is passing away.',
   'Foundations of Faith', ARRAY['1 corinthians', 'marriage', 'singleness', 'calling'], 467, 50),

  ('c0700000-e29b-41d4-a716-446655440008', '1 Corinthians 8: Food, Idols, and Conscience',
   'Read 1 Corinthians 8. Knowledge puffs up, but love builds up. Paul addresses food offered to idols: idols are nothing, and food does not commend us to God. But not everyone has this knowledge. If eating causes a weaker brother to stumble, love demands self-restriction. The right to eat is subordinated to the obligation to love. Christian freedom is never an end in itself — it is always governed by love for the body of Christ.',
   'Foundations of Faith', ARRAY['1 corinthians', 'conscience', 'love', 'idolatry'], 468, 50),

  ('c0700000-e29b-41d4-a716-446655440009', '1 Corinthians 9: Rights and Self-Discipline',
   'Read 1 Corinthians 9. Paul has the right to financial support as an apostle but has not used it — he would rather die than have anyone deprive him of his ground for boasting. He has made himself a servant to all, becoming all things to all people so that by all means he might save some. He does it all for the sake of the gospel. Like an athlete, he disciplines his body so that after preaching to others he himself will not be disqualified.',
   'Foundations of Faith', ARRAY['1 corinthians', 'rights', 'self-discipline', 'mission'], 469, 50),

  ('c0700000-e29b-41d4-a716-446655440010', '1 Corinthians 10: Warnings from Israel',
   'Read 1 Corinthians 10. Paul warns from Israel''s history: they all passed through the sea and ate the same spiritual food, yet God was not pleased with most of them. These things happened as examples for us — do not be idolaters, do not test Christ, do not grumble. No temptation has overtaken you that is not common to man; God is faithful and will provide the way of escape. Flee from idolatry. Whether you eat or drink, do all to the glory of God.',
   'Foundations of Faith', ARRAY['1 corinthians', 'warnings', 'idolatry', 'temptation'], 470, 50),

  ('c0700000-e29b-41d4-a716-446655440011', '1 Corinthians 11: Order in Worship',
   'Read 1 Corinthians 11. Paul addresses propriety in worship — head coverings and the meaning of authority in worship. He then confronts abuses of the Lord''s Supper: divisions at the table, the rich shaming the poor. He recounts the institution of the Supper and warns: whoever eats and drinks in an unworthy manner eats and drinks judgment on himself. Examine yourselves before partaking.',
   'Foundations of Faith', ARRAY['1 corinthians', 'worship', 'lords supper', 'order'], 471, 50),

  ('c0700000-e29b-41d4-a716-446655440012', '1 Corinthians 12: Spiritual Gifts',
   'Read 1 Corinthians 12. There are varieties of gifts but the same Spirit. To each is given the manifestation of the Spirit for the common good. Paul uses the body as a metaphor: the eye cannot say to the hand, "I have no need of you." God has arranged the members as he chose. If one member suffers, all suffer together. The diversity of gifts serves the unity of the body. Paul urges them to earnestly desire the higher gifts — and then shows them "a still more excellent way."',
   'Foundations of Faith', ARRAY['1 corinthians', 'spiritual gifts', 'body of christ', 'unity'], 472, 50),

  ('c0700000-e29b-41d4-a716-446655440013', '1 Corinthians 13: The Way of Love',
   'Read 1 Corinthians 13. If Paul speaks in tongues of men and angels but has not love, he is a noisy gong. Love is patient and kind; it does not envy or boast; it is not arrogant or rude. It does not insist on its own way. Love bears all things, believes all things, hopes all things, endures all things. Love never ends. Prophecies will cease, tongues will cease, knowledge will pass away — but faith, hope, and love abide, and the greatest of these is love.',
   'Foundations of Faith', ARRAY['1 corinthians', 'love', 'spiritual gifts', 'character'], 473, 50),

  ('c0700000-e29b-41d4-a716-446655440014', '1 Corinthians 14: Orderly Worship',
   'Read 1 Corinthians 14. Paul instructs the church to pursue love and earnestly desire spiritual gifts, especially prophecy. Tongues without interpretation do not edify the church; prophecy builds up, encourages, and convicts. When the church gathers, each contribution — a hymn, a teaching, a revelation, a tongue, an interpretation — should be done for building up. God is not a God of confusion but of peace. Let all things be done decently and in order.',
   'Foundations of Faith', ARRAY['1 corinthians', 'prophecy', 'tongues', 'order'], 474, 50),

  ('c0700000-e29b-41d4-a716-446655440015', '1 Corinthians 15: The Resurrection',
   'Read 1 Corinthians 15. Paul delivers the gospel he received: Christ died for our sins, was buried, was raised on the third day — and appeared to Cephas, to the twelve, to more than five hundred, and last of all to Paul. If Christ has not been raised, faith is futile and we are still in our sins. But Christ has been raised — the firstfruits of those who have fallen asleep. The last enemy to be destroyed is death. "O death, where is your victory? O death, where is your sting?"',
   'Foundations of Faith', ARRAY['1 corinthians', 'resurrection', 'gospel', 'hope'], 475, 50),

  ('c0700000-e29b-41d4-a716-446655440016', '1 Corinthians 16: Final Instructions',
   'Read 1 Corinthians 16. Paul gives practical instructions for the collection for the saints in Jerusalem — a practical act of love and unity among believers. He shares travel plans and commends Timothy and Apollos. The letter closes with memorable exhortations: "Be watchful, stand firm in the faith, act like men, be strong. Let all that you do be done in love." Grace, service, and love — the marks of a healthy church.',
   'Foundations of Faith', ARRAY['1 corinthians', 'generosity', 'community', 'love'], 476, 50),

  ('c0700000-e29b-41d4-a716-446655440017', '2 Corinthians 1: Comfort in Affliction',
   'Read 2 Corinthians 1. Paul blesses the God of all comfort, who comforts us in all our affliction so that we may be able to comfort those who are in any affliction with the comfort with which we ourselves are comforted by God. Paul and his companions were so utterly burdened beyond their strength that they despaired of life itself — but this was to make them rely not on themselves but on God who raises the dead.',
   'Foundations of Faith', ARRAY['2 corinthians', 'comfort', 'affliction', 'god''s faithfulness'], 477, 50),

  ('c0700000-e29b-41d4-a716-446655440018', '2 Corinthians 2: Forgiveness and Triumph',
   'Read 2 Corinthians 2. Paul urges the Corinthians to forgive and comfort the repentant offender, lest Satan gain the advantage through unforgiveness. He then describes the Christian life as a triumphal procession: "Thanks be to God, who in Christ always leads us in triumphal procession, and through us spreads the fragrance of the knowledge of him everywhere." To one a fragrance from death to death, to the other a fragrance from life to life.',
   'Foundations of Faith', ARRAY['2 corinthians', 'forgiveness', 'triumph', 'fragrance'], 478, 50),

  ('c0700000-e29b-41d4-a716-446655440019', '2 Corinthians 3: The Glory of the New Covenant',
   'Read 2 Corinthians 3. Paul contrasts the old covenant written on tablets of stone with the new covenant written on tablets of human hearts by the Spirit of the living God. The Spirit''s work is far more glorious than the old covenant, which could only condemn. When one turns to the Lord, the veil is removed. "Where the Spirit of the Lord is, there is freedom." We are being transformed into the same image from one degree of glory to another.',
   'Foundations of Faith', ARRAY['2 corinthians', 'new covenant', 'glory', 'transformation'], 479, 50),

  ('c0700000-e29b-41d4-a716-446655440020', '2 Corinthians 4: Treasure in Jars of Clay',
   'Read 2 Corinthians 4. We have this treasure in jars of clay, to show that the surpassing power belongs to God and not to us. We are afflicted in every way but not crushed, perplexed but not driven to despair, persecuted but not forsaken, struck down but not destroyed. "This light momentary affliction is preparing for us an eternal weight of glory beyond all comparison." We look not to the things that are seen but to the things that are unseen.',
   'Foundations of Faith', ARRAY['2 corinthians', 'suffering', 'glory', 'perseverance'], 480, 50),

  ('c0700000-e29b-41d4-a716-446655440021', '2 Corinthians 5: The Ministry of Reconciliation',
   'Read 2 Corinthians 5. If the earthly tent we live in is destroyed, we have a building from God, a house not made with hands, eternal in the heavens. We walk by faith, not by sight. The love of Christ controls us — he died for all, that those who live might no longer live for themselves but for him. "If anyone is in Christ, he is a new creation." God gave us the ministry of reconciliation: we are ambassadors for Christ.',
   'Foundations of Faith', ARRAY['2 corinthians', 'reconciliation', 'new creation', 'ambassadors'], 481, 50),

  ('c0700000-e29b-41d4-a716-446655440022', '2 Corinthians 6: Servants of God',
   'Read 2 Corinthians 6. Paul commends himself and his companions as servants of God through great endurance — in afflictions, hardships, calamities, beatings, imprisonments, riots, labors, sleepless nights, hunger — and through the Holy Spirit, genuine love, truthful speech, and the power of God. He urges believers: "Do not be unequally yoked with unbelievers. What partnership has righteousness with lawlessness? What fellowship has light with darkness?"',
   'Foundations of Faith', ARRAY['2 corinthians', 'servanthood', 'endurance', 'holiness'], 482, 50),

  ('c0700000-e29b-41d4-a716-446655440023', '2 Corinthians 7: Godly Sorrow and Repentance',
   'Read 2 Corinthians 7. Paul rejoices because the Corinthians'' grief led to repentance. "Godly grief produces a repentance that leads to salvation without regret, whereas worldly grief produces death." Paul''s earlier letter — painful though it was — produced earnestness, eagerness to clear themselves, indignation, fear, longing, zeal, and a desire for justice. Titus brings the good news of their obedience, and Paul is encouraged.',
   'Foundations of Faith', ARRAY['2 corinthians', 'repentance', 'godly sorrow', 'joy'], 483, 50),

  ('c0700000-e29b-41d4-a716-446655440024', '2 Corinthians 8: The Grace of Giving',
   'Read 2 Corinthians 8. Paul holds up the Macedonian churches as models of generosity — out of extreme poverty their abundance of joy overflowed in a wealth of generosity. He appeals to the Corinthians to complete their promised collection for the saints in Jerusalem. "You know the grace of our Lord Jesus Christ, that though he was rich, yet for your sake he became poor, so that you by his poverty might become rich."',
   'Foundations of Faith', ARRAY['2 corinthians', 'generosity', 'grace', 'giving'], 484, 50),

  ('c0700000-e29b-41d4-a716-446655440025', '2 Corinthians 9: Cheerful Giving',
   'Read 2 Corinthians 9. Paul encourages generous and joyful giving: "Whoever sows sparingly will also reap sparingly, and whoever sows bountifully will also reap bountifully." Each one must give as he has decided in his heart, not reluctantly or under compulsion, for God loves a cheerful giver. God is able to make all grace abound to you, so that having all sufficiency in all things at all times, you may abound in every good work.',
   'Foundations of Faith', ARRAY['2 corinthians', 'cheerful giving', 'generosity', 'abundance'], 485, 50),

  ('c0700000-e29b-41d4-a716-446655440026', '2 Corinthians 10: Spiritual Warfare',
   'Read 2 Corinthians 10. Paul defends his authority and apostleship. Though we walk in the flesh, we do not wage war according to the flesh. "The weapons of our warfare are not of the flesh but have divine power to destroy strongholds." Paul takes every thought captive to obey Christ. He warns: "Let the one who boasts, boast in the Lord," for it is not the one who commends himself who is approved, but the one whom the Lord commends.',
   'Foundations of Faith', ARRAY['2 corinthians', 'spiritual warfare', 'authority', 'humility'], 486, 50),

  ('c0700000-e29b-41d4-a716-446655440027', '2 Corinthians 11: Paul''s Sufferings',
   'Read 2 Corinthians 11. Paul reluctantly boasts to counter false apostles who disguise themselves as servants of righteousness. He catalogs his sufferings: five times he received the forty lashes less one, three times he was beaten with rods, once he was stoned, three times he was shipwrecked. In danger from rivers, robbers, his own people, Gentiles, in the city, in the wilderness, at sea, from false brothers — in toil and hardship, through many a sleepless night, in hunger and thirst.',
   'Foundations of Faith', ARRAY['2 corinthians', 'suffering', 'false apostles', 'perseverance'], 487, 50),

  ('c0700000-e29b-41d4-a716-446655440028', '2 Corinthians 12: Power in Weakness',
   'Read 2 Corinthians 12. Paul was caught up to the third heaven and heard things that cannot be told. To keep him from becoming conceited, a thorn in the flesh was given — a messenger of Satan to harass him. Three times he pleaded with the Lord to take it away, and the Lord said: "My grace is sufficient for you, for my power is made perfect in weakness." Therefore Paul boasts gladly of his weaknesses, so that the power of Christ may rest upon him.',
   'Foundations of Faith', ARRAY['2 corinthians', 'weakness', 'grace', 'power'], 488, 50),

  ('c0700000-e29b-41d4-a716-446655440029', '2 Corinthians 13: Final Warnings',
   'Read 2 Corinthians 13. Paul warns that when he comes again he will not spare those who have sinned. He urges the Corinthians to examine themselves to see whether they are in the faith. Christ is not weak in dealing with you but is powerful among you — for he was crucified in weakness but lives by the power of God. "Aim for restoration, comfort one another, agree with one another, live in peace; and the God of love and peace will be with you."',
   'Foundations of Faith', ARRAY['2 corinthians', 'self-examination', 'restoration', 'peace'], 489, 50)

ON CONFLICT (id) DO NOTHING;


-- =====================================================
-- PART 2: LEARNING PATHS
-- =====================================================

-- -------------------------------------------------------
-- Path 35: Ephesians: Riches in Christ
-- Category: Epistles | Level: seeker | 6 topics
-- -------------------------------------------------------
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000035',
  'ephesians-riches-in-christ',
  'Ephesians: Riches in Christ',
  'Paul''s letter to the Ephesians starts with who God is and what he has done, then shows how that changes the way we live every day. In six chapters, discover the spiritual blessings that are yours in Christ, the grace that saved you, the mystery of the church, the call to walk worthy, the picture of marriage as gospel, and the armor of God for spiritual warfare.',
  'auto_awesome', '#6366F1', 18, 'beginner', 'seeker', 'standard', false, 5, 'Epistles'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000035', 'c0100000-e29b-41d4-a716-446655440001', 0, false),
  ('aaa00000-0000-0000-0000-000000000035', 'c0100000-e29b-41d4-a716-446655440002', 1, false),
  ('aaa00000-0000-0000-0000-000000000035', 'c0100000-e29b-41d4-a716-446655440003', 2, false),
  ('aaa00000-0000-0000-0000-000000000035', 'c0100000-e29b-41d4-a716-446655440004', 3, true),
  ('aaa00000-0000-0000-0000-000000000035', 'c0100000-e29b-41d4-a716-446655440005', 4, false),
  ('aaa00000-0000-0000-0000-000000000035', 'c0100000-e29b-41d4-a716-446655440006', 5, true)
ON CONFLICT DO NOTHING;

-- -------------------------------------------------------
-- Path 36: James: Faith That Works
-- Category: Epistles | Level: seeker | 5 topics
-- -------------------------------------------------------
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000036',
  'james-faith-that-works',
  'James: Faith That Works',
  'James writes the most practical letter in the New Testament — a call to faith that proves itself in action. In five chapters, confront the testing of faith, the deadly power of the tongue, the danger of favoritism, the call to humility, and the power of patient, persistent prayer. Faith without works is dead. James does not contradict salvation by grace through faith — he shows what living faith looks like.',
  'front_hand', '#F59E0B', 15, 'beginner', 'seeker', 'standard', false, 4, 'Epistles'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000036', 'c0200000-e29b-41d4-a716-446655440001', 0, false),
  ('aaa00000-0000-0000-0000-000000000036', 'c0200000-e29b-41d4-a716-446655440002', 1, false),
  ('aaa00000-0000-0000-0000-000000000036', 'c0200000-e29b-41d4-a716-446655440003', 2, true),
  ('aaa00000-0000-0000-0000-000000000036', 'c0200000-e29b-41d4-a716-446655440004', 3, false),
  ('aaa00000-0000-0000-0000-000000000036', 'c0200000-e29b-41d4-a716-446655440005', 4, true)
ON CONFLICT DO NOTHING;

-- -------------------------------------------------------
-- Path 37: John's Letters: Light, Love, and Truth
-- Category: Epistles | Level: follower | 7 topics (1-3 John)
-- -------------------------------------------------------
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000037',
  'johns-letters-light-love-truth',
  'John''s Letters: Light, Love, and Truth',
  'The apostle John writes three letters that together paint the fullest picture of what it means to stay close to Jesus and live in him. In 1 John, discover the tests of genuine faith — walking in light, keeping his commandments, and loving one another. 2 John warns against deceivers who deny Christ come in the flesh. 3 John commends faithful hospitality and warns against self-exalting leadership. God is light and God is love — and those who abide in him will know it.',
  'lightbulb', '#10B981', 21, 'intermediate', 'follower', 'standard', false, 8, 'Epistles'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000037', 'c0300000-e29b-41d4-a716-446655440001', 0, false),
  ('aaa00000-0000-0000-0000-000000000037', 'c0300000-e29b-41d4-a716-446655440002', 1, false),
  ('aaa00000-0000-0000-0000-000000000037', 'c0300000-e29b-41d4-a716-446655440003', 2, false),
  ('aaa00000-0000-0000-0000-000000000037', 'c0300000-e29b-41d4-a716-446655440004', 3, true),
  ('aaa00000-0000-0000-0000-000000000037', 'c0300000-e29b-41d4-a716-446655440005', 4, true),
  ('aaa00000-0000-0000-0000-000000000037', 'c0300000-e29b-41d4-a716-446655440006', 5, false),
  ('aaa00000-0000-0000-0000-000000000037', 'c0300000-e29b-41d4-a716-446655440007', 6, false)
ON CONFLICT DO NOTHING;

-- -------------------------------------------------------
-- Path 38: Philippians: Joy in Christ
-- Category: Epistles | Level: seeker | 4 topics
-- -------------------------------------------------------
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000038',
  'philippians-joy-in-christ',
  'Philippians: Joy in Christ',
  'Written from a Roman prison, Philippians overflows with joy. In four chapters, Paul reveals the secret of contentment, the mind of Christ who emptied himself, the surpassing worth of knowing Jesus, and the peace that guards every heart. Learn to rejoice in every circumstance through the one who strengthens you.',
  'sentiment_very_satisfied', '#EC4899', 12, 'beginner', 'seeker', 'standard', false, 3, 'Epistles'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000038', 'c0400000-e29b-41d4-a716-446655440001', 0, false),
  ('aaa00000-0000-0000-0000-000000000038', 'c0400000-e29b-41d4-a716-446655440002', 1, true),
  ('aaa00000-0000-0000-0000-000000000038', 'c0400000-e29b-41d4-a716-446655440003', 2, false),
  ('aaa00000-0000-0000-0000-000000000038', 'c0400000-e29b-41d4-a716-446655440004', 3, true)
ON CONFLICT DO NOTHING;

-- -------------------------------------------------------
-- Path 39: Galatians: Gospel Freedom
-- Category: Epistles | Level: follower | 6 topics
-- -------------------------------------------------------
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000039',
  'galatians-gospel-freedom',
  'Galatians: Gospel Freedom',
  'Paul''s most passionate letter defends the good news against those who say you need to follow religious rules on top of trusting in Jesus. In six chapters, discover why there is no other gospel, how we are made right with God by faith alone, the relationship between the promise and the law, what it means to be adopted as sons, and how to walk by the Spirit in true freedom.',
  'lock_open', '#EF4444', 18, 'intermediate', 'follower', 'standard', false, 7, 'Epistles'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000039', 'c0500000-e29b-41d4-a716-446655440001', 0, false),
  ('aaa00000-0000-0000-0000-000000000039', 'c0500000-e29b-41d4-a716-446655440002', 1, false),
  ('aaa00000-0000-0000-0000-000000000039', 'c0500000-e29b-41d4-a716-446655440003', 2, false),
  ('aaa00000-0000-0000-0000-000000000039', 'c0500000-e29b-41d4-a716-446655440004', 3, true),
  ('aaa00000-0000-0000-0000-000000000039', 'c0500000-e29b-41d4-a716-446655440005', 4, false),
  ('aaa00000-0000-0000-0000-000000000039', 'c0500000-e29b-41d4-a716-446655440006', 5, true)
ON CONFLICT DO NOTHING;

-- -------------------------------------------------------
-- Path 40: Peter's Letters: Hope and Endurance
-- Category: Epistles | Level: follower | 8 topics (1-2 Peter)
-- -------------------------------------------------------
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000040',
  'peters-letters-hope-and-endurance',
  'Peter''s Letters: Hope and Endurance',
  'Peter writes two letters to scattered believers facing hostility and the threat of false teaching. In 1 Peter, discover the living hope of the resurrection, the identity of God''s holy people, the example of Christ in suffering, and the humility that resists the devil. In 2 Peter, grow in godliness through precious promises, recognize false teachers, and look forward to the day of the Lord and the new heavens and new earth.',
  'volunteer_activism', '#8B5CF6', 24, 'intermediate', 'follower', 'standard', false, 6, 'Epistles'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000040', 'c0600000-e29b-41d4-a716-446655440001', 0, false),
  ('aaa00000-0000-0000-0000-000000000040', 'c0600000-e29b-41d4-a716-446655440002', 1, false),
  ('aaa00000-0000-0000-0000-000000000040', 'c0600000-e29b-41d4-a716-446655440003', 2, false),
  ('aaa00000-0000-0000-0000-000000000040', 'c0600000-e29b-41d4-a716-446655440004', 3, false),
  ('aaa00000-0000-0000-0000-000000000040', 'c0600000-e29b-41d4-a716-446655440005', 4, true),
  ('aaa00000-0000-0000-0000-000000000040', 'c0600000-e29b-41d4-a716-446655440006', 5, false),
  ('aaa00000-0000-0000-0000-000000000040', 'c0600000-e29b-41d4-a716-446655440007', 6, false),
  ('aaa00000-0000-0000-0000-000000000040', 'c0600000-e29b-41d4-a716-446655440008', 7, true)
ON CONFLICT DO NOTHING;

-- -------------------------------------------------------
-- Path 41: Corinthians: Christ and His Church
-- Category: Epistles | Level: disciple | 29 topics (1-2 Corinthians)
-- -------------------------------------------------------
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000041',
  'corinthians-christ-and-his-church',
  'Corinthians: Christ and His Church',
  'Paul writes two letters to a gifted but deeply divided church, tackling everything from fighting and lawsuits to marriage, spiritual gifts, the resurrection, suffering, giving, and true leadership. In twenty-nine chapters, discover how the gospel reshapes every area of life and community. At the center stands the way of love, the reality of the risen Christ, and the power made perfect in weakness.',
  'groups', '#0EA5E9', 58, 'advanced', 'disciple', 'deep', false, 10, 'Epistles'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440001',  0, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440002',  1, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440003',  2, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440004',  3, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440005',  4, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440006',  5, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440007',  6, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440008',  7, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440009',  8, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440010',  9, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440011', 10, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440012', 11, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440013', 12, true),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440014', 13, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440015', 14, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440016', 15, true),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440017', 16, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440018', 17, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440019', 18, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440020', 19, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440021', 20, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440022', 21, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440023', 22, true),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440024', 23, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440025', 24, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440026', 25, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440027', 26, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440028', 27, false),
  ('aaa00000-0000-0000-0000-000000000041', 'c0700000-e29b-41d4-a716-446655440029', 28, true)
ON CONFLICT DO NOTHING;


-- =====================================================
-- PART 3: LEARNING PATH TRANSLATIONS (Hindi + Malayalam)
-- =====================================================

-- P35: Ephesians
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000035', 'hi',
   'इफिसियों: मसीह में धन',
   'इफिसियों की पत्री परमेश्वर के बारे में गहरी सच्चाइयों से दैनिक जीवन की व्यावहारिक सलाह तक जाती है। छह अध्यायों में मसीह में आत्मिक आशीषें, अनुग्रह से उद्धार, कलीसिया का रहस्य, योग्य चलना, विवाह का सुसमाचार चित्र, और आत्मिक युद्ध के हथियार खोजें।'),
  ('aaa00000-0000-0000-0000-000000000035', 'ml',
   'എഫെസ്യർ: ക്രിസ്തുവിലെ സമ്പത്ത്',
   'എഫെസ്യർ ലേഖനം ദൈവത്തെ കുറിച്ചുള്ള ആഴമായ സത്യങ്ങളിൽ നിന്ന് ദൈനംദിന ജീവിതത്തിനുള്ള പ്രായോഗിക ഉപദേശത്തിലേക്ക് നീങ്ങുന്നു. ആറ് അദ്ധ്യായങ്ങളിൽ ക്രിസ്തുവിലെ ആത്മീയ അനുഗ്രഹങ്ങൾ, കൃപയാലുള്ള രക്ഷ, സഭയുടെ രഹസ്യം, യോഗ്യമായി നടക്കൽ, വിവാഹം സുവിശേഷ ചിത്രമായി, ആത്മീയ യുദ്ധത്തിന്റെ ആയുധങ്ങൾ കണ്ടെത്തുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;

-- P36: James
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000036', 'hi',
   'याकूब: कर्म करने वाला विश्वास',
   'याकूब नए नियम का सबसे व्यावहारिक पत्र लिखता है — विश्वास जो कर्मों में साबित होता है। पाँच अध्यायों में परीक्षाओं का सामना, जीभ की शक्ति, पक्षपात का खतरा, नम्रता का आह्वान, और धैर्यपूर्ण प्रार्थना की शक्ति पाएँ।'),
  ('aaa00000-0000-0000-0000-000000000036', 'ml',
   'യാക്കോബ്: പ്രവൃത്തിയിലൂടെ വിശ്വാസം',
   'പുതിയ നിയമത്തിലെ ഏറ്റവും പ്രായോഗികമായ ലേഖനം യാക്കോബ് എഴുതുന്നു — പ്രവൃത്തിയിൽ തെളിയിക്കപ്പെടുന്ന വിശ്വാസം. അഞ്ച് അദ്ധ്യായങ്ങളിൽ പരീക്ഷകൾ, നാവിന്റെ ശക്തി, പക്ഷപാതത്തിന്റെ അപകടം, എളിമയുടെ ആഹ്വാനം, ക്ഷമയോടെയുള്ള പ്രാർഥനയുടെ ശക്തി കണ്ടെത്തുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;

-- P37: John's Letters
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000037', 'hi',
   'यूहन्ना के पत्र: ज्योति, प्रेम और सत्य',
   'प्रेरित यूहन्ना तीन पत्र लिखता है जो मसीह में बने रहने का पूरा चित्र प्रस्तुत करते हैं। 1 यूहन्ना में सच्चे विश्वास की परीक्षाएँ खोजें — ज्योति में चलना, आज्ञा मानना, और एक दूसरे से प्रेम करना। 2 यूहन्ना उन धोखेबाजों के विरुद्ध चेतावनी देता है जो मसीह के शरीर में आने से इनकार करते हैं। 3 यूहन्ना विश्वसनीय आतिथ्य की सराहना करता है।'),
  ('aaa00000-0000-0000-0000-000000000037', 'ml',
   'യോഹന്നാന്റെ ലേഖനങ്ങൾ: വെളിച്ചം, സ്നേഹം, സത്യം',
   'ക്രിസ്തുവിൽ നിലനിൽക്കുക എന്നതിന്റെ പൂർണ്ണ ചിത്രം വരയ്ക്കുന്ന മൂന്ന് ലേഖനങ്ങൾ അപ്പൊസ്തലനായ യോഹന്നാൻ എഴുതുന്നു. 1 യോഹന്നാനിൽ യഥാർഥ വിശ്വാസത്തിന്റെ പരീക്ഷണങ്ങൾ — വെളിച്ചത്തിൽ നടക്കൽ, കൽപ്പനകൾ പാലിക്കൽ, പരസ്പരം സ്നേഹിക്കൽ. 2 യോഹന്നാൻ ക്രിസ്തു ജഡത്തിൽ വന്നതിനെ നിഷേധിക്കുന്ന വഞ്ചകരെ കുറിച്ച് മുന്നറിയിപ്പ് നൽകുന്നു. 3 യോഹന്നാൻ വിശ്വസ്ത ആതിഥ്യത്തെ പ്രശംസിക്കുന്നു.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;

-- P38: Philippians
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000038', 'hi',
   'फिलिप्पियों: मसीह में आनंद',
   'रोमी कैदखाने से लिखा गया यह पत्र आनंद से भरपूर है। चार अध्यायों में पौलुस संतोष का रहस्य, मसीह का मन जिसने खुद को दीन किया, यीशु को जानने की अनुपम श्रेष्ठता, और हर दिल की रक्षा करने वाली शांति प्रकट करता है।'),
  ('aaa00000-0000-0000-0000-000000000038', 'ml',
   'ഫിലിപ്പിയർ: ക്രിസ്തുവിലെ സന്തോഷം',
   'റോമൻ തടവറയിൽ നിന്ന് എഴുതിയ ഈ ലേഖനം സന്തോഷം നിറഞ്ഞതാണ്. നാല് അദ്ധ്യായങ്ങളിൽ പൗലോസ് തൃപ്തിയുടെ രഹസ്യം, തന്നെത്തന്നെ ശൂന്യമാക്കിയ ക്രിസ്തുവിന്റെ മനസ്സ്, യേശുവിനെ അറിയുന്നതിന്റെ അത്യുന്നത മൂല്യം, എല്ലാ ഹൃദയത്തെയും കാക്കുന്ന സമാധാനം വെളിപ്പെടുത്തുന്നു.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;

-- P39: Galatians
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000039', 'hi',
   'गलातियों: सुसमाचार की स्वतंत्रता',
   'पौलुस का सबसे उत्कट पत्र उन लोगों के विरुद्ध सुसमाचार की रक्षा करता है जो मसीह में विश्वास में व्यवस्था के कर्म जोड़ना चाहते हैं। छह अध्यायों में जानें कि कोई दूसरा सुसमाचार क्यों नहीं है, केवल विश्वास से धार्मिकता कैसे आती है, प्रतिज्ञा और व्यवस्था का संबंध, पुत्र होने का अर्थ, और आत्मा में सच्ची स्वतंत्रता।'),
  ('aaa00000-0000-0000-0000-000000000039', 'ml',
   'ഗലാത്യർ: സുവിശേഷ സ്വാതന്ത്ര്യം',
   'ക്രിസ്തുവിലുള്ള വിശ്വാസത്തിൽ ന്യായപ്രമാണത്തിന്റെ പ്രവൃത്തികൾ ചേർക്കാൻ ശ്രമിക്കുന്നവർക്കെതിരെ സുവിശേഷത്തെ സംരക്ഷിക്കുന്ന പൗലോസിന്റെ ഏറ്റവും തീക്ഷ്ണമായ ലേഖനം. ആറ് അദ്ധ്യായങ്ങളിൽ മറ്റൊരു സുവിശേഷം ഇല്ലാത്തത് എന്തുകൊണ്ട്, വിശ്വാസത്താൽ മാത്രം നീതി, വാഗ്ദത്തവും ന്യായപ്രമാണവും തമ്മിലുള്ള ബന്ധം, പുത്രത്വം, ആത്മാവിലുള്ള യഥാർഥ സ്വാതന്ത്ര്യം കണ്ടെത്തുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;

-- P40: Peter's Letters
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000040', 'hi',
   'पतरस के पत्र: आशा और धीरज',
   'पतरस बिखरे हुए विश्वासियों को दो पत्र लिखता है जो शत्रुता और झूठी शिक्षा का सामना कर रहे हैं। 1 पतरस में पुनरुत्थान की जीवित आशा, परमेश्वर के पवित्र लोगों की पहचान, दुख में मसीह का उदाहरण, और शैतान का विरोध करने वाली नम्रता खोजें। 2 पतरस में बहुमूल्य प्रतिज्ञाओं से भक्ति में बढ़ें, झूठे शिक्षकों को पहचानें, और प्रभु के दिन की प्रतीक्षा करें।'),
  ('aaa00000-0000-0000-0000-000000000040', 'ml',
   'പത്രോസിന്റെ ലേഖനങ്ങൾ: പ്രത്യാശയും സഹനവും',
   'ശത്രുതയും വ്യാജ ഉപദേശവും നേരിടുന്ന ചിതറിപ്പോയ വിശ്വാസികൾക്ക് പത്രോസ് രണ്ട് ലേഖനങ്ങൾ എഴുതുന്നു. 1 പത്രോസിൽ പുനരുത്ഥാനത്തിന്റെ ജീവനുള്ള പ്രത്യാശ, ദൈവജനത്തിന്റെ സ്വത്വം, കഷ്ടതയിൽ ക്രിസ്തുവിന്റെ മാതൃക, പിശാചിനെ ചെറുക്കുന്ന എളിമ കണ്ടെത്തുക. 2 പത്രോസിൽ വിലയേറിയ വാഗ്ദത്തങ്ങളിലൂടെ ഭക്തിയിൽ വളരുക, വ്യാജ ഉപദേഷ്ടാക്കളെ തിരിച്ചറിയുക, കർത്താവിന്റെ ദിവസത്തിനായി കാത്തിരിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;

-- P41: Corinthians
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000041', 'hi',
   'कुरिन्थियों: मसीह और उसकी कलीसिया',
   'पौलुस एक प्रतिभाशाली पर गहरे विभाजित कलीसिया को दो पत्र लिखता है — गुटों, मुकदमों, विवाह, आत्मिक वरदानों, पुनरुत्थान, दुख, उदारता, और प्रेरिताई अधिकार को संबोधित करता है। उनतीस अध्यायों में जानें कि सुसमाचार जीवन और समुदाय के हर क्षेत्र को कैसे बदलता है। केंद्र में प्रेम का मार्ग, जीवित मसीह की सच्चाई, और निर्बलता में सिद्ध होने वाली सामर्थ्य है।'),
  ('aaa00000-0000-0000-0000-000000000041', 'ml',
   'കൊരിന്ത്യർ: ക്രിസ്തുവും അവന്റെ സഭയും',
   'കഴിവുള്ളതും എന്നാൽ ആഴത്തിൽ ഭിന്നിച്ചതുമായ ഒരു സഭയ്ക്ക് പൗലോസ് രണ്ട് ലേഖനങ്ങൾ എഴുതുന്നു — വിഭാഗങ്ങൾ, വ്യവഹാരങ്ങൾ, വിവാഹം, ആത്മീയ വരങ്ങൾ, പുനരുത്ഥാനം, കഷ്ടത, ഔദാര്യം, അപ്പൊസ്തല അധികാരം എന്നിവ ചർച്ച ചെയ്യുന്നു. ഇരുപത്തൊമ്പത് അദ്ധ്യായങ്ങളിൽ സുവിശേഷം ജീവിതത്തിന്റെയും സമൂഹത്തിന്റെയും എല്ലാ മേഖലകളെയും പുനർരൂപീകരിക്കുന്നു. സ്നേഹത്തിന്റെ മാർഗ്ഗവും ഉയിർത്തെഴുന്നേറ്റ ക്രിസ്തുവിന്റെ യാഥാർഥ്യവും ബലഹീനതയിൽ തികവുറ്റ ശക്തിയും കേന്ദ്രത്തിൽ നിൽക്കുന്നു.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- =====================================================
-- PART 4: TOPIC TRANSLATIONS (Hindi + Malayalam)
-- =====================================================

-- Ephesians (6 topics × 2 = 12 rows)
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES
  ('c0100000-e29b-41d4-a716-446655440001', 'hi', 'इफिसियों 1: मसीह में धन्य', 'इफिसियों 1 पढ़ें। पौलुस मसीह में आत्मिक आशीषों के लिए स्तुति से शुरू करता है — जगत की नींव से पहले चुने गए, गोद लेने के लिए ठहराए गए, उसके लहू से छुटकारा पाए, प्रतिज्ञा किए गए पवित्र आत्मा से मुहर लगाए। हर आशीष पिता के अनंत उद्देश्य से बहती है।', 'विश्वास की नींव'),
  ('c0100000-e29b-41d4-a716-446655440001', 'ml', 'എഫെസ്യർ 1: ക്രിസ്തുവിൽ അനുഗ്രഹിക്കപ്പെട്ടവർ', 'എഫെസ്യർ 1 വായിക്കുക. ക്രിസ്തുവിലെ ആത്മീയ അനുഗ്രഹങ്ങൾക്കായുള്ള സ്തുതിയോടെ പൗലോസ് ആരംഭിക്കുന്നു — ലോകസ്ഥാപനത്തിന് മുമ്പ് തിരഞ്ഞെടുക്കപ്പെട്ടു, ദത്തെടുക്കലിനായി മുമ്പേ തന്നെ തീരുമാനിക്കപ്പെട്ടു, അവന്റെ രക്തത്താൽ വീണ്ടെടുക്കപ്പെട്ടു, വാഗ്ദത്ത പരിശുദ്ധാത്മാവിനാൽ മുദ്രയിടപ്പെട്ടു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0100000-e29b-41d4-a716-446655440002', 'hi', 'इफिसियों 2: मृत्यु से जीवन तक', 'इफिसियों 2 पढ़ें। पौलुस मसीह के बिना मनुष्य की दशा बताता है — अपराधों और पापों में मरे हुए। परंतु परमेश्वर ने दया से हमें मसीह के साथ जिलाया। "अनुग्रह ही से विश्वास के द्वारा तुम्हारा उद्धार हुआ है — यह तुम्हारी ओर से नहीं, परमेश्वर का दान है।" यहूदी और अन्यजाति एक नई मानवता में मिला दिए गए।', 'विश्वास की नींव'),
  ('c0100000-e29b-41d4-a716-446655440002', 'ml', 'എഫെസ്യർ 2: മരണത്തിൽ നിന്ന് ജീവനിലേക്ക്', 'എഫെസ്യർ 2 വായിക്കുക. ക്രിസ്തുവില്ലാതെ മനുഷ്യന്റെ അവസ്ഥ — അതിക്രമങ്ങളിലും പാപങ്ങളിലും മരിച്ചവർ. എന്നാൽ കരുണ നിറഞ്ഞ ദൈവം നമ്മെ ക്രിസ്തുവിനോടൊപ്പം ജീവിപ്പിച്ചു. "കൃപയാൽ വിശ്വാസം മൂലം നിങ്ങൾ രക്ഷിക്കപ്പെട്ടിരിക്കുന്നു — ഇത് ദൈവത്തിന്റെ ദാനമാണ്." യഹൂദനും വിജാതീയനും ഒരു പുതിയ മനുഷ്യത്വത്തിൽ ഒന്നാക്കപ്പെട്ടു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0100000-e29b-41d4-a716-446655440003', 'hi', 'इफिसियों 3: प्रकट किया गया रहस्य', 'इफिसियों 3 पढ़ें। पौलुस युगों से छिपा रहस्य प्रकट करता है: अन्यजाति इस्राएल के साथ सह-उत्तराधिकारी हैं। फिर वह एक शक्तिशाली प्रार्थना करता है — कि विश्वासी भीतरी मनुष्यत्व में सामर्थ्य पाएँ, प्रेम में जड़ पकड़ें, और परमेश्वर की परिपूर्णता से भर जाएँ।', 'विश्वास की नींव'),
  ('c0100000-e29b-41d4-a716-446655440003', 'ml', 'എഫെസ്യർ 3: വെളിപ്പെട്ട രഹസ്യം', 'എഫെസ്യർ 3 വായിക്കുക. യുഗങ്ങളായി മറഞ്ഞിരുന്ന രഹസ്യം പൗലോസ് വെളിപ്പെടുത്തുന്നു: വിജാതീയർ യിസ്രായേലിനൊപ്പം ദൈവത്തിന്റെ കുടുംബത്തിൽ തുല്യ അവകാശികളാണ്. പിന്നെ അദ്ദേഹം ശക്തമായ ഒരു പ്രാർഥന പ്രാർഥിക്കുന്നു — വിശ്വാസികൾ ഉള്ളിലെ മനുഷ്യനിൽ ശക്തിപ്പെടണം, സ്നേഹത്തിൽ വേരൂന്നണം, ദൈവത്തിന്റെ സമ്പൂർണ്ണത കൊണ്ട് നിറയണം.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0100000-e29b-41d4-a716-446655440004', 'hi', 'इफिसियों 4: योग्य चलना', 'इफिसियों 4 पढ़ें। पौलुस सिद्धांत से अभ्यास की ओर जाता है: "जिस बुलाहट से तुम बुलाए गए हो उसके योग्य चलो।" एकता सात बातों पर आधारित है — एक शरीर, एक आत्मा, एक प्रभु, एक विश्वास। पुराने मनुष्यत्व को उतारो और नए को पहनो।', 'विश्वास की नींव'),
  ('c0100000-e29b-41d4-a716-446655440004', 'ml', 'എഫെസ്യർ 4: യോഗ്യമായി നടക്കൽ', 'എഫെസ്യർ 4 വായിക്കുക. പൗലോസ് ഉപദേശത്തിൽ നിന്ന് ജീവിതത്തിലേക്ക് മാറുന്നു: "നിങ്ങളുടെ വിളിക്ക് യോഗ്യമായി നടക്കുക." ഏഴ് കാര്യങ്ങളിൽ അടിസ്ഥാനമിട്ട ഐക്യം — ഒരു ശരീരം, ഒരു ആത്മാവ്, ഒരു കർത്താവ്, ഒരു വിശ്വാസം. പഴയ മനുഷ്യനെ ഉരിഞ്ഞ് പുതിയതിനെ ധരിക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0100000-e29b-41d4-a716-446655440005', 'hi', 'इफिसियों 5: ज्योति की संतान', 'इफिसियों 5 पढ़ें। पौलुस विश्वासियों को ज्योति की संतान के रूप में जीने के लिए बुलाता है। विवाह मसीह और कलीसिया के संबंध का प्रतिबिंब है: मसीह ने कलीसिया से प्रेम किया और अपने आप को उसके लिए दे दिया। यह विवाह के बारे में नए नियम की सबसे स्पष्ट शिक्षा है।', 'विश्वास की नींव'),
  ('c0100000-e29b-41d4-a716-446655440005', 'ml', 'എഫെസ്യർ 5: വെളിച്ചത്തിന്റെ മക്കൾ', 'എഫെസ്യർ 5 വായിക്കുക. വെളിച്ചത്തിന്റെ മക്കളായി ജീവിക്കാൻ പൗലോസ് വിശ്വാസികളെ വിളിക്കുന്നു. വിവാഹം ക്രിസ്തുവും സഭയും തമ്മിലുള്ള ബന്ധത്തിന്റെ പ്രതിഫലനമാണ്: ക്രിസ്തു സഭയെ സ്നേഹിച്ച് തന്നെത്തന്നെ അവൾക്കായി നൽകി. ഇത് വിവാഹത്തെ കുറിച്ചുള്ള ഏറ്റവും വ്യക്തമായ പുതിയ നിയമ പഠിപ്പിക്കലാണ്.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0100000-e29b-41d4-a716-446655440006', 'hi', 'इफिसियों 6: परमेश्वर का हथियार', 'इफिसियों 6 पढ़ें। पौलुस आत्मिक युद्ध के लिए बुलाता है। लड़ाई माँस और लहू के विरुद्ध नहीं बल्कि अंधकार की आत्मिक शक्तियों के विरुद्ध है। सत्य की कमरबंदी, धार्मिकता की झिलम, सुसमाचार के जूते, विश्वास की ढाल, उद्धार का टोप, और आत्मा की तलवार पहनो। सदा प्रार्थना करो।', 'विश्वास की नींव'),
  ('c0100000-e29b-41d4-a716-446655440006', 'ml', 'എഫെസ്യർ 6: ദൈവത്തിന്റെ ആയുധവർഗ്ഗം', 'എഫെസ്യർ 6 വായിക്കുക. ആത്മീയ യുദ്ധത്തിനായി പൗലോസ് വിളിക്കുന്നു. പോരാട്ടം മനുഷ്യരോടല്ല, ഇരുളിന്റെ ആത്മീയ ശക്തികളോടാണ്. സത്യത്തിന്റെ അര, നീതിയുടെ കവചം, സുവിശേഷത്തിന്റെ ചെരിപ്പ്, വിശ്വാസത്തിന്റെ പരിച, രക്ഷയുടെ ശിരസ്ത്രം, ആത്മാവിന്റെ വാൾ ധരിക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- James (5 topics × 2 = 10 rows)
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES
  ('c0200000-e29b-41d4-a716-446655440001', 'hi', 'याकूब 1: परीक्षाएँ और सच्चा विश्वास', 'याकूब 1 पढ़ें। याकूब कहता है: जब परीक्षाएँ आएँ तो आनंद मानो, क्योंकि परखा हुआ विश्वास धीरज उत्पन्न करता है। बिना संदेह बुद्धि माँगो, परमेश्वर पर परीक्षा का दोष न लगाओ, और वचन के करने वाले बनो न कि केवल सुनने वाले।', 'विश्वास की नींव'),
  ('c0200000-e29b-41d4-a716-446655440001', 'ml', 'യാക്കോബ് 1: പരീക്ഷകളും യഥാർഥ വിശ്വാസവും', 'യാക്കോബ് 1 വായിക്കുക. പരീക്ഷകൾ വരുമ്പോൾ സന്തോഷിക്കുക, പരീക്ഷിക്കപ്പെട്ട വിശ്വാസം സഹനശക്തി ഉളവാക്കുന്നു. സംശയിക്കാതെ ജ്ഞാനം ചോദിക്കുക, പ്രലോഭനത്തിന് ദൈവത്തെ കുറ്റപ്പെടുത്തരുത്, വചനം കേൾക്കുന്നവർ മാത്രമല്ല ചെയ്യുന്നവരും ആകുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0200000-e29b-41d4-a716-446655440002', 'hi', 'याकूब 2: विश्वास और कर्म', 'याकूब 2 पढ़ें। कलीसिया में पक्षपात मत करो। याकूब का सबसे प्रसिद्ध तर्क: कर्म बिना विश्वास मरा हुआ है। इब्राहीम को कर्मों से धर्मी ठहराया गया — पौलुस के विरोध में नहीं, बल्कि सबूत के रूप में कि बचाने वाला विश्वास हमेशा दिखाई देने वाला फल लाता है।', 'विश्वास की नींव'),
  ('c0200000-e29b-41d4-a716-446655440002', 'ml', 'യാക്കോബ് 2: വിശ്വാസവും പ്രവൃത്തിയും', 'യാക്കോബ് 2 വായിക്കുക. സഭയിൽ പക്ഷപാതം കാണിക്കരുത്. യാക്കോബിന്റെ ഏറ്റവും പ്രശസ്തമായ വാദം: പ്രവൃത്തിയില്ലാത്ത വിശ്വാസം മരിച്ചതാണ്. അബ്രഹാം പ്രവൃത്തികളാൽ നീതീകരിക്കപ്പെട്ടു — പൗലോസിനെ എതിർക്കുന്നതല്ല, രക്ഷിക്കുന്ന വിശ്വാസം ദൃശ്യമായ ഫലം പുറപ്പെടുവിക്കുമെന്ന തെളിവാണ്.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0200000-e29b-41d4-a716-446655440003', 'hi', 'याकूब 3: जीभ पर काबू', 'याकूब 3 पढ़ें। जीभ छोटा अंग है पर पूरे जीवन को आग लगा देती है। याकूब सजीव चित्रण करता है — लगाम, पतवार, आग, ज़हर। कोई मनुष्य जीभ को वश में नहीं कर सकता। अंत में सांसारिक बुद्धि और स्वर्गीय बुद्धि की तुलना की गई है।', 'विश्वास की नींव'),
  ('c0200000-e29b-41d4-a716-446655440003', 'ml', 'യാക്കോബ് 3: നാവിനെ അടക്കൽ', 'യാക്കോബ് 3 വായിക്കുക. നാവ് ചെറിയ അവയവമാണ്, പക്ഷേ ജീവിതം മുഴുവൻ തീ കൊളുത്തുന്നു. യാക്കോബ് ജീവസുറ്റ ചിത്രങ്ങൾ ഉപയോഗിക്കുന്നു — കടിഞ്ഞാൺ, ചുക്കാൻ, തീ, വിഷം. ഭൂമിയിലെ ജ്ഞാനവും സ്വർഗ്ഗീയ ജ്ഞാനവും തമ്മിലുള്ള വ്യത്യാസം കാണിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0200000-e29b-41d4-a716-446655440004', 'hi', 'याकूब 4: परमेश्वर के सामने नम्रता', 'याकूब 4 पढ़ें। झगड़ों की जड़ भीतर की स्वार्थी इच्छाएँ हैं। परमेश्वर के अधीन हो जाओ, शैतान का विरोध करो। "परमेश्वर अभिमानियों का विरोध करता है पर नम्रों को अनुग्रह देता है।" दूसरों का न्याय मत करो और भविष्य की योजना में परमेश्वर की मर्ज़ी मानो।', 'विश्वास की नींव'),
  ('c0200000-e29b-41d4-a716-446655440004', 'ml', 'യാക്കോബ് 4: ദൈവത്തിന് മുമ്പിൽ താഴ്മ', 'യാക്കോബ് 4 വായിക്കുക. കലഹങ്ങളുടെ ഉറവിടം ഉള്ളിലെ സ്വാർഥമായ ആഗ്രഹങ്ങളാണ്. ദൈവത്തിന് കീഴടങ്ങുക, പിശാചിനോട് എതിർത്ത് നിൽക്കുക. "ദൈവം അഹങ്കാരികളെ ചെറുക്കുന്നു, താഴ്മയുള്ളവർക്ക് കൃപ നൽകുന്നു." പരസ്പരം ന്യായം വിധിക്കരുത്.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0200000-e29b-41d4-a716-446655440005', 'hi', 'याकूब 5: धैर्यपूर्ण सहनशीलता', 'याकूब 5 पढ़ें। याकूब धनवानों को चेतावनी देता है, विश्वासियों को किसान और अय्यूब की तरह धीरज रखने को कहता है। विश्वास की प्रार्थना रोगी को बचाएगी, और धर्मी जन की प्रार्थना में बड़ी शक्ति है। एलिय्याह ने प्रार्थना की और वर्षा रुक गई; फिर प्रार्थना की और वर्षा हुई।', 'विश्वास की नींव'),
  ('c0200000-e29b-41d4-a716-446655440005', 'ml', 'യാക്കോബ് 5: ക്ഷമയോടെയുള്ള സഹനം', 'യാക്കോബ് 5 വായിക്കുക. ധനികരെ മുന്നറിയിപ്പ് നൽകുന്നു, കർഷകനെയും ഇയ്യോബിനെയും പോലെ ക്ഷമിക്കാൻ വിളിക്കുന്നു. വിശ്വാസത്തിന്റെ പ്രാർഥന രോഗിയെ രക്ഷിക്കും, നീതിമാന്റെ പ്രാർഥനക്ക് വലിയ ശക്തിയുണ്ട്. ഏലിയാവ് പ്രാർഥിച്ചു, മഴ നിന്നു; വീണ്ടും പ്രാർഥിച്ചു, മഴ വന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- John's Letters (7 topics x 2 = 14 rows)
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES
  ('c0300000-e29b-41d4-a716-446655440001', 'hi', '1 यूहन्ना 1: ज्योति में चलना', '1 यूहन्ना 1 पढ़ें। परमेश्वर ज्योति है और उसमें कोई अंधकार नहीं। यदि हम ज्योति में चलें तो एक दूसरे से संगति रखते हैं और यीशु का लहू हमें सब पापों से शुद्ध करता है। यदि हम अपने पापों को मान लें तो वह विश्वसनीय और धर्मी है कि हमें क्षमा करे।', 'विश्वास की नींव'),
  ('c0300000-e29b-41d4-a716-446655440001', 'ml', '1 യോഹന്നാൻ 1: വെളിച്ചത്തിൽ നടക്കൽ', '1 യോഹന്നാൻ 1 വായിക്കുക. ദൈവം വെളിച്ചമാണ്, അവനിൽ ഇരുട്ട് ഇല്ല. നാം വെളിച്ചത്തിൽ നടന്നാൽ പരസ്പരം കൂട്ടായ്മ ഉണ്ട്, യേശുവിന്റെ രക്തം നമ്മെ എല്ലാ പാപത്തിൽ നിന്നും ശുദ്ധീകരിക്കുന്നു. പാപം ഏറ്റുപറഞ്ഞാൽ അവൻ ക്ഷമിക്കും.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0300000-e29b-41d4-a716-446655440002', 'hi', '1 यूहन्ना 2: सच्चे और झूठे की पहचान', '1 यूहन्ना 2 पढ़ें। यीशु मसीह धर्मी हमारा सहायक है। यूहन्ना सच्चे विश्वास की परीक्षाएँ देता है: आज्ञा मानना, यीशु जैसा चलना, भाइयों से प्रेम करना। मसीह-विरोधी निकल गए हैं — जो इनकार करते हैं कि यीशु ही मसीह है। मसीह में बने रहो।', 'विश्वास की नींव'),
  ('c0300000-e29b-41d4-a716-446655440002', 'ml', '1 യോഹന്നാൻ 2: സത്യവും അസത്യവും തിരിച്ചറിയൽ', '1 യോഹന്നാൻ 2 വായിക്കുക. നീതിമാനായ യേശുക്രിസ്തു നമുക്കുവേണ്ടി പിതാവിന്റെ മുമ്പിൽ സംസാരിക്കുന്നവനാണ്. യഥാർഥ വിശ്വാസത്തിന്റെ പരീക്ഷണങ്ങൾ: കൽപ്പനകൾ പാലിക്കൽ, യേശുവിനെ പോലെ നടക്കൽ, സഹോദരങ്ങളെ സ്നേഹിക്കൽ. എതിർക്രിസ്തുക്കൾ പുറപ്പെട്ടിരിക്കുന്നു. ക്രിസ്തുവിൽ നിലനിൽക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0300000-e29b-41d4-a716-446655440003', 'hi', '1 यूहन्ना 3: परमेश्वर का प्रेम', '1 यूहन्ना 3 पढ़ें। "देखो पिता ने हम से कैसा प्रेम किया है कि हम परमेश्वर की संतान कहलाएँ।" धार्मिकता का अभ्यास करने वाला धर्मी है। प्रेम सच्चे विश्वास की पहचान है: "हम जानते हैं कि हम मृत्यु से जीवन में आ गए हैं, क्योंकि हम भाइयों से प्रेम करते हैं।"', 'विश्वास की नींव'),
  ('c0300000-e29b-41d4-a716-446655440003', 'ml', '1 യോഹന്നാൻ 3: ദൈവത്തിന്റെ സ്നേഹം', '1 യോഹന്നാൻ 3 വായിക്കുക. "ദൈവമക്കൾ എന്ന് വിളിക്കപ്പെടാൻ പിതാവ് നമുക്ക് എത്ര വലിയ സ്നേഹം നൽകി." നീതി ചെയ്യുന്നവൻ നീതിമാൻ. സ്നേഹം യഥാർഥ വിശ്വാസത്തിന്റെ അടയാളം: "സഹോദരന്മാരെ സ്നേഹിക്കുന്നതിനാൽ നാം മരണത്തിൽ നിന്ന് ജീവനിലേക്ക് കടന്നു എന്ന് അറിയുന്നു."', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0300000-e29b-41d4-a716-446655440004', 'hi', '1 यूहन्ना 4: आत्माओं को परखो', '1 यूहन्ना 4 पढ़ें। आत्माओं को परखो: जो आत्मा मानती है कि यीशु मसीह शरीर में आया, वह परमेश्वर की है। परमेश्वर प्रेम है — अपने पुत्र को हमारे पापों की कीमत चुकाने भेजकर। "हम इसलिए प्रेम करते हैं क्योंकि उसने पहले हम से प्रेम किया।" सिद्ध प्रेम भय को दूर कर देता है।', 'विश्वास की नींव'),
  ('c0300000-e29b-41d4-a716-446655440004', 'ml', '1 യോഹന്നാൻ 4: ആത്മാക്കളെ പരീക്ഷിക്കൽ', '1 യോഹന്നാൻ 4 വായിക്കുക. ആത്മാക്കളെ പരീക്ഷിക്കുക: യേശുക്രിസ്തു ജഡത്തിൽ വന്നു എന്ന് ഏറ്റുപറയുന്ന ആത്മാവ് ദൈവത്തിൽ നിന്നുള്ളതാണ്. ദൈവം സ്നേഹമാണ് — പുത്രനെ നമ്മുടെ പാപങ്ങൾക്ക് വില കൊടുക്കാനായി അയച്ചു. "അവൻ ആദ്യം നമ്മെ സ്നേഹിച്ചതുകൊണ്ട് നാം സ്നേഹിക്കുന്നു." തികഞ്ഞ സ്നേഹം ഭയത്തെ പുറത്താക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0300000-e29b-41d4-a716-446655440005', 'hi', '1 यूहन्ना 5: अनंत जीवन का आश्वासन', '1 यूहन्ना 5 पढ़ें। जो विश्वास करता है कि यीशु ही मसीह है वह परमेश्वर से जन्मा है। विश्वास ही वह जय है जो संसार पर जय पाती है। परमेश्वर ने हमें अनंत जीवन दिया है और यह जीवन उसके पुत्र में है। हम जान सकते हैं कि हमारे पास अनंत जीवन है।', 'विश्वास की नींव'),
  ('c0300000-e29b-41d4-a716-446655440005', 'ml', '1 യോഹന്നാൻ 5: നിത്യജീവന്റെ ഉറപ്പ്', '1 യോഹന്നാൻ 5 വായിക്കുക. യേശു ക്രിസ്തുവാണെന്ന് വിശ്വസിക്കുന്നവൻ ദൈവത്തിൽ നിന്ന് ജനിച്ചവനാണ്. വിശ്വാസം ലോകത്തെ ജയിക്കുന്ന വിജയമാണ്. ദൈവം നമുക്ക് നിത്യജീവൻ നൽകി, ആ ജീവൻ അവന്റെ പുത്രനിലാണ്. നിത്യജീവൻ ഉണ്ടെന്ന് നമുക്ക് അറിയാൻ കഴിയും.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  -- 2 John + 3 John (2 topics × 2 = 4 rows)
  ('c0300000-e29b-41d4-a716-446655440006', 'hi', '2 यूहन्ना: सत्य और प्रेम', '2 यूहन्ना पढ़ें। प्राचीन "चुनी हुई श्रीमती" को लिखता है — सत्य में चलो और एक दूसरे से प्रेम करो जैसा पिता ने आज्ञा दी। उन धोखेबाजों से सावधान रहो जो मानते नहीं कि यीशु मसीह शरीर में आया। ऐसे किसी को अपने घर में न लो, कहीं तुम उसके बुरे कामों में भागी न हो जाओ।', 'विश्वास की नींव'),
  ('c0300000-e29b-41d4-a716-446655440006', 'ml', '2 യോഹന്നാൻ: സത്യവും സ്നേഹവും', '2 യോഹന്നാൻ വായിക്കുക. മൂപ്പൻ "തിരഞ്ഞെടുക്കപ്പെട്ട സ്ത്രീക്ക്" എഴുതുന്നു — സത്യത്തിൽ നടക്കുക, പിതാവ് കൽപ്പിച്ചതുപോലെ പരസ്പരം സ്നേഹിക്കുക. യേശുക്രിസ്തു ജഡത്തിൽ വന്നതിനെ നിഷേധിക്കുന്ന വഞ്ചകരെ സൂക്ഷിക്കുക. അവരെ വീട്ടിൽ സ്വീകരിക്കരുത്, അവരുടെ ദുഷ്പ്രവൃത്തികളിൽ പങ്കാളിയാകാതിരിക്കാൻ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0300000-e29b-41d4-a716-446655440007', 'hi', '3 यूहन्ना: विश्वसनीय आतिथ्य', '3 यूहन्ना पढ़ें। प्राचीन अपने प्रिय गयुस को लिखता है, यात्रा करने वाले सेवकों के प्रति उसकी विश्वसनीय आतिथ्य की सराहना करता है। इसके विपरीत, दियुत्रिफेस अपने आप को बड़ा बनाना चाहता है, भाइयों का स्वागत नहीं करता, और जो करते हैं उन्हें कलीसिया से निकाल देता है। भलाई का अनुकरण करो, क्योंकि भलाई करने वाला परमेश्वर से है।', 'विश्वास की नींव'),
  ('c0300000-e29b-41d4-a716-446655440007', 'ml', '3 യോഹന്നാൻ: വിശ്വസ്ത ആതിഥ്യം', '3 യോഹന്നാൻ വായിക്കുക. മൂപ്പൻ പ്രിയപ്പെട്ട ഗായോസിന് എഴുതുന്നു, സഞ്ചാരികളായ ശുശ്രൂഷകരോടുള്ള വിശ്വസ്ത ആതിഥ്യത്തെ പ്രശംസിക്കുന്നു. നേരെമറിച്ച്, ദിയോത്രെഫേസ് തന്നെത്തന്നെ ഉയർത്താൻ ഇഷ്ടപ്പെടുന്നു, സഹോദരന്മാരെ സ്വീകരിക്കുന്നില്ല, സ്വീകരിക്കുന്നവരെ സഭയിൽ നിന്ന് പുറത്താക്കുന്നു. നന്മ അനുകരിക്കുക, നന്മ ചെയ്യുന്നവൻ ദൈവത്തിൽ നിന്നുള്ളവനാണ്.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Philippians (4 topics × 2 = 8 rows)
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES
  ('c0400000-e29b-41d4-a716-446655440001', 'hi', 'फिलिप्पियों 1: सुसमाचार में आनंद', 'फिलिप्पियों 1 पढ़ें। पौलुस कैदखाने से आनंद से भरपूर लिखता है। वह भरोसा रखता है कि जिसने तुम में अच्छा काम शुरू किया वह उसे पूरा भी करेगा। "मेरे लिए जीवित रहना मसीह है और मरना लाभ है।"', 'विश्वास की नींव'),
  ('c0400000-e29b-41d4-a716-446655440001', 'ml', 'ഫിലിപ്പിയർ 1: സുവിശേഷത്തിലെ സന്തോഷം', 'ഫിലിപ്പിയർ 1 വായിക്കുക. തടവറയിൽ നിന്ന് സന്തോഷത്തോടെ പൗലോസ് എഴുതുന്നു. നല്ല പ്രവൃത്തി ആരംഭിച്ചവൻ അത് പൂർത്തിയാക്കുമെന്ന് ഉറപ്പുണ്ട്. "എനിക്ക് ജീവിക്കുന്നത് ക്രിസ്തുവും മരിക്കുന്നത് ലാഭവും."', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0400000-e29b-41d4-a716-446655440002', 'hi', 'फिलिप्पियों 2: मसीह का मन', 'फिलिप्पियों 2 पढ़ें। मसीह का मन रखो जिसने परमेश्वर के स्वरूप में होकर भी इसे पकड़ कर रखने की वस्तु न समझा, बल्कि दास का स्वरूप लेकर क्रूस की मृत्यु तक नम्र हो गया। इसलिए परमेश्वर ने उसे सर्वोच्च ठहराया। डर और काँपते हुए अपने उद्धार को जीवन में दिखाओ, क्योंकि परमेश्वर ही तुम में इच्छा और कर्म दोनों करता है। इसका मतलब उद्धार कमाना नहीं है — परमेश्वर ने जो तुम में किया है उसे जीवन में जिओ।', 'विश्वास की नींव'),
  ('c0400000-e29b-41d4-a716-446655440002', 'ml', 'ഫിലിപ്പിയർ 2: ക്രിസ്തുവിന്റെ മനസ്സ്', 'ഫിലിപ്പിയർ 2 വായിക്കുക. ക്രിസ്തുവിന്റെ മനസ്സ് ധരിക്കുക — ദൈവരൂപത്തിൽ ഇരുന്നിട്ടും ദാസരൂപം എടുത്ത്, ക്രൂശുമരണം വരെ തന്നെത്തന്നെ താഴ്ത്തി. അതിനാൽ ദൈവം അവനെ ഉയർത്തി. ഭയത്തോടും വിറയലോടും നിങ്ങളുടെ രക്ഷ ജീവിതത്തിൽ പ്രകടമാക്കുക, കാരണം ദൈവം തന്നെ നിങ്ങളിൽ ഇച്ഛയും പ്രവൃത്തിയും ഉളവാക്കുന്നു. ഇത് രക്ഷ സമ്പാദിക്കുക എന്നല്ല — ദൈവം നിങ്ങളിൽ ചെയ്തത് ജീവിതത്തിൽ പ്രകടമാക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0400000-e29b-41d4-a716-446655440003', 'hi', 'फिलिप्पियों 3: लक्ष्य की ओर दौड़ना', 'फिलिप्पियों 3 पढ़ें। पौलुस मसीह यीशु को जानने की श्रेष्ठता के कारण सब कुछ हानि समझता है। यहूदी धर्म में उसकी योग्यता निर्दोष थी — पर वह सब कूड़ा गिनता है ताकि मसीह को पा ले। वह अभी पूरा नहीं हुआ पर परमेश्वर की ऊपरी बुलाहट के पुरस्कार के लिए आगे बढ़ता है।', 'विश्वास की नींव'),
  ('c0400000-e29b-41d4-a716-446655440003', 'ml', 'ഫിലിപ്പിയർ 3: ലക്ഷ്യത്തിലേക്ക് ഓട്ടം', 'ഫിലിപ്പിയർ 3 വായിക്കുക. ക്രിസ്തുയേശുവിനെ അറിയുന്നതിന്റെ ശ്രേഷ്ഠത നിമിത്തം പൗലോസ് എല്ലാം നഷ്ടമായി എണ്ണുന്നു. യഹൂദമതത്തിലെ യോഗ്യതകൾ കുറ്റമറ്റതായിരുന്നു — എന്നാൽ ക്രിസ്തുവിനെ നേടാൻ അവയെ ചപ്പുചവറായി കണക്കാക്കുന്നു. ദൈവത്തിന്റെ ഉയർന്ന വിളിയുടെ സമ്മാനത്തിനായി മുന്നോട്ട് ഓടുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0400000-e29b-41d4-a716-446655440004', 'hi', 'फिलिप्पियों 4: सदा आनंदित रहो', 'फिलिप्पियों 4 पढ़ें। "प्रभु में सदा आनंदित रहो; मैं फिर कहता हूँ, आनंदित रहो।" हर बात में प्रार्थना और धन्यवाद के साथ परमेश्वर से माँगो, और परमेश्वर की शांति तुम्हारे हृदय की रक्षा करेगी। पौलुस ने हर हालत में संतोष का रहस्य सीखा — "जो मुझे सामर्थ्य देता है उसके द्वारा मैं सब कुछ कर सकता हूँ।"', 'विश्वास की नींव'),
  ('c0400000-e29b-41d4-a716-446655440004', 'ml', 'ഫിലിപ്പിയർ 4: എപ്പോഴും സന്തോഷിക്കുക', 'ഫിലിപ്പിയർ 4 വായിക്കുക. "കർത്താവിൽ എപ്പോഴും സന്തോഷിക്കുക; ഞാൻ വീണ്ടും പറയുന്നു, സന്തോഷിക്കുക." എല്ലാ കാര്യത്തിലും പ്രാർഥനയോടും സ്തോത്രത്തോടും ദൈവത്തോട് ചോദിക്കുക; ദൈവത്തിന്റെ സമാധാനം ഹൃദയത്തെ കാക്കും. എല്ലാ സാഹചര്യത്തിലും തൃപ്തിയുടെ രഹസ്യം പൗലോസ് പഠിച്ചു — "എന്നെ ശക്തനാക്കുന്നവനിൽ ഞാൻ എല്ലാം ചെയ്യാൻ കഴിയും."', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Galatians (6 topics × 2 = 12 rows)
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES
  ('c0500000-e29b-41d4-a716-446655440001', 'hi', 'गलातियों 1: कोई दूसरा सुसमाचार नहीं', 'गलातियों 1 पढ़ें। पौलुस चकित है कि गलातिया के विश्वासी इतनी जल्दी दूसरे सुसमाचार की ओर फिर रहे हैं। उसका सुसमाचार मनुष्यों से नहीं बल्कि यीशु मसीह के प्रकाशन से मिला। वह मनुष्यों को नहीं बल्कि परमेश्वर को प्रसन्न करना चाहता है।', 'विश्वास की नींव'),
  ('c0500000-e29b-41d4-a716-446655440001', 'ml', 'ഗലാത്യർ 1: മറ്റൊരു സുവിശേഷം ഇല്ല', 'ഗലാത്യർ 1 വായിക്കുക. ഗലാത്യർ ഇത്ര വേഗം മറ്റൊരു സുവിശേഷത്തിലേക്ക് മാറുന്നതിൽ പൗലോസ് അത്ഭുതപ്പെടുന്നു. അവന്റെ സുവിശേഷം മനുഷ്യരിൽ നിന്നല്ല, യേശുക്രിസ്തുവിന്റെ വെളിപാടിൽ നിന്നാണ്. മനുഷ്യരെയല്ല ദൈവത്തെ പ്രസാദിപ്പിക്കാൻ ആഗ്രഹിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0500000-e29b-41d4-a716-446655440002', 'hi', 'गलातियों 2: विश्वास से धर्मी ठहरना', 'गलातियों 2 पढ़ें। पौलुस ने पतरस का सामना किया जब वह पाखंड से यहूदी रीतियों की ओर लौटा। कोई भी व्यक्ति व्यवस्था के कामों से नहीं बल्कि मसीह यीशु पर विश्वास से धर्मी ठहरता है। "मैं मसीह के साथ क्रूस पर चढ़ाया गया; अब मैं नहीं जीता, मसीह मुझ में जीता है।"', 'विश्वास की नींव'),
  ('c0500000-e29b-41d4-a716-446655440002', 'ml', 'ഗലാത്യർ 2: വിശ്വാസത്താൽ നീതീകരണം', 'ഗലാത്യർ 2 വായിക്കുക. യഹൂദ ആചാരങ്ങളിലേക്ക് കപടഭക്തിയോടെ മടങ്ങിയ പത്രോസിനെ പൗലോസ് എതിർത്തു. ന്യായപ്രമാണത്തിന്റെ പ്രവൃത്തികളാലല്ല, ക്രിസ്തുയേശുവിലുള്ള വിശ്വാസത്താലാണ് നീതീകരിക്കപ്പെടുന്നത്. "ക്രിസ്തുവിനോടുകൂടെ ഞാൻ ക്രൂശിക്കപ്പെട്ടു; ഇനി ജീവിക്കുന്നത് ഞാനല്ല, ക്രിസ്തു എന്നിൽ ജീവിക്കുന്നു."', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0500000-e29b-41d4-a716-446655440003', 'hi', 'गलातियों 3: वादा और व्यवस्था', 'गलातियों 3 पढ़ें। अब्राहम ने विश्वास किया और यह उसके लिए धार्मिकता गिना गया। व्यवस्था मसीह तक पहुँचाने वाला शिक्षक थी। अब विश्वास के द्वारा तुम सब मसीह यीशु में परमेश्वर की संतान हो — न यहूदी न यूनानी, न दास न स्वतंत्र, न पुरुष न स्त्री।', 'विश्वास की नींव'),
  ('c0500000-e29b-41d4-a716-446655440003', 'ml', 'ഗലാത്യർ 3: വാഗ്ദാനവും ന്യായപ്രമാണവും', 'ഗലാത്യർ 3 വായിക്കുക. അബ്രഹാം വിശ്വസിച്ചു, അത് നീതിയായി കണക്കാക്കപ്പെട്ടു. ന്യായപ്രമാണം ക്രിസ്തുവിലേക്ക് നയിക്കുന്ന ശിക്ഷകനായിരുന്നു. ഇപ്പോൾ വിശ്വാസത്താൽ നിങ്ങൾ ക്രിസ്തുയേശുവിൽ ദൈവമക്കളാണ് — യഹൂദനോ ഗ്രീക്കുകാരനോ, അടിമയോ സ്വതന്ത്രനോ, ആണോ പെണ്ണോ എന്ന വ്യത്യാസമില്ല.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0500000-e29b-41d4-a716-446655440004', 'hi', 'गलातियों 4: पुत्र और उत्तराधिकारी', 'गलातियों 4 पढ़ें। अब तुम दास नहीं बल्कि पुत्र हो, और परमेश्वर ने अपने पुत्र की आत्मा तुम्हारे हृदय में भेजी है जो "अब्बा, पिता" पुकारती है। पौलुस गलातियों से विनती करता है कि वे व्यवस्था की दासता में न लौटें। हागार और सारा का रूपक स्वतंत्रता और दासता के बीच अंतर दिखाता है।', 'विश्वास की नींव'),
  ('c0500000-e29b-41d4-a716-446655440004', 'ml', 'ഗലാത്യർ 4: പുത്രന്മാരും അവകാശികളും', 'ഗലാത്യർ 4 വായിക്കുക. ഇനി നിങ്ങൾ അടിമകളല്ല, പുത്രന്മാരാണ്; ദൈവം തന്റെ പുത്രന്റെ ആത്മാവിനെ "അബ്ബാ, പിതാവേ" എന്ന് വിളിക്കുന്ന നിങ്ങളുടെ ഹൃദയത്തിലേക്ക് അയച്ചു. ന്യായപ്രമാണത്തിന്റെ അടിമത്തത്തിലേക്ക് മടങ്ങരുതെന്ന് പൗലോസ് അപേക്ഷിക്കുന്നു. ഹാഗാറിന്റെയും സാറയുടെയും ഉപമ സ്വാതന്ത്ര്യവും അടിമത്തവും തമ്മിലുള്ള വ്യത്യാസം കാണിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0500000-e29b-41d4-a716-446655440005', 'hi', 'गलातियों 5: मसीह में स्वतंत्रता', 'गलातियों 5 पढ़ें। "मसीह ने हमें स्वतंत्रता के लिए स्वतंत्र किया है।" शरीर के काम प्रकट हैं, लेकिन आत्मा का फल प्रेम, आनंद, शांति, धीरज, कृपालुता, भलाई, विश्वासयोग्यता, नम्रता और संयम है। आत्मा के अनुसार चलो तो शरीर की अभिलाषा पूरी न करोगे।', 'विश्वास की नींव'),
  ('c0500000-e29b-41d4-a716-446655440005', 'ml', 'ഗലാത്യർ 5: ക്രിസ്തുവിലെ സ്വാതന്ത്ര്യം', 'ഗലാത്യർ 5 വായിക്കുക. "ക്രിസ്തു നമ്മെ സ്വാതന്ത്ര്യത്തിനായി സ്വതന്ത്രരാക്കി." ജഡത്തിന്റെ പ്രവൃത്തികൾ പ്രകടമാണ്, എന്നാൽ ആത്മാവിന്റെ ഫലം സ്നേഹം, സന്തോഷം, സമാധാനം, ക്ഷമ, ദയ, നന്മ, വിശ്വസ്തത, സൗമ്യത, ആത്മസംയമനം. ആത്മാവിനാൽ നടക്കുക, ജഡമോഹം നിവർത്തിക്കുകയില്ല.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0500000-e29b-41d4-a716-446655440006', 'hi', 'गलातियों 6: एक दूसरे के बोझ उठाओ', 'गलातियों 6 पढ़ें। एक दूसरे के बोझ उठाकर मसीह की व्यवस्था पूरी करो। मनुष्य जो बोता है वही काटता है — शरीर के लिए बोने वाला विनाश काटेगा, आत्मा के लिए बोने वाला अनंत जीवन। भलाई करते न थकें। "न खतना कुछ है न खतनारहित, बल्कि नई सृष्टि।"', 'विश्वास की नींव'),
  ('c0500000-e29b-41d4-a716-446655440006', 'ml', 'ഗലാത്യർ 6: ഒരുവന്റെ ഭാരം മറ്റൊരുവൻ ചുമക്കുക', 'ഗലാത്യർ 6 വായിക്കുക. ഒരുവന്റെ ഭാരം മറ്റൊരുവൻ ചുമന്ന് ക്രിസ്തുവിന്റെ ന്യായപ്രമാണം നിറവേറ്റുക. വിതയ്ക്കുന്നത് കൊയ്യും — ജഡത്തിന് വിതയ്ക്കുന്നവൻ നാശം കൊയ്യും, ആത്മാവിന് വിതയ്ക്കുന്നവൻ നിത്യജീവൻ. നന്മ ചെയ്യുന്നതിൽ മടുക്കരുത്. "പരിച്ഛേദനയല്ല, അപരിച്ഛേദനയുമല്ല, പുതിയ സൃഷ്ടിയാണ് പ്രധാനം."', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- 1 Peter (5 topics × 2 = 10 rows)
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES
  ('c0600000-e29b-41d4-a716-446655440001', 'hi', '1 पतरस 1: एक जीवित आशा', '1 पतरस 1 पढ़ें। परमेश्वर ने अपनी बड़ी दया से हमें यीशु मसीह के मरे हुओं में से पुनरुत्थान के द्वारा एक जीवित आशा के लिए नया जन्म दिया। तुम्हारा विश्वास परखा जाता है — सोने से भी बहुमूल्य — ताकि यीशु मसीह के प्रकट होने पर प्रशंसा, महिमा और आदर हो।', 'विश्वास की नींव'),
  ('c0600000-e29b-41d4-a716-446655440001', 'ml', '1 പത്രോസ് 1: ജീവനുള്ള പ്രത്യാശ', '1 പത്രോസ് 1 വായിക്കുക. ദൈവം തന്റെ മഹാകാരുണ്യത്താൽ യേശുക്രിസ്തുവിന്റെ പുനരുത്ഥാനത്തിലൂടെ നമ്മെ ജീവനുള്ള പ്രത്യാശയ്ക്കായി പുതുതായി ജനിപ്പിച്ചു. വിശ്വാസം പരീക്ഷിക്കപ്പെടുന്നു — സ്വർണത്തേക്കാൾ വിലയേറിയത് — യേശുക്രിസ്തു വെളിപ്പെടുമ്പോൾ സ്തുതിയും മഹത്വവും ബഹുമാനവും ലഭിക്കാൻ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0600000-e29b-41d4-a716-446655440002', 'hi', '1 पतरस 2: एक पवित्र प्रजा', '1 पतरस 2 पढ़ें। तुम जीवित पत्थर हो — एक चुना हुआ वंश, राजकीय याजकवर्ग, पवित्र जाति। जिसने तुम्हें अंधकार में से अपनी अद्भुत ज्योति में बुलाया है उसके गुण प्रकट करो। प्रभु के लिए हर मनुष्य की रची हुई व्यवस्था के अधीन रहो।', 'विश्वास की नींव'),
  ('c0600000-e29b-41d4-a716-446655440002', 'ml', '1 പത്രോസ് 2: വിശുദ്ധ ജനം', '1 പത്രോസ് 2 വായിക്കുക. നിങ്ങൾ ജീവനുള്ള കല്ലുകളാണ് — തിരഞ്ഞെടുക്കപ്പെട്ട വംശം, രാജകീയ പുരോഹിതവർഗം, വിശുദ്ധ ജാതി. ഇരുട്ടിൽ നിന്ന് അത്ഭുതകരമായ വെളിച്ചത്തിലേക്ക് വിളിച്ചവന്റെ ശ്രേഷ്ഠത പ്രസ്താവിക്കുക. കർത്താവിന്റെ നിമിത്തം സകല മനുഷ്യനിയമത്തിനും കീഴ്‌പ്പെടുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0600000-e29b-41d4-a716-446655440003', 'hi', '1 पतरस 3: धार्मिकता के लिए दुख', '1 पतरस 3 पढ़ें। मसीह ने भी पापों के लिए एक बार दुख उठाया — धर्मी ने अधर्मियों के लिए — ताकि हमें परमेश्वर के पास पहुँचाए। जो आशा तुम में है उसका कारण पूछने वाले को उत्तर देने के लिए सदा तैयार रहो — नम्रता और भय के साथ।', 'विश्वास की नींव'),
  ('c0600000-e29b-41d4-a716-446655440003', 'ml', '1 പത്രോസ് 3: നീതിക്കുവേണ്ടി കഷ്ടം', '1 പത്രോസ് 3 വായിക്കുക. ക്രിസ്തു പാപങ്ങൾക്കുവേണ്ടി ഒരിക്കൽ കഷ്ടം സഹിച്ചു — നീതിമാൻ അനീതിക്കാർക്കുവേണ്ടി — നമ്മെ ദൈവത്തിങ്കലേക്ക് കൊണ്ടുവരാൻ. നിങ്ങളിലുള്ള പ്രത്യാശയെ കുറിച്ച് ചോദിക്കുന്നവന് ഉത്തരം പറയാൻ എല്ലായ്പോഴും ഒരുങ്ങിയിരിക്കുക — സൗമ്യതയോടും ഭയത്തോടും.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0600000-e29b-41d4-a716-446655440004', 'hi', '1 पतरस 4: कृपा के भंडारी', '1 पतरस 4 पढ़ें। "सबसे पहले एक दूसरे से गहरा प्रेम रखो, क्योंकि प्रेम बहुत से पापों को ढाँप देता है।" अग्नि-परीक्षा को अनोखी बात न समझो — बल्कि आनंद करो कि तुम मसीह के दुखों में सहभागी हो। परमेश्वर की विविध कृपा के अच्छे भंडारी बनो।', 'विश्वास की नींव'),
  ('c0600000-e29b-41d4-a716-446655440004', 'ml', '1 പത്രോസ് 4: കൃപയുടെ കാര്യവിചാരകർ', '1 പത്രോസ് 4 വായിക്കുക. "സർവോപരി പരസ്പരം ഗാഢമായ സ്നേഹം ഉണ്ടായിരിക്കുക, കാരണം സ്നേഹം അനേകം പാപങ്ങളെ മൂടുന്നു." അഗ്നിപരീക്ഷയെ അപൂർവമായി കരുതരുത് — ക്രിസ്തുവിന്റെ കഷ്ടങ്ങളിൽ പങ്കാളികളാകുന്നതിൽ സന്തോഷിക്കുക. ദൈവത്തിന്റെ വിവിധ കൃപയുടെ നല്ല കാര്യവിചാരകരാകുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0600000-e29b-41d4-a716-446655440005', 'hi', '1 पतरस 5: कृपा में दृढ़ रहो', '1 पतरस 5 पढ़ें। मूर्खता से नहीं बल्कि स्वेच्छा से परमेश्वर की भेड़ों की चरवाही करो। "अपने सब चिंताओं को उस पर डाल दो, क्योंकि उसे तुम्हारी चिंता है।" सावधान रहो — शैतान गर्जनेवाले सिंह की तरह फिरता है। उसका विश्वास में दृढ़ होकर सामना करो।', 'विश्वास की नींव'),
  ('c0600000-e29b-41d4-a716-446655440005', 'ml', '1 പത്രോസ് 5: കൃപയിൽ ഉറച്ചുനിൽക്കുക', '1 പത്രോസ് 5 വായിക്കുക. നിർബന്ധത്താലല്ല, സ്വമേധയാ ദൈവത്തിന്റെ ആട്ടിൻകൂട്ടത്തെ മേയ്ക്കുക. "നിങ്ങളുടെ എല്ലാ ചിന്താഭാരവും അവന്റെ മേൽ ഇടുക, അവൻ നിങ്ങളെ കുറിച്ച് കരുതുന്നു." ജാഗ്രതയുള്ളവരായിരിക്കുക — പിശാച് അലറുന്ന സിംഹത്തെപ്പോലെ ചുറ്റിനടക്കുന്നു. വിശ്വാസത്തിൽ ഉറച്ചുനിന്ന് അവനെ എതിർക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  -- 2 Peter (3 topics × 2 = 6 rows)
  ('c0600000-e29b-41d4-a716-446655440006', 'hi', '2 पतरस 1: भक्ति में बढ़ना', '2 पतरस 1 पढ़ें। परमेश्वर की ईश्वरीय सामर्थ्य ने हमें जीवन और भक्ति की सब वस्तुएँ दी हैं। बहुमूल्य और महान प्रतिज्ञाओं के द्वारा ईश्वरीय स्वभाव के भागी बनो। अपने विश्वास में सद्गुण, ज्ञान, संयम, धीरज, भक्ति, भाईचारे का प्रेम और प्रेम जोड़ते जाओ।', 'विश्वास की नींव'),
  ('c0600000-e29b-41d4-a716-446655440006', 'ml', '2 പത്രോസ് 1: ഭക്തിയിൽ വളരൽ', '2 പത്രോസ് 1 വായിക്കുക. ദൈവത്തിന്റെ ദിവ്യശക്തി ജീവനും ഭക്തിക്കും വേണ്ടതെല്ലാം നൽകിയിരിക്കുന്നു. വിലയേറിയ മഹത്തായ വാഗ്ദത്തങ്ങളിലൂടെ ദൈവിക സ്വഭാവത്തിൽ പങ്കാളികളാകുക. വിശ്വാസത്തിൽ സദ്ഗുണം, ജ്ഞാനം, ആത്മസംയമനം, സഹനം, ഭക്തി, സഹോദര സ്നേഹം, സ്നേഹം എന്നിവ ചേർത്തുകൊണ്ടിരിക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0600000-e29b-41d4-a716-446655440007', 'hi', '2 पतरस 2: झूठे शिक्षक बेनकाब', '2 पतरस 2 पढ़ें। झूठे शिक्षक विनाशकारी भ्रामक शिक्षा लाएँगे, यहाँ तक कि उस स्वामी को भी नकारेंगे जिसने उन्हें मोल लिया। परमेश्वर ने पाप करने वाले स्वर्गदूतों, पुराने संसार, या सदोम-अमोरा को नहीं छोड़ा — पर धर्मी लूत को बचाया। प्रभु भक्तों को परीक्षा से छुड़ाना जानता है।', 'विश्वास की नींव'),
  ('c0600000-e29b-41d4-a716-446655440007', 'ml', '2 പത്രോസ് 2: വ്യാജ ഉപദേഷ്ടാക്കൾ തുറന്നുകാട്ടപ്പെടുന്നു', '2 പത്രോസ് 2 വായിക്കുക. വ്യാജ ഉപദേഷ്ടാക്കൾ വിനാശകരമായ വ്യാജ ഉപദേശങ്ങൾ കൊണ്ടുവരും, തങ്ങളെ വിലയ്ക്ക് വാങ്ങിയ യജമാനനെ പോലും നിഷേധിക്കും. പാപം ചെയ്ത ദൂതന്മാരെയോ പഴയ ലോകത്തെയോ സൊദോം-ഗൊമോറയെയോ ദൈവം വെറുതെ വിട്ടില്ല — നീതിമാനായ ലോത്തിനെ രക്ഷിച്ചു. ഭക്തന്മാരെ പരീക്ഷയിൽ നിന്ന് വിടുവിക്കാൻ കർത്താവിന് അറിയാം.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0600000-e29b-41d4-a716-446655440008', 'hi', '2 पतरस 3: प्रभु का दिन', '2 पतरस 3 पढ़ें। अंतिम दिनों में ठट्ठा करने वाले आएँगे — "उसके आने की प्रतिज्ञा कहाँ है?" पर प्रभु प्रतिज्ञा पूरी करने में देर नहीं करता — वह तुम्हारे प्रति धीरज धरता है, नहीं चाहता कि कोई नाश हो। प्रभु का दिन चोर की तरह आएगा। नए आकाश और नई पृथ्वी की प्रतीक्षा करो जहाँ धार्मिकता वास करती है।', 'विश्वास की नींव'),
  ('c0600000-e29b-41d4-a716-446655440008', 'ml', '2 പത്രോസ് 3: കർത്താവിന്റെ ദിവസം', '2 പത്രോസ് 3 വായിക്കുക. അന്ത്യകാലത്ത് പരിഹാസികൾ വരും — "അവന്റെ വരവിന്റെ വാഗ്ദത്തം എവിടെ?" എന്നാൽ കർത്താവ് വാഗ്ദത്തം നിറവേറ്റുന്നതിൽ താമസിക്കുന്നില്ല — ആരും നശിക്കാതെ മാനസാന്തരപ്പെടണമെന്ന് ക്ഷമിക്കുന്നു. കർത്താവിന്റെ ദിവസം കള്ളനെപ്പോലെ വരും. നീതി വസിക്കുന്ന പുതിയ ആകാശവും പുതിയ ഭൂമിയും പ്രതീക്ഷിക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- Corinthians (29 topics × 2 = 58 rows)
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES
  ('c0700000-e29b-41d4-a716-446655440001', 'hi', '1 कुरिन्थियों 1: कलीसिया में फूट', '1 कुरिन्थियों 1 पढ़ें। पौलुस विनती करता है कि सब एक हों — "क्या मसीह बँटा हुआ है?" परमेश्वर की मूर्खता मनुष्यों के ज्ञान से बढ़कर है, और परमेश्वर की निर्बलता मनुष्यों की शक्ति से बढ़कर। जो घमंड करे वह प्रभु में घमंड करे।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440001', 'ml', '1 കൊരിന്ത്യർ 1: സഭയിലെ ഭിന്നത', '1 കൊരിന്ത്യർ 1 വായിക്കുക. എല്ലാവരും ഒന്നായിരിക്കാൻ പൗലോസ് അപേക്ഷിക്കുന്നു — "ക്രിസ്തു വിഭജിക്കപ്പെട്ടോ?" ദൈവത്തിന്റെ ഭോഷത്വം മനുഷ്യരുടെ ജ്ഞാനത്തേക്കാൾ ജ്ഞാനമാണ്, ദൈവത്തിന്റെ ബലഹീനത മനുഷ്യരുടെ ശക്തിയേക്കാൾ ശക്തിയാണ്. പ്രശംസിക്കുന്നവൻ കർത്താവിൽ പ്രശംസിക്കട്ടെ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440002', 'hi', '1 कुरिन्थियों 2: परमेश्वर का ज्ञान बनाम संसार का', '1 कुरिन्थियों 2 पढ़ें। पौलुस शब्दों के ज्ञान से नहीं बल्कि आत्मा और सामर्थ्य के प्रमाण से आया। "आँखों ने नहीं देखा, कानों ने नहीं सुना — जो परमेश्वर ने अपने प्रेमियों के लिए तैयार किया है।" आत्मा सब कुछ जाँचता है, परमेश्वर की गहरी बातों को भी।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440002', 'ml', '1 കൊരിന്ത്യർ 2: ദൈവത്തിന്റെ ജ്ഞാനം vs ലോകത്തിന്റെ', '1 കൊരിന്ത്യർ 2 വായിക്കുക. വാക്കിന്റെ ജ്ഞാനത്താലല്ല, ആത്മാവിന്റെയും ശക്തിയുടെയും തെളിവോടെ പൗലോസ് വന്നു. "കണ്ണ് കണ്ടിട്ടില്ല, ചെവി കേട്ടിട്ടില്ല — ദൈവം തന്നെ സ്നേഹിക്കുന്നവർക്കായി ഒരുക്കിയത്." ആത്മാവ് എല്ലാം — ദൈവത്തിന്റെ ആഴങ്ങളും — ആരായുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440003', 'hi', '1 कुरिन्थियों 3: मसीह के सेवक', '1 कुरिन्थियों 3 पढ़ें। पौलुस ने रोपा, अपुल्लोस ने सींचा, पर परमेश्वर ने बढ़ाया। तुम परमेश्वर की खेती और परमेश्वर की इमारत हो। नींव मसीह यीशु है — कोई और नींव नहीं रख सकता। क्या तुम नहीं जानते कि तुम परमेश्वर का मंदिर हो?', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440003', 'ml', '1 കൊരിന്ത്യർ 3: ക്രിസ്തുവിന്റെ ശുശ്രൂഷകർ', '1 കൊരിന്ത്യർ 3 വായിക്കുക. പൗലോസ് നട്ടു, അപ്പൊല്ലോസ് നനച്ചു, ദൈവം വളർത്തി. നിങ്ങൾ ദൈവത്തിന്റെ കൃഷിയും ദൈവത്തിന്റെ കെട്ടിടവുമാണ്. അടിസ്ഥാനം ക്രിസ്തുയേശുവാണ് — മറ്റൊരു അടിസ്ഥാനം ആർക്കും ഇടാൻ കഴിയില്ല. നിങ്ങൾ ദൈവത്തിന്റെ ആലയമാണെന്ന് അറിയുന്നില്ലേ?', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440004', 'hi', '1 कुरिन्थियों 4: मसीह के लिए मूर्ख', '1 कुरिन्थियों 4 पढ़ें। हमें मसीह के सेवक और परमेश्वर के भेदों के भंडारी समझो। भंडारियों में विश्वासयोग्यता अपेक्षित है। प्रेरित संसार के लिए तमाशा बने हैं — भूखे, प्यासे, नंगे, पीटे हुए। पर हम मसीह में मूर्ख हैं ताकि तुम बुद्धिमान हो।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440004', 'ml', '1 കൊരിന്ത്യർ 4: ക്രിസ്തുവിനുവേണ്ടി ഭോഷന്മാർ', '1 കൊരിന്ത്യർ 4 വായിക്കുക. ക്രിസ്തുവിന്റെ ശുശ്രൂഷകരും ദൈവമർമ്മങ്ങളുടെ കാര്യവിചാരകരുമായി ഞങ്ങളെ കണക്കാക്കുക. കാര്യവിചാരകരിൽ വിശ്വസ്തത ആവശ്യമാണ്. അപ്പൊസ്തലന്മാർ ലോകത്തിന് കാഴ്ചയായി — വിശന്നും ദാഹിച്ചും നഗ്നരായും അടികൊണ്ടും. ക്രിസ്തുവിൽ ഭോഷന്മാരായി നിങ്ങൾ ബുദ്ധിമാന്മാരാകാൻ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440005', 'hi', '1 कुरिन्थियों 5: कलीसिया का अनुशासन', '1 कुरिन्थियों 5 पढ़ें। पौलुस कलीसिया में व्याप्त अनैतिकता का सामना करता है। ऐसे व्यक्ति को शैतान को सौंप दो ताकि शरीर का नाश हो पर आत्मा प्रभु के दिन बचाई जाए। थोड़ा खमीर पूरे गूँधे को खमीर कर देता है — पुराने खमीर को निकालो।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440005', 'ml', '1 കൊരിന്ത്യർ 5: സഭയുടെ ശിക്ഷണം', '1 കൊരിന്ത്യർ 5 വായിക്കുക. സഭയിലെ അധാർമികതയെ പൗലോസ് അഭിമുഖീകരിക്കുന്നു. അങ്ങനെയുള്ളവനെ സാത്താന് ഏൽപ്പിക്കുക — ജഡം നശിക്കാൻ, ആത്മാവ് കർത്താവിന്റെ ദിവസത്തിൽ രക്ഷിക്കപ്പെടാൻ. അൽപ്പം പുളിമാവ് മുഴുവൻ മാവിനെ പുളിപ്പിക്കും — പഴയ പുളിമാവ് നീക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440006', 'hi', '1 कुरिन्थियों 6: व्यभिचार से भागो', '1 कुरिन्थियों 6 पढ़ें। "क्या तुम नहीं जानते कि तुम्हारी देह पवित्र आत्मा का मंदिर है?" तुम्हें दाम देकर मोल लिया गया है — इसलिए अपनी देह से परमेश्वर की महिमा करो। विश्वासियों को अविश्वासियों की अदालतों में मुकदमा नहीं करना चाहिए।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440006', 'ml', '1 കൊരിന്ത്യർ 6: ദുർന്നടപ്പിൽ നിന്ന് ഓടുക', '1 കൊരിന്ത്യർ 6 വായിക്കുക. "നിങ്ങളുടെ ശരീരം പരിശുദ്ധാത്മാവിന്റെ ആലയമാണെന്ന് അറിയുന്നില്ലേ?" നിങ്ങളെ വിലയ്ക്കു വാങ്ങിയിരിക്കുന്നു — അതിനാൽ ശരീരത്താൽ ദൈവത്തെ മഹത്വപ്പെടുത്തുക. വിശ്വാസികൾ അവിശ്വാസികളുടെ ന്യായാലയത്തിൽ വ്യവഹരിക്കരുത്.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440007', 'hi', '1 कुरिन्थियों 7: विवाह और अविवाहित जीवन', '1 कुरिन्थियों 7 पढ़ें। प्रत्येक व्यक्ति की अपनी वरदान है — कोई विवाह की, कोई अविवाहित रहने की। जैसी दशा में बुलाए गए हो वैसे ही रहो। संसार का रूप बदलता जा रहा है — अविवाहित प्रभु की बातों की चिंता करता है।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440007', 'ml', '1 കൊരിന്ത്യർ 7: വിവാഹവും അവിവാഹിത ജീവിതവും', '1 കൊരിന്ത്യർ 7 വായിക്കുക. ഓരോരുത്തർക്കും സ്വന്തം വരം ഉണ്ട് — ഒരാൾക്ക് വിവാഹത്തിന്, മറ്റൊരാൾക്ക് അവിവാഹിതമായിരിക്കാൻ. വിളിക്കപ്പെട്ട അവസ്ഥയിൽ തുടരുക. ലോകത്തിന്റെ രൂപം മാറിക്കൊണ്ടിരിക്കുന്നു — അവിവാഹിതൻ കർത്താവിന്റെ കാര്യങ്ങൾ ചിന്തിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440008', 'hi', '1 कुरिन्थियों 8: भोजन, मूर्तियाँ और विवेक', '1 कुरिन्थियों 8 पढ़ें। "ज्ञान फुलाता है, पर प्रेम उन्नति करता है।" मूर्ति संसार में कुछ नहीं — एक ही परमेश्वर है पिता और एक ही प्रभु यीशु मसीह। पर सावधान रहो कि तुम्हारी स्वतंत्रता निर्बल भाइयों के लिए ठोकर न बने।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440008', 'ml', '1 കൊരിന്ത്യർ 8: ഭക്ഷണം, വിഗ്രഹങ്ങൾ, മനസ്സാക്ഷി', '1 കൊരിന്ത്യർ 8 വായിക്കുക. "അറിവ് ചീർപ്പിക്കുന്നു, സ്നേഹം ആത്മീയവളർച്ച നൽകുന്നു." വിഗ്രഹം ലോകത്തിൽ ഒന്നുമല്ല — ഒരേ ദൈവം പിതാവും ഒരേ കർത്താവ് യേശുക്രിസ്തുവും. നിങ്ങളുടെ സ്വാതന്ത്ര്യം ബലഹീനരായ സഹോദരങ്ങൾക്ക് ഇടർച്ചയാകാതിരിക്കാൻ ശ്രദ്ധിക്കുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440009', 'hi', '1 कुरिन्थियों 9: अधिकार और आत्म-अनुशासन', '1 कुरिन्थियों 9 पढ़ें। पौलुस अपने प्रेरिताई अधिकारों को स्वेच्छा से छोड़ता है। "मैं सब लोगों के लिए सब कुछ बना ताकि किसी भी तरह कुछ लोगों को बचाऊँ।" दौड़ ऐसे दौड़ो कि इनाम पाओ — मैं अपनी देह को वश में करता हूँ कहीं दूसरों को प्रचार करके स्वयं अयोग्य न ठहरूँ।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440009', 'ml', '1 കൊരിന്ത്യർ 9: അവകാശങ്ങളും ആത്മനിയന്ത്രണവും', '1 കൊരിന്ത്യർ 9 വായിക്കുക. അപ്പൊസ്തല അവകാശങ്ങൾ പൗലോസ് സ്വമേധയാ ഉപേക്ഷിക്കുന്നു. "ചിലരെ എങ്കിലും രക്ഷിക്കാൻ ഞാൻ എല്ലാവർക്കും എല്ലാമായി." സമ്മാനം ലഭിക്കാൻ ഓടുക — മറ്റുള്ളവരോട് പ്രസംഗിച്ചിട്ട് ഞാൻ തന്നെ അയോഗ്യനാകാതിരിക്കാൻ ശരീരത്തെ അടക്കി വെക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440010', 'hi', '1 कुरिन्थियों 10: इस्राएल से चेतावनी', '1 कुरिन्थियों 10 पढ़ें। इस्राएलियों की कहानी हमारे लिए चेतावनी है — मूर्तिपूजा, व्यभिचार और बुड़बुड़ाहट से बचो। "कोई परीक्षा तुम पर ऐसी नहीं आई जो मनुष्य से सहनीय न हो।" परमेश्वर विश्वासयोग्य है और बचने का मार्ग भी बनाएगा। मूर्तिपूजा से भागो।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440010', 'ml', '1 കൊരിന്ത്യർ 10: ഇസ്രായേലിൽ നിന്നുള്ള മുന്നറിയിപ്പുകൾ', '1 കൊരിന്ത്യർ 10 വായിക്കുക. ഇസ്രായേല്യരുടെ കഥ നമുക്ക് മുന്നറിയിപ്പാണ് — വിഗ്രഹാരാധന, ദുർന്നടപ്പ്, പിറുപിറുപ്പ് ഒഴിവാക്കുക. "മനുഷ്യർക്ക് സഹിക്കാൻ കഴിയാത്ത പരീക്ഷ നിങ്ങൾക്ക് നേരിട്ടിട്ടില്ല." ദൈവം വിശ്വസ്തൻ, രക്ഷാമാർഗവും ഒരുക്കും. വിഗ്രഹാരാധനയിൽ നിന്ന് ഓടുക.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440011', 'hi', '1 कुरिन्थियों 11: आराधना में व्यवस्था', '1 कुरिन्थियों 11 पढ़ें। पौलुस आराधना में व्यवस्था के बारे में बताता है। प्रभु भोज के संबंध में गंभीर शिक्षा देता है: "जितनी बार तुम यह रोटी खाते और प्याला पीते हो, प्रभु की मृत्यु का प्रचार करते हो जब तक वह न आए।" अयोग्य रीति से खाने-पीने वाला अपने ऊपर दण्ड लाता है।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440011', 'ml', '1 കൊരിന്ത്യർ 11: ആരാധനയിലെ ക്രമം', '1 കൊരിന്ത്യർ 11 വായിക്കുക. ആരാധനയിലെ ക്രമത്തെ കുറിച്ച് പൗലോസ് പഠിപ്പിക്കുന്നു. കർത്താവിന്റെ അത്താഴത്തെ കുറിച്ചുള്ള ഗൗരവമായ ഉപദേശം: "ഈ അപ്പം തിന്നുകയും പാനപാത്രം കുടിക്കുകയും ചെയ്യുമ്പോഴെല്ലാം, അവൻ വരുവോളം കർത്താവിന്റെ മരണം പ്രഖ്യാപിക്കുന്നു." അയോഗ്യമായി ഭക്ഷിക്കുന്നവൻ ശിക്ഷാവിധി വരുത്തുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440012', 'hi', '1 कुरिन्थियों 12: आत्मिक वरदान', '1 कुरिन्थियों 12 पढ़ें। आत्मिक वरदान विभिन्न हैं पर आत्मा एक ही है। एक देह में बहुत से अंग हैं — आँख हाथ से नहीं कह सकती कि मुझे तेरी आवश्यकता नहीं। हर वरदान आवश्यक है। जब एक अंग दुखी होता है तो सब अंग दुखी होते हैं।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440012', 'ml', '1 കൊരിന്ത്യർ 12: ആത്മീയ വരങ്ങൾ', '1 കൊരിന്ത്യർ 12 വായിക്കുക. ആത്മീയ വരങ്ങൾ വ്യത്യസ്തമാണ് പക്ഷേ ആത്മാവ് ഒന്ന്. ഒരു ശരീരത്തിൽ അനേകം അവയവങ്ങൾ — കണ്ണിന് കൈയോട് "നീ എനിക്ക് ആവശ്യമില്ല" എന്ന് പറയാൻ കഴിയില്ല. ഓരോ വരവും ആവശ്യമാണ്. ഒരു അവയവം വേദനിക്കുമ്പോൾ എല്ലാ അവയവങ്ങളും വേദനിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440013', 'hi', '1 कुरिन्थियों 13: प्रेम का मार्ग', '1 कुरिन्थियों 13 पढ़ें। "यदि मैं मनुष्यों और स्वर्गदूतों की बोलियाँ बोलूँ पर प्रेम न रखूँ तो ठनठनाता पीतल हूँ।" प्रेम धैर्यवान, कृपालु, सब सहता, सब विश्वास करता, सब आशा रखता, सब सहन करता है। विश्वास, आशा, प्रेम — इनमें सबसे बड़ा प्रेम है।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440013', 'ml', '1 കൊരിന്ത്യർ 13: സ്നേഹത്തിന്റെ വഴി', '1 കൊരിന്ത്യർ 13 വായിക്കുക. "മനുഷ്യരുടെയും ദൂതന്മാരുടെയും ഭാഷകളിൽ സംസാരിച്ചാലും സ്നേഹമില്ലെങ്കിൽ ഞാൻ മുഴങ്ങുന്ന ചെമ്പ്." സ്നേഹം ക്ഷമിക്കുന്നു, ദയ കാണിക്കുന്നു, എല്ലാം സഹിക്കുന്നു, എല്ലാം വിശ്വസിക്കുന്നു, എല്ലാം പ്രത്യാശിക്കുന്നു, എല്ലാം ക്ഷമിക്കുന്നു. വിശ്വാസം, പ്രത്യാശ, സ്നേഹം — ഇവയിൽ ഏറ്റവും വലിയത് സ്നേഹം.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440014', 'hi', '1 कुरिन्थियों 14: व्यवस्थित आराधना', '1 कुरिन्थियों 14 पढ़ें। प्रेम का अनुसरण करो और आत्मिक वरदानों की खोज करो, विशेषकर भविष्यवाणी की। भविष्यवाणी कलीसिया की उन्नति करती है; अन्य भाषाएँ बिना अनुवाद के कलीसिया की उन्नति नहीं करतीं। "सब कुछ उचित और व्यवस्थित रूप से किया जाए।"', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440014', 'ml', '1 കൊരിന്ത്യർ 14: ക്രമമുള്ള ആരാധന', '1 കൊരിന്ത്യർ 14 വായിക്കുക. സ്നേഹം പിന്തുടരുക, ആത്മീയ വരങ്ങൾ — വിശേഷിച്ച് പ്രവചനം — ആഗ്രഹിക്കുക. പ്രവചനം സഭയെ പണിയുന്നു; അന്യഭാഷ വ്യാഖ്യാനമില്ലാതെ സഭയെ പണിയുന്നില്ല. "എല്ലാം ഉചിതമായും ക്രമമായും ചെയ്യപ്പെടട്ടെ."', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440015', 'hi', '1 कुरिन्थियों 15: पुनरुत्थान', '1 कुरिन्थियों 15 पढ़ें। "मसीह मर गया, गाड़ा गया, और तीसरे दिन जी उठा — पवित्रशास्त्र के अनुसार।" यदि मसीह नहीं जी उठा तो हमारा विश्वास व्यर्थ है। पर सच में मसीह जी उठा — सोए हुओं में पहला फल। "हे मृत्यु, तेरी जीत कहाँ? हे मृत्यु, तेरा डंक कहाँ?"', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440015', 'ml', '1 കൊരിന്ത്യർ 15: പുനരുത്ഥാനം', '1 കൊരിന്ത്യർ 15 വായിക്കുക. "ക്രിസ്തു മരിച്ചു, അടക്കപ്പെട്ടു, മൂന്നാം ദിവസം ഉയിർത്തെഴുന്നേറ്റു — തിരുവെഴുത്തുകളനുസരിച്ച്." ക്രിസ്തു ഉയിർത്തെഴുന്നേറ്റില്ലെങ്കിൽ നമ്മുടെ വിശ്വാസം വ്യർഥം. എന്നാൽ ക്രിസ്തു ഉയിർത്തെഴുന്നേറ്റു — ഉറങ്ങിയവരിൽ ആദ്യഫലം. "മരണമേ, നിന്റെ വിജയം എവിടെ? മരണമേ, നിന്റെ വിഷം എവിടെ?"', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440016', 'hi', '1 कुरिन्थियों 16: अंतिम निर्देश', '1 कुरिन्थियों 16 पढ़ें। पौलुस यरूशलेम के संतों के लिए चंदे की व्यवस्था करता है। "जागते रहो, विश्वास में दृढ़ रहो, पुरुषार्थ करो, बलवंत बनो।" तुम्हारे सब काम प्रेम से हों। प्रभु यीशु मसीह का अनुग्रह तुम सबके साथ हो।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440016', 'ml', '1 കൊരിന്ത്യർ 16: അന്തിമ നിർദേശങ്ങൾ', '1 കൊരിന്ത്യർ 16 വായിക്കുക. യെരൂശലേമിലെ വിശുദ്ധർക്കായുള്ള ശേഖരണം പൗലോസ് ക്രമീകരിക്കുന്നു. "ഉണർന്നിരിക്കുക, വിശ്വാസത്തിൽ ഉറച്ചുനിൽക്കുക, ധീരത കാണിക്കുക, ബലവാന്മാരാകുക." നിങ്ങളുടെ എല്ലാ പ്രവൃത്തികളും സ്നേഹത്തോടെ ചെയ്യുക. കർത്താവായ യേശുക്രിസ്തുവിന്റെ കൃപ നിങ്ങളോടൊക്കെയും ഇരിക്കട്ടെ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  -- 2 Corinthians (13 topics × 2 = 26 rows)
  ('c0700000-e29b-41d4-a716-446655440017', 'hi', '2 कुरिन्थियों 1: क्लेश में सांत्वना', '2 कुरिन्थियों 1 पढ़ें। पौलुस सब प्रकार की सांत्वना के परमेश्वर को धन्य कहता है, जो हमारे सब क्लेशों में हमें सांत्वना देता है ताकि हम भी दूसरों को सांत्वना दे सकें। पौलुस और उसके साथी सामर्थ्य से परे दबाए गए — पर यह इसलिए था कि वे स्वयं पर नहीं बल्कि मरे हुओं को जिलाने वाले परमेश्वर पर भरोसा रखें।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440017', 'ml', '2 കൊരിന്ത്യർ 1: കഷ്ടതയിലെ ആശ്വാസം', '2 കൊരിന്ത്യർ 1 വായിക്കുക. സകല ആശ്വാസത്തിന്റെ ദൈവത്തെ പൗലോസ് സ്തുതിക്കുന്നു — നമ്മുടെ എല്ലാ കഷ്ടതയിലും നമ്മെ ആശ്വസിപ്പിക്കുന്നവൻ, മറ്റുള്ളവരെ ആശ്വസിപ്പിക്കാൻ. ശക്തിക്കപ്പുറം ഞെരുക്കപ്പെട്ടു — മരിച്ചവരെ ഉയിർപ്പിക്കുന്ന ദൈവത്തിൽ ആശ്രയിക്കാൻ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440018', 'hi', '2 कुरिन्थियों 2: क्षमा और विजय', '2 कुरिन्थियों 2 पढ़ें। पौलुस पश्चातापी अपराधी को क्षमा करने का आग्रह करता है। वह मसीही जीवन को विजयी जुलूस के रूप में वर्णन करता है: "परमेश्वर का धन्यवाद हो जो मसीह में सदा हमें जय-जुलूस में लिए चलता है।" एक के लिए मृत्यु की सुगंध, दूसरे के लिए जीवन की सुगंध।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440018', 'ml', '2 കൊരിന്ത്യർ 2: ക്ഷമയും വിജയവും', '2 കൊരിന്ത്യർ 2 വായിക്കുക. മാനസാന്തരപ്പെട്ട കുറ്റക്കാരന് ക്ഷമിക്കാൻ പൗലോസ് ആവശ്യപ്പെടുന്നു. ക്രിസ്തീയ ജീവിതം വിജയഘോഷയാത്രയായി വർണ്ണിക്കുന്നു: "ക്രിസ്തുവിൽ എപ്പോഴും ഞങ്ങളെ ജയഘോഷയാത്രയിൽ നയിക്കുന്ന ദൈവത്തിന് സ്തോത്രം." ഒരാൾക്ക് മരണത്തിന്റെ സുഗന്ധം, മറ്റൊരാൾക്ക് ജീവന്റെ സുഗന്ധം.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440019', 'hi', '2 कुरिन्थियों 3: नई वाचा की महिमा', '2 कुरिन्थियों 3 पढ़ें। पत्थर की पट्टियों पर लिखी पुरानी वाचा की तुलना जीवते परमेश्वर के आत्मा द्वारा हृदय की पट्टियों पर लिखी नई वाचा से करता है। आत्मा की सेवकाई दण्ड देने वाली पुरानी व्यवस्था से कहीं अधिक महिमामय है। "जहाँ प्रभु का आत्मा है, वहाँ स्वतंत्रता है।" हम महिमा से महिमा में बदलते जा रहे हैं।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440019', 'ml', '2 കൊരിന്ത്യർ 3: പുതിയ ഉടമ്പടിയുടെ മഹത്വം', '2 കൊരിന്ത്യർ 3 വായിക്കുക. കല്പലകയിൽ എഴുതിയ പഴയ ഉടമ്പടിയെ ജീവനുള്ള ദൈവത്തിന്റെ ആത്മാവിനാൽ ഹൃദയപ്പലകയിൽ എഴുതിയ പുതിയ ഉടമ്പടിയുമായി താരതമ്യം ചെയ്യുന്നു. "കർത്താവിന്റെ ആത്മാവ് ഉള്ളിടത്ത് സ്വാതന്ത്ര്യമുണ്ട്." തേജസ്സിൽ നിന്ന് തേജസ്സിലേക്ക് രൂപാന്തരപ്പെടുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440020', 'hi', '2 कुरिन्थियों 4: मिट्टी के बर्तनों में खज़ाना', '2 कुरिन्थियों 4 पढ़ें। हमारे पास यह खज़ाना मिट्टी के बर्तनों में है, ताकि यह असीम सामर्थ्य परमेश्वर की ओर से ठहरे, न कि हमारी ओर से। चारों ओर से क्लेशित पर चूरचूर नहीं, निराश पर हताश नहीं। "यह हलका क्लेश हमारे लिए बहुत भारी और अनंत महिमा उत्पन्न करता है।"', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440020', 'ml', '2 കൊരിന്ത്യർ 4: മൺപാത്രങ്ങളിലെ നിധി', '2 കൊരിന്ത്യർ 4 വായിക്കുക. ഈ നിധി മൺപാത്രങ്ങളിലാണ് — അത്യധികമായ ശക്തി ദൈവത്തിന്റേതാണ്, നമ്മുടേതല്ല. എല്ലാ ഭാഗത്തും ഞെരുക്കപ്പെട്ടിട്ടും തകർന്നില്ല, ആശയക്കുഴപ്പത്തിലായിട്ടും നിരാശരായില്ല. "ഈ ലഘുവായ ക്ഷണികമായ കഷ്ടത നമുക്ക് അത്യന്തം ഘനമേറിയ നിത്യതേജസ്സ് ഉളവാക്കുന്നു."', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440021', 'hi', '2 कुरिन्थियों 5: मेल-मिलाप की सेवकाई', '2 कुरिन्थियों 5 पढ़ें। यदि हमारा पृथ्वी का तम्बू गिराया जाए तो स्वर्ग में परमेश्वर की ओर से अनंत घर है। हम दृष्टि से नहीं विश्वास से चलते हैं। "यदि कोई मसीह में है तो वह नई सृष्टि है।" परमेश्वर ने हमें मेल-मिलाप की सेवकाई दी है: हम मसीह के राजदूत हैं।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440021', 'ml', '2 കൊരിന്ത്യർ 5: അനുരഞ്ജനത്തിന്റെ ശുശ്രൂഷ', '2 കൊരിന്ത്യർ 5 വായിക്കുക. ഭൂമിയിലെ കൂടാരം അഴിക്കപ്പെട്ടാൽ സ്വർഗ്ഗത്തിൽ ദൈവത്തിന്റെ നിത്യ ഭവനമുണ്ട്. കാഴ്ചയാലല്ല, വിശ്വാസത്താൽ നടക്കുന്നു. "ആരെങ്കിലും ക്രിസ്തുവിൽ ആയിരുന്നാൽ അവൻ പുതിയ സൃഷ്ടിയാണ്." ദൈവം നമുക്ക് അനുരഞ്ജനത്തിന്റെ ശുശ്രൂഷ നൽകി: ക്രിസ്തുവിനുവേണ്ടി സ്ഥാനപതിമാർ.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440022', 'hi', '2 कुरिन्थियों 6: परमेश्वर के सेवक', '2 कुरिन्थियों 6 पढ़ें। पौलुस क्लेशों, कठिनाइयों, मार, कैद, दंगों, परिश्रम, जागरण और भूख में सहनशीलता से परमेश्वर के सेवक के रूप में सिद्ध होता है। वह आग्रह करता है: "अविश्वासियों के साथ असमान जुए में मत जुड़ो। धार्मिकता और अधर्म की क्या संगति?"', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440022', 'ml', '2 കൊരിന്ത്യർ 6: ദൈവത്തിന്റെ ശുശ്രൂഷകർ', '2 കൊരിന്ത്യർ 6 വായിക്കുക. കഷ്ടങ്ങൾ, ബുദ്ധിമുട്ടുകൾ, അടി, തടവ്, കലാപം, അധ്വാനം, ഉറക്കമിളയ്ക്കൽ, വിശപ്പ് എന്നിവയിൽ സഹനത്തിലൂടെ ദൈവത്തിന്റെ ശുശ്രൂഷകരായി തെളിയിക്കുന്നു. "അവിശ്വാസികളുമായി അസമമായ നുകത്തിൽ ചേരരുത്. നീതിക്ക് അധർമത്തോട് എന്ത് കൂട്ടായ്മ?"', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440023', 'hi', '2 कुरिन्थियों 7: ईश्वरीय दुख और पश्चाताप', '2 कुरिन्थियों 7 पढ़ें। पौलुस आनंदित है क्योंकि कुरिन्थियों का दुख पश्चाताप की ओर ले गया। "ईश्वरीय दुख ऐसा पश्चाताप उत्पन्न करता है जो उद्धार देता है और जिसका कोई पछतावा नहीं, पर सांसारिक दुख मृत्यु उत्पन्न करता है।" तीतुस उनकी आज्ञाकारिता की शुभ समाचार लाता है।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440023', 'ml', '2 കൊരിന്ത്യർ 7: ദൈവിക ദുഃഖവും മാനസാന്തരവും', '2 കൊരിന്ത്യർ 7 വായിക്കുക. കൊരിന്ത്യരുടെ ദുഃഖം മാനസാന്തരത്തിലേക്ക് നയിച്ചതിനാൽ പൗലോസ് സന്തോഷിക്കുന്നു. "ദൈവിക ദുഃഖം രക്ഷയിലേക്ക് നയിക്കുന്ന മാനസാന്തരം ഉളവാക്കുന്നു, ലൗകിക ദുഃഖം മരണം ഉളവാക്കുന്നു." തീത്തൊസ് അവരുടെ അനുസരണത്തിന്റെ സുവാർത്ത കൊണ്ടുവരുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440024', 'hi', '2 कुरिन्थियों 8: दान देने का अनुग्रह', '2 कुरिन्थियों 8 पढ़ें। पौलुस मकिदुनिया की कलीसियाओं को उदारता का आदर्श प्रस्तुत करता है — अत्यंत गरीबी में भी उनके आनंद की बहुतायत उदारता में बह निकली। "तुम हमारे प्रभु यीशु मसीह का अनुग्रह जानते हो कि वह धनी होकर भी तुम्हारे लिए दरिद्र बन गया ताकि उसकी दरिद्रता से तुम धनी हो जाओ।"', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440024', 'ml', '2 കൊരിന്ത്യർ 8: ദാനത്തിന്റെ കൃപ', '2 കൊരിന്ത്യർ 8 വായിക്കുക. മക്കെദോന്യയിലെ സഭകളെ ഔദാര്യത്തിന്റെ മാതൃകയായി പൗലോസ് ഉയർത്തിക്കാട്ടുന്നു — കടുത്ത ദാരിദ്ര്യത്തിലും സന്തോഷത്തിന്റെ സമൃദ്ധി ഔദാര്യമായി ഒഴുകി. "നമ്മുടെ കർത്താവായ യേശുക്രിസ്തുവിന്റെ കൃപ — ധനവാനായിരുന്നിട്ടും നിങ്ങൾക്കുവേണ്ടി ദരിദ്രനായി, അവന്റെ ദാരിദ്ര്യത്താൽ നിങ്ങൾ ധനവാന്മാരാകാൻ."', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440025', 'hi', '2 कुरिन्थियों 9: आनंद से देना', '2 कुरिन्थियों 9 पढ़ें। "जो कम बोता है वह कम काटेगा, और जो बहुत बोता है वह बहुत काटेगा।" हर एक जैसा मन में ठान ले वैसा दे — न कुढ़ कुढ़ कर, न बेमन से, क्योंकि परमेश्वर हँसमुख दाता से प्रेम करता है। परमेश्वर तुम पर सब प्रकार का अनुग्रह बहुतायत से कर सकता है।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440025', 'ml', '2 കൊരിന്ത്യർ 9: സന്തോഷത്തോടെ ദാനം', '2 കൊരിന്ത്യർ 9 വായിക്കുക. "ലുബ്ധമായി വിതയ്ക്കുന്നവൻ ലുബ്ധമായി കൊയ്യും, ധാരാളമായി വിതയ്ക്കുന്നവൻ ധാരാളമായി കൊയ്യും." ഓരോരുത്തരും ഹൃദയത്തിൽ നിശ്ചയിച്ചതുപോലെ കൊടുക്കട്ടെ — വ്യസനത്തോടെയോ നിർബന്ധത്തോടെയോ അല്ല, കാരണം ദൈവം സന്തോഷമുള്ള ദാതാവിനെ സ്നേഹിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440026', 'hi', '2 कुरिन्थियों 10: आत्मिक युद्ध', '2 कुरिन्थियों 10 पढ़ें। पौलुस अपने अधिकार की रक्षा करता है। हम शरीर में चलते हैं पर शरीर के अनुसार नहीं लड़ते। "हमारे युद्ध के हथियार शारीरिक नहीं बल्कि गढ़ों को ढाने के लिए परमेश्वर की सामर्थ्य से भरपूर हैं।" हर विचार को मसीह की आज्ञाकारिता में बंदी बनाओ। "जो घमंड करे वह प्रभु में घमंड करे।"', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440026', 'ml', '2 കൊരിന്ത്യർ 10: ആത്മീയ യുദ്ധം', '2 കൊരിന്ത്യർ 10 വായിക്കുക. അധികാരത്തെ പൗലോസ് സംരക്ഷിക്കുന്നു. ജഡത്തിൽ നടക്കുന്നു, ജഡപ്രകാരം യുദ്ധം ചെയ്യുന്നില്ല. "നമ്മുടെ യുദ്ധായുധങ്ങൾ ജഡികമല്ല, കോട്ടകൾ ഇടിക്കാൻ ദൈവത്തിന്റെ ശക്തിയുള്ളവ." ഓരോ ചിന്തയും ക്രിസ്തുവിന്റെ അനുസരണത്തിലേക്ക് ബന്ധനസ്ഥമാക്കുക. "പ്രശംസിക്കുന്നവൻ കർത്താവിൽ പ്രശംസിക്കട്ടെ."', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440027', 'hi', '2 कुरिन्थियों 11: पौलुस के कष्ट', '2 कुरिन्थियों 11 पढ़ें। पौलुस अनिच्छा से घमंड करता है — झूठे प्रेरितों का सामना करने के लिए। उसके कष्टों का लेखा: पाँच बार उनतालीस कोड़े, तीन बार बेंतों से मार, एक बार पथराव, तीन बार जहाज़ टूटा। नदियों, लुटेरों, अपने लोगों, अन्यजातियों से खतरों में — परिश्रम, जागरण, भूख और प्यास में।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440027', 'ml', '2 കൊരിന്ത്യർ 11: പൗലോസിന്റെ കഷ്ടങ്ങൾ', '2 കൊരിന്ത്യർ 11 വായിക്കുക. വ്യാജ അപ്പൊസ്തലന്മാരെ നേരിടാൻ പൗലോസ് വിമുഖതയോടെ പ്രശംസിക്കുന്നു. കഷ്ടങ്ങളുടെ കണക്ക്: അഞ്ച് തവണ മുപ്പത്തൊമ്പത് അടി, മൂന്ന് തവണ വടികൊണ്ട് അടി, ഒരിക്കൽ കല്ലെറിഞ്ഞു, മൂന്ന് തവണ കപ്പൽ ഉടഞ്ഞു. നദികളിൽ, കള്ളന്മാരിൽ, സ്വജനങ്ങളിൽ, വിജാതീയരിൽ നിന്ന് അപകടങ്ങൾ — അധ്വാനത്തിലും ഉറക്കമിളയ്ക്കലിലും വിശപ്പിലും ദാഹത്തിലും.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440028', 'hi', '2 कुरिन्थियों 12: निर्बलता में सामर्थ्य', '2 कुरिन्थियों 12 पढ़ें। पौलुस को तीसरे स्वर्ग तक उठा लिया गया। घमंड से बचाने के लिए शरीर में एक काँटा दिया गया — शैतान का दूत। तीन बार उसने प्रभु से विनती की, और प्रभु ने कहा: "मेरा अनुग्रह तेरे लिए बहुत है, क्योंकि मेरी सामर्थ्य निर्बलता में सिद्ध होती है।" इसलिए पौलुस अपनी निर्बलताओं पर आनंद से घमंड करता है।', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440028', 'ml', '2 കൊരിന്ത്യർ 12: ബലഹീനതയിലെ ശക്തി', '2 കൊരിന്ത്യർ 12 വായിക്കുക. മൂന്നാം സ്വർഗ്ഗത്തിലേക്ക് പൗലോസ് എടുക്കപ്പെട്ടു. അഹങ്കാരത്തിൽ നിന്ന് കാക്കാൻ ജഡത്തിൽ ഒരു മുള്ള് — സാത്താന്റെ ദൂതൻ. മൂന്ന് തവണ കർത്താവിനോട് യാചിച്ചു, കർത്താവ് പറഞ്ഞു: "എന്റെ കൃപ നിനക്ക് മതി, എന്റെ ശക്തി ബലഹീനതയിൽ തികവുറ്റതാകുന്നു." ബലഹീനതകളിൽ സന്തോഷത്തോടെ പ്രശംസിക്കുന്നു.', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ'),
  ('c0700000-e29b-41d4-a716-446655440029', 'hi', '2 कुरिन्थियों 13: अंतिम चेतावनियाँ', '2 कुरिन्थियों 13 पढ़ें। पौलुस चेतावनी देता है कि जब वह फिर आएगा तो पाप करने वालों को नहीं छोड़ेगा। अपने आप को परखो कि विश्वास में हो या नहीं। मसीह निर्बलता में क्रूस पर चढ़ाया गया पर परमेश्वर की सामर्थ्य से जीवित है। "सुधार का लक्ष्य रखो, एक दूसरे को सांत्वना दो, एक मन रहो, शांति से रहो; और प्रेम और शांति का परमेश्वर तुम्हारे साथ होगा।"', 'विश्वास की नींव'),
  ('c0700000-e29b-41d4-a716-446655440029', 'ml', '2 കൊരിന്ത്യർ 13: അന്തിമ മുന്നറിയിപ്പുകൾ', '2 കൊരിന്ത്യർ 13 വായിക്കുക. വീണ്ടും വരുമ്പോൾ പാപം ചെയ്തവരെ ഒഴിവാക്കില്ലെന്ന് പൗലോസ് മുന്നറിയിപ്പ് നൽകുന്നു. വിശ്വാസത്തിൽ ഉണ്ടോ എന്ന് സ്വയം പരീക്ഷിക്കുക. ക്രിസ്തു ബലഹീനതയിൽ ക്രൂശിക്കപ്പെട്ടു, ദൈവത്തിന്റെ ശക്തിയാൽ ജീവിക്കുന്നു. "പുനഃസ്ഥാപനം ലക്ഷ്യമാക്കുക, പരസ്പരം ആശ്വസിപ്പിക്കുക, ഒരുമനസ്സായിരിക്കുക, സമാധാനത്തോടെ ജീവിക്കുക; സ്നേഹത്തിന്റെയും സമാധാനത്തിന്റെയും ദൈവം നിങ്ങളോടൊപ്പം ഉണ്ടായിരിക്കും."', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ')
ON CONFLICT (topic_id, language_code) DO NOTHING;

-- =====================================================
-- 6. Compute total XP for each new path
-- =====================================================

SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000035');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000036');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000037');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000038');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000039');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000040');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000041');

-- =====================================================
-- 7. Recategorise Hebrews & Romans into Epistles
--    + reorder all 9 epistles by progression level
-- =====================================================

-- Hebrews: move to Epistles, last in advanced tier
UPDATE learning_paths
SET category = 'Epistles', display_order = 9
WHERE id = 'aaa00000-0000-0000-0000-000000000030';

-- Romans: move to Epistles as beginner, first in category
UPDATE learning_paths
SET category = 'Epistles',
    difficulty_level = 'beginner',
    disciple_level = 'seeker',
    recommended_mode = 'standard',
    display_order = 2
WHERE id = 'aaa00000-0000-0000-0000-000000000033';

-- =====================================================
-- 8. Verification
-- =====================================================

DO $$
DECLARE
  v_count INT;
BEGIN
  -- Ephesians: 6 topics
  SELECT COUNT(*) INTO v_count FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000035';
  ASSERT v_count = 6, 'Ephesians should have 6 topics, got ' || v_count;

  -- James: 5 topics
  SELECT COUNT(*) INTO v_count FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000036';
  ASSERT v_count = 5, 'James should have 5 topics, got ' || v_count;

  -- John's Letters: 7 topics (1-3 John)
  SELECT COUNT(*) INTO v_count FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000037';
  ASSERT v_count = 7, 'John''s Letters should have 7 topics, got ' || v_count;

  -- Philippians: 4 topics
  SELECT COUNT(*) INTO v_count FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000038';
  ASSERT v_count = 4, 'Philippians should have 4 topics, got ' || v_count;

  -- Galatians: 6 topics
  SELECT COUNT(*) INTO v_count FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000039';
  ASSERT v_count = 6, 'Galatians should have 6 topics, got ' || v_count;

  -- Peter's Letters: 8 topics (1-2 Peter)
  SELECT COUNT(*) INTO v_count FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000040';
  ASSERT v_count = 8, 'Peter''s Letters should have 8 topics, got ' || v_count;

  -- Corinthians: 29 topics (1-2 Corinthians)
  SELECT COUNT(*) INTO v_count FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000041';
  ASSERT v_count = 29, 'Corinthians should have 29 topics, got ' || v_count;

  -- Total new topics: 65
  SELECT COUNT(*) INTO v_count FROM recommended_topics WHERE id IN (
    SELECT topic_id FROM learning_path_topics WHERE learning_path_id IN (
      'aaa00000-0000-0000-0000-000000000035',
      'aaa00000-0000-0000-0000-000000000036',
      'aaa00000-0000-0000-0000-000000000037',
      'aaa00000-0000-0000-0000-000000000038',
      'aaa00000-0000-0000-0000-000000000039',
      'aaa00000-0000-0000-0000-000000000040',
      'aaa00000-0000-0000-0000-000000000041'
    )
  );
  ASSERT v_count = 65, 'Should have 65 recommended_topics, got ' || v_count;

  -- No duplicate topic positions within any path
  SELECT COUNT(*) INTO v_count FROM (
    SELECT learning_path_id, position, COUNT(*) AS cnt
    FROM learning_path_topics
    WHERE learning_path_id IN (
      'aaa00000-0000-0000-0000-000000000035',
      'aaa00000-0000-0000-0000-000000000036',
      'aaa00000-0000-0000-0000-000000000037',
      'aaa00000-0000-0000-0000-000000000038',
      'aaa00000-0000-0000-0000-000000000039',
      'aaa00000-0000-0000-0000-000000000040',
      'aaa00000-0000-0000-0000-000000000041'
    )
    GROUP BY learning_path_id, position
    HAVING COUNT(*) > 1
  ) dupes;
  ASSERT v_count = 0, 'Found duplicate topic positions: ' || v_count;

  -- All 9 paths are in 'Epistles' category (7 new + Hebrews + Romans)
  SELECT COUNT(*) INTO v_count FROM learning_paths
  WHERE id IN (
    'aaa00000-0000-0000-0000-000000000030',
    'aaa00000-0000-0000-0000-000000000033',
    'aaa00000-0000-0000-0000-000000000035',
    'aaa00000-0000-0000-0000-000000000036',
    'aaa00000-0000-0000-0000-000000000037',
    'aaa00000-0000-0000-0000-000000000038',
    'aaa00000-0000-0000-0000-000000000039',
    'aaa00000-0000-0000-0000-000000000040',
    'aaa00000-0000-0000-0000-000000000041'
  ) AND category = 'Epistles';
  ASSERT v_count = 9, 'All 9 paths should be in Epistles category, got ' || v_count;

  RAISE NOTICE '✓ All 9 epistle learning paths verified (7 new + Hebrews + Romans, 65 new topics, no duplicates)';
END $$;

COMMIT;

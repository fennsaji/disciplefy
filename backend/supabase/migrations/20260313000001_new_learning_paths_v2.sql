-- =====================================================
-- Migration: 5 New Learning Paths
-- =====================================================
-- Paths:
--   Theology (2):    Jesus's Parables, Romans, Hebrews
--   Foundations (2): Sermon on the Mount, Crucifixion & Resurrection
-- Topics: 28 + 20 + 16 + 16 + 13 = 93 new recommended_topics
-- Theological review: Paul the Apostle (approved with corrections applied)
-- Corrections applied (Round 1 — first Paul review):
--   1. Path 2 Topic 8: "A New Law" → "The Ethic of the Kingdom"
--   2. Path 4 Topics 2/3: Deduplicated Matt 26:36-56 scope
--   3. Path 3 Topic 1: "Gentile sin" → "Universal Human Guilt"
--   4. Path 5 Topic 11: Cloud of witnesses belongs to Heb 12:1 (Topic 12)
-- Corrections applied (Round 2 — second Paul review):
--   5. ppa004 Yeast: Removed unwarranted Spirit attribution; grounds in sovereign scope
--   6. ppa009 Unmerciful Servant: Clarified forgiveness as fruit, not condition (Rom 4:5)
--   7. ppa014 Ten Virgins: Clarified readiness = saving faith/Spirit, not performance
--   8. ppa018 Good Samaritan: Added reframing of lawyer's question (Luke 10:29)
--   9. som006 Divorce: Acknowledged Matt 5:32 exception clause with pastoral note
--  10. som013 Treasures: Replaced "investment/currency" with non-transactional language
--  11. rom006 Dead to Sin: Distinguished Paul's "baptism" from water-baptism mechanism
--  12. cxr001 Last Supper: Added explicit anti-transubstantiation clarification
--  13. heb006 Press On: Expanded with Reformed/Arminian interpretive options (Heb 6:9)
-- =====================================================

BEGIN;

-- =====================================================
-- PART 1: RECOMMENDED TOPICS
-- =====================================================

-- -------------------------------------------------------
-- PPA: Jesus's Parables (28 topics)
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('ab100000-e29b-41d4-a716-446655440001', 'The Sower and the Soils',
   'Jesus opens his great parable chapter with a story that is itself about how the gospel is received. The four soils reveal four kinds of responses to God''s Word: hardness, shallow enthusiasm, competing desires, and fruitful faith. This parable holds up a mirror to every hearer of the gospel and asks: what kind of soil are you?',
   'Foundations of Faith', ARRAY['parables', 'gospel', 'hearing', 'discipleship'], 301, 50),

  ('ab100000-e29b-41d4-a716-446655440002', 'The Wheat and the Weeds',
   'In a world where true and false disciples grow side by side, this parable warns against premature human judgment and assures that God will sort his harvest at the end. Final judgment belongs to God alone — not to those who would uproot the weeds and damage the wheat in the process. Patience and trust in divine justice mark the kingdom citizen.',
   'Foundations of Faith', ARRAY['parables', 'judgment', 'kingdom', 'patience'], 302, 50),

  ('ab100000-e29b-41d4-a716-446655440003', 'The Mustard Seed',
   'The kingdom of God begins like the smallest of seeds — a peasant preacher from Galilee, twelve followers, a borrowed upper room. Yet from such unlikely beginnings, the kingdom grows into something large enough to shelter all who come. This parable invites faith in God''s sovereign work despite humble appearances.',
   'Foundations of Faith', ARRAY['parables', 'kingdom', 'growth', 'faith'], 303, 50),

  ('ab100000-e29b-41d4-a716-446655440004', 'The Yeast',
   'A small amount of yeast works silently through the whole batch of dough. So it will be with the kingdom of God — from seemingly insignificant beginnings, God''s reign penetrates and transforms the whole. What begins as a mustard seed of proclamation works through history until creation itself is renewed (Romans 8:21). Trust the scope of God''s sovereign work, not the size of present appearances.',
   'Foundations of Faith', ARRAY['parables', 'kingdom', 'transformation', 'sovereignty'], 304, 50),

  ('ab100000-e29b-41d4-a716-446655440005', 'The Hidden Treasure',
   'A man stumbles upon a treasure hidden in a field — and with joy sells everything to buy that field. The kingdom of God is like this: when a person truly discovers what Christ offers, no sacrifice is too great. Joy, not duty, drives the radical commitment of genuine faith.',
   'Foundations of Faith', ARRAY['parables', 'kingdom', 'joy', 'sacrifice'], 305, 50),

  ('ab100000-e29b-41d4-a716-446655440006', 'The Pearl of Great Value',
   'A merchant who has spent his life searching for fine pearls finally finds one of surpassing worth — and sells everything to obtain it. Whether we stumble upon the gospel or search for it, the response is the same: everything else pales in comparison to Christ.',
   'Foundations of Faith', ARRAY['parables', 'kingdom', 'seeking', 'value'], 306, 50),

  ('ab100000-e29b-41d4-a716-446655440007', 'The Net',
   'Fishermen drag in a net full of every kind of fish and then sort them at the shore — keeping the good, discarding the bad. So it will be at the end of the age when angels separate the wicked from the righteous. Final judgment belongs to God alone.',
   'Foundations of Faith', ARRAY['parables', 'judgment', 'kingdom', 'end times'], 307, 50),

  ('ab100000-e29b-41d4-a716-446655440008', 'The Lost Sheep',
   'A shepherd leaves ninety-nine sheep to search for one that is lost — and when found, rejoices more than over all the others. God actively pursues the lost rather than merely waiting for them to return. The initiative in salvation belongs to the divine Shepherd, not the straying sheep.',
   'Foundations of Faith', ARRAY['parables', 'grace', 'salvation', 'god''s love'], 308, 50),

  ('ab100000-e29b-41d4-a716-446655440009', 'The Unmerciful Servant',
   'A servant forgiven an astronomically large debt immediately seizes a fellow servant who owes him a small amount. This parable confronts us with the inconsistency of accepting God''s enormous grace while refusing to forgive others. The fruit of genuine salvation is a forgiving heart. The parable does not teach that our forgiveness of others earns God''s forgiveness — rather, those who have truly grasped the enormity of their own debt will find it impossible to withhold forgiveness from others. A persistently unforgiving heart is a sign that the grace of God has not truly penetrated it (Matthew 18:35; cf. Romans 4:5).',
   'Foundations of Faith', ARRAY['parables', 'forgiveness', 'grace', 'mercy'], 309, 50),

  ('ab100000-e29b-41d4-a716-446655440010', 'The Workers in the Vineyard',
   'All workers receive the same wage whether they worked all day or one hour. The landowner''s generosity offends those who worked longest. This parable reveals the sovereign freedom of God''s grace — he gives equally to all who are called, regardless of how long they have labored. There is no earned entitlement before God.',
   'Foundations of Faith', ARRAY['parables', 'grace', 'sovereignty', 'generosity'], 310, 50),

  ('ab100000-e29b-41d4-a716-446655440011', 'The Two Sons',
   'One son says "yes" to his father''s command but does not go; the other says "no" but repents and goes. Jesus applies this to religious leaders who refused John''s baptism while tax collectors and prostitutes entered the kingdom ahead of them. Profession without obedience is empty; repentance and action are everything.',
   'Foundations of Faith', ARRAY['parables', 'repentance', 'obedience', 'hypocrisy'], 311, 50),

  ('ab100000-e29b-41d4-a716-446655440012', 'The Tenants',
   'Wicked tenants kill the landowner''s servants and finally his son. The vineyard will be given to others who bear its fruit. Spoken against the religious leaders, this parable traces the pattern of rejection that culminates in the crucifixion — and announces the inclusion of the Gentiles.',
   'Foundations of Faith', ARRAY['parables', 'rejection', 'israel', 'salvation history'], 312, 50),

  ('ab100000-e29b-41d4-a716-446655440013', 'The Wedding Banquet',
   'Invited guests refuse to come; the invitation goes out to all found on the roads. Yet even among those who come, a man without a wedding garment is cast out. Entry into the kingdom requires the righteousness God provides — imputed through faith in Christ. Hearing the invitation is not enough; one must be clothed in the garment of grace.',
   'Foundations of Faith', ARRAY['parables', 'salvation', 'grace', 'judgment'], 313, 50),

  ('ab100000-e29b-41d4-a716-446655440014', 'The Ten Virgins',
   'Five bridesmaids are prepared when the bridegroom arrives; five are not. "Keep watch," says Jesus, "for you do not know the day or the hour." This parable calls disciples to consistent, Spirit-sustained readiness — not spiritual procrastination. The door, once shut, does not reopen. This readiness is not a matter of spiritual performance but of genuine possession of what cannot be borrowed — saving faith and the indwelling Spirit. No amount of last-minute effort can substitute for the living relationship with Christ that sustains the waiting disciple.',
   'Foundations of Faith', ARRAY['parables', 'readiness', 'return of christ', 'watchfulness'], 314, 50),

  ('ab100000-e29b-41d4-a716-446655440015', 'The Talents',
   'A master entrusts different amounts to his servants before leaving. Two invest and multiply; one buries his out of fear. Faithfulness in the kingdom means active stewardship of all God has entrusted — gifts, time, opportunities. Fearful inaction is itself a form of unfaithfulness.',
   'Foundations of Faith', ARRAY['parables', 'stewardship', 'faithfulness', 'gifts'], 315, 50),

  ('ab100000-e29b-41d4-a716-446655440016', 'The Sheep and the Goats',
   'At the final judgment, nations are separated as a shepherd separates sheep from goats. Those who cared for the hungry, thirsty, stranger, and imprisoned are welcomed; those who did not are sent away. These works are not the basis of salvation but the evidence of it — the fruit of genuine union with Christ, not a works-righteousness formula. The "least of these brothers" refers most naturally to Christ''s disciples and messengers.',
   'Foundations of Faith', ARRAY['parables', 'judgment', 'compassion', 'kingdom ethics'], 316, 50),

  ('ab100000-e29b-41d4-a716-446655440017', 'The Growing Seed',
   'A man scatters seed and sleeps and rises — yet the seed grows by itself. The kingdom of God grows by its own mysterious power, not by human engineering. We sow faithfully, but God gives the growth. This parable guards against both anxious activism and passive indifference.',
   'Foundations of Faith', ARRAY['parables', 'kingdom', 'growth', 'sovereignty'], 317, 50),

  ('ab100000-e29b-41d4-a716-446655440018', 'The Good Samaritan',
   'A man beaten and left for dead is passed by a priest and a Levite — but a Samaritan stops, binds his wounds, and pays for his care. Jesus asks which of the three was a neighbor. Love defined by nearness and convenience is not the love the kingdom demands — neighbor love crosses every boundary. The lawyer asked "Who is my neighbor?" to limit the obligation. Jesus reframes the question: "Which one was a neighbor?" — calling the hearer to become the kind of person who crosses every boundary to love, rather than one who calculates who qualifies.',
   'Foundations of Faith', ARRAY['parables', 'love', 'neighbor', 'compassion'], 318, 50),

  ('ab100000-e29b-41d4-a716-446655440019', 'The Persistent Friend at Midnight',
   'A man knocks at his friend''s door at midnight asking for bread. Though inconvenienced, the friend eventually gives what is needed. Jesus uses this contrast to teach that if even a reluctant friend responds, how much more will your heavenly Father give good things to those who ask?',
   'Foundations of Faith', ARRAY['parables', 'prayer', 'persistence', 'trust'], 319, 50),

  ('ab100000-e29b-41d4-a716-446655440020', 'The Rich Fool',
   'A prosperous farmer builds bigger barns and plans to eat, drink, and be merry — and dies that very night. God calls him a fool. This parable is a warning against the idolatry of wealth and the illusion of self-sufficiency. Life does not consist in the abundance of possessions.',
   'Foundations of Faith', ARRAY['parables', 'wealth', 'idolatry', 'mortality'], 320, 50),

  ('ab100000-e29b-41d4-a716-446655440021', 'The Barren Fig Tree',
   'A fig tree produces no fruit for three years. The owner wants to cut it down, but the gardener asks for one more year. This parable speaks of divine patience with those who have not yet borne the fruit of repentance — but also the real possibility that patience runs out. It is a call to fruitfulness before the season closes.',
   'Foundations of Faith', ARRAY['parables', 'repentance', 'fruitfulness', 'patience'], 321, 50),

  ('ab100000-e29b-41d4-a716-446655440022', 'The Great Banquet',
   'A man prepares a great feast, but all invited make excuses. He sends servants into the streets to bring in the poor, crippled, blind, and lame. The gospel invitation goes where the self-sufficient will not come. Those who consider themselves too busy for God''s kingdom find the door closed.',
   'Foundations of Faith', ARRAY['parables', 'salvation', 'invitation', 'exclusion'], 322, 50),

  ('ab100000-e29b-41d4-a716-446655440023', 'The Lost Coin',
   'A woman with ten coins loses one and searches her whole house until she finds it — then calls her neighbors to celebrate. This brief parable, paired with the Lost Sheep and Prodigal Son, forms a trilogy of divine seeking. Heaven rejoices over one sinner who repents.',
   'Foundations of Faith', ARRAY['parables', 'grace', 'repentance', 'god''s love'], 323, 50),

  ('ab100000-e29b-41d4-a716-446655440024', 'The Prodigal Son',
   'A son demands his inheritance early, wastes it in reckless living, comes to his senses in a pig pen, and returns home — only to be met by a father running to embrace him. This parable is the gospel in miniature: human rebellion, awakening, and a father''s extravagant grace. The older son''s resentment warns that self-righteousness can keep us as far from the Father as open sin.',
   'Foundations of Faith', ARRAY['parables', 'grace', 'repentance', 'redemption'], 324, 50),

  ('ab100000-e29b-41d4-a716-446655440025', 'The Dishonest Manager',
   'A manager about to lose his position uses his remaining authority to reduce debtors'' bills, securing their future goodwill. Jesus commends not the manager''s dishonesty but his shrewdness: use available resources wisely in light of coming crisis. The application is clear — steward whatever God has entrusted to you for eternal, kingdom purposes, before the opportunity expires.',
   'Foundations of Faith', ARRAY['parables', 'stewardship', 'eternity', 'wisdom'], 325, 50),

  ('ab100000-e29b-41d4-a716-446655440026', 'The Rich Man and Lazarus',
   'A rich man feasts daily while a beggar named Lazarus lies at his gate. Both die; Lazarus is carried to Abraham''s side while the rich man is in torment. This account reveals three crucial truths: conscious existence after death, the reversal of earthly conditions in eternity, and the fixed irreversible state of the dead. It also declares the sufficiency of Scripture: "If they do not hear Moses and the Prophets, neither will they be convinced if someone should rise from the dead."',
   'Foundations of Faith', ARRAY['parables', 'eternity', 'judgment', 'scripture'], 326, 50),

  ('ab100000-e29b-41d4-a716-446655440027', 'The Persistent Widow',
   'A widow repeatedly demands justice from an unjust judge who neither fears God nor respects man. Eventually he grants her request simply to stop being bothered. Jesus contrasts this reluctant judge with God — if even an unjust judge responds, will not God vindicate his elect who cry to him day and night? This parable calls to persistent, trustful prayer.',
   'Foundations of Faith', ARRAY['parables', 'prayer', 'justice', 'faith'], 327, 50),

  ('ab100000-e29b-41d4-a716-446655440028', 'The Pharisee and the Tax Collector',
   'Two men pray in the temple. The Pharisee recounts his spiritual achievements; the tax collector can only say, "God, be merciful to me, a sinner." Jesus declares that the tax collector — not the Pharisee — went home justified. Justification comes not to those who trust in their own righteousness but to those who cast themselves entirely on God''s mercy.',
   'Foundations of Faith', ARRAY['parables', 'justification', 'humility', 'prayer'], 328, 50)

ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- SOM: Sermon on the Mount (20 topics)
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('ab200000-e29b-41d4-a716-446655440001', 'The Beatitudes',
   'The Sermon on the Mount opens with counter-cultural blessings that overturn every expectation of the good life. The poor in spirit, the mourning, the meek, the hungry, the merciful, the pure, the peacemakers, and the persecuted are the ones Jesus calls blessed. These are not conditions to achieve but descriptions of the character God produces in those who are his.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'beatitudes', 'kingdom', 'character'], 329, 50),

  ('ab200000-e29b-41d4-a716-446655440002', 'Salt and Light',
   'Followers of Jesus are called to be salt that preserves and light that cannot be hidden. These are not commands to try harder to be influential — they are declarations of what kingdom people already are by grace. The call is not to lose saltiness through assimilation or hide the light through fear, but to let transformed lives shine for the glory of the Father.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'witness', 'discipleship', 'influence'], 330, 50),

  ('ab200000-e29b-41d4-a716-446655440003', 'Christ Fulfills the Law',
   'Jesus does not come to abolish the Law and Prophets but to fulfill them — to bring them to their full intended meaning. He is himself the telos (goal) to which all of Scripture points (Romans 10:4). The Sermon on the Mount does not set a new legal bar for earning God''s favor; it reveals the desires of a heart made new by grace. Reading this text as moral perfectionism misses its Christological center entirely.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'law and gospel', 'grace', 'fulfillment'], 331, 50),

  ('ab200000-e29b-41d4-a716-446655440004', 'Anger and Reconciliation',
   'Jesus deepens the command against murder by reaching into its root: unrighteous anger and contempt for others. The kingdom ethic demands not merely avoiding violence but actively pursuing reconciliation — even leaving a gift at the altar to go make peace first. The condition of our horizontal relationships reflects the genuineness of our vertical relationship with God.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'anger', 'reconciliation', 'peace'], 332, 50),

  ('ab200000-e29b-41d4-a716-446655440005', 'Purity of Heart',
   'Jesus extends the seventh commandment beyond physical adultery to the look of lust, addressing the desire behind the deed. The language of cutting off a hand or gouging out an eye is not literal self-mutilation but a call to radical action: deal ruthlessly with whatever feeds sinful desire. Kingdom purity is a matter of the heart, not merely external conduct.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'purity', 'lust', 'heart'], 333, 50),

  ('ab200000-e29b-41d4-a716-446655440006', 'Divorce',
   'Jesus addresses the Pharisaic misuse of Mosaic divorce provisions, calling his hearers back to God''s original design for marriage as a lifelong covenant. This text requires pastoral care alongside doctrinal clarity — acknowledging both the seriousness of covenant faithfulness and the reality of human brokenness. The Sermon calls disciples to a higher covenant standard than what is merely legally permissible. The exception clause ("except on the ground of sexual immorality," Matt 5:32) has been interpreted differently across evangelical traditions, and requires careful pastoral discernment rather than simplistic application. The Sermon''s emphasis falls on the sanctity and permanence of the covenant, not on codifying exceptions.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'marriage', 'divorce', 'covenant'], 334, 50),

  ('ab200000-e29b-41d4-a716-446655440007', 'Oaths and Integrity',
   'Jesus forbids the elaborate oath systems the Pharisees used to distinguish binding from non-binding statements. Kingdom citizens are to be people of such transparent honesty that oaths become unnecessary — let your yes be yes and your no be no. Integrity is not the result of stronger oaths but of a transformed character.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'honesty', 'integrity', 'speech'], 335, 50),

  ('ab200000-e29b-41d4-a716-446655440008', 'Nonresistance: The Ethic of the Kingdom',
   'Jesus deepens the principle of proportional justice (eye for an eye) by calling his disciples to go further — turn the other cheek, give the cloak, go the extra mile. This is not a new legal code replacing Mosaic law, but a description of kingdom ethics that flows from a heart transformed by grace. Kingdom citizens do not retaliate because they trust the God who vindicates and they no longer live for self-preservation.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'nonresistance', 'kingdom ethics', 'grace'], 336, 50),

  ('ab200000-e29b-41d4-a716-446655440009', 'Love Your Enemies',
   'The pinnacle of the Sermon''s ethical vision: love not just neighbors but enemies, pray for persecutors, be sons of the Father who makes his sun rise on the evil and the good alike. This love is not sentiment but active goodwill — seeking the genuine good of those who harm us. It is only possible through the power of the Spirit and the imitation of a God who loved us while we were still enemies.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'love', 'enemies', 'grace'], 337, 50),

  ('ab200000-e29b-41d4-a716-446655440010', 'Giving in Secret',
   'True acts of generosity, prayer, and fasting are done for an audience of One. Jesus warns against performing religious acts for human applause, calling it hypocrisy that has already received its full reward. Kingdom righteousness does not require an audience because its motivation is the approval of the Father who sees in secret.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'giving', 'hypocrisy', 'generosity'], 338, 50),

  ('ab200000-e29b-41d4-a716-446655440011', 'The Lord''s Prayer',
   'Jesus gives his disciples a model prayer that reorients every dimension of life around God''s glory and kingdom. The six petitions move from God''s name and kingdom to daily needs, sins, and temptations — all placed in the context of fatherly care. The teaching on forgiveness in verses 14-15 does not mean our forgiveness of others earns God''s forgiveness; it reveals that a genuinely forgiven heart is a forgiving heart.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'prayer', 'forgiveness', 'kingdom'], 339, 50),

  ('ab200000-e29b-41d4-a716-446655440012', 'Fasting',
   'Jesus assumes his disciples will fast — "when you fast," not "if." Kingdom fasting is not a public performance for spiritual reputation but a private, disciplined act of seeking God''s face. It is an expression of dependence on God rather than on bread alone.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'fasting', 'spiritual disciplines', 'dependence'], 340, 50),

  ('ab200000-e29b-41d4-a716-446655440013', 'Treasures in Heaven',
   'Where we store our treasure reveals where our heart truly is. Jesus calls disciples to invest in the eternal rather than the earthly — not because material things are evil but because they cannot survive moth, rust, and thief. Generosity and kingdom-oriented giving are the natural expression of those whose hearts are set on heaven, not the means of accumulating divine credit.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'wealth', 'generosity', 'eternity'], 341, 50),

  ('ab200000-e29b-41d4-a716-446655440014', 'Do Not Worry',
   'Jesus calls his disciples to radical trust in the Father''s provision — pointing to birds and lilies as evidence of divine care. This passage is not anxiety management technique but theological rootedness: "Your heavenly Father knows that you need all these things" (v. 32). Trust in divine sovereignty — not positive thinking — is the biblical answer to worry. Seek first his kingdom and righteousness, and these things will be added.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'worry', 'trust', 'providence'], 342, 50),

  ('ab200000-e29b-41d4-a716-446655440015', 'Do Not Judge',
   'Jesus prohibits hypocritical, self-exalting judgment — the kind that ignores the beam in one''s own eye while fixating on the speck in another''s. This is not a ban on all moral discernment. Verse 6 ("do not throw pearls before swine") immediately requires the exercise of moral judgment, proving that Matthew 7:1 is about the posture and consistency of judgment, not its elimination. Do not use this verse to silence biblical correction.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'judgment', 'discernment', 'hypocrisy'], 343, 50),

  ('ab200000-e29b-41d4-a716-446655440016', 'Ask, Seek, Knock',
   'Jesus encourages bold, persistent prayer with the promise that the Father gives good gifts to those who ask. If sinful fathers give good gifts to their children, how much more will the perfectly good heavenly Father give — including the Holy Spirit himself (Luke 11:13) — to those who ask? The movement from asking to seeking to knocking suggests increasing urgency and investment in prayer.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'prayer', 'persistence', 'trust'], 344, 50),

  ('ab200000-e29b-41d4-a716-446655440017', 'The Narrow Gate',
   'The road to destruction is wide and well-traveled; the road to life is narrow and few find it. This is not a statement about the salvation of a small number but a warning against the broad, popular, easy religion that does not lead to life. The kingdom is entered not by the crowd but by deliberate choice — the choice to follow the one who is himself the Way.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'salvation', 'discipleship', 'narrow way'], 345, 50),

  ('ab200000-e29b-41d4-a716-446655440018', 'A Tree and Its Fruit',
   'False prophets come in sheep''s clothing but are known by their fruit. A good tree cannot bear bad fruit; a bad tree cannot bear good fruit. This passage provides the biblical principle for discerning between true and false teachers — not by charisma or claimed authority, but by the character of their lives and the faithfulness of their doctrine.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'false prophets', 'discernment', 'fruit'], 346, 50),

  ('ab200000-e29b-41d4-a716-446655440019', 'True and False Disciples',
   '"Not everyone who says to me, ''Lord, Lord,'' will enter the kingdom of heaven, but the one who does the will of my Father." Even dramatic religious experiences and impressive works performed in Jesus''s name are no guarantee of genuine relationship with him. This terrifying reality guards against false assurance and calls disciples to genuine, ongoing submission to God''s revealed will.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'false assurance', 'discipleship', 'obedience'], 347, 50),

  ('ab200000-e29b-41d4-a716-446655440020', 'The Wise and Foolish Builders',
   'Two builders construct houses on different foundations — rock and sand. When the storm comes, only the house on rock survives. The rock is hearing and doing the words of Jesus; the sand is hearing without doing. This parable concludes the entire Sermon: the question is not whether you have heard these words but whether you are building your life upon them.',
   'Foundations of Faith', ARRAY['sermon on the mount', 'obedience', 'foundation', 'wisdom'], 348, 50)

ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- ROM: Romans (16 topics, one per chapter)
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('ab300000-e29b-41d4-a716-446655440001', 'The Power of the Gospel and Universal Human Guilt',
   'Paul opens his magnum opus by declaring the gospel''s power for salvation to everyone who believes. He then demonstrates why it is needed: from Adam onward, all humanity has suppressed the knowledge of God that creation declares, exchanged the glory of God for idols, and stands under divine wrath. The diagnosis is universal — Gentile and Jew alike are without excuse before a holy God.',
   'Foundations of Faith', ARRAY['romans', 'gospel', 'sin', 'judgment'], 349, 50),

  ('ab300000-e29b-41d4-a716-446655440002', 'God''s Impartial Judgment',
   'Paul confronts the self-righteous moralizer who agrees with God''s condemnation of others while committing the same things. God''s judgment is based on truth and impartial — whether Jew or Gentile, the standard is the same. Those who have the Law will be judged by it; those without it will be judged by the law written on their hearts. No one can appeal to religious privilege before God.',
   'Foundations of Faith', ARRAY['romans', 'judgment', 'impartiality', 'law'], 350, 50),

  ('ab300000-e29b-41d4-a716-446655440003', 'Righteousness Through Faith',
   'The prosecutorial argument of Romans 1-2 reaches its verdict in chapter 3: all have sinned and fall short of the glory of God — not one is righteous. But the same passage announces the stunning solution: justification freely by God''s grace, through the redemption in Christ Jesus, received through faith. This is the heart of the gospel: sinners are declared righteous not by works but by faith alone in Christ alone.',
   'Foundations of Faith', ARRAY['romans', 'justification', 'faith', 'grace'], 351, 50),

  ('ab300000-e29b-41d4-a716-446655440004', 'Abraham, Father of Faith',
   'Paul turns to Abraham to demonstrate that justification by faith is not a Pauline innovation but the pattern of the Old Testament itself. Abraham was declared righteous before circumcision, before the Law existed. He believed God, and it was counted to him as righteousness. The children of Abraham are those who share his faith, not merely his bloodline.',
   'Foundations of Faith', ARRAY['romans', 'abraham', 'faith', 'justification'], 352, 50),

  ('ab300000-e29b-41d4-a716-446655440005', 'Peace with God Through Christ',
   'Because we are justified by faith, we have peace with God through our Lord Jesus Christ. Romans 5 expands the blessings of justification — hope, suffering producing endurance, God''s love poured into our hearts by the Spirit. Paul introduces the two-Adams framework: as Adam''s one act of disobedience brought condemnation, so Christ''s one act of righteousness brings justification of life to all who are in him.',
   'Foundations of Faith', ARRAY['romans', 'justification', 'peace', 'adam and christ'], 353, 50),

  ('ab300000-e29b-41d4-a716-446655440006', 'Dead to Sin, Alive in Christ',
   'Shall we continue in sin so that grace may abound? By no means! Paul explains the believer''s union with Christ in his death and resurrection. Through baptism we were buried with Christ and raised with him. We are to consider ourselves dead to sin and alive to God — presenting our members as instruments of righteousness rather than sin. Paul''s language of baptism here refers to the believer''s spiritual union with Christ — the reality of which water baptism is the outward sign — not to the act of water baptism as the mechanism of dying and rising with Christ.',
   'Foundations of Faith', ARRAY['romans', 'sanctification', 'union with christ', 'sin'], 354, 50),

  ('ab300000-e29b-41d4-a716-446655440007', 'The Struggle with Sin and the Law',
   '"I do not do what I want, but I do the very thing I hate." The strong Reformed tradition, following Augustine, Luther, and Calvin, understands this as describing Paul''s ongoing experience as a regenerate believer. The believer genuinely delights in God''s law in the inner person, while experiencing the ongoing pull of indwelling sin. This internal conflict is the mark of genuine regeneration, not its absence.',
   'Foundations of Faith', ARRAY['romans', 'sin', 'law', 'struggle'], 355, 50),

  ('ab300000-e29b-41d4-a716-446655440008', 'Life in the Spirit',
   'There is therefore now no condemnation for those who are in Christ Jesus. Romans 8 is the greatest single chapter on the Christian life — life in the Spirit, adoption as children of God, the Spirit''s intercession in our weakness, and the unshakeable promise that all things work together for good for those who love God and are called according to his purpose. Nothing in all creation can separate us from the love of God in Christ Jesus.',
   'Foundations of Faith', ARRAY['romans', 'holy spirit', 'assurance', 'no condemnation'], 356, 50),

  ('ab300000-e29b-41d4-a716-446655440009', 'God''s Sovereign Election',
   'Romans 9 contains the New Testament''s clearest statement of unconditional election. Before Jacob and Esau were born or had done anything good or evil, God chose Jacob — not on the basis of works but of his call. Paul quotes God: "I will have mercy on whom I have mercy," and concludes: "It depends not on human will or exertion, but on God, who has mercy." This sovereign freedom in grace is not injustice but the very foundation of all hope.',
   'Foundations of Faith', ARRAY['romans', 'election', 'sovereignty', 'grace'], 357, 50),

  ('ab300000-e29b-41d4-a716-446655440010', 'Salvation for All Who Call',
   'If you confess with your mouth that Jesus is Lord and believe in your heart that God raised him from the dead, you will be saved. Romans 10 moves from divine sovereignty to human responsibility without dissolving the tension. Everyone who calls on the name of the Lord will be saved — Jew and Greek alike. But how will they call on one they have not heard? This chapter carries the church''s missionary mandate.',
   'Foundations of Faith', ARRAY['romans', 'salvation', 'faith', 'mission'], 358, 50),

  ('ab300000-e29b-41d4-a716-446655440011', 'The Mystery of Israel''s Future',
   'Has God abandoned his promises to Israel? By no means. Paul reveals a mystery: a partial hardening has come upon Israel until the fullness of the Gentiles comes in, and then all Israel will be saved. This chapter holds together divine faithfulness to covenant promises and the present Gentile mission, concluding with a doxology: "Oh, the depth of the riches and wisdom and knowledge of God!"',
   'Foundations of Faith', ARRAY['romans', 'israel', 'eschatology', 'covenant'], 359, 50),

  ('ab300000-e29b-41d4-a716-446655440012', 'Living Sacrifices and Kingdom Ethics',
   '"I appeal to you therefore, brothers, by the mercies of God, to present your bodies as a living sacrifice." The therefore connects the ethics of Romans 12 to the gospel of Romans 1-11. Transformed living is the reasonable response to God''s grace. Paul unfolds what this looks like: humble service, love without hypocrisy, blessing enemies, overcoming evil with good.',
   'Foundations of Faith', ARRAY['romans', 'ethics', 'spiritual gifts', 'love'], 360, 50),

  ('ab300000-e29b-41d4-a716-446655440013', 'Governing Authorities and the Debt of Love',
   'Paul addresses submission to governing authorities as God''s servants for justice, and the ongoing debt of love — the only debt that grows larger the more it is paid. The governing authorities passage does not mandate blind obedience but recognizes government''s God-given role in restraining evil. The love passage reframes the entire Law: love your neighbor as yourself and you have fulfilled it.',
   'Foundations of Faith', ARRAY['romans', 'government', 'love', 'neighbors'], 361, 50),

  ('ab300000-e29b-41d4-a716-446655440014', 'Receiving One Another',
   'The strong in faith should not despise those with weaker consciences; the weak should not judge the strong. Paul addresses tensions over food and holy days in the Roman church, calling each group to stop judging and to act in love so as not to cause a brother to stumble. The goal is mutual acceptance after the pattern of Christ, who received both the strong and the weak.',
   'Foundations of Faith', ARRAY['romans', 'conscience', 'unity', 'love'], 362, 50),

  ('ab300000-e29b-41d4-a716-446655440015', 'United in Christ''s Mission',
   'Paul grounds Christian unity in the example of Christ, who did not please himself. He then unveils his apostolic strategy — to proclaim the gospel where Christ has not yet been named — and his desire to extend this mission to Spain via Rome. The gospel is inherently missional; salvation draws every believer into God''s worldwide redemptive project.',
   'Foundations of Faith', ARRAY['romans', 'unity', 'mission', 'gentiles'], 363, 50),

  ('ab300000-e29b-41d4-a716-446655440016', 'Greetings and the Community of Faith',
   'Paul''s closing chapter is a portrait of the early Christian community — diverse, multiethnic, including men and women in ministry service, marked by warmth and mutual care. It also contains his final warning: watch out for those who cause divisions contrary to the doctrine you have been taught (16:17-20). The unity of the church is maintained not by silence about doctrine but by shared faithfulness to the apostolic gospel.',
   'Foundations of Faith', ARRAY['romans', 'community', 'doctrinal faithfulness', 'warning'], 364, 50)

ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- CXR: Jesus's Crucifixion and Resurrection (16 topics)
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('ab400000-e29b-41d4-a716-446655440001', 'The Last Supper',
   'On the night of his betrayal, Jesus gathered his disciples, broke bread, and shared wine — inaugurating the new covenant in his body and blood. This final meal carries Passover memory, covenant language, and the institution of the Lord''s Supper as a lasting memorial of his atoning death. It is also a meal of remarkable intimacy — Jesus washing feet, promising the Spirit, praying for his own. The elements of bread and wine do not become Christ''s body and blood but are signs and seals of the covenant grace received through faith in his once-for-all atoning sacrifice.',
   'Foundations of Faith', ARRAY['crucifixion', 'last supper', 'covenant', 'atonement'], 365, 50),

  ('ab400000-e29b-41d4-a716-446655440002', 'The Garden of Gethsemane',
   'In Gethsemane, Jesus falls on his face and prays: "Father, if it is possible, let this cup pass from me; yet not as I will, but as you will." This is not the prayer of a reluctant victim but of the eternal Son in genuine agony, bearing the weight of what lies ahead. Jesus watches while the disciples sleep — showing both his solidarity with human weakness and his unique, unshared burden. (Matt 26:36-46)',
   'Foundations of Faith', ARRAY['crucifixion', 'gethsemane', 'prayer', 'suffering'], 366, 50),

  ('ab400000-e29b-41d4-a716-446655440003', 'Betrayal and Arrest',
   'Judas arrives with a crowd of chief priests and elders, identifies Jesus with a kiss, and Jesus is seized. One disciple draws a sword; Jesus rebukes him and heals the servant''s ear. Then all the disciples flee. This moment fulfills Scripture and marks the complete transfer of Jesus into the hands of those who will kill him — yet he goes willingly. (Matt 26:47-56)',
   'Foundations of Faith', ARRAY['crucifixion', 'betrayal', 'arrest', 'fulfillment'], 367, 50),

  ('ab400000-e29b-41d4-a716-446655440004', 'Peter''s Denial',
   'Three times Peter is identified as a follower of Jesus. Three times he denies it with increasing intensity — "I do not know the man." At the third denial the rooster crows, Peter remembers Jesus''s words, and goes out and weeps bitterly. His fall is a reminder that even genuine faith can crumble under pressure, and a foreshadowing of the grace that would restore him.',
   'Foundations of Faith', ARRAY['crucifixion', 'peter', 'denial', 'failure'], 368, 50),

  ('ab400000-e29b-41d4-a716-446655440005', 'Jesus Before the Sanhedrin',
   'The council seeks false testimony to put Jesus to death. When the high priest asks, "Are you the Christ, the Son of God?" Jesus answers, "You have said so. And I tell you, from now on you will see the Son of Man seated at the right hand of Power and coming on the clouds of heaven." The council declares blasphemy and condemns him to death.',
   'Foundations of Faith', ARRAY['crucifixion', 'trial', 'identity', 'messiah'], 369, 50),

  ('ab400000-e29b-41d4-a716-446655440006', 'Jesus Before Pilate',
   'Pilate finds no guilt in Jesus yet yields to the crowd''s demand for crucifixion. He washes his hands, declaring himself innocent of Jesus''s blood. The crowd cries, "His blood be on us." Pilate releases Barabbas — a murderer — in Jesus''s place, illustrating what the cross accomplishes: the guilty go free while the innocent dies as our substitute.',
   'Foundations of Faith', ARRAY['crucifixion', 'pilate', 'trial', 'substitution'], 370, 50),

  ('ab400000-e29b-41d4-a716-446655440007', 'The Crucifixion',
   'Jesus is nailed to the cross between two criminals. Passersby mock him; the chief priests taunt him. Yet even in death, Jesus extends grace — praying for his persecutors (Luke 23:34), promising paradise to the repentant thief (Luke 23:43). The inscription above reads: "This is Jesus, the King of the Jews." The crucifixion is simultaneously the world''s greatest crime and its greatest gift.',
   'Foundations of Faith', ARRAY['crucifixion', 'cross', 'atonement', 'grace'], 371, 50),

  ('ab400000-e29b-41d4-a716-446655440008', 'The Death of Jesus',
   'From noon until 3 PM darkness covers the land. Jesus cries, "My God, my God, why have you forsaken me?" — the opening of Psalm 22, the cry of one bearing divine abandonment. He breathes his last. The temple curtain tears from top to bottom. In his death, Jesus bears the full penalty of sin and opens the way into God''s holy presence — the barrier removed, not by human effort but by his blood.',
   'Foundations of Faith', ARRAY['crucifixion', 'death', 'atonement', 'forsaken'], 372, 50),

  ('ab400000-e29b-41d4-a716-446655440009', 'The Burial of Jesus',
   'Joseph of Arimathea places Jesus''s body in his own new tomb, sealed with a stone. The chief priests request a guard to prevent the disciples from stealing the body. God''s providential care is visible even in the burial: the very precautions taken to prevent a resurrection claim only deepen the evidence that the resurrection actually occurred.',
   'Foundations of Faith', ARRAY['crucifixion', 'burial', 'resurrection', 'providence'], 373, 50),

  ('ab400000-e29b-41d4-a716-446655440010', 'The Empty Tomb',
   'On the first day of the week, the women come to the tomb and find it empty. An angel declares: "He is not here, for he has risen, as he said." The resurrection is not a subjective experience of the disciples — it is a historical event attested by an empty tomb, angelic announcement, and multiple appearances. It is the foundation on which all Christian faith stands or falls.',
   'Foundations of Faith', ARRAY['resurrection', 'empty tomb', 'foundation', 'history'], 374, 50),

  ('ab400000-e29b-41d4-a716-446655440011', 'Jesus Appears to Mary Magdalene',
   'Mary Magdalene stands weeping outside the tomb. She mistakes the risen Jesus for a gardener — until he speaks her name. Her recognition comes through his voice, not his appearance. This intimate encounter is the first recorded resurrection appearance. Mary becomes the first witness of the risen Christ — the risen Lord makes himself known through personal encounter.',
   'Foundations of Faith', ARRAY['resurrection', 'mary magdalene', 'appearance', 'recognition'], 375, 50),

  ('ab400000-e29b-41d4-a716-446655440012', 'The Road to Emmaus',
   'Two disciples walking to Emmaus meet the risen Jesus but do not recognize him. He walks with them, expounds "in all the Scriptures the things concerning himself," and is revealed to them in the breaking of bread. Their hearts had burned as he opened the Scriptures. The resurrection gives meaning to the entire Old Testament and enables true comprehension of all that Scripture points to.',
   'Foundations of Faith', ARRAY['resurrection', 'emmaus', 'scripture', 'recognition'], 376, 50),

  ('ab400000-e29b-41d4-a716-446655440013', 'Jesus Appears to the Disciples',
   'Jesus appears to the gathered disciples, shows his hands and side, and breathes on them, saying, "Receive the Holy Spirit." The commission in verse 23 — "If you forgive the sins of anyone, they are forgiven" — entrusts the church with the ministry of declaring the gospel: announcing forgiveness to those who repent and believe, and the retention of sin to those who do not. This is the church''s proclamatory authority, not sacerdotal power.',
   'Foundations of Faith', ARRAY['resurrection', 'commission', 'holy spirit', 'church'], 377, 50),

  ('ab400000-e29b-41d4-a716-446655440014', 'Thomas: Doubt and Belief',
   'Thomas, absent from the first appearance, refuses to believe without seeing the wounds. A week later, Jesus appears again and invites Thomas to touch his hands and side. Thomas''s response is the highest confession in John''s Gospel: "My Lord and my God." Jesus''s words follow: "Blessed are those who have not seen and yet have believed." Faith, not sight, is the normal and blessed way of knowing the risen Christ.',
   'Foundations of Faith', ARRAY['resurrection', 'thomas', 'doubt', 'faith'], 378, 50),

  ('ab400000-e29b-41d4-a716-446655440015', 'The Great Commission',
   'Jesus meets his disciples on a mountain in Galilee. He declares universal authority and sends them: "Go therefore and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit, teaching them to observe all that I have commanded you." The resurrection is the basis, universal lordship is the authority, and disciple-making across all nations is the mission.',
   'Foundations of Faith', ARRAY['resurrection', 'great commission', 'mission', 'discipleship'], 379, 50),

  ('ab400000-e29b-41d4-a716-446655440016', 'The Ascension',
   'Forty days after his resurrection, Jesus is lifted up and a cloud takes him from the disciples'' sight. Two angels promise: "This Jesus, who was taken from you into heaven, will come in the same way as you saw him go." The ascension is not the end of Christ''s story but the beginning of his heavenly reign — seated at the right hand of the Father, interceding, ruling, and preparing to return.',
   'Foundations of Faith', ARRAY['resurrection', 'ascension', 'return of christ', 'lordship'], 380, 50)

ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- HEB: Hebrews (13 topics, one per chapter)
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('ab500000-e29b-41d4-a716-446655440001', 'The Supremacy of Christ',
   'God spoke through prophets in many ways at many times, but in these last days he has spoken through his Son — the radiance of his glory and the exact imprint of his nature. Hebrews opens by establishing Christ''s absolute supremacy: above the prophets, above the angels who mediated the Law, seated at the right hand of the Majesty on high. Every argument in Hebrews builds on this foundation.',
   'Foundations of Faith', ARRAY['hebrews', 'christ', 'supremacy', 'revelation'], 381, 50),

  ('ab500000-e29b-41d4-a716-446655440002', 'A Great Salvation',
   'The first of Hebrews'' great warnings: "How shall we escape if we neglect such a great salvation?" The Son who is above angels shared in human flesh and blood, tasted death for everyone, and destroyed the power of the devil. Because he suffered and was tempted, he is able to help those who are tempted. The word is urgent: do not drift from what you have heard.',
   'Foundations of Faith', ARRAY['hebrews', 'salvation', 'warning', 'suffering'], 382, 50),

  ('ab500000-e29b-41d4-a716-446655440003', 'Jesus Greater Than Moses',
   'Moses was faithful as a servant in God''s house; Jesus is faithful as the Son over God''s house, and we are that house if we hold our confidence firm. The second warning: "Harden not your hearts as in the rebellion." The Israelite generation that witnessed God''s miracles did not enter rest because of unbelief. Perseverance is not a supplement to saving faith — it is the shape saving faith takes through time.',
   'Foundations of Faith', ARRAY['hebrews', 'moses', 'warning', 'perseverance'], 383, 50),

  ('ab500000-e29b-41d4-a716-446655440004', 'Entering God''s Rest',
   'The promise of rest remains — a rest the Israelites failed to enter through unbelief, and that Joshua''s conquest only partially anticipated. God''s rest (sabbatismos) is the ultimate inheritance of his people, a rest from works as God rested from his. The living and active word of God, sharper than any two-edged sword, lays bare the heart''s condition before the God to whom we must give account.',
   'Foundations of Faith', ARRAY['hebrews', 'rest', 'word of god', 'faith'], 384, 50),

  ('ab500000-e29b-41d4-a716-446655440005', 'Our Great High Priest',
   'Jesus is our great High Priest who has passed through the heavens, who can sympathize with our weaknesses because he was tempted in every respect as we are — yet without sin. He did not exalt himself but was appointed by God, like Melchizedek. This is an introduction to the Melchizedek argument that will be developed fully in chapter 7.',
   'Foundations of Faith', ARRAY['hebrews', 'high priest', 'melchizedek', 'sympathy'], 385, 50),

  ('ab500000-e29b-41d4-a716-446655440006', 'Press On to Maturity',
   'Hebrews 6 contains the most difficult warning in the New Testament: those who have been enlightened, tasted the heavenly gift, shared in the Holy Spirit, and then fallen away cannot be restored to repentance. Yet the author is convinced of "better things" for his readers. The warning functions as a means of perseverance — designed to call the audience to press on and hold fast, not to destabilize those who genuinely trust Christ. The author describes those who fall away using language that describes genuine experience of the Spirit''s work — whether this describes fully regenerate believers who apostatize (an Arminian reading) or those who experience external blessings of the covenant without true saving faith (the Reformed reading) has been debated for centuries. What is not in dispute is the solemn function of the warning itself: it is a call to press forward in genuine faith. The author''s assurance that he expects "better things" of his readers (6:9) indicates the warning is addressed to those in danger of drifting — for those who genuinely trust Christ, this passage is a call to endurance, not a source of despair.',
   'Foundations of Faith', ARRAY['hebrews', 'warning', 'apostasy', 'perseverance'], 386, 50),

  ('ab500000-e29b-41d4-a716-446655440007', 'The Priesthood of Melchizedek',
   'Jesus holds a permanent priesthood — not by Levitical descent but according to the order of Melchizedek, a priest-king whose priesthood Scripture presents without beginning or end. The Levitical priesthood required endless repetition because death kept cutting it short. Jesus, by contrast, lives forever and therefore holds his priesthood permanently, able to save to the uttermost all who come to God through him.',
   'Foundations of Faith', ARRAY['hebrews', 'melchizedek', 'priesthood', 'intercession'], 387, 50),

  ('ab500000-e29b-41d4-a716-446655440008', 'A Better Covenant',
   'The Levitical priesthood was imperfect, so God promised through Jeremiah a new covenant — one where the law is written on hearts, sins are fully forgiven, and God''s people know him personally. The fact that God announced a new covenant showed that the first was obsolete and ready to vanish away. Every promise of the old covenant finds its "yes" in Christ, the mediator of the better covenant.',
   'Foundations of Faith', ARRAY['hebrews', 'new covenant', 'jeremiah', 'promise'], 388, 50),

  ('ab500000-e29b-41d4-a716-446655440009', 'The Heavenly Sanctuary',
   'The earthly tabernacle was only a shadow and copy of the heavenly sanctuary. Christ entered not a man-made copy but heaven itself, appearing before God on our behalf. The old sacrifices could not perfect the conscience — they were repeated annually precisely because they were insufficient. But Christ offered himself once for all, obtaining eternal redemption. One perfect sacrifice ends all sacrifice.',
   'Foundations of Faith', ARRAY['hebrews', 'atonement', 'tabernacle', 'sacrifice'], 389, 50),

  ('ab500000-e29b-41d4-a716-446655440010', 'Once and for All',
   'By a single offering Christ has perfected for all time those who are being sanctified. Where sins are forgiven, there is no longer any offering for sin. The fourth warning follows: draw near through Christ''s blood, do not neglect meeting together, and beware of sinning willfully after receiving the knowledge of the truth. This willful sin is not ongoing struggle but deliberate, persistent apostasy — the rejection of Christ''s sacrifice itself. This must not be confused with the ongoing sin struggle of Romans 7.',
   'Foundations of Faith', ARRAY['hebrews', 'atonement', 'warning', 'perseverance'], 390, 50),

  ('ab500000-e29b-41d4-a716-446655440011', 'The Hall of Faith',
   'Faith is the assurance of things hoped for, the conviction of things not seen. Hebrews 11 parades Abel, Enoch, Noah, Abraham, Sarah, Isaac, Jacob, Joseph, Moses, Rahab, the judges, David, and the prophets — all of whom lived and died trusting God for what they had not yet received. They are not examples of heroic achievement but of trust sustained through trial, torture, and death. They saw the promises from afar and greeted them.',
   'Foundations of Faith', ARRAY['hebrews', 'faith', 'heroes', 'hope'], 391, 50),

  ('ab500000-e29b-41d4-a716-446655440012', 'Running the Race',
   'Therefore, since we are surrounded by so great a cloud of witnesses (the heroes of faith in chapter 11), let us lay aside every weight and sin, and run with endurance, looking to Jesus the founder and perfecter of our faith. God disciplines those he loves as a father disciplines his children — for our good, that we may share his holiness. The community is called to pursue peace, holiness, and the grace that does not fail.',
   'Foundations of Faith', ARRAY['hebrews', 'perseverance', 'discipline', 'holiness'], 392, 50),

  ('ab500000-e29b-41d4-a716-446655440013', 'Final Instructions',
   'Hebrews closes with pastoral instruction: show hospitality to strangers, remember those in prison, honor marriage, be free from love of money, remember your leaders and imitate their faith. The climax is Christological: Jesus suffered outside the gate to sanctify the people through his own blood — so let us go to him outside the camp, bearing his reproach. The sacrifice of praise replaces all old sacrifices.',
   'Foundations of Faith', ARRAY['hebrews', 'hospitality', 'discipleship', 'worship'], 393, 50)

ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- PART 2: LEARNING PATHS
-- =====================================================

-- -------------------------------------------------------
-- Path 26: Jesus's Parables
-- Category: Theology | Level: follower | 28 topics
-- -------------------------------------------------------
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000026',
  'jesus-parables',
  'Jesus''s Parables',
  'Jesus taught in parables — earthly stories with heavenly meanings. These 28 stories reveal the nature of God''s kingdom, the scandal of grace, the weight of judgment, and the radical demands of discipleship. From the Prodigal Son to the Sower, each parable holds up a mirror to the human heart.',
  'auto_stories', '#F59E0B', 42, 'intermediate', 'follower', 'standard', false, 26, 'Theology'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440001',  0, false),  -- The Sower and the Soils
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440002',  1, false),  -- The Wheat and the Weeds
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440003',  2, false),  -- The Mustard Seed
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440004',  3, false),  -- The Yeast
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440005',  4, false),  -- The Hidden Treasure
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440006',  5, false),  -- The Pearl of Great Value
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440007',  6, true),   -- The Net (Milestone 1)
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440008',  7, false),  -- The Lost Sheep
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440009',  8, false),  -- The Unmerciful Servant
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440010',  9, false),  -- The Workers in the Vineyard
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440011', 10, false),  -- The Two Sons
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440012', 11, false),  -- The Tenants
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440013', 12, false),  -- The Wedding Banquet
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440014', 13, true),   -- The Ten Virgins (Milestone 2)
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440015', 14, false),  -- The Talents
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440016', 15, false),  -- The Sheep and the Goats
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440017', 16, false),  -- The Growing Seed
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440018', 17, false),  -- The Good Samaritan
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440019', 18, false),  -- The Persistent Friend
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440020', 19, false),  -- The Rich Fool
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440021', 20, true),   -- The Barren Fig Tree (Milestone 3)
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440022', 21, false),  -- The Great Banquet
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440023', 22, false),  -- The Lost Coin
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440024', 23, false),  -- The Prodigal Son
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440025', 24, false),  -- The Dishonest Manager
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440026', 25, false),  -- The Rich Man and Lazarus
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440027', 26, false),  -- The Persistent Widow
  ('aaa00000-0000-0000-0000-000000000026', 'ab100000-e29b-41d4-a716-446655440028', 27, true)    -- The Pharisee and the Tax Collector (Milestone 4)
ON CONFLICT DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000026', 'hi',
   'यीशु के दृष्टान्त',
   'यीशु ने दृष्टान्तों के माध्यम से परमेश्वर के राज्य के रहस्यों को प्रकट किया। खोए हुए पुत्र से लेकर बीज बोने वाले तक, ये 28 कहानियाँ अनुग्रह, न्याय और शिष्यता की गहरी सच्चाइयाँ उजागर करती हैं।'),
  ('aaa00000-0000-0000-0000-000000000026', 'ml',
   'യേശുവിന്റെ ഉപമകൾ',
   'യേശു ഉപമകളിലൂടെ ദൈവരാജ്യത്തിന്റെ രഹസ്യങ്ങൾ വെളിപ്പെടുത്തി. കാണാതായ പുത്രൻ മുതൽ വിതക്കാരൻ വരെ — ഈ 28 കഥകൾ കൃപ, ന്യായവിധി, ശിഷ്യത്വം എന്നിവയുടെ ആഴമേറിയ സത്യങ്ങൾ വെളിപ്പെടുത്തുന്നു.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- -------------------------------------------------------
-- Path 27: Sermon on the Mount
-- Category: Foundations | Level: follower | 20 topics
-- -------------------------------------------------------
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000027',
  'sermon-on-the-mount',
  'Sermon on the Mount',
  'In Matthew 5-7, Jesus delivers the most famous sermon ever preached — the constitution of the kingdom of God. From the Beatitudes to the Wise Builder, the Sermon reveals the ethics of the kingdom not as a new law to earn salvation but as the fruit of a heart transformed by grace. Study it carefully; it will not let you be comfortable.',
  'terrain', '#10B981', 30, 'intermediate', 'follower', 'standard', false, 27, 'Foundations'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440001',  0, false),  -- The Beatitudes
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440002',  1, false),  -- Salt and Light
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440003',  2, false),  -- Christ Fulfills the Law
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440004',  3, false),  -- Anger and Reconciliation
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440005',  4, false),  -- Purity of Heart
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440006',  5, false),  -- Divorce
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440007',  6, false),  -- Oaths and Integrity
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440008',  7, false),  -- Nonresistance: The Ethic of the Kingdom
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440009',  8, true),   -- Love Your Enemies (Milestone 1)
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440010',  9, false),  -- Giving in Secret
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440011', 10, false),  -- The Lord's Prayer
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440012', 11, false),  -- Fasting
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440013', 12, false),  -- Treasures in Heaven
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440014', 13, false),  -- Do Not Worry
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440015', 14, true),   -- Do Not Judge (Milestone 2)
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440016', 15, false),  -- Ask, Seek, Knock
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440017', 16, false),  -- The Narrow Gate
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440018', 17, false),  -- A Tree and Its Fruit
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440019', 18, false),  -- True and False Disciples
  ('aaa00000-0000-0000-0000-000000000027', 'ab200000-e29b-41d4-a716-446655440020', 19, true)    -- The Wise and Foolish Builders (Milestone 3)
ON CONFLICT DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000027', 'hi',
   'पहाड़ी उपदेश',
   'मत्ती 5-7 में यीशु परमेश्वर के राज्य का संविधान देते हैं। धन्यवादिताओं से बुद्धिमान निर्माता तक — यह उपदेश नई व्यवस्था नहीं बल्कि कृपा से रूपांतरित हृदय का फल है। इसका अध्ययन करें; यह आपको वैसा नहीं रहने देगा जैसे आप थे।'),
  ('aaa00000-0000-0000-0000-000000000027', 'ml',
   'മലയിലെ പ്രസംഗം',
   'മത്തായി 5-7 ൽ യേശു ദൈവരാജ്യത്തിന്റെ ഭരണഘടന നൽകുന്നു. ഭാഗ്യോക്തികൾ മുതൽ ജ്ഞാനിയായ പണിക്കാരൻ വരെ — ഈ പ്രസംഗം നൂതന നിയമമല്ല, മറിച്ച് കൃപയാൽ മാറ്റിമറിക്കപ്പെട്ട ഹൃദയത്തിന്റെ ഫലമാണ്.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- -------------------------------------------------------
-- Path 28: Romans: The Gospel Unfolded
-- Category: Theology | Level: disciple | 16 topics
-- -------------------------------------------------------
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000028',
  'romans-gospel-unfolded',
  'Romans: The Gospel Unfolded',
  'Paul''s letter to the Romans is the most systematic exposition of the gospel in all of Scripture. Study it chapter by chapter: universal sin, justification by faith alone, union with Christ, life in the Spirit, sovereign election, Israel''s future, and the ethics of a transformed life. Romans will change how you understand everything.',
  'import_contacts', '#6366F1', 32, 'advanced', 'disciple', 'deep', false, 28, 'Theology'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440001',  0, false),  -- Romans 1: Power of the Gospel & Universal Guilt
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440002',  1, false),  -- Romans 2: God's Impartial Judgment
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440003',  2, false),  -- Romans 3: Righteousness Through Faith
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440004',  3, true),   -- Romans 4: Abraham, Father of Faith (Milestone 1)
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440005',  4, false),  -- Romans 5: Peace with God Through Christ
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440006',  5, false),  -- Romans 6: Dead to Sin, Alive in Christ
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440007',  6, false),  -- Romans 7: The Struggle with Sin and the Law
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440008',  7, true),   -- Romans 8: Life in the Spirit (Milestone 2)
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440009',  8, false),  -- Romans 9: God's Sovereign Election
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440010',  9, false),  -- Romans 10: Salvation for All Who Call
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440011', 10, false),  -- Romans 11: The Mystery of Israel's Future
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440012', 11, true),   -- Romans 12: Living Sacrifices (Milestone 3)
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440013', 12, false),  -- Romans 13: Governing Authorities & Debt of Love
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440014', 13, false),  -- Romans 14: Receiving One Another
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440015', 14, false),  -- Romans 15: United in Christ's Mission
  ('aaa00000-0000-0000-0000-000000000028', 'ab300000-e29b-41d4-a716-446655440016', 15, true)    -- Romans 16: Greetings & Community of Faith (Milestone 4)
ON CONFLICT DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000028', 'hi',
   'रोमियों: सुसमाचार का प्रकाशन',
   'रोमियों पत्र पवित्रशास्त्र में सुसमाचार की सबसे व्यवस्थित व्याख्या है। 16 अध्यायों में पाएं: सार्वभौमिक पाप, विश्वास से धार्मिकता, मसीह के साथ एकता, आत्मा में जीवन, परमेश्वर का चुनाव, और रूपांतरित जीवन की नैतिकता।'),
  ('aaa00000-0000-0000-0000-000000000028', 'ml',
   'റോമർ: സുവിശേഷത്തിന്റെ ആഴം',
   'റോമർ ലേഖനം തിരുവെഴുത്തിലെ സുവിശേഷത്തിന്റെ ഏറ്റവും ക്രമബദ്ധമായ വ്യാഖ്യാനമാണ്. 16 അദ്ധ്യായങ്ങളിൽ: സാർവ്വത്രിക പാപം, വിശ്വാസത്താൽ നീതി, ക്രിസ്തുവുമായുള്ള ഐക്യം, ആത്മാവിൽ ജീവൻ, ദൈവ തിരഞ്ഞെടുപ്പ്, പരിവർത്തനം ചെയ്യപ്പെട്ട ജീവിതത്തിന്റെ ധർമ്മശാസ്ത്രം.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- -------------------------------------------------------
-- Path 29: The Crucifixion and Resurrection of Jesus
-- Category: Foundations | Level: seeker | 16 topics
-- -------------------------------------------------------
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000029',
  'crucifixion-and-resurrection',
  'The Crucifixion and Resurrection of Jesus',
  'This is the center of Christian faith — the events that change everything. From the Last Supper to the Ascension, follow the story of Jesus''s arrest, trial, death, burial, and bodily resurrection through 16 studies. No other events in history carry this weight. Here is the gospel in its fullest form.',
  'brightness_5', '#EF4444', 24, 'beginner', 'seeker', 'standard', false, 29, 'Foundations'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440001',  0, false),  -- The Last Supper
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440002',  1, false),  -- The Garden of Gethsemane
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440003',  2, false),  -- Betrayal and Arrest
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440004',  3, false),  -- Peter's Denial
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440005',  4, false),  -- Jesus Before the Sanhedrin
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440006',  5, false),  -- Jesus Before Pilate
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440007',  6, false),  -- The Crucifixion
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440008',  7, true),   -- The Death of Jesus (Milestone 1)
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440009',  8, false),  -- The Burial of Jesus
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440010',  9, false),  -- The Empty Tomb
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440011', 10, false),  -- Jesus Appears to Mary Magdalene
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440012', 11, false),  -- The Road to Emmaus
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440013', 12, false),  -- Jesus Appears to the Disciples
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440014', 13, false),  -- Thomas: Doubt and Belief
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440015', 14, false),  -- The Great Commission
  ('aaa00000-0000-0000-0000-000000000029', 'ab400000-e29b-41d4-a716-446655440016', 15, true)    -- The Ascension (Milestone 2)
ON CONFLICT DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000029', 'hi',
   'यीशु का क्रूस और पुनरुत्थान',
   'यह मसीही विश्वास का केंद्र है। अंतिम भोज से स्वर्गारोहण तक, 16 अध्ययनों में यीशु की गिरफ्तारी, परीक्षण, मृत्यु, दफनाने और शारीरिक पुनरुत्थान की कहानी का अनुसरण करें। यहाँ सुसमाचार अपने पूर्णतम रूप में है।'),
  ('aaa00000-0000-0000-0000-000000000029', 'ml',
   'യേശുവിന്റെ ക്രൂശുമരണവും പുനരുത്ഥാനവും',
   'ഇതാണ് ക്രിസ്തീയ വിശ്വാസത്തിന്റെ കേന്ദ്രം. അന്ത്യ അത്താഴം മുതൽ സ്വർഗ്ഗാരോഹണം വരെ, 16 പഠനങ്ങളിൽ യേശുവിന്റെ അറസ്റ്റ്, വിചാരണ, മരണം, സംസ്കാരം, ശാരീരിക പുനരുത്ഥാനം എന്നിവ പിന്തുടരുക. ഇവിടെ സുവിശേഷം അതിന്റെ പൂർണ്ണ രൂപത്തിൽ ഉണ്ട്.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- -------------------------------------------------------
-- Path 30: Hebrews: Jesus Our High Priest
-- Category: Theology | Level: disciple | 13 topics
-- -------------------------------------------------------
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000030',
  'hebrews-jesus-our-high-priest',
  'Hebrews: Jesus Our High Priest',
  'The letter to the Hebrews makes one sustained argument: Jesus is better. Better than angels, better than Moses, better than the Levitical priesthood — his one sacrifice is perfect and complete. Study all 13 chapters to discover how the entire Old Testament points to Christ, and why there is no going back.',
  'account_balance', '#8B5CF6', 26, 'advanced', 'disciple', 'deep', false, 30, 'Theology'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000030', 'ab500000-e29b-41d4-a716-446655440001',  0, false),  -- Hebrews 1: The Supremacy of Christ
  ('aaa00000-0000-0000-0000-000000000030', 'ab500000-e29b-41d4-a716-446655440002',  1, false),  -- Hebrews 2: A Great Salvation
  ('aaa00000-0000-0000-0000-000000000030', 'ab500000-e29b-41d4-a716-446655440003',  2, false),  -- Hebrews 3: Jesus Greater Than Moses
  ('aaa00000-0000-0000-0000-000000000030', 'ab500000-e29b-41d4-a716-446655440004',  3, false),  -- Hebrews 4: Entering God's Rest
  ('aaa00000-0000-0000-0000-000000000030', 'ab500000-e29b-41d4-a716-446655440005',  4, false),  -- Hebrews 5: Our Great High Priest
  ('aaa00000-0000-0000-0000-000000000030', 'ab500000-e29b-41d4-a716-446655440006',  5, false),  -- Hebrews 6: Press On to Maturity
  ('aaa00000-0000-0000-0000-000000000030', 'ab500000-e29b-41d4-a716-446655440007',  6, true),   -- Hebrews 7: The Priesthood of Melchizedek (Milestone 1)
  ('aaa00000-0000-0000-0000-000000000030', 'ab500000-e29b-41d4-a716-446655440008',  7, false),  -- Hebrews 8: A Better Covenant
  ('aaa00000-0000-0000-0000-000000000030', 'ab500000-e29b-41d4-a716-446655440009',  8, false),  -- Hebrews 9: The Heavenly Sanctuary
  ('aaa00000-0000-0000-0000-000000000030', 'ab500000-e29b-41d4-a716-446655440010',  9, false),  -- Hebrews 10: Once and for All
  ('aaa00000-0000-0000-0000-000000000030', 'ab500000-e29b-41d4-a716-446655440011', 10, false),  -- Hebrews 11: The Hall of Faith
  ('aaa00000-0000-0000-0000-000000000030', 'ab500000-e29b-41d4-a716-446655440012', 11, false),  -- Hebrews 12: Running the Race
  ('aaa00000-0000-0000-0000-000000000030', 'ab500000-e29b-41d4-a716-446655440013', 12, true)    -- Hebrews 13: Final Instructions (Milestone 2)
ON CONFLICT DO NOTHING;

INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000030', 'hi',
   'इब्रानियों: हमारे महायाजक यीशु',
   'इब्रानियों पत्र एक तर्क करता है: यीशु श्रेष्ठ है। स्वर्गदूतों से, मूसा से, लेवीय याजकत्व से श्रेष्ठ। उनकी एक बलिदान पूर्ण और संपूर्ण है। 13 अध्यायों में सीखें कि पूरा पुराना नियम मसीह की ओर इशारा करता है।'),
  ('aaa00000-0000-0000-0000-000000000030', 'ml',
   'എബ്രായർ: നമ്മുടെ മഹാപുരോഹിതൻ',
   'എബ്രായർ ലേഖനം ഒരു വാദഗതി ഉന്നയിക്കുന്നു: യേശു ശ്രേഷ്ഠൻ. ദൂതന്മാരേക്കാളും, മോശക്കാളും, ലേവ്യ പൗരോഹിത്യത്തേക്കാളും ശ്രേഷ്ഠൻ. അവന്റെ ഒറ്റ യാഗം പൂർണ്ണവും സമ്പൂർണ്ണവുമാണ്. 13 അദ്ധ്യായങ്ങളിൽ പഴയ നിയമം മുഴുവൻ ക്രിസ്തുവിലേക്ക് ചൂണ്ടുന്നതെങ്ങനെ എന്ന് പഠിക്കൂ.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;

COMMIT;

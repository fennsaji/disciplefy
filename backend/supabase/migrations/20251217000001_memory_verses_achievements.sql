-- Migration: Memory Verses Enhancement - Gamification Achievements
-- Created: 2025-12-17
-- Purpose: Add 10 core memory verse achievements (Beginner + Intermediate tiers)

BEGIN;

-- =============================================================================
-- UPDATE: Existing Memory Achievements
-- =============================================================================
-- Update memory_5 (Memorizer → Scripture Collector, 50 XP → 150 XP)
-- Update memory_25 (Scripture Keeper, 150 XP → 300 XP)

UPDATE achievements
SET
    name_en = 'Scripture Collector',
    name_hi = 'वचन संग्रहकर्ता',
    name_ml = 'തിരുവചന ശേഖരണക്കാരൻ',
    description_en = 'Memorize 5 verses',
    description_hi = '5 पद याद करें',
    description_ml = '5 വാക്യങ്ങൾ മനഃപാഠമാക്കുക',
    xp_reward = 150,
    sort_order = 15
WHERE id = 'memory_5';

UPDATE achievements
SET
    xp_reward = 300,
    sort_order = 20
WHERE id = 'memory_25';

-- =============================================================================
-- INSERT: 8 New Memory Achievements (Beginner + Intermediate Tiers)
-- =============================================================================

INSERT INTO achievements (id, name_en, name_hi, name_ml, description_en, description_hi, description_ml, icon, xp_reward, category, threshold, sort_order)
VALUES
    -- Beginner Tier (New Achievements)
    ('memory_first_verse', 'First Steps', 'पहला कदम', 'ആദ്യ ചുവട്', 'Add your first memory verse', 'अपना पहला याद का पद जोड़ें', 'നിങ്ങളുടെ ആദ്യ മെമ്മറി വാക്യം ചേർക്കുക', '🌱', 50, 'memory', 1, 11),

    ('memory_practice_streak_3', 'Daily Devotion', 'दैनिक भक्ति', 'ദിനംതോറുമുള്ള ഭക്തി', 'Practice memory verses 3 days in a row', 'लगातार 3 दिन याद के पद का अभ्यास करें', 'തുടർച്ചയായി 3 ദിവസം മെമ്മറി വാക്യങ്ങൾ പരിശീലിക്കുക', '📅', 100, 'memory', 3, 12),

    ('memory_modes_3', 'Verse Explorer', 'पद अन्वेषक', 'വാക്യ പര്യവേക്ഷകൻ', 'Try 3 different practice modes', '3 अलग-अलग अभ्यास मोड आज़माएँ', '3 വ്യത്യസ്ത പരിശീലന മോഡുകൾ പരീക്ഷിക്കുക', '🎯', 75, 'memory', 3, 13),

    ('memory_perfect_recall', 'Quick Learner', 'तेज़ सीखने वाला', 'പെട്ടെന്നുള്ള പഠിതാവ്', 'Achieve your first perfect recall (quality 5)', 'अपनी पहली सटीक याद प्राप्त करें', 'നിങ്ങളുടെ ആദ്യ തികഞ്ഞ ഓർമ്മ നേടുക', '⭐', 100, 'memory', 1, 14),

    -- Intermediate Tier (New Achievements)
    ('memory_practice_streak_7', 'Dedicated Student', 'समर्पित छात्र', 'സമർപ്പിത വിദ്യാർത്ഥി', 'Practice memory verses 7 days in a row', 'लगातार 7 दिन याद के पद का अभ्यास करें', 'തുടർച്ചയായി 7 ദിവസം മെമ്മറി വാക്യങ്ങൾ പരിശീലിക്കുക', '🔥', 200, 'memory', 7, 16),

    ('memory_modes_5', 'Verse Variety', 'पद विविधता', 'വാക്യ വൈവിധ്യം', 'Practice all 5 basic modes', 'सभी 5 बुनियादी मोड का अभ्यास करें', 'എല്ലാ 5 അടിസ്ഥാന മോഡുകളും പരിശീലിക്കുക', '🌈', 250, 'memory', 5, 17),

    ('memory_mastery_intermediate_3', 'Rising Star', 'उभरता हुआ सितारा', 'ഉദിക്കുന്ന നക്ഷത്രം', 'Reach Intermediate mastery on 3 verses', '3 पदों पर मध्यम स्तर की महारत हासिल करें', '3 വാക്യങ്ങളിൽ ഇന്റർമീഡിയറ്റ് വൈദഗ്ധ്യം നേടുക', '🌟', 200, 'memory', 3, 18),

    ('memory_daily_goal_5', 'Daily Champion', 'दैनिक चैंपियन', 'ദിനംപ്രതി ചാമ്പ്യൻ', 'Complete daily memory goal 5 times', '5 बार दैनिक याद लक्ष्य पूरा करें', '5 തവണ ദിനസരി മെമ്മറി ലക്ഷ്യം പൂർത്തിയാക്കുക', '🏅', 250, 'memory', 5, 19)

ON CONFLICT (id) DO UPDATE SET
    name_en = EXCLUDED.name_en,
    name_hi = EXCLUDED.name_hi,
    name_ml = EXCLUDED.name_ml,
    description_en = EXCLUDED.description_en,
    description_hi = EXCLUDED.description_hi,
    description_ml = EXCLUDED.description_ml,
    icon = EXCLUDED.icon,
    xp_reward = EXCLUDED.xp_reward,
    category = EXCLUDED.category,
    threshold = EXCLUDED.threshold,
    sort_order = EXCLUDED.sort_order;

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON TABLE achievements IS 'Master list of all available achievement badges. Extended with 8 new memory verse achievements for practice streaks, modes, mastery, and daily goals.';

COMMIT;

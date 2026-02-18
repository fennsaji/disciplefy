-- =====================================================
-- Consolidated Migration: Learning Paths Translations
-- =====================================================
-- Source: 20251201000001_create_learning_paths_translations.sql
-- Tables: Updates learning_path_translations (created in 0009)
-- Description: Improved, simpler translations for all learning paths
--              in Hindi and Malayalam with consistent English versions
-- =====================================================

-- Dependencies: 0009_learning_paths.sql (learning_path_translations table must exist)

BEGIN;

-- =====================================================
-- SUMMARY: Migration updates learning path translations
-- Completed 0001-0011 (44 tables), now updating learning
-- path translations with simpler, more readable versions
-- =====================================================

-- =====================================================
-- PART 1: CLEANUP DUPLICATE TABLE (if exists)
-- =====================================================

-- Drop duplicate table with incorrect naming (plural 'paths_translations')
-- The correct table name is 'learning_path_translations' (singular 'path')
DROP TABLE IF EXISTS learning_paths_translations CASCADE;

-- =====================================================
-- PART 2: UPDATE HINDI TRANSLATIONS
-- =====================================================

-- Insert or update Hindi translations with simpler, more readable text
-- 7 learning paths with improved translations (Paths 8 & 9 commented out)
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES

-- New Believer Essentials
('aaa00000-0000-0000-0000-000000000001', 'hi',
 'नए विश्वासी की मूल बातें',
 'इन मूलभूत विषयों के साथ अपनी विश्वास यात्रा शुरू करें। यीशु, सुसमाचार और परमेश्वर के साथ अपने रिश्ते को बढ़ाने के बारे में जानें।'),

-- Growing in Discipleship
('aaa00000-0000-0000-0000-000000000002', 'hi',
 'शिष्यता में बढ़ना',
 'अपने विश्वास को गहरा करें और जानें कि यीशु का सच्चा शिष्य होने का क्या अर्थ है। आध्यात्मिक अनुशासन, मसीही जीवन और व्यक्तिगत विकास का अन्वेषण करें।'),

-- Serving & Mission
('aaa00000-0000-0000-0000-000000000003', 'hi',
 'सेवा और मिशन',
 'दूसरों की सेवा करने और सुसमाचार साझा करने की अपनी बुलाहट को खोजें। कलीसिया समुदाय, आध्यात्मिक वरदानों और मसीह के लिए दुनिया तक पहुँचने के बारे में जानें।'),

-- Defending Your Faith
('aaa00000-0000-0000-0000-000000000004', 'hi',
 'अपने विश्वास की रक्षा करना',
 'बुद्धि, अनुग्रह और बाइबिल की समझ के साथ अपने विश्वासों को साझा करने और उनकी रक्षा करने में आत्मविश्वास बनाएं। कठिन प्रश्नों का उत्तर देना सीखें।'),

-- Faith & Family
('aaa00000-0000-0000-0000-000000000005', 'hi',
 'विश्वास और परिवार',
 'बाइबिल के सिद्धांतों के माध्यम से अपने रिश्तों को मजबूत करें और मसीह-केंद्रित घर बनाएं। विवाह, पालन-पोषण और मित्रता के लिए परमेश्वर की योजना जानें।'),

-- Deepening Your Walk
('aaa00000-0000-0000-0000-000000000006', 'hi',
 'अपनी चाल को गहरा करना',
 'आध्यात्मिक अनुशासन, संगति और उदार जीवन के माध्यम से परमेश्वर के साथ अपने रिश्ते में और गहरे जाएं। अपनी दैनिक आदतों को आराधना के कार्यों में बदलें।'),

-- Heart for the World
('aaa00000-0000-0000-0000-000000000007', 'hi',
 'दुनिया के लिए दिल',
 'मिशन पर एक वैश्विक दृष्टिकोण विकसित करें और मसीह के लिए अपने समुदाय और राष्ट्रों को प्रभावित करना सीखें। एक गुणा करने वाले शिष्य बनें।')  -- Removed trailing comma since this is now the last entry

-- COMMENTED OUT: Path 8 and 9 don't exist in learning_paths table
-- -- Rooted in Christ
-- ('aaa00000-0000-0000-0000-000000000008', 'hi',
--  'मसीह में जड़ें',
--  'मसीह में अपनी पहचान को समझकर, अनुग्रह से जीते हुए, और अटल विश्वास बनाकर अपनी नींव स्थापित करें।'),
--
-- -- Eternal Perspective (Faith & Reason)
-- ('aaa00000-0000-0000-0000-000000000009', 'hi',
--  'अनंत दृष्टिकोण',
--  'परमेश्वर की अनंत योजना को समझकर आशा और उद्देश्य प्राप्त करें - मसीह का पुनरागमन, स्वर्ग, और हमारा महिमामय भविष्य।')


ON CONFLICT (learning_path_id, lang_code) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    updated_at = NOW();

-- =====================================================
-- PART 3: UPDATE MALAYALAM TRANSLATIONS
-- =====================================================

-- Insert or update Malayalam translations with simpler, more readable text
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES

-- New Believer Essentials
('aaa00000-0000-0000-0000-000000000001', 'ml',
 'പുതിയ വിശ്വാസിയുടെ അടിസ്ഥാനങ്ങൾ',
 'ഈ അടിസ്ഥാന വിഷയങ്ങളോടെ നിങ്ങളുടെ വിശ്വാസ യാത്ര ആരംഭിക്കുക. യേശുവിനെയും സുവിശേഷവും ദൈവവുമായുള്ള നിങ്ങളുടെ ബന്ധം വളർത്തുന്നതും പഠിക്കുക.'),

-- Growing in Discipleship
('aaa00000-0000-0000-0000-000000000002', 'ml',
 'ശിഷ്യത്വത്തിൽ വളരുക',
 'നിങ്ങളുടെ വിശ്വാസം ആഴത്തിലാക്കുകയും യേശുവിന്റെ യഥാർത്ഥ ശിഷ്യനാകുക എന്നതിന്റെ അർത്ഥം പഠിക്കുകയും ചെയ്യുക. ആത്മീയ അച്ചടക്കം, ക്രിസ്തീയ ജീവിതം, വ്യക്തിഗത വളർച്ച എന്നിവ പര്യവേക്ഷണം ചെയ്യുക.'),

-- Serving & Mission
('aaa00000-0000-0000-0000-000000000003', 'ml',
 'സേവനവും മിഷനും',
 'മറ്റുള്ളവരെ സേവിക്കാനും സുവിശേഷം പങ്കുവെക്കാനുമുള്ള നിങ്ങളുടെ വിളി കണ്ടെത്തുക. സഭാ സമൂഹം, ആത്മീയ വരങ്ങൾ, ക്രിസ്തുവിനായി ലോകത്തെ എത്തിച്ചേരൽ എന്നിവയെക്കുറിച്ച് പഠിക്കുക.'),

-- Defending Your Faith
('aaa00000-0000-0000-0000-000000000004', 'ml',
 'നിങ്ങളുടെ വിശ്വാസം സംരക്ഷിക്കുക',
 'ജ്ഞാനം, കൃപ, ബൈബിൾ ധാരണ എന്നിവയോടെ നിങ്ങളുടെ വിശ്വാസങ്ങൾ പങ്കുവെക്കുന്നതിലും സംരക്ഷിക്കുന്നതിലും ആത്മവിശ്വാസം വളർത്തുക. കഠിനമായ ചോദ്യങ്ങൾക്ക് ഉത്തരം നൽകാൻ പഠിക്കുക.'),

-- Faith & Family
('aaa00000-0000-0000-0000-000000000005', 'ml',
 'വിശ്വാസവും കുടുംബവും',
 'ബൈബിൾ തത്വങ്ങളിലൂടെ നിങ്ങളുടെ ബന്ധങ്ങൾ ശക്തിപ്പെടുത്തുകയും ക്രിസ്തു കേന്ദ്രീകൃത ഭവനം കെട്ടിപ്പടുക്കുകയും ചെയ്യുക. വിവാഹം, മാതാപിതൃത്വം, സൗഹൃദം എന്നിവയ്ക്കുള്ള ദൈവത്തിന്റെ രൂപകൽപ്പന പഠിക്കുക.'),

-- Deepening Your Walk
('aaa00000-0000-0000-0000-000000000006', 'ml',
 'നിങ്ങളുടെ നടത്തം ആഴത്തിലാക്കുക',
 'ആത്മീയ അച്ചടക്കം, കൂട്ടായ്മ, ഔദാര്യമുള്ള ജീവിതം എന്നിവയിലൂടെ ദൈവവുമായുള്ള നിങ്ങളുടെ ബന്ധത്തിൽ കൂടുതൽ ആഴത്തിൽ പോകുക. നിങ്ങളുടെ ദൈനംദിന ശീലങ്ങളെ ആരാധനയുടെ പ്രവൃത്തികളാക്കി മാറ്റുക.'),

-- Heart for the World
('aaa00000-0000-0000-0000-000000000007', 'ml',
 'ലോകത്തിനായുള്ള ഹൃദയം',
 'മിഷനുകളെക്കുറിച്ച് ആഗോള വീക്ഷണം വികസിപ്പിക്കുകയും ക്രിസ്തുവിനായി നിങ്ങളുടെ സമൂഹത്തെയും രാഷ്ട്രങ്ങളെയും സ്വാധീനിക്കാൻ പഠിക്കുകയും ചെയ്യുക. ഗുണിക്കുന്ന ശിഷ്യനാകുക.')  -- Removed trailing comma since this is now the last entry

-- COMMENTED OUT: Path 8 and 9 don't exist in learning_paths table
-- -- Rooted in Christ
-- ('aaa00000-0000-0000-0000-000000000008', 'ml',
--  'ക്രിസ്തുവിൽ വേരൂന്നിയവർ',
--  'ക്രിസ്തുവിലുള്ള നിങ്ങളുടെ സ്വത്വം മനസ്സിലാക്കി, കൃപയാൽ ജീവിച്ച്, അടിയുറച്ച വിശ്വാസം പടുത്തുയർത്തി നിങ്ങളുടെ അടിത്തറ സ്ഥാപിക്കുക.'),
--
-- -- Eternal Perspective (Faith & Reason)
-- ('aaa00000-0000-0000-0000-000000000009', 'ml',
--  'നിത്യ വീക്ഷണം',
--  'ദൈവത്തിന്റെ നിത്യ പദ്ധതി മനസ്സിലാക്കി പ്രത്യാശയും ഉദ്ദേശ്യവും നേടുക - ക്രിസ്തുവിന്റെ മടങ്ങിവരവ്, സ്വർഗ്ഗം, നമ്മുടെ മഹത്വമുള്ള ഭാവി.')


ON CONFLICT (learning_path_id, lang_code) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    updated_at = NOW();

-- =====================================================
-- PART 4: ADD ENGLISH TRANSLATIONS FOR CONSISTENCY
-- =====================================================

-- Insert English translations from learning_paths table
-- This ensures all 3 languages (en, hi, ml) have consistent structure
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
SELECT id, 'en', title, description
FROM learning_paths
WHERE id IN (
  'aaa00000-0000-0000-0000-000000000001',
  'aaa00000-0000-0000-0000-000000000002',
  'aaa00000-0000-0000-0000-000000000003',
  'aaa00000-0000-0000-0000-000000000004',
  'aaa00000-0000-0000-0000-000000000005',
  'aaa00000-0000-0000-0000-000000000006',
  'aaa00000-0000-0000-0000-000000000007'
  -- COMMENTED OUT: Path 8 and 9 don't exist in learning_paths table
  -- 'aaa00000-0000-0000-0000-000000000008',
  -- 'aaa00000-0000-0000-0000-000000000009'
)
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;

-- =====================================================
-- PART 5: COMMENTS AND DOCUMENTATION
-- =====================================================

COMMENT ON TABLE learning_path_translations IS
  'Multi-language translations for learning paths (Hindi, Malayalam, English).
   Updated with simpler, more readable translations for better user experience.
   Currently includes 7 learning paths with translations in all 3 supported languages.
   (Paths 8 and 9 are commented out pending topic creation)';

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

COMMIT;

-- Verification query
SELECT
  'Migration 0012 Complete' as status,
  (SELECT COUNT(*) FROM learning_path_translations) as total_translations,
  (SELECT COUNT(DISTINCT learning_path_id) FROM learning_path_translations) as paths_with_translations,
  (SELECT COUNT(DISTINCT lang_code) FROM learning_path_translations) as languages_count;

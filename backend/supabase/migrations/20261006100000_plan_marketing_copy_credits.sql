-- Honest plan copy: credits, not tokens; memory limit is a daily review limit; Discipler counts.
UPDATE public.subscription_plans SET marketing_features = CASE plan_code
  WHEN 'free' THEN '["Daily Bible verse","15 credits a day","Quick Read and Standard studies","Guided learning paths","Review 3 memory verses a day","2 practice modes","Join fellowships"]'::jsonb
  WHEN 'standard' THEN '["Daily Bible verse","40 credits a day","Quick Read, Standard, Deep Dive and Lectio Divina","Guided learning paths","Review 5 memory verses a day · all 8 practice modes","5 follow-ups per study","Discipler · 3 conversations a month","Join fellowships"]'::jsonb
  WHEN 'plus' THEN '["Daily Bible verse","60 credits a day","All study modes","Guided learning paths","Review 10 memory verses a day · all 8 practice modes","10 follow-ups per study","Discipler · 10 conversations a month","Create and lead fellowships"]'::jsonb
  WHEN 'premium' THEN '["Daily Bible verse","Unlimited credits","All study modes","Guided learning paths","Unlimited memory reviews","Unlimited follow-ups","Unlimited Discipler conversations","Create and lead fellowships"]'::jsonb
  ELSE marketing_features END,
  updated_at = NOW()
WHERE plan_code IN ('free','standard','plus','premium');

UPDATE public.subscription_plans SET marketing_features_i18n = jsonb_set(jsonb_set(COALESCE(marketing_features_i18n,'{}'::jsonb),
  '{hi}', CASE plan_code
    WHEN 'free' THEN '["रोज़ का बाइबल वचन","15 क्रेडिट/दिन","क्विक और स्टैंडर्ड अध्ययन","सीखने के पथ","रोज़ 3 वचन दोहराएँ","2 अभ्यास तरीके","फ़ेलोशिप से जुड़ें"]'::jsonb
    WHEN 'standard' THEN '["रोज़ का बाइबल वचन","40 क्रेडिट/दिन","क्विक, स्टैंडर्ड, डीप डाइव, लेक्टियो","सीखने के पथ","रोज़ 5 वचन · सभी 8 अभ्यास","हर अध्ययन पर 5 प्रश्न","Discipler · 3 बातचीत/माह","फ़ेलोशिप से जुड़ें"]'::jsonb
    WHEN 'plus' THEN '["रोज़ का बाइबल वचन","60 क्रेडिट/दिन","सभी अध्ययन तरीके","सीखने के पथ","रोज़ 10 वचन · सभी 8 अभ्यास","हर अध्ययन पर 10 प्रश्न","Discipler · 10 बातचीत/माह","फ़ेलोशिप बनाएँ"]'::jsonb
    ELSE '["रोज़ का बाइबल वचन","असीमित क्रेडिट","सभी अध्ययन तरीके","सीखने के पथ","असीमित वचन अभ्यास","असीमित प्रश्न","असीमित Discipler","फ़ेलोशिप बनाएँ"]'::jsonb END),
  '{ml}', CASE plan_code
    WHEN 'free' THEN '["ദിവസ വചനം","ദിവസം 15 ക്രെഡിറ്റ്","ക്വിക്ക്, സ്റ്റാൻഡേർഡ് പഠനം","പഠന പാതകൾ","ദിവസം 3 വാക്യം","2 പരിശീലന രീതി","ഫെലോഷിപ്പിൽ ചേരാം"]'::jsonb
    WHEN 'standard' THEN '["ദിവസ വചനം","ദിവസം 40 ക്രെഡിറ്റ്","ക്വിക്ക്, സ്റ്റാൻഡേർഡ്, ഡീപ്പ്, ലെക്റ്റിയോ","പഠന പാതകൾ","ദിവസം 5 വാക്യം · 8 രീതികൾ","ഓരോ പഠനത്തിനും 5 ചോദ്യം","Discipler · മാസം 3","ഫെലോഷിപ്പിൽ ചേരാം"]'::jsonb
    WHEN 'plus' THEN '["ദിവസ വചനം","ദിവസം 60 ക്രെഡിറ്റ്","എല്ലാ പഠന രീതികളും","പഠന പാതകൾ","ദിവസം 10 വാക്യം · 8 രീതികൾ","ഓരോ പഠനത്തിനും 10 ചോദ്യം","Discipler · മാസം 10","ഫെലോഷിപ്പ് തുടങ്ങാം"]'::jsonb
    ELSE '["ദിവസ വചനം","പരിധിയില്ലാത്ത ക്രെഡിറ്റ്","എല്ലാ പഠന രീതികളും","പഠന പാതകൾ","പരിധിയില്ലാത്ത പരിശീലനം","പരിധിയില്ലാത്ത ചോദ്യങ്ങൾ","പരിധിയില്ലാത്ത Discipler","ഫെലോഷിപ്പ് തുടങ്ങാം"]'::jsonb END),
  updated_at = NOW()
WHERE plan_code IN ('free','standard','plus','premium');

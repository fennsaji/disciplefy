\pset pager off
\echo '--- active count on prod ---'
SELECT count(*) AS active_paths FROM learning_paths WHERE is_active;

\echo '--- paths ACTIVE on local but NOT active on prod ---'
WITH local_active(slug) AS (SELECT unnest(ARRAY['attributes-of-god','baptism-and-lords-supper','christianity-and-culture','corinthians-christ-and-his-church','crucifixion-and-resurrection','deepening-your-walk','defending-your-faith','ephesians-riches-in-christ','eternal-perspective','evangelism-everyday-life','faith-and-family','faith-and-reason','friendship-and-christian-community','galatians-gospel-freedom','gospel-of-john','gospel-of-luke','gospel-of-mark','gospel-of-matthew','growing-in-discipleship','heart-for-the-world','hebrews-jesus-our-high-priest','historical-reliability-bible','james-faith-that-works','jesus-parables','johns-letters-light-love-truth','law-grace-and-covenants','mental-health-emotions-gospel','money-generosity-gospel','new-believer-essentials','peters-letters-hope-and-endurance','philippians-joy-in-christ','romans-gospel-unfolded','rooted-in-christ','sermon-on-the-mount','sin-repentance-and-grace','spiritual-warfare','the-local-church','theology-of-suffering','understanding-the-bible','who-is-the-holy-spirit','work-and-vocation-as-worship']))
SELECT l.slug,
       COALESCE(p.is_active::text,'MISSING ROW') AS prod_state
  FROM local_active l
  LEFT JOIN learning_paths p ON p.slug = l.slug
 WHERE p.slug IS NULL OR p.is_active = false;

\echo '--- paths ACTIVE on prod but NOT in local active set ---'
WITH local_active(slug) AS (SELECT unnest(ARRAY['attributes-of-god','baptism-and-lords-supper','christianity-and-culture','corinthians-christ-and-his-church','crucifixion-and-resurrection','deepening-your-walk','defending-your-faith','ephesians-riches-in-christ','eternal-perspective','evangelism-everyday-life','faith-and-family','faith-and-reason','friendship-and-christian-community','galatians-gospel-freedom','gospel-of-john','gospel-of-luke','gospel-of-mark','gospel-of-matthew','growing-in-discipleship','heart-for-the-world','hebrews-jesus-our-high-priest','historical-reliability-bible','james-faith-that-works','jesus-parables','johns-letters-light-love-truth','law-grace-and-covenants','mental-health-emotions-gospel','money-generosity-gospel','new-believer-essentials','peters-letters-hope-and-endurance','philippians-joy-in-christ','romans-gospel-unfolded','rooted-in-christ','sermon-on-the-mount','sin-repentance-and-grace','spiritual-warfare','the-local-church','theology-of-suffering','understanding-the-bible','who-is-the-holy-spirit','work-and-vocation-as-worship']))
SELECT p.slug FROM learning_paths p
 WHERE p.is_active AND p.slug NOT IN (SELECT slug FROM local_active);

\echo '--- all INACTIVE paths on prod ---'
SELECT slug FROM learning_paths WHERE NOT is_active ORDER BY slug;

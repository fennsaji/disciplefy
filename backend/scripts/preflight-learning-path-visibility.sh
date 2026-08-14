#!/usr/bin/env bash
#
# Pre-deploy gate for migrations 20260721000002 .. 20260721000006
# (learning path topic visibility).
#
# READ-ONLY. Every statement is a SELECT. This script cannot modify anything.
#
# WHY THIS EXISTS
#
# The migrations commit individually, and the abort states are not equal. An
# abort at 20260721000005 with 20260721000004 already committed is the one
# genuinely dangerous outcome: hides are live, positions are gapped, and stored
# cursors still hold raw positions while the RPCs return visible ordinals. Every
# learner and fellowship on the affected paths then reads the WRONG lesson, with
# no down migration. These gates catch that before anything is applied.
#
# USAGE
#   ./preflight-learning-path-visibility.sh "postgresql://user:pass@host:5432/postgres"
#   ./preflight-learning-path-visibility.sh --local
#
# Exit 0 = all gates pass, safe to deploy. Exit 1 = STOP.

set -uo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <DB_URL> | --local" >&2
  exit 2
fi

if [[ "$1" == "--local" ]]; then
  PSQL=(docker exec -i supabase_db_backend psql -U postgres -d postgres)
else
  PSQL=(psql "$1")
fi

RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YEL=$'\033[1;33m'; NC=$'\033[0m'
FAILED=0

# Run a gate. Passes when the query returns NO rows.
# gate <number> <name> <sql> <what a row means>
gate() {
  local num="$1" name="$2" sql="$3" meaning="$4"
  echo
  echo "── Gate ${num}: ${name}"
  local out
  out="$("${PSQL[@]}" -t -A -F'|' -c "$sql" 2>&1)"
  if [[ $? -ne 0 ]]; then
    echo "${RED}ERROR${NC} could not run query:"; echo "$out"; FAILED=1; return
  fi
  out="$(echo "$out" | sed '/^$/d')"
  if [[ -z "$out" ]]; then
    echo "${GRN}PASS${NC}"
  else
    echo "${RED}STOP${NC} — ${meaning}"
    echo "$out" | sed 's/^/    /'
    FAILED=1
  fi
}

# Report an expected scalar. expect <number> <name> <sql> <expected>
expect() {
  local num="$1" name="$2" sql="$3" want="$4"
  echo
  echo "── Gate ${num}: ${name}"
  local got
  got="$("${PSQL[@]}" -t -A -c "$sql" 2>&1 | tr -d '[:space:]')"
  if [[ "$got" == "$want" ]]; then
    echo "${GRN}PASS${NC} (${got})"
  else
    echo "${RED}STOP${NC} — expected ${want}, got ${got}"
    FAILED=1
  fi
}

echo "═══════════════════════════════════════════════════════════════"
echo " Pre-deploy gates: learning path topic visibility"
echo " READ-ONLY — no statement in this script modifies data"
echo "═══════════════════════════════════════════════════════════════"

# Fail fast on a bad connection. Without this the script runs every gate and
# every inventory query against a dead connection -- 11 failed auth attempts in
# a row, which is enough for Supabase to start refusing the host outright.
CONNCHECK="$("${PSQL[@]}" -t -A -c "SELECT 1;" 2>&1)"
if [[ "$CONNCHECK" != "1" ]]; then
  echo
  echo "${RED}CANNOT CONNECT — aborting before running any gate.${NC}"
  echo
  echo "$CONNCHECK" | sed 's/^/  /'
  echo
  if [[ "$CONNCHECK" == *"password authentication failed"* ]]; then
    echo "${YEL}  Most likely cause: special characters in a password passed inside the URL.${NC}"
    echo "  libpq percent-DECODES the userinfo section, so a literal '%' must be"
    echo "  written '%25', and '@' must be '%40'. A password containing '%4' will"
    echo "  silently become a different string and fail to authenticate."
    echo
    echo "  Avoid the problem entirely — keep the secret out of the URL:"
    echo
    echo "    read -rs PGPASSWORD && export PGPASSWORD"
    echo "    $0 'postgresql://postgres@HOST:5432/postgres'"
    echo "    unset PGPASSWORD"
    echo
    echo "  read -rs does not echo and does not enter shell history."
  fi
  exit 2
fi

# These gates describe a PRE-migration database. Run against one that has
# already been migrated, several of them report failures that are really just
# "this already happened" -- the UUIDs exist, the Stage 1 count is 77 not 75.
# Detect that first and say so, rather than emitting misleading STOPs.
ALREADY="$("${PSQL[@]}" -t -A -c "
SELECT COUNT(*) FROM information_schema.tables
 WHERE table_schema='public' AND table_name='learning_path_topic_titles';" 2>/dev/null | tr -d '[:space:]')"

if [[ "$ALREADY" == "1" ]]; then
  echo
  echo "${YEL}ALREADY APPLIED${NC} — learning_path_topic_titles exists on this database."
  echo
  echo "  These gates check the preconditions for applying migrations 2-6, so they"
  echo "  only mean something against a database that has NOT had them applied."
  echo "  Running them here will report false failures (the new UUIDs exist, the"
  echo "  Stage 1 baseline is 77 rather than 75)."
  echo
  echo "  For a post-apply check, use the verification queries in the catalog doc"
  echo "  and confirm every cursor still resolves to the same topic title."
  echo
  "${PSQL[@]}" -c "
  SELECT (SELECT COUNT(*) FROM learning_path_topics WHERE is_active = false) AS hidden,
         (SELECT COUNT(*) FROM learning_path_topics lpt JOIN learning_paths lp ON lp.id=lpt.learning_path_id
           WHERE lp.disciple_level='seeker' AND lp.is_active AND lpt.is_active) AS stage1_visible,
         (SELECT COUNT(*) FROM learning_path_topic_titles) AS overrides,
         (SELECT COUNT(*) FROM learning_path_topics WHERE position >= 100000) AS stranded;" 2>&1 | sed 's/^/  /'
  echo
  echo "  Expected after a clean apply: hidden=13, stage1_visible=64, overrides=2, stranded=0"
  exit 0
fi

# ---------------------------------------------------------------------------
gate 1 "Position contiguity (migration 5 precondition — THE CRITICAL ONE)" "
SELECT lp.slug || ' : n=' || COUNT(*) || ' min=' || MIN(lpt.position) || ' max=' || MAX(lpt.position)
  FROM learning_paths lp
  JOIN learning_path_topics lpt ON lpt.learning_path_id = lp.id
 GROUP BY lp.slug
HAVING MIN(lpt.position) <> 0 OR MAX(lpt.position) <> COUNT(*) - 1
 ORDER BY 1;" \
"these paths have gapped or non-zero-based positions. Migration 5 will ABORT — after migration 4 has already committed. Repair positions in a separate reviewed migration first. Most likely cause: the admin remove-topic screen, whose shift step throws before it runs (client.raw() does not exist in supabase-js v2)."

# ---------------------------------------------------------------------------
gate 2 "Visibility-definition divergence" "
SELECT lp.slug || ' : ' || rt.title
  FROM learning_path_topics lpt
  JOIN learning_paths lp     ON lp.id = lpt.learning_path_id
  JOIN recommended_topics rt ON rt.id = lpt.topic_id
 WHERE rt.is_active IS NOT TRUE
 ORDER BY 1;" \
"the 8 Edge Functions count these rows as visible; migration 5 and the 7 RPCs do not. Risks a unique violation in migration 6 and a stalled fellowship advance."

# ---------------------------------------------------------------------------
gate 3 "All 13 hide pairs resolve" "
WITH hides(path_slug, topic_title) AS (VALUES
  ('baptism-and-lords-supper','Baptism and Communion'),
  ('the-local-church','Baptism and Communion'),
  ('understanding-the-bible','Why Read the Bible?'),
  ('growing-in-discipleship','Overcoming Temptation'),
  ('understanding-the-bible','Meditation on God''s Word'),
  ('growing-in-discipleship','Living a Holy Life'),
  ('growing-in-discipleship','How to Study the Bible'),
  ('understanding-the-bible','How We Got the Bible'),
  ('the-local-church','Church Leadership and Authority'),
  ('the-local-church','Spiritual Gifts and Their Use'),
  ('baptism-and-lords-supper','Baptism, the Lord''s Supper, and Church Membership'),
  ('growing-in-discipleship','Discerning God''s Will'),
  ('growing-in-discipleship','Fasting and Prayer'))
SELECT h.path_slug || ' : ' || h.topic_title
  FROM hides h
  LEFT JOIN learning_paths lp     ON lp.slug  = h.path_slug
  LEFT JOIN recommended_topics rt ON rt.title = h.topic_title
  LEFT JOIN learning_path_topics lpt
         ON lpt.learning_path_id = lp.id AND lpt.topic_id = rt.id
 WHERE lpt.id IS NULL;" \
"these (slug, title) pairs match nothing. Migration 4 will abort on its '13 hidden' assertion. This is the exact failure that aborted the first local run — two titles had been abbreviated in the catalog."

# ---------------------------------------------------------------------------
gate 4 "No ambiguous titles (silent wrong-instance risk)" "
SELECT title || ' x' || COUNT(*)
  FROM recommended_topics
 WHERE title IN (
   'Baptism and Communion','Why Read the Bible?','Overcoming Temptation',
   'Meditation on God''s Word','Living a Holy Life','How to Study the Bible',
   'How We Got the Bible','Church Leadership and Authority',
   'Spiritual Gifts and Their Use',
   'Baptism, the Lord''s Supper, and Church Membership',
   'Discerning God''s Will','Fasting and Prayer','Participating Worthily',
   'Serving in the Church','Living by Faith, Not Feelings','Spiritual Warfare',
   'Who is Jesus Christ?','The Cost of Following Jesus',
   'What is the Gospel?','Understanding God''s Grace')
 GROUP BY title HAVING COUNT(*) > 1;" \
"duplicate titles. Migrations 4 and 6 join on title, so they could hide, retitle, or anchor on the WRONG instance — and every count assertion would still pass. This one fails silently."

# ---------------------------------------------------------------------------
gate 5 "No path is already missing a milestone" "
SELECT lp.slug FROM learning_paths lp
 WHERE lp.is_active
   AND NOT EXISTS (SELECT 1 FROM learning_path_topics lpt
                    WHERE lpt.learning_path_id = lp.id AND lpt.is_milestone)
 ORDER BY 1;" \
"migration 4 asserts every active path keeps a visible milestone. These already have none, so it will abort on a pre-existing condition unrelated to this change."

# ---------------------------------------------------------------------------
gate 6 "New topic UUIDs and display_order slots are free" "
SELECT id || ' / ' || title || ' / ' || display_order
  FROM recommended_topics
 WHERE id IN ('111e8400-e29b-41d4-a716-4466554400f1','111e8400-e29b-41d4-a716-4466554400f2')
    OR display_order IN (823, 824);" \
"migration 6 inserts these UUIDs and display_orders. If a UUID exists, ON CONFLICT DO NOTHING silently skips the insert while the wiring block still runs."

# ---------------------------------------------------------------------------
# Checks that all 41 slugs 20260721000001 sequences actually EXIST -- NOT that
# 41 paths are active. That migration was rekeyed to match by slug precisely
# because production has 40 active paths ('historical-reliability-bible' was
# deactivated out-of-band; no migration accounts for it), and asserting on the
# active count aborted the deploy over something unrelated to this change.
expect 7 "All 41 sequenced slugs exist (activation state irrelevant)" \
  "SELECT COUNT(*) FROM learning_paths WHERE slug IN ('new-believer-essentials','rooted-in-christ','sin-repentance-and-grace','understanding-the-bible','growing-in-discipleship','gospel-of-mark','baptism-and-lords-supper','the-local-church','friendship-and-christian-community','who-is-the-holy-spirit','gospel-of-john','philippians-joy-in-christ','ephesians-riches-in-christ','attributes-of-god','crucifixion-and-resurrection','romans-gospel-unfolded','galatians-gospel-freedom','theology-of-suffering','mental-health-emotions-gospel','peters-letters-hope-and-endurance','defending-your-faith','sermon-on-the-mount','james-faith-that-works','deepening-your-walk','faith-and-family','money-generosity-gospel','evangelism-everyday-life','jesus-parables','gospel-of-matthew','law-grace-and-covenants','hebrews-jesus-our-high-priest','johns-letters-light-love-truth','spiritual-warfare','gospel-of-luke','corinthians-christ-and-his-church','work-and-vocation-as-worship','eternal-perspective','historical-reliability-bible','faith-and-reason','christianity-and-culture','heart-for-the-world');" "41"

# NOTE: this must NOT key on disciple_level. That column is SET BY 20260721000001,
# so before that migration lands the 'seeker' set is the OLD grouping (11 paths,
# ~148 topics) and this gate reports a meaningless number. Key on the 8 known
# Stage 1 slugs instead, which are stable either side of that migration.
expect 8 "Stage 1 baseline is 75 topics (migration 4 asserts 62 after hides)" \
  "SELECT COUNT(*) FROM learning_path_topics lpt
     JOIN learning_paths lp ON lp.id = lpt.learning_path_id
    WHERE lp.is_active AND lp.slug IN (
      'new-believer-essentials','rooted-in-christ','sin-repentance-and-grace',
      'understanding-the-bible','growing-in-discipleship','gospel-of-mark',
      'baptism-and-lords-supper','the-local-church');" "75"

# ---------------------------------------------------------------------------
echo
echo "═══════════════════════════════════════════════════════════════"
echo " INVENTORY — record this, it is your post-deploy baseline"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "In-flight fellowship studies (0 locally, so migration 5 phase 4 is UNTESTED):"
"${PSQL[@]}" -c "
SELECT lp.slug, fs.current_guide_index,
       (SELECT rt.title FROM learning_path_topics lpt
          JOIN recommended_topics rt ON rt.id = lpt.topic_id
         WHERE lpt.learning_path_id = fs.learning_path_id
           AND lpt.position = fs.current_guide_index) AS currently_on
  FROM fellowship_study fs JOIN learning_paths lp ON lp.id = fs.learning_path_id
 WHERE fs.completed_at IS NULL ORDER BY lp.slug;" 2>&1 | sed 's/^/  /'

echo
echo "In-flight Stage 1 enrolments:"
"${PSQL[@]}" -c "
SELECT lp.slug, left(ulpp.user_id::text,8) AS usr, ulpp.current_topic_position AS pos,
       ulpp.topics_completed AS done,
       (SELECT rt.title FROM learning_path_topics lpt
          JOIN recommended_topics rt ON rt.id = lpt.topic_id
         WHERE lpt.learning_path_id = ulpp.learning_path_id
           AND lpt.position = ulpp.current_topic_position) AS currently_on
  FROM user_learning_path_progress ulpp JOIN learning_paths lp ON lp.id = ulpp.learning_path_id
 WHERE ulpp.completed_at IS NULL AND lp.disciple_level = 'seeker'
 ORDER BY lp.slug;" 2>&1 | sed 's/^/  /'

echo
echo "Completed enrolments migration 6 will REOPEN (path gained a topic):"
"${PSQL[@]}" -c "
SELECT lp.slug, COUNT(*) AS enrolments
  FROM user_learning_path_progress ulpp JOIN learning_paths lp ON lp.id = ulpp.learning_path_id
 WHERE ulpp.completed_at IS NOT NULL
   AND lp.slug IN ('new-believer-essentials','growing-in-discipleship')
 GROUP BY lp.slug;" 2>&1 | sed 's/^/  /'

# ---------------------------------------------------------------------------
echo
echo "═══════════════════════════════════════════════════════════════"
if [[ $FAILED -eq 0 ]]; then
  echo "${GRN} ALL GATES PASS — safe to apply${NC}"
  echo
  echo " Reminders:"
  echo "   * Migrations run BEFORE functions deploy (backend-deploy.yml already does this)."
  echo "   * After applying, re-run the inventory above and confirm every cursor"
  echo "     still resolves to the SAME topic title. That is the only real proof"
  echo "     the remap worked on production data."
  echo "   * Do NOT use the admin add/remove/reorder topic screens on Stage 1"
  echo "     paths until admin-learning-paths is made is_active-aware."
  echo "═══════════════════════════════════════════════════════════════"
  exit 0
else
  echo "${RED} ONE OR MORE GATES FAILED — DO NOT DEPLOY${NC}"
  echo
  echo "${YEL} Applying now risks aborting mid-sequence. An abort at migration 5${NC}"
  echo "${YEL} with migration 4 already committed leaves learners and fellowships${NC}"
  echo "${YEL} silently reading the wrong lesson, with no down migration.${NC}"
  echo "═══════════════════════════════════════════════════════════════"
  exit 1
fi

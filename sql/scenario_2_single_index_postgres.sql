-- ============================================================================
-- Scenario 2: Single-Column B-tree Indexes  (PostgreSQL)
-- StackOverflow DB
--
-- Drops all benchmark indexes, then creates one B-tree index per commonly
-- filtered column.
--
-- Run with:
--   psql -h localhost -U postgres -d StackOverflow -W \
--        -f sql/scenario_2_single_index_postgres.sql
-- ============================================================================

-- ── Drop all benchmark indexes first (idempotency) ───────────────────────────
DROP INDEX IF EXISTS idx_u_location;
DROP INDEX IF EXISTS idx_u_reputation;
DROP INDEX IF EXISTS idx_u_displayname;
DROP INDEX IF EXISTS idx_p_owner_user_id;
DROP INDEX IF EXISTS idx_p_post_type_id;
DROP INDEX IF EXISTS idx_p_score;
DROP INDEX IF EXISTS idx_p_view_count;
DROP INDEX IF EXISTS idx_c_post_id;
DROP INDEX IF EXISTS idx_c_user_id;
DROP INDEX IF EXISTS idx_c_score;
DROP INDEX IF EXISTS idx_v_post_id;
DROP INDEX IF EXISTS idx_v_vote_type_id;
DROP INDEX IF EXISTS idx_b_user_id;
DROP INDEX IF EXISTS idx_p_type_score_vc;
DROP INDEX IF EXISTS idx_p_owner_type_score;
DROP INDEX IF EXISTS idx_c_post_score;
DROP INDEX IF EXISTS idx_u_loc_rep;
DROP INDEX IF EXISTS idx_p_body_ft;
DROP INDEX IF EXISTS idx_p_tags_trgm;
DROP INDEX IF EXISTS idx_u_aboutme_ft;

-- ============================================================================
-- Create single-column B-tree indexes
-- ============================================================================

-- ── Users ─────────────────────────────────────────────────────────────────────
-- Q06: WHERE "Location" = 'United States'
CREATE INDEX idx_u_location    ON "Users" ("Location");
-- Reputation range filters
CREATE INDEX idx_u_reputation  ON "Users" ("Reputation");
-- DisplayName prefix searches
CREATE INDEX idx_u_displayname ON "Users" ("DisplayName");

-- ── Posts ─────────────────────────────────────────────────────────────────────
-- Q09/Q10: JOIN on "OwnerUserId"
CREATE INDEX idx_p_owner_user_id ON "Posts" ("OwnerUserId");
-- Q07/Q09/Q11/Q12: WHERE "PostTypeId" = 1
CREATE INDEX idx_p_post_type_id  ON "Posts" ("PostTypeId");
-- Q07/Q09/Q11: WHERE "Score" > 50
CREATE INDEX idx_p_score         ON "Posts" ("Score");
-- Q07: WHERE "ViewCount" > 1000
CREATE INDEX idx_p_view_count    ON "Posts" ("ViewCount");

-- ── Comments ──────────────────────────────────────────────────────────────────
-- Q10: JOIN "Comments" ON "PostId"
CREATE INDEX idx_c_post_id ON "Comments" ("PostId");
-- UserId FK coverage
CREATE INDEX idx_c_user_id ON "Comments" ("UserId");
-- Q10: WHERE c."Score" > 3
CREATE INDEX idx_c_score   ON "Comments" ("Score");

-- ── Votes ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_v_post_id      ON "Votes" ("PostId");
CREATE INDEX idx_v_vote_type_id ON "Votes" ("VoteTypeId");

-- ── Badges ────────────────────────────────────────────────────────────────────
CREATE INDEX idx_b_user_id ON "Badges" ("UserId");

\echo 'Scenario 2 (Single-Column B-tree Indexes) applied — PostgreSQL OK'

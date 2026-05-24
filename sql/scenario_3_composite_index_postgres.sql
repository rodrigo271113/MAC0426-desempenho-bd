-- ============================================================================
-- Scenario 3: Composite B-tree Indexes  (PostgreSQL)
-- StackOverflow DB
--
-- Drops all benchmark indexes, then creates multi-column B-tree indexes
-- specifically tailored to the compound WHERE clauses and JOINs in the
-- benchmark query set (Q07–Q12).
--
-- Run with:
--   psql -h localhost -U postgres -d StackOverflow -W \
--        -f sql/scenario_3_composite_index_postgres.sql
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
-- Create composite B-tree indexes
-- ============================================================================

-- ── Posts ─────────────────────────────────────────────────────────────────────

-- Q07: WHERE "PostTypeId" = 1 AND "Score" > 50 AND "ViewCount" > 1000
-- Q09: WHERE "PostTypeId" = 1 AND "Score" > 50
-- Q11: Subquery inner – WHERE "PostTypeId" = 1 AND "Score" > <avg>
-- Q12: GROUP BY "PostTypeId"  (leftmost column covers the group-by)
-- Covering index: "PostTypeId" → "Score" → "ViewCount" lets the engine filter all
-- three conditions with a single index range scan.
CREATE INDEX idx_p_type_score_vc ON "Posts" ("PostTypeId", "Score", "ViewCount");

-- Q09: JOIN + filter – "Posts" WHERE "PostTypeId" = 1 AND "OwnerUserId" IS NOT NULL
-- Adding "OwnerUserId" allows the JOIN to reuse the same index scan.
CREATE INDEX idx_p_owner_type_score ON "Posts" ("OwnerUserId", "PostTypeId", "Score");

-- ── Comments ──────────────────────────────────────────────────────────────────

-- Q10: JOIN "Comments" ON "PostId" + WHERE "Score" > 3
-- The composite ("PostId", "Score") lets PostgreSQL do a single index lookup for both
-- the join condition and the score filter.
CREATE INDEX idx_c_post_score ON "Comments" ("PostId", "Score");

-- ── Users ─────────────────────────────────────────────────────────────────────

-- Q06: WHERE "Location" = 'United States'
-- Adding "Reputation" as a second column turns this into a covering index for
-- queries that also filter or sort by reputation (e.g. extra experiments).
CREATE INDEX idx_u_loc_rep ON "Users" ("Location", "Reputation");

\echo 'Scenario 3 (Composite B-tree Indexes) applied — PostgreSQL OK'

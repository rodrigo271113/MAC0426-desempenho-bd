-- ============================================================================
-- Scenario 4: Composite + Full-Text / Trigram Indexes  (PostgreSQL)
-- StackOverflow DB
--
-- Drops all benchmark indexes, then creates multi-column B-tree indexes
-- (Scenario 3) and adds GIN indexes using pg_trgm (trigram) and to_tsvector
-- (full-text search) for fast string pattern matches.
--
-- Run with:
--   psql -h localhost -U postgres -d StackOverflow -W \
--        -f sql/scenario_4_fulltext_index_postgres.sql
-- ============================================================================

-- Ensure the pg_trgm extension is active for trigram-based GIN indexes
CREATE EXTENSION IF NOT EXISTS pg_trgm;

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
CREATE INDEX idx_p_type_score_vc ON "Posts" ("PostTypeId", "Score", "ViewCount");
CREATE INDEX idx_p_owner_type_score ON "Posts" ("OwnerUserId", "PostTypeId", "Score");

-- ── Comments ──────────────────────────────────────────────────────────────────
CREATE INDEX idx_c_post_score ON "Comments" ("PostId", "Score");

-- ── Users ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_u_loc_rep ON "Users" ("Location", "Reputation");

-- ============================================================================
-- Create Full-Text / Trigram indexes (Scenario 4 Addition)
-- ============================================================================

-- Q13: Functional GIN index using tsvector on Body
CREATE INDEX idx_p_body_ft ON "Posts" USING GIN (to_tsvector('english', "Body"));

-- Q08: Trigram GIN index on Tags to speed up infix LIKE '%<python>%'
CREATE INDEX idx_p_tags_trgm ON "Posts" USING GIN ("Tags" gin_trgm_ops);

-- Functional GIN index using tsvector on AboutMe (extra experiments)
CREATE INDEX idx_u_aboutme_ft ON "Users" USING GIN (to_tsvector('english', "AboutMe"));

\echo 'Scenario 4 (Composite + Full-Text / Trigram Indexes) applied — PostgreSQL OK'

-- ============================================================================
-- Scenario 1: No Secondary Indexes  (PostgreSQL)
-- StackOverflow DB
--
-- Drops every benchmark index we may have created.  Primary keys are kept.
-- Run with:
--   psql -h localhost -U postgres -d StackOverflow -W \
--        -f sql/scenario_1_no_index_postgres.sql
-- ============================================================================

-- ── Drop single-column benchmark indexes ─────────────────────────────────────
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

-- ── Drop composite benchmark indexes ─────────────────────────────────────────
DROP INDEX IF EXISTS idx_p_type_score_vc;
DROP INDEX IF EXISTS idx_p_owner_type_score;
DROP INDEX IF EXISTS idx_c_post_score;
DROP INDEX IF EXISTS idx_u_loc_rep;

-- ── Drop full-text / trigram benchmark indexes ────────────────────────────────
DROP INDEX IF EXISTS idx_p_body_ft;
DROP INDEX IF EXISTS idx_p_tags_trgm;
DROP INDEX IF EXISTS idx_u_aboutme_ft;

\echo 'Scenario 1 (No Secondary Indexes) applied — PostgreSQL OK'

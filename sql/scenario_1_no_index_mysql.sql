-- ============================================================================
-- Scenario 1: No Secondary Indexes  (MySQL / MariaDB)
-- StackOverflow DB
--
-- Drops every benchmark index we may have created.  Primary keys are kept.
-- Run with:
--   mysql -u root -p StackOverflow < sql/scenario_1_no_index_mysql.sql
-- ============================================================================

USE StackOverflow;

-- ── Helper: safely drop an index only when it exists ─────────────────────────
DROP PROCEDURE IF EXISTS _bench_drop_idx;

DELIMITER //
CREATE PROCEDURE _bench_drop_idx(IN p_tbl VARCHAR(100), IN p_idx VARCHAR(100))
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME   = p_tbl
          AND INDEX_NAME   = p_idx
    ) THEN
        SET @_sql = CONCAT('ALTER TABLE `', p_tbl, '` DROP INDEX `', p_idx, '`');
        PREPARE _s FROM @_sql;
        EXECUTE _s;
        DEALLOCATE PREPARE _s;
    END IF;
END //
DELIMITER ;

-- ── Drop single-column benchmark indexes ─────────────────────────────────────
CALL _bench_drop_idx('Users',    'idx_u_location');
CALL _bench_drop_idx('Users',    'idx_u_reputation');
CALL _bench_drop_idx('Users',    'idx_u_displayname');
CALL _bench_drop_idx('Posts',    'idx_p_owner_user_id');
CALL _bench_drop_idx('Posts',    'idx_p_post_type_id');
CALL _bench_drop_idx('Posts',    'idx_p_score');
CALL _bench_drop_idx('Posts',    'idx_p_view_count');
CALL _bench_drop_idx('Comments', 'idx_c_post_id');
CALL _bench_drop_idx('Comments', 'idx_c_user_id');
CALL _bench_drop_idx('Comments', 'idx_c_score');
CALL _bench_drop_idx('Votes',    'idx_v_post_id');
CALL _bench_drop_idx('Votes',    'idx_v_vote_type_id');
CALL _bench_drop_idx('Badges',   'idx_b_user_id');

-- ── Drop composite benchmark indexes ─────────────────────────────────────────
CALL _bench_drop_idx('Posts',    'idx_p_type_score_vc');
CALL _bench_drop_idx('Posts',    'idx_p_owner_type_score');
CALL _bench_drop_idx('Comments', 'idx_c_post_score');
CALL _bench_drop_idx('Users',    'idx_u_loc_rep');

-- ── Drop full-text benchmark indexes ─────────────────────────────────────────
CALL _bench_drop_idx('Posts',    'idx_p_body_ft');
CALL _bench_drop_idx('Posts',    'idx_p_tags_ft');
CALL _bench_drop_idx('Users',    'idx_u_aboutme_ft');

-- ── Cleanup helper ────────────────────────────────────────────────────────────
DROP PROCEDURE IF EXISTS _bench_drop_idx;

SELECT 'Scenario 1 (No Secondary Indexes) applied — MySQL OK' AS _status;

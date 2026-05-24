-- ============================================================================
-- Scenario 3: Composite B-tree Indexes  (MySQL / MariaDB)
-- StackOverflow DB
--
-- Drops all benchmark indexes, then creates multi-column B-tree indexes
-- specifically tailored to the compound WHERE clauses and JOINs in the
-- benchmark query set (Q07–Q12).
--
-- Run with:
--   mysql -u root -p StackOverflow < sql/scenario_3_composite_index_mysql.sql
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

-- ── Drop all benchmark indexes first (idempotency) ───────────────────────────
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
CALL _bench_drop_idx('Posts',    'idx_p_type_score_vc');
CALL _bench_drop_idx('Posts',    'idx_p_owner_type_score');
CALL _bench_drop_idx('Comments', 'idx_c_post_score');
CALL _bench_drop_idx('Users',    'idx_u_loc_rep');
CALL _bench_drop_idx('Posts',    'idx_p_body_ft');
CALL _bench_drop_idx('Posts',    'idx_p_tags_ft');
CALL _bench_drop_idx('Users',    'idx_u_aboutme_ft');

DROP PROCEDURE IF EXISTS _bench_drop_idx;

-- ============================================================================
-- Create composite B-tree indexes
-- ============================================================================

-- ── Posts ─────────────────────────────────────────────────────────────────────

-- Q07: WHERE PostTypeId = 1 AND Score > 50 AND ViewCount > 1000
-- Q09: WHERE PostTypeId = 1 AND Score > 50
-- Q11: Subquery inner – WHERE PostTypeId = 1 AND Score > <avg>
-- Q12: GROUP BY PostTypeId  (leftmost column covers the group-by)
-- Covering index: PostTypeId → Score → ViewCount lets the engine filter all
-- three conditions with a single index range scan.
CREATE INDEX idx_p_type_score_vc ON Posts (PostTypeId, Score, ViewCount);

-- Q09: JOIN + filter – Posts WHERE PostTypeId = 1 AND OwnerUserId IS NOT NULL
-- Adding OwnerUserId allows the JOIN to reuse the same index scan.
CREATE INDEX idx_p_owner_type_score ON Posts (OwnerUserId, PostTypeId, Score);

-- ── Comments ──────────────────────────────────────────────────────────────────

-- Q10: JOIN Comments ON PostId + WHERE Score > 3
-- The composite (PostId, Score) lets MySQL do a single index lookup for both
-- the join condition and the score filter.
CREATE INDEX idx_c_post_score ON Comments (PostId, Score);

-- ── Users ─────────────────────────────────────────────────────────────────────

-- Q06: WHERE Location = 'United States'
-- Adding Reputation as a second column turns this into a covering index for
-- queries that also filter or sort by reputation (e.g. extra experiments).
CREATE INDEX idx_u_loc_rep ON Users (Location(191), Reputation);

SELECT 'Scenario 3 (Composite B-tree Indexes) applied — MySQL OK' AS _status;

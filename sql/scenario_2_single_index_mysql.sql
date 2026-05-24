-- ============================================================================
-- Scenario 2: Single-Column B-tree Indexes  (MySQL / MariaDB)
-- StackOverflow DB
--
-- Drops all benchmark indexes, then creates one B-tree index per commonly
-- filtered column.  These indexes help Q04–Q09 and partially Q10–Q12.
--
-- Run with:
--   mysql -u root -p StackOverflow < sql/scenario_2_single_index_mysql.sql
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
-- Create single-column B-tree indexes
-- ============================================================================

-- ── Users ─────────────────────────────────────────────────────────────────────
-- Q06: WHERE Location = 'United States'
CREATE INDEX idx_u_location    ON Users (Location(191));
-- Q03/Q02: WHERE Id = ? (already PK, this is extra for non-PK reputation filter)
CREATE INDEX idx_u_reputation  ON Users (Reputation);
-- Q08 prefix search on DisplayName (not used in our suite, useful for extra experiments)
CREATE INDEX idx_u_displayname ON Users (DisplayName(191));

-- ── Posts ─────────────────────────────────────────────────────────────────────
-- Q09/Q10: JOIN on OwnerUserId
CREATE INDEX idx_p_owner_user_id ON Posts (OwnerUserId);
-- Q07/Q09/Q11/Q12: WHERE PostTypeId = 1
CREATE INDEX idx_p_post_type_id  ON Posts (PostTypeId);
-- Q07/Q09/Q11: WHERE Score > 50
CREATE INDEX idx_p_score         ON Posts (Score);
-- Q07: WHERE ViewCount > 1000
CREATE INDEX idx_p_view_count    ON Posts (ViewCount);

-- ── Comments ──────────────────────────────────────────────────────────────────
-- Q10: JOIN Comments ON PostId
CREATE INDEX idx_c_post_id ON Comments (PostId);
-- Q10: JOIN Users via UserId (not used in current query but good FK coverage)
CREATE INDEX idx_c_user_id ON Comments (UserId);
-- Q10: WHERE c.Score > 3
CREATE INDEX idx_c_score   ON Comments (Score);

-- ── Votes ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_v_post_id      ON Votes (PostId);
CREATE INDEX idx_v_vote_type_id ON Votes (VoteTypeId);

-- ── Badges ────────────────────────────────────────────────────────────────────
CREATE INDEX idx_b_user_id ON Badges (UserId);

SELECT 'Scenario 2 (Single-Column B-tree Indexes) applied — MySQL OK' AS _status;

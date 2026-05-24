-- ============================================================================
-- Scenario 4: Composite + Full-Text Indexes  (MySQL / MariaDB)
-- StackOverflow DB
--
-- Drops all benchmark indexes, then creates multi-column B-tree indexes
-- (Scenario 3) and adds FULLTEXT indexes for fast text pattern searches
-- on Posts (Body, Tags) and Users (AboutMe).
--
-- Run with:
--   mysql -u root -p StackOverflow < sql/scenario_4_fulltext_index_mysql.sql
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
CREATE INDEX idx_p_type_score_vc ON Posts (PostTypeId, Score, ViewCount);
CREATE INDEX idx_p_owner_type_score ON Posts (OwnerUserId, PostTypeId, Score);

-- ── Comments ──────────────────────────────────────────────────────────────────
CREATE INDEX idx_c_post_score ON Comments (PostId, Score);

-- ── Users ─────────────────────────────────────────────────────────────────────
CREATE INDEX idx_u_loc_rep ON Users (Location(191), Reputation);

-- ============================================================================
-- Create FULLTEXT indexes (Scenario 4 Addition)
-- ============================================================================

-- Fast pattern search on Posts.Body (Q13)
CREATE FULLTEXT INDEX idx_p_body_ft ON Posts (Body);

-- Fast pattern search on Posts.Tags (Q08)
CREATE FULLTEXT INDEX idx_p_tags_ft ON Posts (Tags);

-- Fast pattern search on Users.AboutMe (extra experiments)
CREATE FULLTEXT INDEX idx_u_aboutme_ft ON Users (AboutMe);

SELECT 'Scenario 4 (Composite + Full-Text Indexes) applied — MySQL OK' AS _status;

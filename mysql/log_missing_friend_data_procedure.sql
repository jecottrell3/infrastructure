-- A procedure to log missing friend data into MissingFriendDataLog.
--
-- Create the log table with:
--   CREATE TABLE MissingFriendDataLog LIKE Member_Management;
--   ALTER TABLE MissingFriendDataLog ADD COLUMN log_time DATETIME NOT NULL FIRST, ADD COLUMN ufi_has_data VARCHAR(3) AFTER log_time;
--   ALTER TABLE MissingFriendDataLog DROP PRIMARY KEY, ADD PRIMARY KEY (log_time, UserID, AppID);
--
-- Gary Gabriel <ggabriel@microstrategy.com>

DROP PROCEDURE IF EXISTS log_missing_friend_data;
DELIMITER //

CREATE PROCEDURE
log_missing_friend_data ()
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
BEGIN
  DECLARE shard_count BIGINT;
  DECLARE rmf_members VARCHAR(4096);
  DECLARE ufi_members VARCHAR(4096);

  SELECT COUNT(DISTINCT ShardID) INTO shard_count FROM Member_Management;
  IF shard_count > 1 THEN
    -- Find members that were added more than 6 hours ago and don't have any friends in REL_MEMBER_FRIENDS.
    SELECT GROUP_CONCAT(mm.UserID SEPARATOR ', ') INTO rmf_members
    FROM Member_Management mm LEFT JOIN REL_MEMBER_FRIENDS rmf ON mm.UserID = rmf.MEMBER_ID
    WHERE rmf.MEMBER_ID IS NULL AND ShardID = 1 AND mm.TokenStatus = 1 AND mm.CrawlStatus >= 2
    AND (mm.Web_Token_Insert_Time < DATE_ADD(NOW(), INTERVAL -6 HOUR) OR mm.Web_Token_Insert_Time IS NULL);

    -- Find members that were added more than 6 hours ago and don't have any friends in User_Friend_Info.
    SELECT GROUP_CONCAT(mm.UserID SEPARATOR ', ') INTO ufi_members
    FROM Member_Management mm LEFT JOIN User_Friend_Info ufi ON mm.UserID = ufi.id_Info_User
    WHERE ufi.id_Info_User IS NULL AND ShardID = 1 AND mm.TokenStatus = 1 AND mm.CrawlStatus >= 2
    AND (mm.Web_Token_Insert_Time < DATE_ADD(NOW(), INTERVAL -6 HOUR) OR mm.Web_Token_Insert_Time IS NULL);
  ELSE
    -- Find members that were added more than 6 hours ago and don't have any friends in REL_MEMBER_FRIENDS.
    SELECT GROUP_CONCAT(mm.UserID SEPARATOR ', ') INTO rmf_members
    FROM Member_Management mm LEFT JOIN REL_MEMBER_FRIENDS rmf ON mm.UserID = rmf.MEMBER_ID
    WHERE rmf.MEMBER_ID IS NULL AND mm.TokenStatus = 1 AND mm.CrawlStatus >= 2
    AND (mm.Web_Token_Insert_Time < DATE_ADD(NOW(), INTERVAL -6 HOUR) OR mm.Web_Token_Insert_Time IS NULL);

    -- Find members that were added more than 6 hours ago and don't have any friends in User_Friend_Info.
    SELECT GROUP_CONCAT(mm.UserID SEPARATOR ', ') INTO ufi_members
    FROM Member_Management mm LEFT JOIN User_Friend_Info ufi ON mm.UserID = ufi.id_Info_User
    WHERE ufi.id_Info_User IS NULL AND mm.TokenStatus = 1 AND mm.CrawlStatus >= 2
    AND (mm.Web_Token_Insert_Time < DATE_ADD(NOW(), INTERVAL -6 HOUR) OR mm.Web_Token_Insert_Time IS NULL);
  END IF;

  SET @sql_text = CONCAT('INSERT INTO MissingFriendDataLog ',
                         'SELECT NOW() AS log_time, IF(UserID IN (', ufi_members, '), NULL, "YES") AS ufi_has_data, ',
                         'Member_Management.* FROM Member_Management WHERE AppID = 155202421210030 ',
                         'AND UserID IN (', rmf_members, ')');
  PREPARE stmt FROM @sql_text;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;
  SET @sql_text = NULL;

END//
DELIMITER ;


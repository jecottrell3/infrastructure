-- Stored procedures and events to manage daily partitions on tables.
--
-- To create daily partitions on a new table:
-- CALL create_daily_partitions('Post', 'Object_created_day', 'idPost');
--
-- To add daily partitions to an already-partitioned table every day:
-- CALL add_daily_partitions('Post');
--
-- Gary Gabriel <ggabriel@microstrategy.com>

DROP PROCEDURE IF EXISTS create_daily_partitions;
DELIMITER //

CREATE PROCEDURE
create_daily_partitions (IN table_name VARCHAR(255), IN partition_key VARCHAR(255), IN subpartition_key VARCHAR(255))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
BEGIN
  DECLARE today_days BIGINT;
  DECLARE pday BIGINT;

  SET @sql_text = CONCAT('ALTER TABLE ', table_name, '\n');
  SET @sql_text = CONCAT(@sql_text, 'PARTITION BY RANGE(', partition_key, ')\n');
  IF subpartition_key IS NOT NULL THEN
    SET @sql_text = CONCAT(@sql_text, 'SUBPARTITION BY KEY(', subpartition_key, ')\n');
    SET @sql_text = CONCAT(@sql_text, 'SUBPARTITIONS 10 (\n');
  END IF;

  SET today_days = TO_DAYS(NOW()) - 693959; -- Microsoft day number for today.
  SET pday = today_days - 30;
  WHILE pday <= today_days + 5 DO
    SET @sql_text = CONCAT(@sql_text, '  PARTITION p', pday, ' VALUES LESS THAN (', pday + 1 ,'),\n');
    SET pday = pday + 1;
  END WHILE;
  SET @sql_text = CONCAT(@sql_text, '  PARTITION pnew VALUES LESS THAN MAXVALUE\n)');

  -- PREPARE requires the SQL text to be a literal or a user variable.
  PREPARE stmt FROM @sql_text;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;
  SET @sql_text = NULL;
END//
DELIMITER ;

-- CALL create_daily_partitions('Checkin', 'Object_created_day', 'Object_idCheckin');
-- CALL create_daily_partitions('Object_Comment', 'Object_created_day', 'idComment');
-- CALL create_daily_partitions('Object_Likes', 'Object_created_day', 'id_FromUser');
-- CALL create_daily_partitions('Object_Tag', 'Object_created_day', 'Object_idObject');
-- CALL create_daily_partitions('Object_Visibility', 'Object_created_day', 'Object_idObject');
-- CALL create_daily_partitions('Post', 'Object_created_day', 'idPost');
-- CALL create_daily_partitions('FBObject', 'created_day', 'idObject');

DROP PROCEDURE IF EXISTS add_daily_partitions;
DELIMITER //

CREATE PROCEDURE
add_daily_partitions (IN table_to_process VARCHAR(255))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
BEGIN
  DECLARE today_days BIGINT;
  DECLARE newest_partition VARCHAR(255);
  DECLARE partition_number BIGINT;

  -- Find the newest partition.
  SELECT MAX(partition_name) INTO newest_partition
    FROM information_schema.partitions
    WHERE table_schema = DATABASE() AND table_name = table_to_process AND partition_name <> 'pnew';
  SET today_days = TO_DAYS(NOW()) - 693959; -- Microsoft day number for today.
  SELECT CAST(SUBSTRING(newest_partition FROM 2) AS UNSIGNED INTEGER) + 1 INTO partition_number;
  WHILE partition_number <= today_days + 5 DO
    SET @sql_text = CONCAT('ALTER TABLE ', table_to_process, ' REORGANIZE PARTITION pnew INTO (\n');
    SET @sql_text = CONCAT(@sql_text, '  PARTITION p', partition_number);
    SET @sql_text = CONCAT(@sql_text, ' VALUES LESS THAN (', partition_number + 1, '),\n');
    SET @sql_text = CONCAT(@sql_text, '  PARTITION pnew VALUES LESS THAN MAXVALUE)');
    -- PREPARE requires the SQL text to be a literal or a user variable.
    PREPARE stmt FROM @sql_text;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SET partition_number = partition_number + 1;
  END WHILE;

  SET @sql_text = NULL;
END//
DELIMITER ;

DROP EVENT IF EXISTS event_add_daily_partitions;
DELIMITER //

CREATE EVENT event_add_daily_partitions
ON SCHEDULE EVERY 1 DAY STARTS CURDATE() + INTERVAL '1 6:15' DAY_MINUTE -- Run at 6:15am UTC (2:15am EDT.)
DO
BEGIN
  CALL add_daily_partitions('Checkin');
  CALL add_daily_partitions('Object_Comment');
  CALL add_daily_partitions('Object_Likes');
  CALL add_daily_partitions('Object_Tag');
  CALL add_daily_partitions('Object_Visibility');
  CALL add_daily_partitions('Post');
  CALL add_daily_partitions('FBObject');
END//
DELIMITER ;


-- Analyze all tables in the warehouse with higher precision than the default.
--
-- Gary Gabriel <ggabriel@microstrategy.com>

DROP PROCEDURE IF EXISTS analyze_warehouse_tables;
DELIMITER //

CREATE PROCEDURE
analyze_warehouse_tables ()
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
BEGIN
  DECLARE old_innodb_stats_sample_pages BIGINT;
  DECLARE tname VARCHAR(255);
  DECLARE done INT DEFAULT 0;
  DECLARE dummy INT;
  DECLARE tcursor CURSOR FOR SELECT table_name FROM information_schema.tables WHERE table_schema = DATABASE();
  DECLARE CONTINUE HANDLER FOR NOT FOUND
  BEGIN
    SET done = 1;
    -- Select something from a table to clear the "no data" warning after the
    -- last fetch from the cursor.  Ugly MySQL hack.
    SELECT 1 INTO dummy FROM information_schema.global_variables limit 1;
  END;

  -- Save the old innodb_stats_sample_pages value.
  SELECT variable_value INTO old_innodb_stats_sample_pages FROM information_schema.global_variables WHERE variable_name = 'innodb_stats_sample_pages';
  SET GLOBAL innodb_stats_sample_pages = 1024;

  OPEN tcursor;

  read_loop: LOOP
    FETCH tcursor INTO tname;
    IF done = 1 THEN
      LEAVE read_loop;
    END IF;
    SET @sql_text = CONCAT('ANALYZE TABLE ', tname);
    -- PREPARE requires the SQL text to be a literal or a user variable.
    PREPARE stmt FROM @sql_text;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END LOOP;

  CLOSE tcursor;
  SET GLOBAL innodb_stats_sample_pages = old_innodb_stats_sample_pages;
  SET @sql_text = NULL;
END//
DELIMITER ;


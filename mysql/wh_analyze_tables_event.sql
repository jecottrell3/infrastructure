DROP EVENT IF EXISTS event_analyze_warehouse_tables;

CREATE EVENT event_analyze_warehouse_tables
ON SCHEDULE EVERY 1 DAY STARTS CURDATE() + INTERVAL '1 5:15' DAY_MINUTE -- Run at 5:15am UTC (1:15am EDT.)
DO CALL analyze_warehouse_tables();


DROP EVENT IF EXISTS mon.event_update_heartbeat;

CREATE EVENT mon.event_update_heartbeat
ON SCHEDULE EVERY 1 SECOND STARTS NOW() + INTERVAL 1 SECOND
DO UPDATE mon.Heartbeat SET heartbeat = NOW() LIMIT 1;


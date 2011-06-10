#!/bin/sh

HOST="$1"
if [ -z "$HOST" ]; then
  echo "Usage: $0 <master database host>"
  exit 1
fi

ETLPWD="`cat /MSTR/cron/mysql_etl.pwd`"

SQL="INSERT INTO JobExecuteLog (job_name, thread_id, start_time) VALUES ('ADD_DAILY_PARTITIONS', CONNECTION_ID(), NOW()); SELECT LAST_INSERT_ID() INTO @etl_execute_log_id; CALL add_daily_partitions('Checkin'); CALL add_daily_partitions('Object_Comment'); CALL add_daily_partitions('Object_Likes'); CALL add_daily_partitions('Object_Tag'); CALL add_daily_partitions('Object_Visibility'); CALL add_daily_partitions('Post'); CALL add_daily_partitions('FBObject'); UPDATE JobExecuteLog SET end_time = NOW() WHERE id = @etl_execute_log_id";

mysql -uetl -p"$ETLPWD" -h"$HOST" -P3306 -A -Dsma_wh -e"$SQL"

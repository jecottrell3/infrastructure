#!/bin/sh

HOST="$1"
if [ -z "$HOST" ]; then
  echo "Usage: $0 <master database host>"
  exit 1
fi

ETLPWD="`cat /MSTR/cron/mysql_etl.pwd`"

SQL="INSERT INTO JobExecuteLog (job_name, thread_id, start_time) VALUES ('ETL', CONNECTION_ID(), NOW()); SELECT LAST_INSERT_ID() INTO @etl_execute_log_id; CALL warehouse_update(); UPDATE JobExecuteLog SET end_time = NOW() WHERE id = @etl_execute_log_id";

mysql -uetl -p"$ETLPWD" -h"$HOST" -P3306 -A -Dsma_wh -e"$SQL"

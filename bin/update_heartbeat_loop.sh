#!/bin/sh

PORT="$1"
if [ -z "$PORT" ]; then
  echo "Usage: $0 <mysql port>"
  exit 1
fi

MYSQL="/MSTR/mysql$PORT/mysql/bin/mysql"
if [ ! -x "$MYSQL" ]; then
  echo "$MYSQL is not executable"
  exit 1
fi

/bin/sh -c "while true; do $MYSQL -uheartbeat -h127.0.0.1 -P$PORT -e'UPDATE mon.Heartbeat SET heartbeat = NOW() LIMIT 1'; sleep 1; done" </dev/null &>/dev/null &


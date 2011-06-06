#!/bin/env /MSTR/zenoss/python/bin/python

import sys
import getopt
import MySQLdb

def usage():
  return "Usage: %s (-h|--host) <host> (-P|--port) <port>" % sys.argv[0]

def parse_args(args):
  try:
    opts, args = getopt.getopt(args, "h:P:", ["host=", "port="])
    host, port = None, None
    for o, a in opts:
      if o in ("-h", "--host"):
        host = a
      elif o in ("-P", "--port"):
        try:
          port = int(a)
        except ValueError:
          raise getopt.GetoptError, "port must be an integer"
    if not host or not port:
      raise getopt.GetoptError, "host and port are required"
  except getopt.GetoptError, err:
    print usage()
    print str(err)
    sys.exit(3)
  return host, port

def main():
  host, port = parse_args(sys.argv[1:])
  conn = MySQLdb.connect(host=host, user="mon", port=port)
  cursor = conn.cursor()
  cursor.execute("SELECT UNIX_TIMESTAMP() - UNIX_TIMESTAMP(heartbeat) FROM mon.Heartbeat LIMIT 1")
  row = cursor.fetchone()
  delay = row[0]
  cursor.close()
  conn.close()

  state = "OK"
  if delay > 900:
    state = "CRITICAL"
  elif delay > 300:
    state = "WARNING"

  exit_code = {"CRITICAL": 2, "WARNING": 1, "OK": 0}[state]

  print "STATE_%s| replication_delay=%ds" % (state, row[0])

  sys.exit(exit_code)

if __name__ == "__main__":
  main()


#!/usr/bin/env python

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
  try:
    conn = MySQLdb.connect(host=host, user="mon", port=port)
  except MySQLdb.OperationalError, err:
    sys.exit(1)
  cursor = conn.cursor()
  cursor.execute("SELECT COUNT(uid) FROM alert.alertUser")
  row = cursor.fetchone()
  num_users = row[0]
  cursor.close()
  conn.close()
  print "|num_alert_users=%dc" % num_users

if __name__ == "__main__":
  main()


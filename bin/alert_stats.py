#!/usr/bin/env python

import sys
import getopt
import MySQLdb
import MySQLdb.cursors

def usage():
  return "Usage: %s (-h|--host) <host> (-P|--port) <port> (-u|--user) <user> (-p|--password) <password>" % sys.argv[0]

def parse_args(args):
  try:
    opts, args = getopt.getopt(args, "h:P:u:p:", ["host=", "port=", "user=", "password="])
    host, port, user, password = None, None, None, None
    for o, a in opts:
      if o in ("-h", "--host"):
        host = a
      elif o in ("-P", "--port"):
        try:
          port = int(a)
        except ValueError:
          raise getopt.GetoptError, "port must be an integer"
      elif o in ("-u", "--user"):
        user = a
      elif o in ("-p", "--password"):
        password = a
    if host == None or port == None or user == None or password == None:
      raise getopt.GetoptError, "host, port, user and password are required"
  except getopt.GetoptError, err:
    print usage()
    print str(err)
    sys.exit(3)
  return host, port, user, password

def main():
  host, port, user, password = parse_args(sys.argv[1:])
  try:
    conn = MySQLdb.connect(host=host, port=port, user=user, passwd=password, cursorclass=MySQLdb.cursors.SSCursor)
  except MySQLdb.OperationalError, err:
    sys.exit(1)

  cursor = conn.cursor()
  cursor.execute("SELECT COUNT(uid) FROM alert.alertUser")
  row = cursor.fetchone()
  num_users = int(row[0])
  cursor.close()

  cursor = conn.cursor()
  cursor.execute("SELECT SUM(data_length), SUM(index_length) FROM information_schema.tables WHERE table_schema = 'alert'")
  row = cursor.fetchone()
  data_size = int(row[0])
  index_size = int(row[1])
  cursor.close()

  conn.close()
  print "|num_alert_users=%d data_size=%dB index_size=%dB" % (num_users, data_size, index_size)

if __name__ == "__main__":
  main()


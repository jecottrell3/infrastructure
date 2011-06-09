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
  cursor.execute("SELECT COUNT(1) FROM sma_wh.Local_Member_Management")
  row = cursor.fetchone()
  num_users = int(row[0])
  cursor.close()

  oltp_tables = ("Album", "Application", "Checkin", "Comment_Likes", "Crawl_Info", "Event", "Event_Resp_Status",
                 "Event_Visibility", "FBCall", "FBGroup", "FBObject", "FBUser", "Friendlist", "Friendlist_has_User",
                 "Group_has_User", "Likes", "Link", "Location", "Member_Crawl_Records", "Note", "Object_Comment",
                 "Object_Likes", "Object_Privacy_Detail", "Object_Tag", "Object_Visibility", "Page", "Photo", "Post",
                 "Profile", "StatusMessage", "User_Daily_Data_Amount", "User_Friend_Info", "User_Page_Info", "Video",
                 "photo_tag", "Member_Crawl_Records", "Member_Management")
  geo_tables = ("GEODATASOURCE_CITIES_TITANIUM", "GEODATASOURCE_COUNTRIES")

  cursor = conn.cursor()
  cursor.execute("SELECT table_name, data_length, index_length FROM information_schema.tables WHERE table_schema = 'sma_wh' AND table_type = 'BASE TABLE'")
  oltp_data_size = 0
  oltp_index_size = 0
  geo_data_size = 0
  geo_index_size = 0
  etl_data_size = 0
  etl_index_size = 0
  for row in cursor:
    if row[0] in oltp_tables:
      oltp_data_size += int(row[1])
      oltp_index_size += int(row[2])
    elif row[0] in geo_tables:
      geo_data_size += int(row[1])
      geo_index_size += int(row[2])
    else:
      etl_data_size += int(row[1])
      etl_index_size += int(row[2])
  cursor.close()

  conn.close()
  print "|num_wisdom_users=%d oltp_data_size=%dB oltp_index_size=%dB geo_data_size=%dB geo_index_size=%dB etl_data_size=%dB etl_index_size=%dB" % \
        (num_users, oltp_data_size, oltp_index_size, geo_data_size, geo_index_size, etl_data_size, etl_index_size)

if __name__ == "__main__":
  main()


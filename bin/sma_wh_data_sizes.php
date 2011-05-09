#!/usr/bin/php
<?

$num_shards = 5;

$oltp_tables = array('Album', 'Application', 'Checkin', 'Comment_Likes', 'Crawl_Info', 'Event', 'Event_Resp_Status', 'Event_Visibility', 'FBCall', 'FBGroup', 'FBObject', 'FBUser', 'Friendlist', 'Friendlist_has_User', 'Group_has_User', 'Likes', 'Link', 'Location', 'Member_Crawl_Records', 'Note', 'Object_Comment', 'Object_Likes', 'Object_Privacy_Detail', 'Object_Tag', 'Object_Visibility', 'Page', 'Photo', 'Post', 'Profile', 'StatusMessage', 'User_Daily_Data_Amount', 'User_Friend_Info', 'User_Page_Info', 'Video', 'photo_tag', 'Member_Crawl_Records', 'Member_Management');
$geo_tables = array('GEODATASOURCE_CITIES_TITANIUM', 'GEODATASOURCE_COUNTRIES');

$all_users = array();
for($shard = 1; $shard <= $num_shards; $shard++) {
  echo "Shard $shard\n";
  $conn = mysql_connect("s${shard}db-master.prod.wisdom.com", "crawl", "crawl9279");

  $res = mysql_query("SELECT COUNT(1) FROM sma_wh.Member_Management WHERE ShardID = $shard", $conn);
  $row = mysql_fetch_row($res);
  echo "number of users\t" . $row[0] . "\n";
  mysql_free_result($res);

  $res = mysql_query("SELECT SUM(data_length) / (1024 * 1024), SUM(index_length) / (1024 * 1024) FROM information_schema.tables WHERE table_schema = 'sma_wh' AND table_name IN ('" . implode("', '", $oltp_tables) . "')", $conn);
  $row = mysql_fetch_row($res);
  echo "OLTP data size in MB\t" . $row[0] . "\n";
  echo "OLTP index size in MB\t" . $row[0] . "\n";
  mysql_free_result($res);

  $res = mysql_query("SELECT SUM(data_length) / (1024 * 1024), SUM(index_length) / (1024 * 1024) FROM information_schema.tables WHERE table_schema = 'sma_wh' AND table_name IN ('" . implode("', '", $geo_tables) . "')", $conn);
  $row = mysql_fetch_row($res);
  echo "GEO data size in MB\t" . $row[0] . "\n";
  echo "GEO index size in MB\t" . $row[0] . "\n";
  mysql_free_result($res);

  $res = mysql_query("SELECT SUM(data_length) / (1024 * 1024), SUM(index_length) / (1024 * 1024) FROM information_schema.tables WHERE table_schema = 'sma_wh' AND table_name NOT IN ('" . implode("', '", array_merge($oltp_tables, $geo_tables)) . "')", $conn);
  $row = mysql_fetch_row($res);
  echo "ETL data size in MB\t" . $row[0] . "\n";
  echo "ETL index size in MB\t" . $row[0] . "\n";
  mysql_free_result($res);

  mysql_close($conn);
}

?>

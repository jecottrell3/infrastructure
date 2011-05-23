#!/usr/bin/php
<?

$num_shards = 5;

$oltp_tables = array('Album', 'Application', 'Checkin', 'Comment_Likes', 'Crawl_Info', 'Event', 'Event_Resp_Status', 'Event_Visibility', 'FBCall', 'FBGroup', 'FBObject', 'FBUser', 'Friendlist', 'Friendlist_has_User', 'Group_has_User', 'Likes', 'Link', 'Location', 'Member_Crawl_Records', 'Note', 'Object_Comment', 'Object_Likes', 'Object_Privacy_Detail', 'Object_Tag', 'Object_Visibility', 'Page', 'Photo', 'Post', 'Profile', 'StatusMessage', 'User_Daily_Data_Amount', 'User_Friend_Info', 'User_Page_Info', 'Video', 'photo_tag', 'Member_Crawl_Records', 'Member_Management');
$geo_tables = array('GEODATASOURCE_CITIES_TITANIUM', 'GEODATASOURCE_COUNTRIES');

echo "\tTotal Users\tOLTP Data (MB)\tOLTP Index(MB)\tETL Data (MB)\tETL Index (MB)\tTotal DB - OLTP & ETL (MB)\n";
$total_num_users = 0;
$total_oltp_data_size_mb = 0.0;
$total_oltp_index_size_mb = 0.0;
$total_geo_data_size_mb = 0.0;
$total_geo_index_size_mb = 0.0;
$total_etl_data_size_mb = 0.0;
$total_etl_index_size_mb = 0.0;

for($shard = 1; $shard <= $num_shards; $shard++) {
  $conn = mysql_connect("s${shard}db-master.prod.wisdom.com", "crawl", "crawl9279");

  $res = mysql_query("SELECT COUNT(1) FROM sma_wh.Member_Management WHERE ShardID = $shard", $conn);
  $row = mysql_fetch_row($res);
  $num_users = (int)$row[0];
  $total_num_users += $num_users;
  mysql_free_result($res);

  $res = mysql_query("SELECT SUM(data_length) / (1024 * 1024), SUM(index_length) / (1024 * 1024) FROM information_schema.tables WHERE table_schema = 'sma_wh' AND table_name IN ('" . implode("', '", $oltp_tables) . "')", $conn);
  $row = mysql_fetch_row($res);
  $oltp_data_size_mb = (double)$row[0];
  $oltp_index_size_mb = (double)$row[1];
  $total_oltp_data_size_mb += $oltp_data_size_mb;
  $total_oltp_index_size_mb += $oltp_index_size_mb;
  mysql_free_result($res);

  $res = mysql_query("SELECT SUM(data_length) / (1024 * 1024), SUM(index_length) / (1024 * 1024) FROM information_schema.tables WHERE table_schema = 'sma_wh' AND table_name IN ('" . implode("', '", $geo_tables) . "')", $conn);
  $row = mysql_fetch_row($res);
  $geo_data_size_mb = (double)$row[0];
  $geo_index_size_mb = (double)$row[1];
  $total_geo_data_size_mb += $oltp_data_size_mb;
  $total_geo_index_size_mb += $oltp_index_size_mb;
  mysql_free_result($res);

  $res = mysql_query("SELECT SUM(data_length) / (1024 * 1024), SUM(index_length) / (1024 * 1024) FROM information_schema.tables WHERE table_schema = 'sma_wh' AND table_name NOT IN ('" . implode("', '", array_merge($oltp_tables, $geo_tables)) . "')", $conn);
  $row = mysql_fetch_row($res);
  $etl_data_size_mb = (double)$row[0];
  $etl_index_size_mb = (double)$row[1];
  $total_etl_data_size_mb += $oltp_data_size_mb;
  $total_etl_index_size_mb += $oltp_index_size_mb;
  mysql_free_result($res);

  mysql_close($conn);

  printf("Shard %d\t%d\t%1.0f\t%1.0f\t%1.0f\t%1.0f\t%1.0f\n", $shard, $num_users,
         $oltp_data_size_mb, $oltp_index_size_mb, $etl_data_size_mb, $etl_index_size_mb,
         ($oltp_data_size_mb + $oltp_index_size_mb + $etl_data_size_mb + $etl_index_size_mb));
}

printf("Totals\t%d\t%1.0f\t%1.0f\t%1.0f\t%1.0f\t%1.0f\n", $total_num_users,
         $total_oltp_data_size_mb, $total_oltp_index_size_mb, $total_etl_data_size_mb, $total_etl_index_size_mb,
         ($total_oltp_data_size_mb + $total_oltp_index_size_mb + $total_etl_data_size_mb + $total_etl_index_size_mb));

?>

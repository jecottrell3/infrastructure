#!/usr/bin/php
<?

$num_shards = 5;

$all_users = array();
for($shard = 1; $shard <= $num_shards; $shard++) {
  echo "Getting users from shard $shard ... ";
  $conn = mysql_connect("s${shard}db-master.prod.wisdom.com", "crawl", "crawl9279");
  mysql_select_db("sma_wh", $conn);
  $res = mysql_query("SELECT idUser FROM FBUser", $conn);
  $shard_count = 0;
  while($row = mysql_fetch_row($res)) {
    $all_users[(int)$row[0]] = true;
    $shard_count++;
  }
  mysql_free_result($res);
  mysql_close($conn);
  echo "found $shard_count users.\n";
}

echo "Total unique users: " . count($all_users) . "\n";

?>

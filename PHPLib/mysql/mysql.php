<?

// MySQL access library.
// Gary Gabriel <ggabriel@microstrategy.com>

// Example:
//
// require_once("mysql.php");
//
// $conn = new Database\Connection("127.0.0.1", 3306, "myuser", "mypassword", "cooldb");
// try {
//   // This is not required, since calling $conn->query() would connect automatically.
//   $conn->connect();
// } catch(Database\Exception $e) {
//   echo "Unable to connect: $e\n";
//   exit(1);
// }
//
// try {
//   $query = $conn->query("SELECT id, first_name, last_name FROM users WHERE first_name LIKE 'J%'");
// } catch(Database\QueryException $e) {
//   // Perhaps the query syntax is incorrect, or some other MySQL server error occurred.
//   echo "Unable to execute query: $e\n";
//   exit(1);
// }
//
// while($row = $query->fetch()) {
//   echo "[" . $row->id ."] " . $row->first_name . " " . $row->last_name . "\n";
// }

namespace Database;

class Exception extends \Exception {}
class ConnectionError extends Exception {}
class NoSuchDatabaseError extends Exception {}
class CharacterSetError extends Exception {}
class SqlModeError extends Exception {}
class StringEscapeError extends Exception {}

class QueryException extends Exception {}
class DuplicateEntryError extends Exception {}

class Connection {
  protected $host;
  protected $port;
  protected $user;
  protected $password;
  protected $database;
  protected $dbconn;

  // To use a local socket, set $host to null and $port to the socket path.
  function __construct($host, $port, $user, $password, $database) {
    $this->host = $host;
    $this->port = $port;
    $this->user = $user;
    $this->password = $password;
    $this->database = $database;
    $this->dbconn = null;
  }

  function __destruct() {
    if($this->is_connected()) {
      mysql_close($this->dbconn);
    }
  }

  public function is_connected() {
    return $this->dbconn != null;
  }

  public function connect() {
    if(!$this->is_connected()) {
      $this->real_connect();
    }
  }

  protected function real_connect() {
    $hostport = (string)$this->host;
    if($this->port) {
      $hostport .= ":" . $this->port;
    }
    $this->dbconn = mysql_connect($hostport, $this->user, $this->password, true);
    if(!$this->dbconn) {
      throw new ConnectionError("Unable to connect to $hostport");
    }
    if(!mysql_select_db($this->database, $this->dbconn)) {
      throw new NoSuchDatabaseError("Unable to select database " . $this->database);
    }
    if(!mysql_set_charset("utf8", $this->dbconn)) {
      throw new CharacterSetError("Unable to set character set to UTF8");
    }
    if(!mysql_query("SET SESSION sql_mode = 'TRADITIONAL'", $this->dbconn)) {
      throw new SqlModeError("Unable to set SQL mode to 'TRADITIONAL'");
    }
  }

  public function connection_id() {
    $this->connect();
    $id = mysql_thread_id($this->dbconn);
    if(!$id) {
      throw new Exception("Unable to retrieve the connection id.");
    }
    return $id;
  }

  protected function escape_string($str) {
    $this->connect();
    $escaped = mysql_real_escape_string($str, $this->dbconn);
    if($escaped === false) {
      throw new StringEscapeError("Unable to escape string '$str'");
    }
    return $escaped;
  }

  protected function quote_scalar($thing) {
    if(is_null($thing)) {
      return "NULL";
    } elseif(is_int($thing) or is_float($thing)) {
      return (string)$thing;
    } else {
      return "'" . $this->escape_string($thing) . "'";
    }
  }

  public function quote($thing) {
    if(is_array($thing)) {
      $quoted_list = array();
      foreach($thing as $item) {
        $quoted_list[] = $this->quote_scalar($item);
      }
      return "(" . implode(",", $quoted_list) . ")";
    } else {
      return $this->quote_scalar($thing);
    }
  }

  public function query($query) {
    $this->connect();
    return new Query($query, $this->dbconn);
  }
}

class Query {
  protected $query;
  protected $dbconn;
  protected $result;
  protected $field_types;

  function __construct($query, $dbconn) {
    $this->query = $query;
    $this->dbconn = $dbconn;
    $this->result = mysql_query($this->query, $this->dbconn);
    if(!$this->result) {
      $errno = mysql_errno($this->dbconn);
      $error_text = mysql_error($this->dbconn);
      if($errno == 1062) {
        throw new DuplicateEntryError($error_text);
      } else {
        throw new QueryException($error_text);
      }
    }

    // Ask MySQL for field information.
    $this->field_types = array();
    $num_fields = mysql_num_fields($this->result);
    for($i = 0; $i < $num_fields; $i++) {
      $field_name = mysql_field_name($this->result, $i);
      $field_type = mysql_field_type($this->result, $i);
      $this->field_types[$field_name] = $field_type;
    }
  }

  function __destruct() {
    mysql_free_result($this->result);
  }

  // Fetch one row as an object.
  protected function real_fetch() {
    return mysql_fetch_object($this->result);
  }

  // Fetch one row as an object and convert numbers to corresponding PHP types.
  public function fetch() {
    $row = $this->real_fetch();
    foreach($this->field_types as $field_name => $field_type) {
      if(is_null($row->$field_name)) {
        continue;
      }
      if($field_type == "int") {
        $row->$field_name = (int)$row->$field_name;
      } elseif($field_type == "real") {
        $row->$field_name = (float)$row->$field_name;
      }
    }
    return $row;
  }
}

?>

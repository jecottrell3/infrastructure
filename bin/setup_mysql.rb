#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "net/ssh"
require "net/sftp"

MYSQL_DOWNLOAD = "mysql-5.5.9-linux2.6-x86_64"

unless host = ARGV[0]
  puts "Usage: #{$0} host_to_setup [<port>]"
  puts "       default port is 3306"
  exit 1
end

port = ARGV[1] ? ARGV[1].to_i : 3306

def get_server_id(ssh, port)
  port_byte = (port & 255).to_s(16)
  output = ssh.exec!("ifconfig eth0 2>/dev/null")
  if matches = output.match(/HWaddr\s+([A-Z0-9:]+)/i)
    return (matches[1].split(":")[-3, 3].join + port_byte).hex
  else
    raise "Unable to get server id"
  end
end

def make_dbdir(ssh, mysql_root)
  ssh.exec!("mkdir -p #{mysql_root}")
end

def download_mysql(ssh, mysql_root)
  ssh.exec!("wget -O '#{mysql_root}/#{MYSQL_DOWNLOAD}.tar.gz' 'http://dev.mysql.com/get/Downloads/MySQL-5.5/#{MYSQL_DOWNLOAD}.tar.gz/from/http://mysql.mirrors.pair.com/'")
end

def install_mysql(ssh, mysql_root, port, server_id)
  ssh.exec!("cd #{mysql_root}; tar xzf #{MYSQL_DOWNLOAD}.tar.gz")
  ssh.exec!("cd #{mysql_root}; ln -s #{MYSQL_DOWNLOAD} mysql")
  ssh.exec!("rm #{mysql_root}/#{MYSQL_DOWNLOAD}.tar.gz")
  ssh.exec!("groupadd -g 1001 mstrmysql")
  ssh.exec!("useradd -d /MSTR -M -g mstrmysql -u 1001 mstrmysql")
  ssh.exec!("cd #{mysql_root}/mysql; mkdir etc etc/conf.d log run tmp")
  ssh.exec!("cd #{mysql_root}/mysql; chown -R mstrmysql:mstrmysql .")
  ssh.exec!("cd #{mysql_root}/mysql; scripts/mysql_install_db --user=mstrmysql")
  ssh.exec!("cd #{mysql_root}/mysql; chown -R root .")
  ssh.exec!("cd #{mysql_root}/mysql; chown -R mstrmysql data log run tmp")

  # Create #{mysql_root}/mysql/etc/my.cnf and #{mysql_root}/mysql/bin/mysql.start.
  my_cnf = [ "[client]",
             "port = #{port}",
             "socket = #{mysql_root}/mysql/run/mysqld.sock",
             "default-character-set = utf8",
             "",
             "[mysqld-safe]",
             "socket = #{mysql_root}/mysql/run/mysqld.sock",
             "pid-file = #{mysql_root}/mysql/run/mysqld.pid",
             "nice = 0",
             "",
             "[mysqld]",
             "user = mstrmysql",
             "socket = #{mysql_root}/mysql/run/mysqld.sock",
             "pid-file = #{mysql_root}/mysql/run/mysqld.pid",
             "log_error = #{mysql_root}/mysql/log/error.log",
             "port = #{port}",
             "basedir = #{mysql_root}/mysql",
             "datadir = #{mysql_root}/mysql/data",
             "tmpdir = #{mysql_root}/mysql/tmp",
             "skip-external-locking",
             "key_buffer_size = 384M",
             "max_allowed_packet = 250M",
             "thread_stack = 192K",
             "thread_cache_size = 8",
             "query_cache_size = 32M",
             "expire_logs_days = 10",
             "max_binlog_size = 100M",
             "max_connections = 250",
             "innodb_file_format = Barracuda",
             "innodb_file_per_table",
             "default-storage-engine = InnoDB",
             "character-set-server = utf8",
             "sysdate-is-now",
             "innodb_flush_log_at_trx_commit = 1",
             "sync_binlog = 1",
             "relay-log = slave",
             "replicate-wild-ignore-table = mysql.%",
             "innodb_buffer_pool_size = 16G",
             "innodb_buffer_pool_instances = 8",
             "server-id = #{server_id}",
             "",
             "!includedir #{mysql_root}/mysql/etc/conf.d"
           ].map { |x| x + "\n" }.join
  mysql_start = [ "#!/bin/sh",
                  "",
                  "MYSQL=#{mysql_root}/mysql",
                  "cd $MYSQL",
                  "$MYSQL/bin/mysqld_safe --defaults-file=$MYSQL/etc/my.cnf --user=mstrmysql >/dev/null 2>&1 &",
                  "echo -n \"Starting MySQL \"",
                  "CNT=0",
                  "while [ $CNT -lt 120 ]; do",
                  "  CNT=`expr $CNT + 1`",
                  "  if [ -s #{mysql_root}/mysql/run/mysqld.pid ]; then",
                  "    break",
                  "  else",
                  "    echo -n \".\"",
                  "    sleep 1",
                  "  fi",
                  "done",
                  "if [ -s #{mysql_root}/mysql/run/mysqld.pid ]; then",
                  "  echo \"started.\"",
                  "else",
                  "  echo \"still hasn't started, not waiting for it any more.\"",
                  "  exit 1",
                  "fi"
                ].map { |x| x + "\n" }.join
  mysql_stop = [ "#!/bin/sh",
                 "",
                 "PID=`cat #{mysql_root}/mysql/run/mysqld.pid 2>/dev/null`",
                 "[ -z \"$PID\" ] && echo \"MySQL is not running or the PID file is missing.\" && exit 1",
                 "ps -p $PID >/dev/null 2>&1 || (echo \"Stale PID file\" && exit 1)",
                 "",
                 "kill $PID",
                 "echo -n \"Stopping MySQL \"",
                 "CNT=0",
                 "while [ $CNT -lt 120 ]; do",
                 "  CNT=`expr $CNT + 1`",
                 "  if ps -p $PID >/dev/null 2>&1; then",
                 "    echo -n \".\"",
                 "    sleep 1",
                 "  else",
                 "    break",
                 "  fi",
                 "done",
                 "",
                 "if ps -p $PID >/dev/null 2>&1; then",
                 "  echo \"still running, not waiting for it any more.\"",
                 "  exit 1",
                 "else",
                 "  echo \" stopped.\"",
                 "fi"
               ].map { |x| x + "\n" }.join
  ssh.sftp.connect do |sftp|
    sftp.file.open("#{mysql_root}/mysql/etc/my.cnf", "w") do |f|
      f.write(my_cnf)
    end
    sftp.file.open("#{mysql_root}/mysql/bin/mysql.start", "w") do |f|
      f.write(mysql_start)
    end
    sftp.file.open("#{mysql_root}/mysql/bin/mysql.stop", "w") do |f|
      f.write(mysql_stop)
    end
  end
  ssh.exec!("chmod +x #{mysql_root}/mysql/bin/mysql.start")
  ssh.exec!("chmod +x #{mysql_root}/mysql/bin/mysql.stop")
end

def start_mysql(ssh, mysql_root)
  ssh.exec!("#{mysql_root}/mysql/bin/mysql.start")
end

def fix_mysql_privileges(ssh, mysql_root, port)
  # Set the root password.
  fix_sql = [ "DELETE FROM mysql.user WHERE user = ''",
              "UPDATE mysql.user SET password = '*F344FBB28F4FCBC5715D2B436296803647FFA474' WHERE user = 'root'",
              "FLUSH PRIVILEGES"
            ].map { |x| x + ";"}.join(" ")
  ssh.exec!("echo \"#{fix_sql}\" | #{mysql_root}/mysql/bin/mysql -uroot -h127.0.0.1 -P#{port}")
end


Net::SSH.start(host, "root") do |ssh|
  mysql_root = "/MSTR/mysql#{port}"

  puts "Getting the server id"
  server_id = get_server_id(ssh, port)
  puts "    server id is #{server_id}"

  puts "Creating #{mysql_root}"
  make_dbdir(ssh, mysql_root)

  puts "Downloading MySQL"
  download_mysql(ssh, mysql_root)

  puts "Installing MySQL"
  install_mysql(ssh, mysql_root, port, server_id)

  puts "Starting MySQL"
  start_mysql(ssh, mysql_root)

  puts "Fixing MySQL privileges"
  fix_mysql_privileges(ssh, mysql_root, port)

  puts "Done."
end


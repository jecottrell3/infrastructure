#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "net/ssh"
require "net/sftp"

MYSQL_DOWNLOAD = "mysql-5.5.9-linux2.6-x86_64"

unless host = ARGV[0]
  puts "Usage: #{$0} host_to_setup"
  exit 1
end

def get_server_id(ssh)
  output = ssh.exec!("ifconfig eth0 2>/dev/null")
  if matches = output.match(/HWaddr\s+([A-Z0-9:]+)/i)
    return matches[1].split(":")[-4, 4].join.hex
  else
    raise "Unable to get server id"
  end
end

def make_dbfs(ssh)
  ssh.exec!("yes | mkfs -t ext3 /dev/sdf")
  ssh.exec!("mkdir -p /databases")
end

def backup_fstab(ssh)
  ssh.exec!("cp /etc/fstab /etc/fstab.mstr_old")
end

def edit_fstab(ssh)
  ssh.sftp.connect do |sftp|
    # Add a /dev/sdf /databases entry
    new_fstab = ""
    sftp.file.open("/etc/fstab", "r") do |f|
      while line = f.gets
        if line.match(/^\s*\/dev\/sdf\s+/)
          # /dev/sdf should not already be there, but we'll comment it out if it is
          new_fstab += "##{line}"
        else
          new_fstab += line
        end
      end
    end

    new_fstab += "/dev/sdf\t/databases\text3\tdefaults\t0\t0\n"

    sftp.file.open("/etc/fstab", "w") do |f|
      f.write(new_fstab)
    end
  end
end

def mount_dbfs(ssh)
  ssh.exec!("mount /databases")
end

def download_mysql(ssh)
  ssh.exec!("wget -O '/databases/#{MYSQL_DOWNLOAD}.tar.gz' 'http://dev.mysql.com/get/Downloads/MySQL-5.5/#{MYSQL_DOWNLOAD}.tar.gz/from/http://mysql.mirrors.pair.com/'")
end

def install_mysql(ssh, server_id)
  ssh.exec!("cd /databases; tar xzf #{MYSQL_DOWNLOAD}.tar.gz")
  ssh.exec!("cd /databases; ln -s #{MYSQL_DOWNLOAD} mysql")
  ssh.exec!("rm /databases/#{MYSQL_DOWNLOAD}.tar.gz")
  ssh.exec!("groupadd -g 1001 mstrmysql")
  ssh.exec!("useradd -d /databases -M -g mstrmysql -u 1001 mstrmysql")
  ssh.exec!("cd /databases/mysql; mkdir etc etc/conf.d log run tmp")
  ssh.exec!("cd /databases/mysql; chown -R mstrmysql:mstrmysql .")
  ssh.exec!("cd /databases/mysql; scripts/mysql_install_db --user=mstrmysql")
  ssh.exec!("cd /databases/mysql; chown -R root .")
  ssh.exec!("cd /databases/mysql; chown -R mstrmysql data log run tmp")

  # Create /databases/mysql/etc/my.cnf and /databases/mysql/bin/mysql.start.
  my_cnf = [ "[client]",
             "port = 3306",
             "socket = /databases/mysql/run/mysqld.sock",
             "default-character-set = utf8",
             "",
             "[mysqld-safe]",
             "socket = /databases/mysql/run/mysqld.sock",
             "pid-file = /databases/mysql/run/mysqld.pid",
             "nice = 0",
             "",
             "[mysqld]",
             "user = mstrmysql",
             "socket = /databases/mysql/run/mysqld.sock",
             "pid-file = /databases/mysql/run/mysqld.pid",
             "log_error = /databases/mysql/log/error.log",
             "port = 3306",
             "basedir = /databases/mysql",
             "datadir = /databases/mysql/data",
             "tmpdir = /databases/mysql/tmp",
             "skip-external-locking",
             "key_buffer_size = 384M",
             "max_allowed_packet = 250M",
             "thread_stack = 192K",
             "thread_cache_size = 8",
             "query_cache_size = 32M",
             "expire_logs_days = 10",
             "max_binlog_size = 100M",
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
             "!includedir /databases/mysql/etc/conf.d"
           ].map { |x| x + "\n" }.join
  mysql_start = [ "#!/bin/sh",
                  "",
                  "MYSQL=/databases/mysql",
                  "cd $MYSQL",
                  "$MYSQL/bin/mysqld_safe --defaults-file=$MYSQL/etc/my.cnf --user=mstrmysql >/dev/null 2>&1 &",
                  "echo -n \"Starting MySQL \"",
                  "CNT=0",
                  "while [ $CNT -lt 120 ]; do",
                  "  CNT=`expr $CNT + 1`",
                  "  if [ -s /databases/mysql/run/mysqld.pid ]; then",
                  "    break",
                  "  else",
                  "    echo -n \".\"",
                  "    sleep 1",
                  "  fi",
                  "done",
                  "if [ -s /databases/mysql/run/mysqld.pid ]; then",
                  "  echo \"started.\"",
                  "else",
                  "  echo \"still hasn't started, not waiting for it any more.\"",
                  "  exit 1",
                  "fi"
                ].map { |x| x + "\n" }.join
  mysql_stop = [ "#!/bin/sh",
                 "",
                 "PID=`cat /databases/mysql/run/mysqld.pid 2>/dev/null`",
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
    sftp.file.open("/databases/mysql/etc/my.cnf", "w") do |f|
      f.write(my_cnf)
    end
    sftp.file.open("/databases/mysql/bin/mysql.start", "w") do |f|
      f.write(mysql_start)
    end
    sftp.file.open("/databases/mysql/bin/mysql.stop", "w") do |f|
      f.write(mysql_stop)
    end
  end
  ssh.exec!("chmod +x /databases/mysql/bin/mysql.start")
  ssh.exec!("chmod +x /databases/mysql/bin/mysql.stop")
end

def start_mysql(ssh)
  ssh.exec!("/databases/mysql/bin/mysql.start")
end

def fix_mysql_privileges(ssh)
  # Set the root password.
  fix_sql = [ "DELETE FROM mysql.user WHERE user = ''",
              "UPDATE mysql.user SET password = '*82A0C96BC9C820E3541661E2100D038C36A6D305' WHERE user = 'root'",
              "FLUSH PRIVILEGES"
            ].map { |x| x + ";"}.join(" ")
  ssh.exec!("echo \"#{fix_sql}\" | /databases/mysql/bin/mysql -uroot -h127.0.0.1")
end


Net::SSH.start(host, "root") do |ssh|
  puts "Getting the server id"
  server_id = get_server_id(ssh)
  puts "    server id is #{server_id}"

  puts "Creating a new filesystem"
  make_dbfs(ssh)

  puts "Backing up fstab"
  backup_fstab(ssh)

  puts "Modifying fstab"
  edit_fstab(ssh)

  puts "Mounting new filesystem"
  mount_dbfs(ssh)

  puts "Downloading MySQL"
  download_mysql(ssh)

  puts "Installing MySQL"
  install_mysql(ssh, server_id)

  puts "Starting MySQL"
  start_mysql(ssh)

  puts "Fixing MySQL privileges"
  fix_mysql_privileges(ssh)

  puts "Done."
end


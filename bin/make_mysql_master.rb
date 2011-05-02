#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "net/ssh"
require "net/sftp"

unless host = ARGV[0]
  puts "Usage: #{$0} host_to_make_master [<port>]"
  puts "       default port is 3306"
  exit 1
end

port = ARGV[1] ? ARGV[1].to_i : 3306

def stop_mysql(ssh, mysql_root)
  ssh.exec!("#{mysql_root}/mysql/bin/mysql.stop")
  sleep 1
end

def start_mysql(ssh, mysql_root)
  ssh.exec!("#{mysql_root}/mysql/bin/mysql.start")
end

def write_master_mycnf(ssh, mysql_root)
  ssh.sftp.connect do |sftp|
    local_mycnf = [ "[mysqld]",
                    "log-bin = master",
                    "binlog_format = ROW"
                  ].map { |x| x + "\n" }.join
    sftp.file.open("#{mysql_root}/mysql/etc/conf.d/master.cnf", "w") do |f|
      f.write(local_mycnf)
    end
  end
end

Net::SSH.start(host, "root") do |ssh|
  mysql_root = "/MSTR/mysql#{port}"

  puts "Stopping MySQL"
  stop_mysql(ssh, mysql_root)

  puts "Making this MySQL a master"
  write_master_mycnf(ssh, mysql_root)

  puts "Starting MySQL"
  start_mysql(ssh, mysql_root)

  puts "Done."
end


#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "net/ssh"
require "net/sftp"

unless host = ARGV[0]
  puts "Usage: #{$0} host_to_make_master"
  exit 1
end

def stop_mysql(ssh)
  ssh.exec!("/databases/mysql/bin/mysql.stop")
  sleep 1
end

def start_mysql(ssh)
  ssh.exec!("/databases/mysql/bin/mysql.start")
end

def write_master_mycnf(ssh)
  ssh.sftp.connect do |sftp|
    local_mycnf = [ "[mysqld]",
                    "log-bin = master",
                    "binlog_format = ROW"
                  ].map { |x| x + "\n" }.join
    sftp.file.open("/databases/mysql/etc/conf.d/master.cnf", "w") do |f|
      f.write(local_mycnf)
    end
  end
end

Net::SSH.start(host, "root") do |ssh|
  puts "Stopping MySQL"
  stop_mysql(ssh)

  puts "Making this MySQL a master"
  write_master_mycnf(ssh)

  puts "Starting MySQL"
  start_mysql(ssh)

  puts "Done."
end


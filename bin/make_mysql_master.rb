# Run this with "ruby -rubygems make_mysql_master.rb host_to_make_master"
#
# Gary Gabriel <ggabriel@microstrategy.com>

require "net/ssh"
require "net/sftp"

unless host = ARGV[0]
  puts "Usage: ruby -rubygems make_mysql_master.rb host_to_make_master"
  exit 1
end

def stop_mysql(ssh)
  ssh.exec!("service mysql stop")
  sleep 1
end

def start_mysql(ssh)
  ssh.exec!("service mysql start")
end

def write_master_mycnf(sftp)
  local_mycnf = [ "[mysqld]\n",
                  "log-bin = master\n",
                  "binlog_format = ROW\n"
                ].join
  sftp.file.open("/etc/mysql/conf.d/mstr_master.cnf", "w") do |f|
    f.write(local_mycnf)
  end
end

Net::SSH.start(host, "root") do |ssh|
  puts "Stopping MySQL"
  stop_mysql(ssh)

  ssh.sftp.connect do |sftp|
    puts "Making this MySQL a master"
    write_master_mycnf(sftp)
  end

  puts "Starting MySQL"
  start_mysql(ssh)

  puts "Done."
end


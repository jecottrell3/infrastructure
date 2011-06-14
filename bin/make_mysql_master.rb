#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "net/ssh"
require "net/sftp"
require "highline/import"

unless host = ARGV[0]
  puts "Usage: #{$0} host_to_make_master [<port>]"
  puts "       default port is 3306"
  exit 1
end

port = ARGV[1] ? ARGV[1].to_i : 3306
ROOT_PWD = ask("MySQL root password: ") { |q| q.echo = false }
REPL_PWD = ask("MySQL repl (replication) password: ") { |q| q.echo = false }

def stop_mysql(ssh, mysql_root)
  ssh.exec!("#{mysql_root}/mysql/bin/mysql.stop")
  sleep 1
end

def start_mysql(ssh, mysql_root)
  ssh.exec!("#{mysql_root}/mysql/bin/mysql.start")
end

def add_users(ssh, mysql_root, port)
  e_root_pwd = ROOT_PWD.gsub(/"/, '\"').gsub(/\$/, '\$')
  mysql_cmd = "#{mysql_root}/mysql/bin/mysql -uroot -p\"#{e_root_pwd}\" -h127.0.0.1 -P#{port}"
  ssh.exec!("#{mysql_cmd} -e\"GRANT REPLICATION SLAVE on *.* TO 'repl'@'%' IDENTIFIED BY '#{REPL_PWD}'\"")
  ssh.exec!("#{mysql_cmd} -e\"GRANT SELECT, UPDATE ON mon.Heartbeat TO 'heartbeat'@'127.0.0.1'\"")
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

  puts "Adding the replication user"
  add_users(ssh, mysql_root, port)

  puts "Done."
end


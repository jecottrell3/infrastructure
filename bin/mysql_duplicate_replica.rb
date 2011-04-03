#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "net/ssh"

if ARGV.size < 3
  puts "Usage: #{$0} port mysql_replica_from mysql_repica_to"
  exit 1
end

port = ARGV[0]
host_from = ARGV[1]
host_to = ARGV[2]

Net::SSH.start(host_to, "root") do |ssh|
  puts "Stopping MySQL on destination (#{host_to})"
  output = ssh.exec!("/MSTR/mysql#{port}/mysql/bin/mysql.stop")
  if output.include? "such file"
    puts "MySQL is not installed on #{host_to}:#{port}, did you run 'setup_mysql.rb #{host_to} #{port}' ?"
    exit 1
  end
end

Net::SSH.start(host_from, "root") do |ssh|
  puts "Stopping MySQL on source (#{host_from})"
  output = ssh.exec!("/MSTR/mysql#{port}/mysql/bin/mysql.stop")
  if output.include? "such file"
    puts "MySQL is not installed on #{host_from}:#{port}, did you run 'setup_mysql.rb #{host_to} #{port}' ?"
    exit 1
  end
end

Net::SSH.start(host_to, "root", :forward_agent => true) do |ssh|
  puts "Deleting data on destination (#{host_to})"
  ssh.exec!("rm -Rf /MSTR/mysql#{port}/mysql/data/*")
  puts "Copying data #{host_from} -> #{host_to}"
  ssh.exec!("scp -oStrictHostKeyChecking=no -rp #{host_from}:/MSTR/mysql#{port}/mysql/data/'*' /MSTR/mysql#{port}/mysql/data/")
  puts "Fixing filesystem permissions"
  ssh.exec!("chown -R mstrmysql:mstrmysql /MSTR/mysql#{port}/mysql/data/*")
  puts "Starting MySQL on destination (#{host_to})"
  ssh.exec!("/MSTR/mysql#{port}/mysql/bin/mysql.start")
end

Net::SSH.start(host_from, "root") do |ssh|
  puts "Starting MySQL on source (#{host_from})"
  ssh.exec!("/MSTR/mysql#{port}/mysql/bin/mysql.start")
end

puts "Copied #{host_from}:#{port} to #{host_to}:#{port}, please verify"


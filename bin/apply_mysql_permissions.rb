#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "highline/import"
require "net/ssh"
require "mysql"

unless host = ARGV[0] and permissions = ARGV[1]
  puts "Usage: #{$0} host_to_apply_to permissions_file.sql"
  exit 1
end

# Parse the permissions file.
clean_file = ""
File.open(permissions) do |f|
  f.each_line do |line|
    next if line.strip.start_with? "--"
    clean_file += line
  end
end
permission_statements = clean_file.split(";").map { |x| x.strip }.select { |x| not x.empty? }

# Ask for root password without echo.
root_pwd = ask("MySQL root password: ") { |q| q.echo = false }

Net::SSH.start(host, "root") do |ssh|
  puts "Forwarding local port to remote"
  port = 13306
  loop do
    begin
      ssh.forward.local(port, "127.0.0.1", 3306)
      break
    rescue Errno::EADDRINUSE
      port += 1
    end
  end

  done = false

  Thread.abort_on_exception = true
  Thread.new do
    puts "Connecting to MySQL"
    dbh = Mysql.real_connect("127.0.0.1", "root", root_pwd, "mysql", port)

    puts "Clearing old permissions"
    [ "DELETE FROM mysql.user WHERE user <> 'root'",
      "DELETE FROM mysql.db WHERE user <> 'root'",
      "DELETE FROM mysql.tables_priv WHERE user <> 'root'",
      "DELETE FROM mysql.columns_priv WHERE user <> 'root'",
      "FLUSH PRIVILEGES"
    ].each { |sql| dbh.query(sql) }

    puts "Adding new permissions"
    permission_statements.each { |sql| dbh.query(sql) }

    dbh.close
    done = true
  end

  ssh.loop(1) { not done }
  puts "Done."
end


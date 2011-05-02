#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "optparse"
require "socket"
require "highline"
require "mysql"

FLAGS = {}
opts = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} --port <MySQL port> <host> [<host> ...]"
  opts.on("--port PORT", Integer, "Port that MySQL is installed on.") { |x| FLAGS[:port] = x }
  opts.on("--help", "Dispaly this help.") do
    puts opts
    exit
  end
end
opts.parse!

abort "You must specify the MySQL port.\n#{opts}" unless FLAGS[:port]
abort "You must specify the list of hosts to run on.\n#{opts}" if ARGV.size < 1

hosts = ARGV.map { |x| "#{x}:#{FLAGS[:port]}" }

HighLine.use_color = false unless $stdout.tty?
HIGHLINE = HighLine.new

def short_hostname(host)
  if host.end_with?("machine.wisdom.com") or host.end_with?("prod.wisdom.com") or host.end_with?("prod.alert.com")
    host.split(".").first
  else
    host
  end
end

def color_error(message)
  HIGHLINE.color(message, HighLine::RED, HighLine::BOLD)
end

host_threads = {}
hosts.each do |hostport|
  next if host_threads[hostport]
  host_threads[hostport] = Thread.new(hostport) do |hostport|
    (host, port) = hostport.split(":")
    Thread.current[:error] = nil
    Thread.current[:slave_status] = nil
    Thread.current[:master_status] = nil
    Thread.current[:heartbeat_behind] = nil
    begin
      dbh = Mysql::new(host, "mon", nil, nil, port)
      res = dbh.query("SHOW SLAVE STATUS")
      res.each_hash { |row| Thread.current[:slave_status] = row; break }
      res = dbh.query("SHOW MASTER STATUS")
      res.each_hash { |row| Thread.current[:master_status] = row; break }
      begin
        res = dbh.query("SELECT NOW() - heartbeat AS delay FROM mon.Heartbeat LIMIT 1")
        res.each_hash { |row| Thread.current[:heartbeat_behind] = row["delay"]; break }
      rescue Mysql::ServerError => e
        # Heartbeat table probably not configured.
      end
      dbh.close
    rescue SocketError, Errno::ECONNREFUSED
      Thread.current[:error] = "Unable to connect"
    end
  end
end

hosts.each { |x| host_threads[x].join }

host_messages = {}
masters = []
others = []
master_replicas = {}
hosts.each do |hostport|
  next if host_messages[hostport]
  (host, port) = hostport.split(":")
  thread = host_threads[hostport]
  heartbeat = thread[:heartbeat_behind]
  if thread[:error]
    host_messages[hostport] = color_error(thread[:error])
    others << hostport
  elsif thread[:master_status]
    status = thread[:master_status]
    host_messages[hostport] = "#{status["File"]}:#{status["Position"]}"
    if heartbeat
      host_messages[hostport] += color_error(" (heartbeat #{heartbeat.to_i}s behind)") if heartbeat.to_i > 1
    else
      host_messages[hostport] += color_error(" (no heartbeat)")
    end
    masters << hostport
    ip = Socket.gethostbyname(host)[3]
    ipport = "#{ip}:#{port}"
    master_replicas[ipport] = [] unless master_replicas[ipport]
  elsif thread[:slave_status]
    status = thread[:slave_status]
    master_host = status["Master_Host"]
    master_port = status["Master_Port"]
    file = status["Relay_Master_Log_File"]
    pos = status["Exec_Master_Log_Pos"]
    slave_io = status["Slave_IO_Running"] == "Yes" ? "Y" : color_error("N")
    slave_sql = status["Slave_SQL_Running"] == "Yes" ? "Y" : color_error("N")
    delay = status["Seconds_Behind_Master"].to_i
    delay = heartbeat.to_i if heartbeat
    delay = color_error("#{delay}") if delay > 30
    io_state = status["Slave_IO_State"]
    last_error = status["Last_Error"]
    if last_error.empty?
      error_message = ""
    else
      error_message = color_error(" ERROR:#{last_error}")
    end
    host_messages[hostport] = "#{file}:#{pos} #{slave_io}/#{slave_sql} #{delay}s#{heartbeat ? "" : color_error(" (no heartbeat)")} (#{io_state}#{error_message})"
    ip = Socket.gethostbyname(master_host)[3]
    ipport = "#{ip}:#{master_port}"
    master_replicas[ipport] = [] unless master_replicas[ipport]
    master_replicas[ipport] << hostport
  else
    host_messages[hostport] = color_error("not a replica or a master")
    others << hostport
  end
end

puts "REPLICATED HOSTS"
puts "----------------"
masters.each do |hostport|
  (host, port) = hostport.split(":")
  printf "%-32s #{host_messages[hostport]}\n", "[M: #{short_hostname(host)}:#{port}]"
  ip = Socket.gethostbyname(host)[3]
  ipport = "#{ip}:#{port}"
  master_replicas[ipport].each do |replica|
    (replica_host, replica_port) = replica.split(":")
    printf "%-32s #{host_messages[replica]}\n", "    [R: #{short_hostname(replica_host)}:#{replica_port}]"
  end
  puts ""
end

if others.size > 0
  puts "OTHER HOSTS"
  puts "-----------"
  others.each do |hostport|
    (host, port) = hostport.split(":")
    puts "[#{short_hostname(host)}:#{port}] #{host_messages[hostport]}"
  end
end


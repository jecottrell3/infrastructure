#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "net/ssh"

if ARGV.size < 2 or ARGV[0].to_i < 1
  puts "Usage: #{$0} port mysql_host [mysql_host ...]"
  exit 1
end

port = ARGV[0]
hosts = ARGV[1..-1]

def output2status(output)
  lines = output.split("\n")
  fields = lines.first.split("\t")
  values = lines.last.split("\t")
  status = {}
  fields.zip(values).each { |x| status[x.first] = x.last }
  status
end

hosts.each do |host|
  Net::SSH.start(host, "root") do |ssh|
    output = ssh.exec!("/MSTR/mysql#{port}/mysql/bin/mysql -umon -h127.0.0.1 -P#{port} -e 'show slave status'")
    if output
      if output.include? "such file"
        message = "MySQL not installed"
      elsif output.include? "denied"
        message = "mon user broken"
      elsif output.include? "Can't connect"
        message = "MySQL down"
      else
        status = output2status(output)
        master_host = status["Master_Host"]
        master_port = status["Master_Port"]
        file = status["Relay_Master_Log_File"]
        pos = status["Exec_Master_Log_Pos"]
        slave_io = status["Slave_IO_Running"]
        slave_sql = status["Slave_SQL_Running"]
        delay = status["Seconds_Behind_Master"]
        io_state = status["Slave_IO_State"]
        last_error = status["Last_Error"]
        if last_error.empty?
          error_message = ""
        else
          error_message = "ERROR:#{last_error}"
        end
        message = "master:#{master_host}:#{master_port} #{file}:#{pos} IO/SQL:#{slave_io}/#{slave_sql} delay:#{delay} state:#{io_state} #{error_message}"
      end
    else
      # Returned nil, so it's not a slave.  See if it's a master.
      output = ssh.exec!("/MSTR/mysql#{port}/mysql/bin/mysql -umon -h127.0.0.1 -P#{port} -e 'show master status'")
      if output.nil?
        message = "not a replica or a master"
      else
        status = output2status(output)
        file = status["File"]
        pos = status["Position"]
        message = "MASTER: #{file}:#{pos}"
      end
    end
    puts "#{host}: #{message}"

  end
end


#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "optparse"
require "highline/import"
require "net/ssh"
require "net/sftp"

FLAGS = {}
opts = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} --file <file.sql> --port <MySQL port> [--database <MySQL database>] <host> [<host> ...]"
  opts.on("--file FILE", "File containing SQL to run.") { |x| FLAGS[:file] = x }
  opts.on("--port PORT", Integer, "Port that MySQL is installed on.") { |x| FLAGS[:port] = x }
  opts.on("--database DB", "MySQL database to connect to.") { |x| FLAGS[:db] = x }
  opts.on("--help", "Dispaly this help.") do
    puts opts
    exit
  end
end
opts.parse!

abort "You must specify an SQL file.\n#{opts}" unless FLAGS[:file]
abort "You must specify the MySQL port.\n#{opts}" unless FLAGS[:port]
abort "You must specify the list of hosts to run on.\n#{opts}" if ARGV.size < 1

hosts = ARGV
SQL = File.read(FLAGS[:file])
ROOT_PWD = ask("MySQL root password: ") { |q| q.echo = false }

# Thread-safe puts, adds the host to each line.
LOCK = Mutex.new
def tputs(str)
  LOCK.synchronize do
    puts str.split("\n").map { |x| "[#{Thread.current[:host]}] #{x}\n" }.join
    $stdout.flush
  end
end

# Connect to all hosts first, since this is not thread-safe.
# Also open an SFTP session on each for the same reason.
sessions = hosts.map do |host|
  ssh = Net::SSH.start(host, "root")
  ssh.sftp.connect!
  ssh
end

threads = sessions.map do |session|
  Thread.new(session) do |ssh|
    Thread.current[:host] = ssh.host
    begin
      tputs "Copying SQL file"
      date = ssh.exec!("date +%s").strip
      tmp_file_name = "#{date}_#{rand(32767)}"
      ssh.sftp.file.open("/MSTR/#{tmp_file_name}.sql", "w") do |f|
        f.write(SQL)
      end

      tputs "Running SQL"
      e_root_pwd = ROOT_PWD.gsub(/"/, '\"').gsub(/\$/, '\$')
      mysql_cmd = "/MSTR/mysql#{FLAGS[:port]}/mysql/bin/mysql -uroot -p\"#{e_root_pwd}\" -h127.0.0.1 -P#{FLAGS[:port]}"
      mysql_cmd += " -D#{FLAGS[:db]}" if FLAGS[:db]
      mysql_cmd += " --table --show-warnings"
      output = ssh.exec!("#{mysql_cmd} < /MSTR/#{tmp_file_name}.sql")

      # Delete the copied SQL file.
      ssh.exec!("rm /MSTR/#{tmp_file_name}.sql")

      # Check the output for errors.
      next if output.nil?
      if output.include? "such file"
        tputs "MySQL is not installed for port #{FLAGS[:port]}"
        next
      elsif output.include? "ERROR 1045"
        tputs "Incorrect password"
        next
      end

      # If there was any output, display it.
      tputs output
    rescue Exception => e
      tputs "Caught exception: #{e}, backtrace: #{e}"
    ensure
      ssh.sftp.close_channel
      ssh.close
    end
  end
end
threads.each { |t| t.join }


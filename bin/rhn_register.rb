#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "highline/import"
require "net/ssh"

if ARGV.size < 1
  puts "Usage: #{$0} host_to_register [host_to_register ...]"
  exit 1
end

RHN_USER = "mstrredhat"
hosts = ARGV

# Ask for RHN password without echo.
rhn_pwd = ask("RHN password for #{RHN_USER}: ") { |q| q.echo = false }

hosts.each do |host|
  Net::SSH.start(host, "root") do |ssh|
    puts "Unregistering host #{host} ..."
    output = ssh.exec!("ruby -r xmlrpc/client -r socket -e 'hostname = Socket.gethostname; server = XMLRPC::Client.new2(\"https://rhn.redhat.com/rpc/api/\"); session_key = server.call(\"auth.login\", \"#{RHN_USER}\", \"#{rhn_pwd}\"); server.call(\"system.list_user_systems\", session_key).select { |x| x[\"name\"] == hostname }.each { |info| server.call(\"system.delete_systems\", session_key, [info[\"id\"].to_i]) }; server.call(\"auth.logout\", session_key)'")
    if output.include? "error.invalid_login"
      puts "Invalid password."
      exit 1
    end

    puts "Registering host #{host} ..."
    ssh.exec!("rhnreg_ks --username='#{RHN_USER}' --password='#{rhn_pwd}' --force")

    puts "Done."
  end
end


#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "net/ssh"
require "net/sftp"

if ARGV.size != 1
  puts "Generates and writes a new /etc/dhcpd.conf on the given server."
  puts ""
  puts "Usage: #{$0} <DHCP server>"
  exit 1
end

host = ARGV.first

VLANS = [
          # ADC
          "10.20.101",
          "10.20.103",
          "10.20.105",
          "10.20.107",
          "10.20.109",
        ]

# vlan should be the first three octets of the network, "10.20.105"
def subnet_stanza(vlan)
  "subnet #{vlan}.0 netmask 255.255.255.0 {\n" +
  "  option routers #{vlan}.254;\n" +
  "  range dynamic-bootp #{vlan}.101 #{vlan}.150;\n" +
  "}\n"
end

dhcpd_conf = "option domain-name-servers 10.20.103.3, 10.20.101.3;\n" +
             "option domain-name \"machine.wisdom.com\";\n" +
             "ddns-update-style none;\n" +
             "filename \"/pxelinux.0\";\n"

puts "Generating dhcpd.conf for #{host}"

Net::SSH.start(host, "root") do |ssh|
  output = ssh.exec!("ifconfig bond0 2>/dev/null")
  raise "bond0 not configured properly" unless matches = output.match(/inet addr:((\d+\.\d+\.\d+)\.\d+)/i)
  ip = matches[1]
  vlan = matches[2]

  dhcpd_conf += "next-server #{ip};\n\n"
  dhcpd_conf += subnet_stanza(vlan) + "\n"
  (VLANS - [vlan]).each { |x| dhcpd_conf += subnet_stanza(x) + "\n" }

  puts "Backing up /etc/dhcpd.conf to /etc/dhcpd.conf.mstr_backup"
  ssh.exec!("mv /etc/dhcpd.conf /etc/dhcpd.conf.mstr_backup")

  puts "Writing new dhcpd.conf"
  ssh.sftp.connect do |sftp|
    sftp.file.open("/etc/dhcpd.conf", "w") do |f|
      f.write(dhcpd_conf)
    end
  end
end


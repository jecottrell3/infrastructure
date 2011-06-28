#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "net/ssh"
require "net/sftp"

if ARGV.size != 2
  puts "Generates and writes a new /etc/dhcpd.conf on the given server."
  puts ""
  puts "Usage: #{$0} <DHCP server> <Datacenter>"
  exit 1
end

host = ARGV[0]
datacenter = ARGV[1]

if datacenter.downcase == "adc"
  VLANS = [
          # ADC
          "10.20.101",
          "10.20.103",
          "10.20.105",
          "10.20.107",
          "10.20.109",
          ]
  NAMESERVERS = ["10.20.103.3", "10.20.101.3"]
elsif datacenter.downcase == "bdc"
  VLANS = [
          # BDC
          "10.140.101",
          "10.140.103",
          "10.140.105",
          "10.140.107",
          "10.140.109",
          ]
  NAMESERVERS = ["10.140.101.5", "10.140.103.5"]
else
  puts "Unknown datacenter #{datacenter}"
  exit 1
end

# vlan should be the first three octets of the network, i.e. "10.20.105"
def subnet_stanza(vlan)
  "subnet #{vlan}.0 netmask 255.255.255.0 {\n" +
  "  option routers #{vlan}.254;\n" +
  "  range dynamic-bootp #{vlan}.101 #{vlan}.150;\n" +
  "}\n"
end

dhcpd_conf = "option domain-name-servers #{NAMESERVERS.join(", ")};\n" +
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
  dhcpd_conf += "# Local VLAN of the DHCP server must be listed first.\n\n"
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


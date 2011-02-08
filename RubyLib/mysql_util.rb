# Useful  utilities for MySQL.
#
# Gary Gabriel <ggabriel@microstrategy.com>

module MysqlUtil
  # Find the MAC address of the specified interface under Linux.  eth0 is the
  # default interface.
  def self.mac_address_string(interface="eth0")
    IO.popen("ifconfig #{interface} 2>/dev/null") do |file|
      file.each_line do |line|
        if matches = line.match(/HWaddr\s+([A-Z0-9:]+)/i)
          return matches[1]
        end
      end
    end
    return nil
  end

  def self.server_id_from_mac(interface="eth0")
    return nil unless mac = self.mac_address_string(interface)
    mac.split(":")[-4, 4].join.hex
  end
end

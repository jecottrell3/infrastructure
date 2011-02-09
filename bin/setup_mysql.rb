# Run this with "ruby -rubygems setup_mysql.rb host_to_setup"
#
# Gary Gabriel <ggabriel@microstrategy.com>

require "net/ssh"
require "net/sftp"

unless host = ARGV[0]
  puts "Usage: ruby -rubygems setup_mysql.rb host_to_setup"
  exit 1
end

def install_mysql(ssh)
  # WARNING: this will leave MySQL with an empty root password.
  ssh.exec!("DEBIAN_FRONTEND=noninteractive apt-get -q -y install mysql-client mysql-server")
  # Set the root password.
  ssh.exec!("echo \"UPDATE mysql.user SET password = '*82A0C96BC9C820E3541661E2100D038C36A6D305' WHERE user = 'root'; FLUSH PRIVILEGES;\" | mysql -uroot")
end

def stop_mysql(ssh)
  ssh.exec!("service mysql stop")
  sleep 1
end

def start_mysql(ssh)
  ssh.exec!("service mysql start")
end

def get_server_id(ssh)
  output = ssh.exec!("ifconfig eth0 2>/dev/null")
  if matches = output.match(/HWaddr\s+([A-Z0-9:]+)/i)
    return matches[1].split(":")[-4, 4].join.hex
  else
    raise "Unable to get server id"
  end
end

def backup_mycnf(ssh)
  ssh.exec!("cp /etc/mysql/my.cnf /etc/mysql/my.cnf.mstr_old")
end

def backup_fstab(ssh)
  ssh.exec!("cp /etc/fstab /etc/fstab.mstr_old")
end

def make_dbfs(ssh)
  ssh.exec!("mkfs -t ext4 /dev/sdf")
  ssh.exec!("mkdir -p /databases")
end

def mount_dbfs(ssh)
  ssh.exec!("mount /databases")
  ssh.exec!("mkdir /databases/tmp")
  ssh.exec!("chmod 1777 /databases/tmp")
end

def move_mysql_data(ssh)
  ssh.exec!("mv /var/lib/mysql /databases/")
end

def edit_fstab(sftp)
  # Add a /dev/sdf /databases entry
  new_fstab = ""
  sftp.file.open("/etc/fstab", "r") do |f|
    while line = f.gets
      if line.match(/^\s*\/dev\/sdf\s+/)
        # /dev/sdf should not already be there, but we'll comment it out if it is
        new_fstab += "##{line}"
      else
        new_fstab += line
      end
    end
  end

  new_fstab += "/dev/sdf\t/databases\text4\tdefaults\t0\t0\n"

  sftp.file.open("/etc/fstab", "w") do |f|
    f.write(new_fstab)
  end
end

def write_local_apparmor(sftp)
  # Add new directories to apparmor
  local_apparmor = [ "/databases/mysql/ r,\n",
                     "/databases/mysql/** rwk,\n",
                     "/databases/tmp/ r,\n",
                     "/databases/tmp/** rwk,\n"
                   ].join
  sftp.file.open("/etc/apparmor.d/local/usr.sbin.mysqld", "w") do |f|
    f.write(local_apparmor)
  end
end

def edit_mycnf(sftp)
  # Rewrite my.cnf with datadir, tmpdir and bind-address commented out.
  new_mycnf = ""
  sftp.file.open("/etc/mysql/my.cnf", "r") do |f|
    while line = f.gets
      if line.match(/^\s*datadir\s*=/) or line.match(/^\s*tmpdir\s*=/) or line.match(/^\s*bind-address\s*=/)
        new_mycnf += "##{line}"
      else
        new_mycnf += line
      end
    end
  end

  sftp.file.open("/etc/mysql/my.cnf", "w") do |f|
    f.write(new_mycnf)
  end
end

def write_local_mycnf(sftp, server_id)
  local_mycnf = [ "[mysqld]\n",
                  "datadir = /databases/mysql\n",
                  "tmpdir = /databases/tmp\n",
                  "server-id = #{server_id}\n",
                  "innodb_file_per_table\n",
                  "default-storage-engine = InnoDB\n",
                  "character-set-server = utf8\n",
                  "sysdate-is-now\n",
                  "\n",
                  "[client]\n",
                  "default-character-set = utf8\n"
                ].join
  sftp.file.open("/etc/mysql/conf.d/mstr.cnf", "w") do |f|
    f.write(local_mycnf)
  end
end

Net::SSH.start(host, "root") do |ssh|
  puts "Installing MySQL"
  install_mysql(ssh)

  puts "Stopping MySQL"
  stop_mysql(ssh)

  puts "Backing up fstab"
  backup_fstab(ssh)

  puts "Backing up my.cnf"
  backup_mycnf(ssh)

  puts "Getting the server id"
  server_id = get_server_id(ssh)
  puts "    server id is #{server_id}"

  puts "Creating a new filesystem"
  make_dbfs(ssh)

  ssh.sftp.connect do |sftp|
    puts "Modifying fstab"
    edit_fstab(sftp)
  end

  puts "Mounting new filesystem"
  mount_dbfs(ssh)

  puts "Moving existing MySQL data"
  move_mysql_data(ssh)

  ssh.sftp.connect do |sftp|
    puts "Writing local apparmor"
    write_local_apparmor(sftp)

    puts "Modifying my.cnf"
    edit_mycnf(sftp)

    puts "Writing local my.cnf (mstr.cnf)"
    write_local_mycnf(sftp, server_id)
  end

  puts "Starting MySQL"
  start_mysql(ssh)

  puts "Done."
end


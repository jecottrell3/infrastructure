#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "optparse"
require "highline/import"
require "rexml/document"
require "net/ssh"
require "net/sftp"

FLAGS = {}
opts = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} install --shard <number> --version <version> --package <package.tar.gz> --key <cdkey> <host>\n" +
                "       #{$0} install_cluster --shard <number> --version <version> --package <package.tar.gz> --key <cdkey> <host1> <host2>\n" +
                "       #{$0} upgrade_cluster --shard <number> --vfrom <version> --vto <version> --package <package.tar.gz> --key <cdkey> <host1> <host2>"
  opts.on("--shard SHARD", Integer, "Shard number.") { |x| FLAGS[:shard] = x }
  opts.on("--version VERSION", "Version to install.") { |x| FLAGS[:version] = x }
  opts.on("--vfrom VERSION", "Version to upgrade from.") { |x| FLAGS[:vfrom] = x }
  opts.on("--vto VERSION", "Version to upgrade to.") { |x| FLAGS[:vto] = x }
  opts.on("--package PACKAGE", "Installation package in tar.gz format.") { |x| FLAGS[:package] = x }
  opts.on("--key CDKEY", "Installation CD key.") { |x| FLAGS[:key] = x }
  opts.on("--help", "Dispaly this help.") do
    puts opts
    exit
  end
end
opts.parse!

abort "You must specify the command.\n\n#{opts}" if ARGV.size < 1
command = ARGV.shift

if command == "install"
  abort "You must specify the shard number.\n\n#{opts}" unless FLAGS[:shard]
  abort "You must specify the version to install.\n\n#{opts}" unless FLAGS[:version]
  abort "You must specify the tar.gz package to install.\n\n#{opts}" unless FLAGS[:package]
  abort "You must specify the CD key.\n\n#{opts}" unless FLAGS[:key]
  abort "You must specify the host to install on.\n\n#{opts}" if ARGV.size < 1
elsif command == "install_cluster"
  abort "You must specify the shard number.\n\n#{opts}" unless FLAGS[:shard]
  abort "You must specify the version to install.\n\n#{opts}" unless FLAGS[:version]
  abort "You must specify the tar.gz package to install.\n\n#{opts}" unless FLAGS[:package]
  abort "You must specify the CD key.\n\n#{opts}" unless FLAGS[:key]
  abort "You must specify the two hosts to install on.\n\n#{opts}" if ARGV.size != 2
elsif command == "upgrade_cluster"
  abort "You must specify the shard number.\n\n#{opts}" unless FLAGS[:shard]
  abort "You must specify the version to upgrade from.\n\n#{opts}" unless FLAGS[:vfrom]
  abort "You must specify the version to upgrade to.\n\n#{opts}" unless FLAGS[:vto]
  abort "Versions cannot be the same.\n\n#{opts}" if FLAGS[:vfrom] == FLAGS[:vto]
  abort "You must specify the tar.gz package to install.\n\n#{opts}" unless FLAGS[:package]
  abort "You must specify the CD key.\n\n#{opts}" unless FLAGS[:key]
  abort "You must specify the two hosts in the cluster.\n\n#{opts}" if ARGV.size != 2
else
  abort "Invalid command: #{command}\n\n#{opts}"
end

PASSWORDS = {}
PASSWORDS[:md_pwd] = ask("MySQL password for the metadata database: ") { |q| q.echo = false }
PASSWORDS[:adm_pwd] = ask("IServer password for Administrator: ") { |q| q.echo = false }

# Update sysctl parameters.
def update_sysctl(ssh, variable, value, comment)
  output = ssh.exec!("egrep '^[^#]*\\b#{variable}\\b' /etc/sysctl.conf")
  if output
    # Already in the file, update it.
    ssh.exec!("sed -i -e 's/^[^#]*\\b#{variable}\\s*=.*/#{variable} = #{value}/' /etc/sysctl.conf")
  else
    # Add variable to the file.
    ssh.exec!("echo '' >> /etc/sysctl.conf")
    ssh.exec!("echo '# #{comment}' >> /etc/sysctl.conf")
    ssh.exec!("echo '#{variable} = #{value}' >> /etc/sysctl.conf")
  end
  ssh.exec!("sysctl -w #{variable}='#{value}'")
end

def download_url(ssh, url, filepath)
  output = ssh.exec!("wget -q -O '#{filepath}' '#{url}' || echo MSTRFAIL")
  raise "Download of #{url} failed." if output and output.include? "MSTRFAIL"
end

def start_iserver(ssh, shard, version)
  puts "Starting the Intelligence Server"
  install_root = "/MSTR/shard#{shard}/#{version}"
  ssh.exec!("bash -c '#{install_root}/MicroStrategy/bin/mstrctl -s IntelligenceServer start </dev/null &>/dev/null'")
  sleep 1
  seconds = 0
  timeout = 300
  loop do
    state = ""
    output = ssh.exec!("#{install_root}/MicroStrategy/bin/mstrctl -s IntelligenceServer gs")
    REXML::Document.new(output).elements.each("status/state") { |x| state = x.text }
    raise "Unable to start, state is #{state}" unless state == "starting" or state == "running"
    break if state == "running"
    raise "Unable to start, timeout of #{timeout} seconds reached" if seconds > timeout
    print "."
    $stdout.flush
    seconds += 1
    sleep 1
  end
  puts " started"
end

def stop_iserver(ssh, shard, version)
  puts "Stopping the Intelligence Server"
  install_root = "/MSTR/shard#{shard}/#{version}"
  ssh.exec!("bash -c '#{install_root}/MicroStrategy/bin/mstrctl -s IntelligenceServer stop </dev/null &>/dev/null'")
  sleep 1
  seconds = 0
  timeout = 300
  loop do
    state = ""
    output = ssh.exec!("#{install_root}/MicroStrategy/bin/mstrctl -s IntelligenceServer gs")
    REXML::Document.new(output).elements.each("status/state") { |x| state = x.text }
    raise "Unable to stop, state is #{state}" unless state == "stopping" or state == "unloading" or state == "stopped"
    break if state == "stopped"
    raise "Unable to stop, timeout of #{timeout} seconds reached" if seconds > timeout
    print "."
    $stdout.flush
    seconds += 1
    sleep 1
  end
  puts " stopped"
end

# Install the IServer on the host that ssh is connected to.  ssh should already
# have an open sftp channel as well.
def install_iserver(ssh, shard, version, package, cdkey)
  install_url = "http://install.infra.wisdom.com/install"
  install_root = "/MSTR/shard#{shard}/#{version}"
  output = ssh.exec!("ls -d #{install_root}")
  raise "Host #{ssh.host} already has #{install_root}." unless output.include? "such file"

  puts "Updating sysctl if needed"
  update_sysctl(ssh, "kernel.sem", "250 32000 32 4096", "Increase semmni to 4096")
  update_sysctl(ssh, "vm.max_map_count", "5242880", "Increase vm.max_map_count")

  puts "Downloading installation files"
  download_dir = "#{install_root}/tmp_download"
  ssh.exec!("mkdir -p #{download_dir}")
  download_url(ssh, "#{install_url}/MicroStrategy/#{package}", "#{download_dir}/#{package}")
  download_url(ssh, "#{install_url}/MicroStrategy/CoreFonts.zip", "#{download_dir}/CoreFonts.zip")
  download_url(ssh, "#{install_url}/MicroStrategy/TN34084_TN34084_2.zip", "#{download_dir}/TN34084_TN34084_2.zip")
  ssh.exec!("cd #{download_dir}; tar xzf #{package}")
  output = ssh.exec!("ls -d #{download_dir}/QueryReportingAnalysis_Linux")
  raise "QueryReportingAnalysis_Linux not found in the IServer download" if output.include? "such file"
  ssh.exec!("mv #{download_dir}/QueryReportingAnalysis_Linux #{install_root}")

  puts "Installing required packages"
  ssh.exec!("yum install -y unixODBC xorg-x11-xauth")
  ssh.exec!("rpm -i http://install.infra.wisdom.com/install/MySQL/mysql-connector-odbc-3.51.28-1.rhel5.i386.rpm")

  options_txt = [ '-W userRegistration.user="Administrator"',
                  '-W userRegistration.company="MicroStrategy, Inc"',
                  '-W userRegistration.cdkey="' + cdkey + '"',
                  '-W silent.homeDirectory=' + install_root + '/MicroStrategy',
                  '-W silent.installDirectory=' + install_root + '/MicroStrategy/install',
                  '-W silent.logDirectory=' + install_root + '/MicroStrategy/log',
                  '-P WebUAnalystFeature.active=false',
                  '-P WebUReporterFeature.active=false',
                  '-P WebUProfFeature.active=false',
                  '-P PortletsFeature.active=false',
                  '-P GISConnectorsFeature.active=false',
                  '-P WebServicesJ2EEFeature.active=false',
                  '-P MobileClientFeature.active=false',
                  '-P MobileWebFeature.active=false',
                  '-P SDKFeature.active=false',
                  '-W silent.commandManagerDirectory=' + install_root + '/MicroStrategy/install/CommandManager',
                  '-W silent.temporaryLogFile="silent_error.log"',
                  '-G replaceNewerResponse=yesToAll',
                  '-G replaceExistingResponse=yesToAll'
                ].map { |x| x + "\n" }.join
  ssh.exec!("cd #{install_root}/QueryReportingAnalysis_Linux; mv options.txt options.txt.orig")
  ssh.sftp.file.open("#{install_root}/QueryReportingAnalysis_Linux/options.txt", "w") do |f|
    f.write(options_txt)
  end

  puts "Installing the Intelligence Server"
  ssh.exec!("cd #{install_root}/QueryReportingAnalysis_Linux; ./setupLinux.bin -silent -options options.txt -is:log silent.log")
  ssh.exec!("cd #{download_dir}; unzip TN34084_TN34084_2.zip")
  ssh.exec!("mv #{download_dir}/TN34084_TN34084_2/* #{install_root}/MicroStrategy/log/")
  ssh.exec!("cd #{install_root}/MicroStrategy/install/PDFGeneratorFiles; unzip #{download_dir}/CoreFonts.zip")

  puts "Configuring the Intelligence Server"
  # Update Tunable.sh .
  tunable_sh = ""
  ssh.sftp.file.open("#{install_root}/MicroStrategy/env/Tunable.sh", "r") do |f|
    tunable_sh = f.read
  end
  tunable_append = [ '# Number of open files',
                     'ulimit -n 65536 > /dev/null 2>&1',
                     '# Core file size to unlimited',
                     'ulimit -c unlimited > /dev/null 2>&1',
                     '',
                     '# Max Block 256MB',
                     'export MSTR_MEM_CACHE_MAX_BLOCK_SIZE=268435456',
                     '# Max Cache bytes 64GB',
                     'export MSTR_MEM_CACHE_MAX_TOTAL_SIZE=68719476736',
                     '# Cache Increment bytes 256MB',
                     'export MSTR_MEM_INCREMENT_SIZE_KB=262144',
                     '# Max Cache Blocks Per Band bytes 4MB',
                     'export MSTR_MEM_CACHE_MAX_BLOCKS_PER_BAND=4096',
                     '# Max Cache Free Pages bytes',
                     'export MSTR_MEM_CACHE_MAX_FREE_PAGES_KB=2684354560',
                     '# Set Time Zone',
                     'export TZ=UTC'
                   ].map { |x| x + "\n" }.join
  ssh.sftp.file.open("#{install_root}/MicroStrategy/env/Tunable.sh", "w") do |f|
    f.write(tunable_sh + "\n" + tunable_append)
  end
  # Update odbc.ini .
  odbc_ini = [ '[ODBC Data Sources]',
               'sma_md=MySQL',
               'sma_wh=MySQL',
               'sma_stats=MicroStrategy ODBC Driver for SQL Server Wire Protocol',
               '',
               '',
               '[ODBC]',
               'Trace=0',
               'TraceFile=odbctrace.out',
               'TraceDll=' + install_root + '/MicroStrategy/install/lib32/odbctrac.so',
               'InstallDir=' + install_root + '/MicroStrategy/install',
               'IANAAppCodePage=106',
               'UseCursorLib=0',
               '',
               '[sma_md]',
               'Driver=/usr/lib/libmyodbc3.so',
               'Description=MySQL ODBC 3.51 Driver DSN',
               'Server=s' + shard.to_s + 'mdb-master.prod.wisdom.com',
               'Port=3307',
               'Database=sma_md',
               '',
               '[sma_wh]',
               'Driver=/usr/lib/libmyodbc3.so',
               'Description=MySQL ODBC 3.51 Driver DSN',
               'Server=s' + shard.to_s + 'db-master.prod.wisdom.com',
               'Port=3306',
               'Database=sma_wh',
               'Charset=utf8',
               '',
               '[sma_stats]',
               'Database=SMA_STATS',
               'Address=10.20.107.9,1433',
               'Driver=' + install_root + '/MicroStrategy/install/lib32/MYmsssXX.so',
               'Description=MicroStrategy ODBC Driver for SQL Server Wire Protocol',
               'QuotedId=Yes',
               'AnsiNPW=Yes',
               'IANAAppCodePage=106'
             ].map { |x| x + "\n" }.join
  ssh.exec!("mv #{install_root}/MicroStrategy/odbc.ini #{install_root}/MicroStrategy/odbc.ini.orig")
  ssh.sftp.file.open("#{install_root}/MicroStrategy/odbc.ini", "w") do |f|
    f.write(odbc_ini)
  end
  # Update the registry.
  port = ("3" + shard.to_s * 4).to_i
  configuration_xml = "<configuration>"
  configuration_xml += "<metadata><login pwd=\"#{PASSWORDS[:md_pwd]}\">md</login><odbc dsn=\"sma_md\"/></metadata>"
  configuration_xml += "<svrd n=\"WAS-HSOEWANDI77\"/>"
  configuration_xml += "<tcp_port_number>#{port}</tcp_port_number>"
  configuration_xml += "</configuration>"
  xml_sent = false
  channel = ssh.open_channel do |ch|
    ch.exec("#{install_root}/MicroStrategy/bin/mstrctl -s IntelligenceServer ssic") do |ch, success|
      ch.send_data(configuration_xml)
      xml_sent = true
    end
  end
  ssh.loop { not xml_sent }
  channel.eof!
  channel.wait
  channel.close
  ssh.exec!("mv /root/vpd.properties #{install_root}/")

  puts "Removing temporary installation files"
  ssh.exec!("rm -Rf #{download_dir}")

  puts "Starting NFS"
  ssh.exec!("chkconfig nfs on")
  ssh.exec!("service nfs start")
end

def update_exports(ssh, export_dir, shard, other_host)
  exports = ""
  ssh.sftp.file.open("/etc/exports", "r") do |f|
    exports = f.read
  end
  lines = exports.split("\n").select { |x| not x.start_with? "/MSTR/shard#{shard}" }
  lines.push "#{export_dir} #{other_host.upcase}(rw,no_root_squash)"
  ssh.sftp.file.open("/etc/exports", "w") { |f| f.write(lines.join("\n") + "\n") }
end

def update_fstab(ssh, export_dir, other_host)
  fstab = ""
  ssh.sftp.file.open("/etc/fstab", "r") do |f|
    fstab = f.read
  end
  lines = fstab.split("\n").select { |x| not x.downcase.start_with? "#{other_host.downcase}:" }
  lines.push "#{other_host.upcase}:#{export_dir} /#{other_host.upcase}/ClusterCube nfs defaults 0 0"
  ssh.sftp.file.open("/etc/fstab", "w") { |f| f.write(lines.join("\n") + "\n") }
end

def configure_cluster_nfs(ssh1, ssh2, shard, version)
  # Update exports.
  export_dir = "/MSTR/shard#{shard}/#{version}/MicroStrategy/IntelligenceServer/Cube/WAS-HSOEWANDI77"
  update_exports(ssh1, export_dir, shard, ssh2.host)
  ssh1.exec!("exportfs -r")
  update_exports(ssh2, export_dir, shard, ssh1.host)
  ssh2.exec!("exportfs -r")
  sleep 2
  # Update mounts.
  ssh1.exec!("mkdir -p /#{ssh2.host.upcase}/ClusterCube")
  update_fstab(ssh1, export_dir, ssh2.host)
  ssh1.exec!("mount /#{ssh2.host.upcase}/ClusterCube")
  ssh2.exec!("mkdir -p /#{ssh1.host.upcase}/ClusterCube")
  update_fstab(ssh2, export_dir, ssh1.host)
  ssh2.exec!("mount /#{ssh1.host.upcase}/ClusterCube")
end

def cluster_iserver(ssh, shard, version, other_host)
  install_root = "/MSTR/shard#{shard}/#{version}"
  port = ("3" + shard.to_s * 4).to_i
  loop do
    script = "CONNECT SERVER \"#{ssh.host.upcase}\" USER \"Administrator\" PASSWORD \"#{PASSWORDS[:adm_pwd]}\" PORT #{port};\n" +
             "ADD SERVER \"#{other_host.upcase}\" TO CLUSTER;\n"
    ssh.sftp.file.open("#{install_root}/tmp_cluster.scp", "w") do |f|
      f.write(script)
    end
    output = ssh.exec!("#{install_root}/MicroStrategy/bin/mstrcmdmgr -connlessMSTR -f #{install_root}/tmp_cluster.scp")
    ssh.exec!("rm #{install_root}/tmp_cluster.scp")
    if output.include? "Incorrect login"
      puts "IServer Administrator password incorrect."
      PASSWORDS[:adm_pwd] = ask("IServer password for Administrator: ") { |q| q.echo = false }
    else
      break
    end
  end
end

def idle_iserver(ssh, shard, version)
  install_root = "/MSTR/shard#{shard}/#{version}"
  port = ("3" + shard.to_s * 4).to_i
  loop do
    script = "CONNECT SERVER \"#{ssh.host.upcase}\" USER \"Administrator\" PASSWORD \"#{PASSWORDS[:adm_pwd]}\" PORT #{port};\n" +
             "IDLE PROJECT \"SMA Project 03-31\" MODE REQUEST;\n"
    ssh.sftp.file.open("#{install_root}/tmp_idle.scp", "w") do |f|
      f.write(script)
    end
    output = ssh.exec!("#{install_root}/MicroStrategy/bin/mstrcmdmgr -connlessMSTR -f #{install_root}/tmp_idle.scp")
    puts "DEBUG: #{output}"
    ssh.exec!("rm #{install_root}/tmp_idle.scp")
    if output.include? "Incorrect login"
      puts "IServer Administrator password incorrect."
      PASSWORDS[:adm_pwd] = ask("IServer password for Administrator: ") { |q| q.echo = false }
    else
      break
    end
  end
end

if command == "install"
  host = ARGV[0]
  ssh = Net::SSH.start(host, "root")
  ssh.sftp.connect!
  begin
    puts "Installing version #{FLAGS[:version]} for shard #{FLAGS[:shard]} on host #{host}"
    install_iserver(ssh, FLAGS[:shard], FLAGS[:version], FLAGS[:package], FLAGS[:key])
    start_iserver(ssh, FLAGS[:shard], FLAGS[:version])
  ensure
    # Disconnect from the host.
    ssh.sftp.close_channel
    ssh.close
  end

elsif command == "install_cluster"
  host1 = ARGV[0]
  host2 = ARGV[1]
  ssh1 = Net::SSH.start(host1, "root")
  ssh1.sftp.connect!
  ssh2 = Net::SSH.start(host2, "root")
  ssh2.sftp.connect!

  begin
    puts "Installing version #{FLAGS[:version]} for shard #{FLAGS[:shard]} on cluster hosts #{host1} and #{host2}"
    puts "Installing on #{host1}"
    install_iserver(ssh1, FLAGS[:shard], FLAGS[:version], FLAGS[:package], FLAGS[:key])
    start_iserver(ssh1, FLAGS[:shard], FLAGS[:version])
    puts "Done on #{host1}"
    puts "Installing on #{host2}"
    install_iserver(ssh2, FLAGS[:shard], FLAGS[:version], FLAGS[:package], FLAGS[:key])
    start_iserver(ssh2, FLAGS[:shard], FLAGS[:version])
    puts "Done on #{host2}"
    puts "Setting up NFS for clustering"
    configure_cluster_nfs(ssh1, ssh2, FLAGS[:shard], FLAGS[:version])
    puts "Clustering the Intelligence Servers"
    cluster_iserver(ssh1, FLAGS[:shard], FLAGS[:version], host2)
  ensure
    # Disconnect from hosts.
    ssh1.sftp.close_channel
    ssh1.close
    ssh2.sftp.close_channel
    ssh2.close
  end
elsif command == "upgrade_cluster"
  host1 = ARGV[0]
  host2 = ARGV[1]
  puts "Upgrading #{host1} and #{host2} from version #{FLAGS[:vfrom]} to version #{FLAGS[:vto]}"

  # Connect to both hosts and open sftp sessions.
  ssh1 = Net::SSH.start(host1, "root")
  ssh1.sftp.connect!
  ssh2 = Net::SSH.start(host2, "root")
  ssh2.sftp.connect!

  begin
    from_root = "/MSTR/shard#{FLAGS[:shard]}/#{FLAGS[:vfrom]}"

    # Make sure the version and shard number is correct for both hosts.
    [ssh1, ssh2].each do |ssh|
      output = ssh.exec!("ls -d #{from_root}")
      raise "Host #{ssh.host} does not have #{from_root}." if output.include? "such file"
      output = ssh.exec!("pgrep -f #{from_root}/MicroStrategy/install/IntelligenceServer/bin/MSTRSvr")
      raise "MSTRSvr is not running on host #{ssh.host}." unless output
    end

    # Install the new version.
    puts "Installing version #{FLAGS[:vto]} on #{host1}"
    install_iserver(ssh1, FLAGS[:shard], FLAGS[:vto], FLAGS[:package], FLAGS[:key])
    puts "Installed on #{host1}"
    puts "Installing version #{FLAGS[:vto]} on #{host2}"
    install_iserver(ssh2, FLAGS[:shard], FLAGS[:vto], FLAGS[:package], FLAGS[:key])
    puts "Installed on #{host2}"

    # Idle host1 and shut it down.
    puts "Idling version #{FLAGS[:vfrom]} on #{host1}"
    idle_iserver(ssh1, FLAGS[:shard], FLAGS[:vfrom])
    puts "Waiting 60 seconds."
    sleep 60
    puts "Stopping version #{FLAGS[:vfrom]} on #{host1}"
    stop_iserver(ssh1, FLAGS[:shard], FLAGS[:vfrom])

  ensure
    # Disconnect from hosts.
    ssh1.sftp.close_channel
    ssh1.close
    ssh2.sftp.close_channel
    ssh2.close
  end
end


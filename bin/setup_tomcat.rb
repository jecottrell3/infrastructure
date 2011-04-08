#!/usr/bin/ruby -rubygems

# Gary Gabriel <ggabriel@microstrategy.com>

require "net/ssh"
require "net/sftp"

unless host = ARGV[0] and shard = ARGV[1].to_i
  puts "Usage: #{$0} host_to_setup shard_number"
  exit 1
end

JDK_DOWNLOAD = "jdk-6u24-linux-x64.bin"
JAVA_DIR = "jdk1.6.0_24"
LIBAPR_DOWNLOAD = "libapr_so.tar.gz"
TOMCAT = "apache-tomcat-6.0.32"
LIBTCNATIVE_DOWNLOAD = "tomcat_native_lib_so.tar.gz"

Net::SSH.start(host, "root", :forward_agent => true) do |ssh|
  output = ssh.exec!("ls -d /usr/java/#{JAVA_DIR}")
  if output.include? "such file"
    # Java not installed.
    puts "Installing Java"
    ssh.exec!("mkdir /usr/java")
    ssh.exec!("wget -O '/usr/java/#{JDK_DOWNLOAD}' 'http://install.infra.wisdom.com/install/Java/#{JDK_DOWNLOAD}'")
    ssh.exec!("cd /usr/java; echo | sh ./#{JDK_DOWNLOAD}")
    ssh.exec!("rm /usr/java/#{JDK_DOWNLOAD}")
  else
    puts "Found Java in /usr/java/#{JAVA_DIR} ."
  end

  output = ssh.exec!("ls /MSTR/libapr/lib/libapr-1.so")
  if output.include? "such file"
    # libapr not installed.
    puts "Installing libapr"
    ssh.exec!("wget -O '/MSTR/#{LIBAPR_DOWNLOAD}' 'http://install.infra.wisdom.com/install/Tomcat/#{LIBAPR_DOWNLOAD}'")
    ssh.exec!("cd /MSTR; tar xzf #{LIBAPR_DOWNLOAD}");
    ssh.exec!("rm /MSTR/#{LIBAPR_DOWNLOAD}");
  else
    puts "Found libapr in /MSTR/libapr/lib/libapr-1.so"
  end

  apps_home = "/MSTR/strategyApps/shard#{shard}"
  ssh.exec!("mkdir -p #{apps_home}")
  ssh.exec!("mkdir #{apps_home}/WARbackup #{apps_home}/WARstage")

  puts "Installing Tomcat"
  ssh.exec!("wget -O '#{apps_home}/#{TOMCAT}.tar.gz' 'http://install.infra.wisdom.com/install/Tomcat/#{TOMCAT}.tar.gz'")
  ssh.exec!("cd #{apps_home}; tar xzf #{TOMCAT}.tar.gz")
  ssh.exec!("rm #{apps_home}/#{TOMCAT}.tar.gz")
  ssh.exec!("cd #{apps_home}; ln -s #{TOMCAT} tomcat")
  ssh.exec!("mkdir #{apps_home}/tomcat/conf/keys")
  ssh.exec!("scp -o StrictHostKeyChecking=no root@install.infra.wisdom.com:/MSTR/private/tomcat_ssl_keys/host_priv.key #{apps_home}/tomcat/conf/keys/")
  ssh.exec!("scp -o StrictHostKeyChecking=no root@install.infra.wisdom.com:/MSTR/private/tomcat_ssl_keys/wildcard.wisdom.com.cer #{apps_home}/tomcat/conf/keys/")
  ssh.exec!("scp -o StrictHostKeyChecking=no root@install.infra.wisdom.com:/MSTR/private/tomcat_ssl_keys/SSL_CA_Bundle_Apache.pem #{apps_home}/tomcat/conf/keys/")
  ssh.exec!("mkdir #{apps_home}/tomcat/run")
  ssh.exec!("rm -Rf #{apps_home}/tomcat/webapps/docs")
  ssh.exec!("rm -Rf #{apps_home}/tomcat/webapps/examples")
  ssh.exec!("rm -Rf #{apps_home}/tomcat/webapps/ROOT")
  ssh.exec!("wget -O '#{apps_home}/tomcat/webapps/tomcat_root.tar.gz' 'http://install.infra.wisdom.com/install/Tomcat/tomcat_root.tar.gz'")
  ssh.exec!("cd #{apps_home}/tomcat/webapps; tar xzf tomcat_root.tar.gz")
  ssh.exec!("rm #{apps_home}/tomcat/webapps/tomcat_root.tar.gz")
  ssh.exec!("useradd tomcat")
  ssh.exec!("chown -R tomcat:tomcat #{apps_home}/#{TOMCAT}")
  tomcat_sh = [ "#!/bin/sh",
                "",
                "JAVA_HOME=/usr/java/#{JAVA_DIR}",
                "PATH=\"$JAVA_HOME\"/bin:\"$PATH\"",
                "CATALINA_HOME=#{apps_home}/tomcat",
                "CATALINA_OPTS=\"-server -Xms512m -Xmx2048m -Dbuild.compiler.emacs=true -Djava.library.path=$CATALINA_HOME/lib\"",
                "CATALINA_PID=\"$CATALINA_HOME\"/run/tomcat.pid",
                "",
                "export JAVA_HOME CATALINA_HOME CATALINA_OPTS PATH CATALINA_PID",
                "",
                "case \"$1\" in",
                "  start)",
                "    echo \"Starting Tomcat\"",
                "    su tomcat -c \"'$CATALINA_HOME'/bin/startup.sh\"",
                "    ;;",
                "  stop)",
                "    echo \"Stopping Tomcat\"",
                "    su tomcat -c \"'$CATALINA_HOME'/bin/shutdown.sh 20 -force\"",
                "    ;;",
                "  restart)",
                "    echo \"Stopping Tomcat\"",
                "    su tomcat -c \"'$CATALINA_HOME'/bin/shutdown.sh 20 -force\"",
                "    echo \"Starting Tomcat\"",
                "    su tomcat -c \"'$CATALINA_HOME'/bin/startup.sh\"",
                "    ;;",
                "  *)",
                "    echo \"Usage: $0 {start|stop|restart}\"",
                "    exit 1",
                "esac"
              ].map { |x| x + "\n" }.join
  ssh.sftp.connect do |sftp|
    sftp.file.open("#{apps_home}/tomcat/tomcat.sh", "w") do |f|
      f.write(tomcat_sh)
    end
  end
  ssh.exec!("chmod +x #{apps_home}/tomcat/tomcat.sh")
  ssh.sftp.connect do |sftp|
    sftp.file.open("#{apps_home}/tomcat/webapps/ROOT/status.jsp", "w") do |f|
      f.write('<%= "OK" %>')
    end
  end
  ssh.exec!("chown tomcat:tomcat #{apps_home}/tomcat/webapps/ROOT/status.jsp")

  puts "Installing Tomcat Native libraries"
  ssh.exec!("wget -O '/MSTR/#{LIBTCNATIVE_DOWNLOAD}' 'http://install.infra.wisdom.com/install/Tomcat/#{LIBTCNATIVE_DOWNLOAD}'")
  ssh.exec!("cd #{apps_home}/tomcat/lib; tar xzf /MSTR/#{LIBTCNATIVE_DOWNLOAD}")
  ssh.exec!("rm /MSTR/#{LIBTCNATIVE_DOWNLOAD}")

  puts "Configuring Tomcat for shard #{shard}"
  ssh.exec!("cd #{apps_home}/tomcat/conf; mv server.xml server.xml.mstr_backup")
  server_xml = [ "<?xml version='1.0' encoding='utf-8'?>",
                 '<Server port="' + (6000 + shard).to_s + '" shutdown="SHUTDOWN">',
                 '',
                 '  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />',
                 '  <Listener className="org.apache.catalina.core.JasperListener" />',
                 '  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />',
                 '  <Listener className="org.apache.catalina.mbeans.ServerLifecycleListener" />',
                 '  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />',
                 '',
                 '  <GlobalNamingResources>',
                 '    <Resource name="UserDatabase" auth="Container"',
                 '              type="org.apache.catalina.UserDatabase"',
                 '              description="User database that can be updated and saved"',
                 '              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"',
                 '              pathname="conf/tomcat-users.xml" />',
                 '  </GlobalNamingResources>',
                 '',
                 '  <Service name="Catalina">',
                 '    <Connector port="' + (8000 + shard).to_s + '" protocol="HTTP/1.1"',
                 '               connectionTimeout="20000"',
                 '               redirectPort="443" />',
                 '    <Connector port="' + (9000 + shard).to_s + '" protocol="HTTP/1.1" SSLEnabled="true"',
                 '               maxThreads="150" scheme="https" secure="true"',
                 '               sslProtocol="all"',
                 '               maxHttpHeaderSize="16384"',
                 '               SSLCertificateFile="${catalina.home}/conf/keys/wildcard.wisdom.com.cer"',
                 '               SSLCertificateKeyFile="${catalina.home}/conf/keys/host_priv.key"',
                 '               SSLCACertificateFile="${catalina.home}/conf/keys/SSL_CA_Bundle_Apache.pem" />',
                 '    <Connector port="' + (7000 + shard).to_s + '" protocol="AJP/1.3" redirectPort="443" />',
                 '    <Engine name="Catalina" defaultHost="localhost">',
                 '      <Realm className="org.apache.catalina.realm.UserDatabaseRealm"',
                 '             resourceName="UserDatabase"/>',
                 '      <Host name="localhost"  appBase="webapps"',
                 '            unpackWARs="true" autoDeploy="true"',
                 '            xmlValidation="false" xmlNamespaceAware="false">',
                 '      </Host>',
                 '    </Engine>',
                 '  </Service>',
                 '</Server>'
               ].map { |x| x + "\n" }.join
  ssh.sftp.connect do |sftp|
    sftp.file.open("#{apps_home}/tomcat/conf/server.xml", "w") do |f|
      f.write(server_xml)
    end
  end
  ssh.exec!("cd #{apps_home}/tomcat/conf; mv tomcat-users.xml tomcat-users.xml.mstr_backup")
  users_xml = [ "<?xml version='1.0' encoding='utf-8'?>",
                '<tomcat-users>',
                '  <role rolename="admin"/>',
                '  <user username="hostadmin" password="hostadmin385" roles="admin"/>',
                '</tomcat-users>'
              ].map { |x| x + "\n" }.join
  ssh.sftp.connect do |sftp|
    sftp.file.open("#{apps_home}/tomcat/conf/tomcat-users.xml", "w") do |f|
      f.write(users_xml)
    end
  end

  puts "Starting Tomcat"
  ssh.exec!("#{apps_home}/tomcat/tomcat.sh start")

  puts "Done."
end


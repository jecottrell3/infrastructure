# Set keyboard, language and timezone.
keyboard us
lang en_US
timezone --utc Etc/GMT

# Use shadow passwords and MD5.
auth --useshadow --enablemd5

# Disable firstboot.
firstboot --disable

# Disable selinux.
selinux --disabled

# Install the bootloader into the MBR.
bootloader --location=mbr

# Partition the disk.
clearpart --drives=sda --initlabel
part /boot --fstype=ext3 --size=100 --asprimary
part swap --size=10240 --asprimary
part / --fstype=ext3 --size=5120 --asprimary
part /MSTR --fstype=ext3 --size=1 --grow --asprimary

# Network information.
%include /tmp/mstr_network_config

# Install rather than upgrade.
install

# Install from our installation server.
url --url $tree

# If any cobbler repo definitions were referenced in the kickstart profile, include them here.
$yum_repo_stanza

# Skip the installation key.
key --skip

# Set the root password.
rootpw --iscrypted $1$GGoFFa7v$mn4UoL.0IV1w/Gtrvb.3c.

# Do not install X.
skipx

# Install in text mode.
text

# Reboot after the installation.
reboot

%pre
$SNIPPET('log_ks_pre')
$kickstart_start
MSTRHOSTNAME=`cat /proc/cmdline | python -c 'import sys; import re; m = re.search(r"mstrhostname=(\w+)",sys.stdin.readline()); g = m and m.group(1); sys.stdout.write(g or "")'`
if [ -z "$MSTRHOSTNAME" ]; then
  echo >/dev/tty1
  echo >/dev/tty1
  echo >/dev/tty1
  echo "===============================" >/dev/tty1
  echo >/dev/tty1
  echo -n "Enter hostname: " >/dev/tty1
  read MSTRHOSTNAME
fi
# TODO set the correct domain on the machine.
MSTRFQDN="$MSTRHOSTNAME".test.microstrategy.com
MSTRIP=`nslookup "$MSTRFQDN" | grep -A1 "Name:.*$MSTRFQDN" | grep '^Address:[^0-9.]*[0-9.][0-9.]*' | sed 's/^Address:[^0-9.]*\([0-9.][0-9.]*\).*/\1/'`
if [ -z "$MSTRIP" ]; then
  echo >/dev/tty1
  echo >/dev/tty1
  echo "ERROR: Unable to look up host '$MSTRFQDN', please reinstall" >/dev/tty1
  read DUMMY
fi
MSTRGATEWAY=`route -n | awk '/^0.0.0.0/ {print $2}'`
echo "network --bootproto=static --ip='$MSTRIP' --netmask=255.255.255.0 --gateway='$MSTRGATEWAY' --nameserver=10.15.70.11,10.15.70.12 --hostname='$MSTRFQDN'" > /tmp/mstr_network_config
# Enable installation monitoring
$SNIPPET('pre_anamon')

# Packages to install.
%packages
@ Administration Tools
@ Editors
ruby
ruby-libs
koan

%post
$SNIPPET('log_ks_post')
# Start yum configuration
$yum_config_stanza
# End yum configuration
$SNIPPET('post_install_kernel_options')
$SNIPPET('func_register_if_enabled')
$SNIPPET('download_config_files')
$SNIPPET('koan_environment')
# Enable post-install boot notification
$SNIPPET('post_anamon')
# Start final steps
$kickstart_done
# End final steps

# Post installation script.
# TODO: change the ntpdate ip address to our router.
# TODO: before turning on ntpd change the config to point to our routers.
%post
ntpdate 70.86.250.6
hwclock --systohc
rm /root/.bash_logout
rm /etc/skel/.bash_logout
sed -i -e 's/^alias /#alias /' /root/.bashrc
mkdir /root/.ssh
chmod 700 /root/.ssh
wget -O /root/.ssh/authorized_keys http://$http_server/install/authorized_keys
chmod 600 /root/.ssh/authorized_keys
chkconfig bluetooth off
chkconfig firstboot off
chkconfig gpm off
chkconfig iptables off
chkconfig ip6tables off
chkconfig iscsi off
chkconfig iscsid off
chkconfig lvm2-monitor off
chkconfig avahi-daemon off
chkconfig xfs off
chkconfig ntpd on
chkconfig ipmi on


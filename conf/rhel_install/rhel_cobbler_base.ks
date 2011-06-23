# Set keyboard, language and timezone.
keyboard us
lang en_US
timezone --utc Etc/GMT

# Use shadow passwords and MD5.
auth --useshadow --enablemd5

# Disable firstboot.
firstboot --disable

# Set selinux to enabled but non-enforcing
selinux --permissive

# Install the bootloader into the MBR.
bootloader --location=mbr

# Partition information
%include /tmp/diskpart

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
MSTRFQDN="$MSTRHOSTNAME".machine.wisdom.com
MSTRIP=`nslookup "$MSTRFQDN" | grep -A1 "Name:.*$MSTRFQDN" | grep '^Address:[^0-9.]*[0-9.][0-9.]*' | sed 's/^Address:[^0-9.]*\([0-9.][0-9.]*\).*/\1/'`
if [ -z "$MSTRIP" ]; then
  echo >/dev/tty1
  echo >/dev/tty1
  echo "ERROR: Unable to look up host '$MSTRFQDN', please reinstall" >/dev/tty1
  read DUMMY
fi
MSTRGATEWAY=`route -n | awk '/^0.0.0.0/ {print $2}'`
MSTRDNSSERVERS=`awk -v ORS=, '/^nameserver/ {print $2}' /etc/resolv.conf | sed 's/,$//'`
echo "network --bootproto=static --ip='$MSTRIP' --netmask=255.255.255.0 --gateway='$MSTRGATEWAY' --nameserver=$MSTRDNSSERVERS --hostname='$MSTRFQDN'" > /tmp/mstr_network_config
# Build the RAID volumes if needed
/usr/bin/wget -O /tmp/MegaCli64 http://install1-bdc.infra.wisdom.com/install/megacli/MegaCli64
/usr/bin/chmod 755 /tmp/MegaCli64
DRIVECOUNT=`/tmp/MegaCli64 -EncInfo -a0 | /usr/bin/grep -m1 "Number of Physical Drives" | /usr/bin/awk '{print $6}'`
if [ $DRIVECOUNT -eq 24 ] ; then
  /tmp/MegaCli64 -CfgSpanAdd -R10 -Array0[24:0,24:1,24:2,24:3] -Array1[24:4,24:5,24:6,24:7] -Array2[24:8,24:9,24:10,24:11] -Array3[24:12,24:13,24:14,24:15] -Array4[24:16,24:17,24:18,24:19] -Array5[24:20,24:21,24:22,24:23] -sz100 -a0
  /tmp/MegaCli64 -CfgSpanAdd -R10 -Array0[24:0,24:1,24:2,24:3] -Array1[24:4,24:5,24:6,24:7] -Array2[24:8,24:9,24:10,24:11] -Array3[24:12,24:13,24:14,24:15] -Array4[24:16,24:17,24:18,24:19] -Array5[24:20,24:21,24:22,24:23] -afterLd0 -a0
elif [ $DRIVECOUNT -eq 12 ] ; then
  /tmp/MegaCli64 -CfgLdAdd -R6[12:0,12:1,12:2,12:3,12:4,12:5,12:6,12:7,12:8,12:9,12:10,12:11] -sz100 -a0
  /tmp/MegaCli64 -CfgLdAdd -R6[12:0,12:1,12:2,12:3,12:4,12:5,12:6,12:7,12:8,12:9,12:10,12:11] -afterLd0 -a0
elif [ $DRIVECOUNT -eq 16 ] ; then
  /tmp/MegaCli64 -CfgSpanAdd -R10 -Array0[32:0,32:1] -Array1[32:2,32:3] -Array2[32:4,32:5] -Array3[32:6,32:7] -Array4[32:8,32:9] -Array5[32:10,32:11] -Array6[32:12,32:13] -Array7[32:14,32:15] -sz100 -a0
  /tmp/MegaCli64 -CfgSpanAdd -R10 -Array0[32:0,32:1] -Array1[32:2,32:3] -Array2[32:4,32:5] -Array3[32:6,32:7] -Array4[32:8,32:9] -Array5[32:10,32:11] -Array6[32:12,32:13] -Array7[32:14,32:15] -afterLd0 -a0
elif [ $DRIVECOUNT -eq 6 ] ; then
  /tmp/MegaCli64 -CfgSpanAdd -R10 -Array0[32:0,32:1] -Array1[32:2,32:3] -Array2[32:4,32:5] -sz100 -a0
  /tmp/MegaCli64 -CfgSpanAdd -R10 -Array0[32:0,32:1] -Array1[32:2,32:3] -Array2[32:4,32:5] -afterLd0 -a0
fi
  
  
# Determine Drive Configuration
if [ -b /dev/sdb ] ; then
  echo "clearpart --drives=sda,sdb --all --initlabel" > /tmp/diskpart
  echo "part /boot --ondisk=sda --fstype=ext3 --size=1 --grow --asprimary" >> /tmp/diskpart
  echo "part swap --ondisk=sdb --size=10240 --asprimary" >> /tmp/diskpart
  echo "part / --ondisk=sdb --fstype=ext3 --size=5120 --asprimary" >> /tmp/diskpart
  echo "part /MSTR --ondisk=sdb --fstype=ext3 --size=1 --grow --asprimary" >> /tmp/diskpart
else
  echo "clearpart --drives=sda --all --initlabel" > /tmp/diskpart
  echo "part /boot --ondisk=sda --fstype=ext3 --size=100 --asprimary" >> /tmp/diskpart
  echo "part swap --ondisk=sda --size=10240 --asprimary" >> /tmp/diskpart
  echo "part / --ondisk=sda --fstype=ext3 --size=5120 --asprimary" >> /tmp/diskpart
  echo "part /MSTR --ondisk=sda --fstype=ext3 --size=1 --grow --asprimary" >> /tmp/diskpart
fi

# Enable installation monitoring
$SNIPPET('pre_anamon')

# Packages to install.
%packages
@ Administration Tools
@ Editors
ruby
ruby-libs
koan
sysstat
pstack
strace
net-snmp
screen

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
%post
sed -i -e 's/^server 0.rhel.pool.ntp.org/server ntp1.infra.wisdom.com/' /etc/ntp.conf
sed -i -e 's/^server 1.rhel.pool.ntp.org/server ntp2.infra.wisdom.com/' /etc/ntp.conf
sed -i -e '/^server 2.rhel.pool.ntp.org/d' /etc/ntp.conf
ntpdate ntp1.infra.wisdom.com
hwclock --systohc
CONFIGURED_ETH=`grep -l IPADDR /etc/sysconfig/network-scripts/ifcfg-eth* | head -1`
sed -e '/^#/d' -e 's/DEVICE=eth.*/DEVICE=bond0/' -e '/^HWADDR/d' $CONFIGURED_ETH > /etc/sysconfig/network-scripts/ifcfg-bond0
sed -i -e '/^#\|DEVICE\|HWADDR/!d' $CONFIGURED_ETH
sed -i -e '/^#\|DEVICE\|HWADDR/!d' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e '/^#\|DEVICE\|HWADDR/!d' /etc/sysconfig/network-scripts/ifcfg-eth1
echo "BOOTPROTO=none" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "BOOTPROTO=none" >> /etc/sysconfig/network-scripts/ifcfg-eth1
echo "ONBOOT=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "ONBOOT=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth1
echo "MASTER=bond0" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "MASTER=bond0" >> /etc/sysconfig/network-scripts/ifcfg-eth1
echo "SLAVE=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "SLAVE=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth1
echo "alias bond0 bonding" >> /etc/modprobe.conf
echo "options bonding mode=802.3ad" >> /etc/modprobe.conf
mv /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.mstr_orig
DATACENTER=`awk -F= '/^IPADDR/ {if($2~/^10\.20\./) {print "adc"} else if($2~/^10\.140\./) {print "bdc"}}' /etc/sysconfig/network-scripts/ifcfg-bond0`
echo "rocommunity machine nms1-$DATACENTER.infra.wisdom.com" > /etc/snmp/snmpd.conf
echo "rocommunity machine nms2-$DATACENTER.infra.wisdom.com" >> /etc/snmp/snmpd.conf
echo "rocommunity machine nms3-$DATACENTER.infra.wisdom.com" >> /etc/snmp/snmpd.conf
echo "sysLocation `echo $DATACENTER |tr a-z A-Z`" >> /etc/snmp/snmpd.conf
sed -i -e "s/^# OPTIONS=/OPTIONS=/" -e "s/-Lsd/-LS 0-4 d/" /etc/sysconfig/snmpd.options
sed -i -e 's/^search.*/search machine.wisdom.com/' /etc/resolv.conf
sed -i -e 's/^defscrollback.*/defscrollback 8192/' /etc/screenrc
echo "bind s" >> /etc/screenrc
rm /root/.bash_logout
rm /etc/skel/.bash_logout
sed -i -e 's/^alias /#alias /' /root/.bashrc
sed -i -e 's/^HISTORY=.*/HISTORY=30/' /etc/sysconfig/sysstat
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
chkconfig snmpd on


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
# Build the RAID volumes if needed
/usr/bin/wget -O /tmp/MegaCli64 http://$http_server/install/megacli/MegaCli64
/usr/bin/chmod 755 /tmp/MegaCli64
/usr/bin/wget -O /libsysfs.tar.gz http://$http_server/install/megacli/libsysfs.tar.gz
cd /; /usr/bin/tar zxvf /libsysfs.tar.gz
BOOTVOLNAME=`/tmp/MegaCli64 -LDInfo -l0 -a0 | /usr/bin/grep "Name" | head -1 |  /usr/bin/cut -d: -f2`
if [ "$BOOTVOLNAME" != "MSTRBoot" ] ; then
  DRIVECOUNT=`/tmp/MegaCli64 -EncInfo -a0 | /usr/bin/grep "Number of Physical Drives" | head -1 |  /usr/bin/awk '{print $6}'`
  ENCID=`/tmp/MegaCli64 -EncInfo -a0 | /usr/bin/grep "Device ID" | head -1 |  /usr/bin/awk '{print $4}'`
  if [ $DRIVECOUNT -eq 24 ] ; then
    /tmp/MegaCli64 -CfgClr -a0
    /tmp/MegaCli64 -CfgSpanAdd -R10 -Array0[${ENCID}:0,${ENCID}:1,${ENCID}:2,${ENCID}:3] -Array1[${ENCID}:4,${ENCID}:5,${ENCID}:6,${ENCID}:7] -Array2[${ENCID}:8,${ENCID}:9,${ENCID}:10,${ENCID}:11] -Array3[${ENCID}:12,${ENCID}:13,${ENCID}:14,${ENCID}:15] -Array4[${ENCID}:16,${ENCID}:17,${ENCID}:18,${ENCID}:19] -Array5[${ENCID}:20,${ENCID}:21,${ENCID}:22,${ENCID}:23] -sz100 -a0
    /tmp/MegaCli64 -CfgSpanAdd -R10 -Array0[${ENCID}:0,${ENCID}:1,${ENCID}:2,${ENCID}:3] -Array1[${ENCID}:4,${ENCID}:5,${ENCID}:6,${ENCID}:7] -Array2[${ENCID}:8,${ENCID}:9,${ENCID}:10,${ENCID}:11] -Array3[${ENCID}:12,${ENCID}:13,${ENCID}:14,${ENCID}:15] -Array4[${ENCID}:16,${ENCID}:17,${ENCID}:18,${ENCID}:19] -Array5[${ENCID}:20,${ENCID}:21,${ENCID}:22,${ENCID}:23] -afterLd0 -a0
    /tmp/MegaCli64 -LDSetProp -Name MSTRBoot -l0 -a0
    /tmp/MegaCli64 -LDSetProp -Name MSTRData -l1 -a0
    /usr/bin/mknod /dev/sda b 8 0
    /usr/bin/mknod /dev/sdb b 8 16
    reboot
  elif [ $DRIVECOUNT -eq 12 ] ; then
    /tmp/MegaCli64 -CfgClr -a0
    /tmp/MegaCli64 -CfgLdAdd -R6[${ENCID}:0,${ENCID}:1,${ENCID}:2,${ENCID}:3,${ENCID}:4,${ENCID}:5,${ENCID}:6,${ENCID}:7,${ENCID}:8,${ENCID}:9,${ENCID}:10,${ENCID}:11] -sz100 -a0
    /tmp/MegaCli64 -CfgLdAdd -R6[${ENCID}:0,${ENCID}:1,${ENCID}:2,${ENCID}:3,${ENCID}:4,${ENCID}:5,${ENCID}:6,${ENCID}:7,${ENCID}:8,${ENCID}:9,${ENCID}:10,${ENCID}:11] -afterLd0 -a0
    /tmp/MegaCli64 -LDSetProp -Name MSTRBoot -l0 -a0
    /tmp/MegaCli64 -LDSetProp -Name MSTRData -l1 -a0
    /usr/bin/mknod /dev/sda b 8 0
    /usr/bin/mknod /dev/sdb b 8 16
    reboot
  elif [ $DRIVECOUNT -eq 16 ] ; then
    /tmp/MegaCli64 -CfgClr -a0
    /tmp/MegaCli64 -CfgSpanAdd -R10 -Array0[${ENCID}:0,${ENCID}:1] -Array1[${ENCID}:2,${ENCID}:3] -Array2[${ENCID}:4,${ENCID}:5] -Array3[${ENCID}:6,${ENCID}:7] -Array4[${ENCID}:8,${ENCID}:9] -Array5[${ENCID}:10,${ENCID}:11] -Array6[${ENCID}:12,${ENCID}:13] -Array7[${ENCID}:14,${ENCID}:15] -sz100 -a0
    /tmp/MegaCli64 -CfgSpanAdd -R10 -Array0[${ENCID}:0,${ENCID}:1] -Array1[${ENCID}:2,${ENCID}:3] -Array2[${ENCID}:4,${ENCID}:5] -Array3[${ENCID}:6,${ENCID}:7] -Array4[${ENCID}:8,${ENCID}:9] -Array5[${ENCID}:10,${ENCID}:11] -Array6[${ENCID}:12,${ENCID}:13] -Array7[${ENCID}:14,${ENCID}:15] -afterLd0 -a0
    /tmp/MegaCli64 -LDSetProp -Name MSTRBoot -l0 -a0
    /tmp/MegaCli64 -LDSetProp -Name MSTRData -l1 -a0
    /usr/bin/mknod /dev/sda b 8 0
    /usr/bin/mknod /dev/sdb b 8 16
    reboot
  elif [ $DRIVECOUNT -eq 6 ] ; then
    /tmp/MegaCli64 -CfgClr -a0
    /tmp/MegaCli64 -CfgSpanAdd -R10 -Array0[${ENCID}:0,${ENCID}:1] -Array1[${ENCID}:2,${ENCID}:3] -Array2[${ENCID}:4,${ENCID}:5] -sz100 -a0
    /tmp/MegaCli64 -CfgSpanAdd -R10 -Array0[${ENCID}:0,${ENCID}:1] -Array1[${ENCID}:2,${ENCID}:3] -Array2[${ENCID}:4,${ENCID}:5] -afterLd0 -a0
    /tmp/MegaCli64 -LDSetProp -Name MSTRBoot -l0 -a0
    /tmp/MegaCli64 -LDSetProp -Name MSTRData -l1 -a0
    /usr/bin/mknod /dev/sda b 8 0
    /usr/bin/mknod /dev/sdb b 8 16
    reboot
  fi
fi

# Get the hostname, and set some network info
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
wget -O /root/OM-SrvAdmin-Dell-Web-LX-6.5.0-2247.RHEL5.x86_64_A01.4.tar.gz http://$http_server/install/OpenManage/OM-SrvAdmin-Dell-Web-LX-6.5.0-2247.RHEL5.x86_64_A01.4.tar.gz
mkdir /tmp/OpenManage
tar zxf /root/OM-SrvAdmin-Dell-Web-LX-6.5.0-2247.RHEL5.x86_64_A01.4.tar.gz -C /tmp/OpenManage
/root/OpenManage/linux/supportscripts/srvadmin-install.sh –x –a 
rm -rf /tmp/OpenManage
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


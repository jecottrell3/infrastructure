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
clearpart --drives=sda,sdb --all --initlabel
part /boot --ondisk=sda --fstype=ext3 --size=1 --grow --asprimary
part swap --ondisk=sdb --size=10240 --asprimary
part / --ondisk=sdb --fstype=ext3 --size=5120 --asprimary
part /MSTR --ondisk=sdb --fstype=ext3 --size=1 --grow --asprimary

#network --bootproto=static --ip=10.0.2.15 --netmask=255.255.240.0 --gateway=10.0.2.254 --nameserver=10.15.70.11,10.15.17.12 --hostname=tester123
network --bootproto=static --ip=192.168.131.128 --netmask=255.255.255.0 --gateway=192.168.131.2 --nameserver=10.15.70.11,10.15.70.12 --hostname=testvm01

# Install rather than upgrade.
install

# Install from our installation server.
#url --url http://install.appcloud.microstrategy.com/rhel/foo/bar
url --url http://10.22.9.100/RHEL56

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


# Post installation script.
%post
sed -i -e 's/^server 0.rhel.pool.ntp.org/server ntp.infra.wisdom.com/' /etc/ntp.conf
sed -i -e '/^server 1.rhel.pool.ntp.org/d' /etc/ntp.conf
sed -i -e '/^server 2.rhel.pool.ntp.org/d' /etc/ntp.conf
ntpdate ntp.infra.wisdom.com
hwclock --systohc
rm /root/.bash_logout
rm /etc/skel/.bash_logout
sed -i -e 's/^alias /#alias /' /root/.bashrc
sed -i -e 's/^HISTORY=.*/HISTORY=30/' /etc/sysconfig/sysstat
mkdir /root/.ssh
chmod 700 /root/.ssh
wget -O /root/.ssh/authorized_keys http://10.22.9.100/~ggabriel/authorized_keys
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


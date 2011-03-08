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

#network --bootproto=static --ip=10.0.2.15 --netmask=255.255.240.0 --gateway=10.0.2.254 --nameserver=10.15.70.11,10.15.17.12 --hostname=tester123
#network --bootproto=static --ip=10.15.73.58 --netmask=255.255.240.0 --gateway=10.15.64.1 --nameserver=10.15.70.11,10.15.70.12 --hostname=tester123
network --bootproto=dhcp

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


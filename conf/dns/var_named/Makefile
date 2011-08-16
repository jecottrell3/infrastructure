# Push data to all Nameservers, then Reload.
# Includes Self, so it works Anywhere.
#
# git doesn't preserve mtime, so use rsync -c

W=ns1-adc.infra.wisdom.com
X=ns2-adc.infra.wisdom.com
Y=ns1-bdc.infra.wisdom.com
Z=ns2-bdc.infra.wisdom.com

D=/var/named/chroot/var/named

all:	push kick

show:
	rsync -van -c --exclude data . root@$W:$D
	rsync -van -c --exclude data . root@$X:$D
#	ns1-bdc temporarily broken
#	rsync -van -c --exclude data . root@$Y:$D
	rsync -van -c --exclude data . root@$Z:$D

pull:
	rsync -vax -c --exclude data -u root@$W:$D .

push:
	rsync -vax -c --exclude data . root@$W:$D
	rsync -vax -c --exclude data . root@$X:$D
#	ns1-bdc temporarily broken
#	rsync -vax -c --exclude data . root@$Y:$D
	rsync -vax -c --exclude data . root@$Z:$D

kick:
	ssh -A root@$W rndc reload
	ssh -A root@$X rndc reload
#	ns1-bdc temporarily broken
#	ssh -A root@$Y rndc reload
	ssh -A root@$Z rndc reload

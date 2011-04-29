#!/bin/sh

# This script should run as user git on git.infra.wisdom.com.
# Back up all git repositories to git-backup.infra.wisdom.com.
#
# Gary Gabriel <ggabriel@microstrategy.com>

GIT_HOME=/MSTR/git-repos
BACKUP_HOST=git-backup.infra.wisdom.com

for REPO in `ls -1d $GIT_HOME/*.git`; do
  ssh git@"$BACKUP_HOST" sh -c "'mkdir -p $REPO; cd $REPO; git rev-parse --git-dir || git init --bare'" &>/dev/null
  cd $REPO
  git push --mirror ssh://git@"${BACKUP_HOST}${REPO}" &>/dev/null
done


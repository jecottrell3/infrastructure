#!/bin/sh

# This script should run as user git on git.infra.wisdom.com.
# Back up all git repositories to git-backup.infra.wisdom.com.
#
# Gary Gabriel <ggabriel@microstrategy.com>

GIT_HOME=/MSTR/git-repos
BACKUP_HOST=git-backup.infra.wisdom.com

for REPO in `ls -1 $GIT_HOME`; do
  RHOME="$GIT_HOME"/"$REPO"
  ssh git@"$BACKUP_HOST" sh -c "'mkdir -p $RHOME; cd $RHOME; git rev-parse --git-dir || git init --bare'" &>/dev/null
  cd $RHOME
  git push --mirror ssh://git@"${BACKUP_HOST}${RHOME}" &>/dev/null
done


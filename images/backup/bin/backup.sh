#!/bin/bash
set -e
. /root/backup_env
url=$BACKUP_HOSTNAME
interval=$1
remote_root_dir=magnolia
LFTP_PASSWORD=$BACKUP_PASSWORD

mkdir -p $HOME/.ssh
chmod 0700 $HOME/.ssh
touch $HOME/.ssh/known_hosts
chmod 0600 $HOME/.ssh/known_hosts
ssh-keyscan -t rsa $BACKUP_HOSTNAME >> ~/.ssh/known_hosts

function remote_exec {
  echo "remotely executing: $1"
  lftp sftp://${url} -u $BACKUP_USERNAME,$BACKUP_PASSWORD -e "$1; bye"
}

function create_dir_if_needed {
  remote_exec "cd $1 || mkdir $1"
}

function purge_stale_backups {
  output=`remote_exec "cls --sort=date /$remote_root_dir/$PROJECT_PREFIX/$1/"`
  stale_date=$(date -d "-$2 00:00:00" +%s)

  echo "$output" | while IFS= read -r line ; do
    if [[ ! "$line" =~ ^sftp ]] && [[ "$line" =~ (/$remote_root_dir/$PROJECT_PREFIX/$1/${PROJECT_PREFIX}-([0-9]+).tar.gz)$ ]]; then
      date=`date -d "${BASH_REMATCH[2]}" +%s`
      file_path=${BASH_REMATCH[1]}

      if [[ ${date} < ${stale_date} ]]; then
        remote_exec "rm -f $file_path"
      else 
        echo "Keeping $file_path (${date} > ${stale_date})"
      fi
    fi
  done
}

if [[ "$interval" != "daily" ]] && [[ "$interval" != "weekly" ]]; then
  echo "Usage: $0 daily|weekly"
  exit 1
fi

if [ -z "${PROJECT_PREFIX}" ]; then
  echo "Project prefix is not set!"
  exit 1
fi

if [ -z "${DELAY}" ]; then
  DELAY=$[ ( $RANDOM % 120 )  + 1 ]
fi

echo "Will start $interval backup in $DELAY minutes"
sleep ${DELAY}m
echo "Starting backup"

create_dir_if_needed "$remote_root_dir"
create_dir_if_needed "$remote_root_dir/$PROJECT_PREFIX"
create_dir_if_needed "$remote_root_dir/$PROJECT_PREFIX/$interval"

filename=${PROJECT_PREFIX}-$(date +%Y%m%d)
latest_filename=${PROJECT_PREFIX}-latest.tar.gz
source_path_dir=/backups/$filename
source_path=${source_path_dir}.tar.gz
dest_path=/$remote_root_dir/${PROJECT_PREFIX}/${interval}/${filename}.tar.gz
latest_dest_path=/$remote_root_dir/${PROJECT_PREFIX}/${latest_filename}
cmd="curl \
  -X POST \
  -H \"Content-Type: application/json\" \
  http://magnolia:8080/.rest/commands/v2/backup/backup \
  --data \
  '{ 
    \"repositoryPath\": \"/home/tomcat/magnolia_tmp/repositories\", \
    \"configurationPath\": \"/usr/local/tomcat/webapps/ROOT/WEB-INF/config/repo-conf/author.xml\", \
    \"backupLocation\": \"${source_path_dir}\", \
    \"maxRetries\": 3 \
  }'"

if [ -z "$MAGNOLIA_SUPERUSER_PASSWORD" ]; then
  MAGNOLIA_SUPERUSER_PASSWORD=superuser
fi

cmd="$cmd -u superuser:$MAGNOLIA_SUPERUSER_PASSWORD"
eval $cmd

cd $source_path_dir
tar -czf ${source_path} *
cd - &>/dev/null

if [ $? -ne 0 ]; then
    echo "Backup failed: curl returned non-zero exit code" >&2
    exit 1
fi

remote_exec "put -e ${source_path} -o ${dest_path}"
remote_exec "rm -f $latest_dest_path"
remote_exec "ln -s $dest_path $latest_dest_path"

if [[ "$interval" == "daily" ]]; then
  purge_stale_backups daily "7 day"
else
  purge_stale_backups weekly "1 month"
fi

if [ -f ${source_path} ]; then
  rm ${source_path}
fi

echo "Backup finished successfully"
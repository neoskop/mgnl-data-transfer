#!/bin/bash
if [ -z "$PROJECT_PREFIX" ]; then
  echo "\$PROJECT_PREFIX must be set!" >&2
  exit 1
fi

env | egrep '^(BACKUP_|PROJECT_|MAGNOLIA_|DELAY)' > /root/backup_env
exec $@
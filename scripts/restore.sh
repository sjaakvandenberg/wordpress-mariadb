#!/bin/sh
if [ -z "$1" ]; then
  echo "Usage: restore BACKUP.sql"
fi

if [ -e "$1" ]; then
  mysql \
  --user=$MYSQL_USER \
  --password=$MYSQL_PASSWORD \
  $MYSQL_DATABASE < $1
  echo "Database backup $1 restored."
else
  echo "$1 not found."
fi

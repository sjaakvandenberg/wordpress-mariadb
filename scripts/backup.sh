#!/bin/sh
TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="/backup"

mysqldump \
--user=$MYSQL_USER \
--password=$MYSQL_PASSWORD \
$MYSQL_DATABASE > "$BACKUP_DIR/$MYSQL_DATABASE-$TIMESTAMP.sql"

echo "Database backed up as /backup/$MYSQL_DATABASE-$TIMESTAMP.sql"

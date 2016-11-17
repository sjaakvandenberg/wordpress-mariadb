#!/bin/sh

# Rename scripts
for script in /usr/local/bin/*.sh; do
  mv -f "$script" "${script%.sh}";
done

set -o pipefail
set -o xtrace
set -o verbose

DATA_DIR="$(mysqld --verbose --help --log-bin-index=`mktemp -u` 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"
PID_FILE=/run/mysqld/mysqld.pid

if [ ! -d "$DATA_DIR/mysql" ]; then
  if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
    echo >&2 'error: database is uninitialized and password option is not specified '
    echo >&2 'You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
    exit 1
  fi

  mkdir -p "$DATA_DIR"
  chown -R mysql:mysql "$DATA_DIR"

  echo 'Initializing database'
  mysql_install_db --user=mysql --datadir="$DATA_DIR" --rpm > /dev/null 2>&1
  echo 'Database initialized'

  mysqld_safe --pid-file=$PID_FILE --skip-networking --nowatch > /dev/null 2>&1

  mysql_options='--protocol=socket -uroot'

  for i in `seq 30 -1 0`; do
    # if mysql $mysql_options -e 'SELECT 1' &> /dev/null; then
    if mysql $mysql_options -e 'SELECT 1'; then
      break
    fi
    echo 'MySQL init process in progress...'
    sleep 1
  done
  if [ "$i" = 0 ]; then
    echo >&2 'MySQL init process failed.'
    exit 1
  fi

  if [ -z "$MYSQL_INITDB_SKIP_TZINFO" ]; then
    apk add --update-cache tzdata
    # sed is for https://bugs.mysql.com/bug.php?id=20545
    mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/FCTY/' | mysql $mysql_options mysql
  fi

  if [ ! -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
    MYSQL_ROOT_PASSWORD="$(/dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-10})"
    echo "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
  fi

  mysql $mysql_options <<-EOSQL
    -- What's done in this file shouldn't be replicated
    --  or products like mysql-fabric won't work
    SET @@SESSION.SQL_LOG_BIN=0;
    DELETE FROM mysql.user ;
    CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
    GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
    DROP DATABASE IF EXISTS test ;
    FLUSH PRIVILEGES ;
EOSQL

  if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
    mysql_options="$mysql_options -p${MYSQL_ROOT_PASSWORD}"
  fi

  if [ "$MYSQL_DATABASE" ]; then
    mysql $mysql_options -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;"
    mysql_options="$mysql_options $MYSQL_DATABASE"
  fi

  if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
    mysql $mysql_options -e "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;"

    if [ "$MYSQL_DATABASE" ]; then
      mysql $mysql_options -e "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;"
    fi

    mysql $mysql_options 'FLUSH PRIVILEGES ;' > /dev/null 2>&1
  fi

  pid="`cat $PID_FILE`"
  if ! kill -s TERM "$pid"; then
    echo >&2 'MySQL init process failed.'
    exit 1
  fi

  sleep 2

  echo
  echo "MySQL init process done. Ready for start up."
  echo

fi

uname -a
mysql --version
echo
echo "MariaDB       : $(getent hosts mysql | awk '{print $1}')"
echo "Redis         : $(getent hosts redis | awk '{print $1}')"
echo "PHP-FPM       : $(getent hosts php-fpm | awk '{print $1}')"
echo "Adminer       : $(getent hosts adminer | awk '{print $1}')"
echo "Nginx         : $(getent hosts nginx | awk '{print $1}')"
echo
echo "IP address    : $(hostname -i)"
echo "Port          : $MYSQL_PORT"
echo "Mount         : $MYSQL_MOUNT"
echo "Pid file      : $PID_FILE"
echo "Data dir      : $DATA_DIR"
echo "Database      : $MYSQL_DATABASE"
echo "Root password : $MYSQL_ROOT_PASSWORD"
echo "User          : $MYSQL_USER"
echo "Password      : $MYSQL_PASSWORD"
echo
echo "Tools"
echo "----------------------------------------"
echo "backups       List backups in /backup/"
echo "backup        Make backup of wp-content"
echo "restore FILE  Restore database backup"
echo

exec mysqld_safe --pid-file=$PID_FILE "$@"

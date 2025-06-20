#!/usr/bin/env bash
set -e

USER_PASSWORD="$(<"$MYSQL_PASSWORD_FILE")"
ROOT_PASSWORD="$(<"$MYSQL_ROOT_PASSWORD_FILE")"

trap "kill $child_pid; wait $child_pid; exit 0" TERM INT

mysqld --user=mysql --skip-networking &
child_pid="$!"

until [ -S /var/run/mysqld/mysqld.sock ]; do sleep 0.1; done

if [ ! -f /var/lib/mysql/.initialized ]; then
  mysql -uroot -p"${ROOT_PASSWORD}" <<EOSQL
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${USER_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL

  mysql -uroot -p"${ROOT_PASSWORD}" <<EOSQL
    DROP USER IF EXISTS ''@'localhost', ''@'%';
    DROP USER IF EXISTS 'root'@'%';
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASSWORD}';
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db LIKE 'test\\_%';
    FLUSH PRIVILEGES;
EOSQL
  touch /var/lib/mysql/.initialized
else
  echo "[INFO] Data base is already initialized"
fi

kill "$child_pid"
wait "$child_pid"

exec "$@"

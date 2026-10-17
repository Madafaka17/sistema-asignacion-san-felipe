#!/bin/bash
# Se ejecuta una sola vez al crear el volumen de MySQL (docker-entrypoint-initdb.d):
# crea la base de las pruebas de aceptación del servidor, <DB_NAME>_pruebas,
# y da permisos sobre ella al usuario de la aplicación. Las pruebas borran y
# recrean sus tablas, por eso usan una base aparte.
set -euo pipefail
mysql --protocol=socket -uroot -p"${MYSQL_ROOT_PASSWORD}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}_pruebas\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}_pruebas\`.* TO '${MYSQL_USER}'@'%';
SQL

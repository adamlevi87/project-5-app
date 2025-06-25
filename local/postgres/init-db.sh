#!/bin/sh
envsubst < /docker-entrypoint-initdb.d/init-db.template.sql > /docker-entrypoint-initdb.d/init-db.sql
exec "$@"
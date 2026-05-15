#!/bin/sh
set -e

MNEMA_HOME="${MNEMA_HOME:-/app/.mnema}"

chown -R mnema:mnema "$MNEMA_HOME"

if [ "$1" = "init" ]; then

  mkdir -p "$MNEMA_HOME/config"

  if [ ! -f "$MNEMA_HOME/docker-compose.yml" ]; then
    cp /app/docker-compose.yml "$MNEMA_HOME/docker-compose.yml"
    echo "compose file written"
  else
    echo "compose file already present, skipping"
  fi

  if [ ! -f "$MNEMA_HOME/.env" ]; then
    MONGO_PASS=$(node -e "process.stdout.write(require('crypto').randomBytes(24).toString('base64').replace(/[\/+=]/g,'').slice(0,32))")
    printf 'MONGO_INITDB_ROOT_USERNAME=mnema\nMONGO_INITDB_ROOT_PASSWORD=%s\nMNEMA_PORT=5757\n' \
      "$MONGO_PASS" > "$MNEMA_HOME/.env"
    chmod 600 "$MNEMA_HOME/.env"
    echo "credentials written"
  else
    echo "credentials already present, skipping"
  fi

  exit 0
fi

exec gosu mnema "$@"
#!/bin/sh
set -e

chown -R mnema:mnema /app/.mnema
exec gosu mnema "$@"
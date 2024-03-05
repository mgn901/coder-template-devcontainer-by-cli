#!/bin/sh
set -xe

IS_COMPOSE=`cat "/workspaces/$1/$2" | node /tmp/coder-devcontainer-builder/is_compose_based.js | tr -d '\n'`
if [ "$IS_COMPOSE" = "true" ]; then
  docker compose -p "${1}_devcontainer" down
else
  docker container rm "${1}_devcontainer"
fi

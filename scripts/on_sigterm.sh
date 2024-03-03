#!/bin/sh
set -xe
cd "/workspaces/$1"

IS_COMPOSE=`cat "workspaces/$1/$2" | node /tmp/coder-devcontainer-builder/is_compose_based.js | tr '\n' ''`
if [ "$IS_COMPOSE" = "true" ]; then
  docker compose -p "coder-$3" down
else
  docker container rm "coder-$3"
fi

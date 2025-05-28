#!/bin/sh

set -e

## environments used ##
# DOCKER_REGISTRY_HOSTNAME
# DOCKER_REGISTRY_USERNAME
# DOCKER_REGISTRY_PASSWORD

if [ ! `docker stats --no-stream` ]; then
  dockerd > /tmp/dockerd.log 2>&1 &

  while [ ! `docker stats --no-stream` ]; do
    # Docker takes a few seconds to initialize
    echo "Waiting for Docker to launch..."
    sleep 1
  done
fi

# Login to docker registry
docker login $DOCKER_REGISTRY_HOSTNAME -u $DOCKER_REGISTRY_USERNAME -p $DOCKER_REGISTRY_PASSWORD

exit 0

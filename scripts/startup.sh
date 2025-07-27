#!/bin/sh

set -e

## environments used ##
# CODER_TEMPLATE_NAMESERVER
# DOCKER_REGISTRY_HOSTNAME
# DOCKER_REGISTRY_USERNAME
# DOCKER_REGISTRY_PASSWORD

# Docker and BuildKit settings
mkdir -p /etc/docker

echo "nameserver $CODER_TEMPLATE_NAMESERVER
search .
options ndots:0
" > /etc/resolv.conf

echo "{
  \"dns\": [\"$CODER_TEMPLATE_NAMESERVER\"],
  \"features\": {
    \"buildkit\": true
  },
  \"registry-mirrors\": [
    "https://hub.$DOCKER_REGISTRY_HOSTNAME"
  ]
}
" > /etc/docker/daemon.json

mkdir -p /tmp/buildkitd-toml

echo "[registry.\"ghcr.io\"]
  mirrors = [\"ghcr.$DOCKER_REGISTRY_HOSTNAME\"]

[registry.\"docker.io\"]
  mirrors = [\"hub.$DOCKER_REGISTRY_HOSTNAME\"]

[registry.\"mcr.microsoft.com\"]
  mirrors = [\"mcr.$DOCKER_REGISTRY_HOSTNAME\"]

[dns]
  nameservers=[\"$CODER_TEMPLATE_NAMESERVER\"]
  options=[\"edns0\"]
" > /tmp/buildkitd-toml/buildkitd.toml

if [ ! `docker stats --no-stream` ]; then
  dockerd --config-file /etc/docker/daemon.json > /tmp/dockerd.log 2>&1 &

  while [ ! `docker stats --no-stream` ]; do
    # Docker takes a few seconds to initialize
    echo "Waiting for Docker to launch..."
    sleep 1
  done
fi

# Login to docker registry
docker login https://$DOCKER_REGISTRY_HOSTNAME -u $DOCKER_REGISTRY_USERNAME -p $DOCKER_REGISTRY_PASSWORD
docker login https://hub.$DOCKER_REGISTRY_HOSTNAME -u $DOCKER_REGISTRY_USERNAME -p $DOCKER_REGISTRY_PASSWORD
docker login https://mcr.$DOCKER_REGISTRY_HOSTNAME -u $DOCKER_REGISTRY_USERNAME -p $DOCKER_REGISTRY_PASSWORD
docker login https://ghcr.$DOCKER_REGISTRY_HOSTNAME -u $DOCKER_REGISTRY_USERNAME -p $DOCKER_REGISTRY_PASSWORD

# Create buildx instance
docker buildx create --use --bootstrap --name devcontainer-builder --driver docker-container --config /tmp/buildkitd-toml/buildkitd.toml 

# Change owner of files under /workspaces
chown -R 1000 /workspaces
chgrp -R 1000 /workspaces

exit 0

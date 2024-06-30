#!/bin/sh

set -xe
unset DOCKER_HOST

## environments used ##
# DOCKER_REGISTRY_HOSTNAME
# DOCKER_REGISTRY_USERNAME
# DOCKER_REGISTRY_PASSWORD
# WORKSPACE_NAME
# REPO_OWNER_NAME
# REPO_NAME
# BRANCH_NAME
# GITHUB_AUTHENTICATION_TOKEN
# CONFIG_PATH
# WORKSPACE_AGENT_TOKEN
# WORKSPACE_AGENT_SCRIPT

if [ ! `docker stats --no-stream` ]; then
  dockerd &

  while [ ! `docker stats --no-stream` ]; do
    # Docker takes a few seconds to initialize
    echo "Waiting for Docker to launch..."
    sleep 1
  done
fi

# Login to docker registry
docker login $DOCKER_REGISTRY_HOSTNAME -u $DOCKER_REGISTRY_USERNAME -p $DOCKER_REGISTRY_PASSWORD

# Create directories for workspaces.
mkdir -p /workspaces

# Create temporary resources.
mkdir -p /tmp/coder-devcontainer-builder

cat <<EOF0 > /tmp/coder-devcontainer-builder/on_devcontainer_start_banner.sh
  #!/bin/sh
  export CODER_AGENT_TOKEN=$WORKSPACE_AGENT_TOKEN

EOF0

cat <<EOF0 > /tmp/coder-devcontainer-builder/on_devcontainer_start.sh
  `echo "$WORKSPACE_AGENT_SCRIPT"`
EOF0

# Clone workspace repository (if not exists)
if [ ! -e "/workspaces/$WORKSPACE_NAME" ]
then
  git clone --branch $BRANCH_NAME --depth 1 "https://$GITHUB_AUTHENTICATION_TOKEN@github.com/$REPO_OWNER_NAME/$REPO_NAME.git" "/workspaces/$WORKSPACE_NAME"
  cd "/workspaces/$WORKSPACE_NAME"
  git remote set-url origin https://github.com/$REPO_OWNER_NAME/$REPO_NAME.git
  chown -R 1000 .
  chgrp -R 1000 .
fi

cd "/workspaces/$WORKSPACE_NAME"

devcontainer up \
  --workspace-folder . \
  --config "$CONFIG_PATH" \

devcontainer exec \
  --workspace-folder . \
  --config "$CONFIG_PATH" \
  sh -c "`cat /tmp/coder-devcontainer-builder/on_devcontainer_start_banner.sh /tmp/coder-devcontainer-builder/on_devcontainer_start.sh`"

exit 0

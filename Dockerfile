# Node.js bundled with VS Code Server is not compatible to Alpine Linux
FROM cruizba/ubuntu-dind:noble-28.1.1

RUN apt-get update\
  && apt-get install -y bash ca-certificates gcc git g++ make python3\
  && npm install -g @devcontainers/cli
# "bash" is needed to use "git-clone" module

WORKDIR /

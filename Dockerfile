FROM docker:dind

RUN mkdir -p /tmp/coder-devcontainer-builder

WORKDIR /tmp/coder-devcontainer-builder

RUN apk update\
  && apk upgrade\
  && apk add --no-cache ca-certificates gcc git g++ make nodejs npm python3\
  && npm install -g @devcontainers/cli

WORKDIR /

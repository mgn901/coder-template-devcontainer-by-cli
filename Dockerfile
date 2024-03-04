FROM node:alpine

COPY ./scripts /tmp/coder-devcontainer-builder

WORKDIR /tmp/coder-devcontainer-builder

RUN apk update\
  && apk upgrade\
  && apk add --no-cache ca-certificates docker-cli docker-cli-compose gcc git g++ make python3\
  && npm install -g @devcontainers/cli\
  && npm install jsonc-parser

WORKDIR /

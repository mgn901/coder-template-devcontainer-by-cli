FROM docker:dind

COPY ./scripts /tmp/coder-devcontainer-builder

WORKDIR /tmp/coder-devcontainer-builder

RUN apk update\
  && apk upgrade\
  && apk add --no-cache ca-certificates gcc git g++ make nodejs npm python3\
  && npm install -g @devcontainers/cli\
  && npm install jsonc-parser

WORKDIR /

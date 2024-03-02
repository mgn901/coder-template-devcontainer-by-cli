FROM node:alpine

RUN apk update && \
    apk upgrade && \
    apk add --no-cache make gcc g++ python3\
    npm install -g @devcontainers/cli

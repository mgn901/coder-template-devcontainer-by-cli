terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "coder" {
}

provider "docker" {
}

data "coder_provisioner" "me" {}

data "coder_workspace" "me" {}

variable "docker-sock" {
  description = "Path to docker.sock"
}

data "coder_parameter" "repo" {
  order        = 1
  name         = "repo"
  display_name = "Git Repository URL"
  default      = ""
  mutable      = true
}

data "coder_parameter" "config" {
  order        = 2
  name         = "config"
  display_name = "Path to devcontainer.json"
  default      = ".devcontainer/devcontainer.json"
  mutable      = true
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = data.coder_provisioner.me.os
  dir  = "/workspaces/${lower(data.coder_workspace.me.name)}"

  # These environment variables allow you to make Git commits right away after creating a
  # workspace. Note that they take precedence over configuration defined in ~/.gitconfig!
  # You can remove this block if you'd prefer to configure Git manually or using
  # dotfiles. (see docs/dotfiles.md)
  env = {
    GIT_AUTHOR_NAME     = "${data.coder_workspace.me.owner}"
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace.me.owner_email}"
    GIT_COMMITTER_NAME  = "${data.coder_workspace.me.owner}"
    GIT_COMMITTER_EMAIL = "${data.coder_workspace.me.owner_email}"
  }

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
}

# Adds code-server
# See all available modules at https://registry.coder.com
module "code-server" {
  source   = "registry.coder.com/modules/code-server/coder"
  version  = "1.0.5"
  agent_id = coder_agent.main.id
  folder   = "/workspaces/${lower(data.coder_workspace.me.name)}"
}

module "vscode" {
  source   = "registry.coder.com/modules/vscode-desktop/coder"
  version  = "1.0.2"
  agent_id = coder_agent.example.id
  folder   = "/workspaces/${lower(data.coder_workspace.me.name)}"
}

locals {
  exec_script  = <<EOT
    #!/bin/sh
    set -xe
    cd /workspaces/${lower(data.coder_workspace.me.name)}

    IS_COMPOSE=`cat ${lower(data.coder_parameter.config)} | node /scripts/is_compose_based.js`

    if [ $IS_COMPOSE = true ]; then
      docker compose -p coder-${data.coder_workspace.me.id} down
    else
      docker container rm coder-${data.coder_workspace.me.id}
    fi
  EOT
  build_script = <<EOT
    #!/bin/sh

    set -xe

    mkdir -p /parent-of-workspaces
    mkdir -p /tmp/coder-devcontainer-builder
    git clone ${data.coder_parameter.repo} /parent-of-workspaces/workspaces/${lower(data.coder_workspace.me.name)}
    cd /parent-of-workspaces/workspaces/${lower(data.coder_workspace.me.name)}

    echo {\"runArgs\": \"coder-${data.coder_workspace.me.id}\"} > /tmp/coder-devcontainer-builder/override.json

    IS_COMPOSE=`cat ${lower(data.coder_parameter.config)} | node /scripts/is_compose_based.js`
    COMPOSE_PROJECT_NAME=coder-${data.coder_workspace.me.id}

    if [ $IS_COMPOSE = true ]; then
      devcontainer up\
        --workspace-folder .\
        --config ${data.coder_parameter.config}

      sh -s <<EOF
        ${local.exec_script}
      EOF &\
      devcontainer exec\
        --workspace-folder .\
        --config ${data.coder_parameter.config}\
        sh -s <<EOF
        ${coder_agent.main.init_script}
        EOF
    else
      devcontainer up\
        --workspace-folder .\
        --config ${data.coder_parameter.config}
        --override-config /tmp/coder-devcontainer-builder/override.json

      sh -s <<EOF
        ${local.exec_script}
      EOF &\
      devcontainer exec\
        --workspace-folder .\
        --config ${data.coder_parameter.config}\
        --override-config /tmp/coder-devcontainer-builder/override.json
        sh -s <<EOF
        #!/bin/sh
        CODER_AGENT_TOKEN=${coder_agent.main.token}
        ${coder_agent.main.init_script}
        EOF
    fi
  EOT
}

resource "docker_image" "builder" {
  build {
    context    = "."
    dockerfile = "Dockerfile"
  }
  name = "registry.mgn901.com:5000/coder-devcontainer-builder"
}

resource "docker_container" "builder" {
  count   = data.coder_workspace.me.start_count
  image   = docker_image.builder.name
  name    = "coder-${data.coder_workspace.me.id}-builder"
  command = ["sh", "-c", local.build_script]

  volumes {
    volume_name    = docker_volume.main.name
    container_path = "/parent-of-workspaces"
    read_only      = false
  }

  volumes {
    host_path      = "./scripts"
    container_path = "/scripts"
    read_only      = true
  }

  volumes {
    host_path      = var.docker-sock
    container_path = "/var/run/docker.sock"
    read_only      = false
  }
}

resource "docker_volume" "main" {
  name = "coder-${data.coder_workspace.me.id}"
  lifecycle {
    ignore_changes = all
  }
}

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
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "config" {
  order        = 2
  name         = "config"
  display_name = "Path to devcontainer.json"
  type         = "string"
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
  agent_id = coder_agent.main.id
  folder   = "/workspaces/${lower(data.coder_workspace.me.name)}"
}

locals {
  init_script = templatefile("${path.module}", {
    workspace_id   = data.coder_workspace.me.id
    workspace_name = lower(data.coder_workspace.me.name)
    config         = data.coder_parameter.config.value
    agent_token    = coder_agent.main.token
    agent_script   = coder_agent.main.init_script
  })
}

resource "docker_image" "builder" {
  build {
    context    = "${path.module}"
    dockerfile = "Dockerfile"
  }
  name = "registry.mgn901.com:5000/coder-devcontainer-builder"
}

resource "docker_container" "builder" {
  count   = data.coder_workspace.me.start_count
  image   = docker_image.builder.name
  name    = "coder-${data.coder_workspace.me.id}-builder"
  command = ["sh", "-s", "'${local.init_script}'"]

  volumes {
    volume_name    = docker_volume.main.name
    container_path = "/parent-of-workspaces"
    read_only      = false
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

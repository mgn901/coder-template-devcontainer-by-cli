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
  validation {
    regex = "^((http|git|ssh|http(s)|\\/?)|(git@[\\w\\.]+))(:(\\/\\/)?)([\\w\\.@\\:/\\-~]+)(\\.git)(\\/)?$"
    error = "Valid Git Repository URL is required."
  }
  default = "https://github.com/mgn901/webapp-development-exercise.git"
  mutable = true
}

data "coder_parameter" "config" {
  order        = 2
  name         = "config"
  display_name = "Path to devcontainer.json"
  type         = "string"
  validation {
    regex = "^.+$"
    error = "Path to devcontainer.json is required."
  }
  default = ".devcontainer/devcontainer.json"
  mutable = true
}

data "coder_parameter" "external_volume" {
  order        = 3
  name         = "external_volume"
  display_name = "External volume name"
  description  = "If you are using Docker Compose based Dev container, you **MUST** specify external volume to preserve your source tree declared in the `devcontainer.json`."
  type         = "string"
  validation {
    regex = "^([a-z]|[0-9]|_|__|-+)*$"
    error = "Specify valid volume name or empty."
  }
  default = ""
  mutable = true
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
  folder   = "/workspaces/coder-${lower(data.coder_workspace.me.name)}-${data.coder_workspace.me.id}"
}

module "vscode" {
  source   = "registry.coder.com/modules/vscode-desktop/coder"
  version  = "1.0.2"
  agent_id = coder_agent.main.id
  folder   = "/workspaces/coder-${lower(data.coder_workspace.me.name)}-${data.coder_workspace.me.id}"
}

locals {
  init_script = templatefile("${path.module}/scripts/init.sh.tftpl", {
    workspace_id    = data.coder_workspace.me.id
    workspace_name  = lower(data.coder_workspace.me.name)
    repo            = data.coder_parameter.repo.value
    config          = data.coder_parameter.config.value
    external_volume = data.coder_parameter.external_volume.value
    agent_token     = coder_agent.main.token
    agent_script    = coder_agent.main.init_script
  })
}

resource "docker_image" "builder" {
  build {
    context    = path.module
    dockerfile = "Dockerfile"
  }
  name = "registry.mgn901.com:5000/coder-devcontainer-builder"
}

resource "docker_volume" "main" {
  name = "coder-${data.coder_workspace.me.id}"

  lifecycle {
    ignore_changes = all
  }

  labels {
    label = "coder.owner_id"
    value = data.coder_workspace.me.owner_id
  }

  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
}

resource "docker_container" "builder" {
  count   = data.coder_workspace.me.start_count
  image   = docker_image.builder.name
  name    = "coder-${data.coder_workspace.me.id}-builder"
  command = ["sh", "-c", "${local.init_script}"]

  volumes {
    volume_name    = docker_volume.main.name
    container_path = "/workspaces"
    read_only      = false
  }

  volumes {
    host_path      = var.docker-sock
    container_path = "/var/run/docker.sock"
    read_only      = false
  }

  labels {
    label = "coder.owner_id"
    value = data.coder_workspace.me.owner_id
  }

  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
}

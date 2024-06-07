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

# Configure variables on creating a template on Coder Web UI
variable "docker-sock" {
  description = "Path to docker.sock"
}

variable "coder-github-auth-id" {
  description = "ID of Coder GitHub Authentication Provider to use"
}

# Configure variables on creating a workspace on Coder Web UI
data "coder_parameter" "repo_owner_name" {
  order        = 1
  name         = "repo_owner_name"
  display_name = "Git Repository Owner Name"
  type         = "string"
  validation {
    regex = "^[0-9a-zA-Z_-]+$"
    error = "Valid Git Repository Owner Name is required."
  }
  default = "mgn901"
  mutable = true
}

data "coder_parameter" "repo_name" {
  order        = 2
  name         = "repo_name"
  display_name = "Git Repository Name"
  type         = "string"
  validation {
    regex = "^[0-9a-zA-Z_-]+$"
    error = "Valid Git Repository Name is required."
  }
  default = "webapp-development-exercise"
  mutable = true
}

data "coder_parameter" "branch_name" {
  order        = 3
  name         = "branch_name"
  display_name = "Git Branch Name"
  type         = "string"
  validation {
    regex = ".+$"
    error = "Valid Git Branch Name is required."
  }
  default = "main"
  mutable = true
}

data "coder_parameter" "config_path" {
  order        = 4
  name         = "config_path"
  display_name = "Path to devcontainer.json"
  type         = "string"
  validation {
    regex = "^.+$"
    error = "Path to devcontainer.json is required."
  }
  default = ".devcontainer/devcontainer.json"
  mutable = true
}

data "coder_external_auth" "github" {
  id = var.coder-github-auth-id
}

# Resource Definitions
resource "coder_agent" "workspace" {
  arch = data.coder_provisioner.me.arch
  os   = data.coder_provisioner.me.os
  dir  = "/workspaces/${lower(data.coder_workspace.me.name)}"
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
  order = 1
  display_apps {
    vscode = true
    vscode_insiders = false
    web_terminal = true
    ssh_helper = true
    port_forwarding_helper = true
  }
}

resource "coder_agent" "builder" {
  arch            = data.coder_provisioner.me.arch
  os              = data.coder_provisioner.me.os
  order           = 2
  startup_script = templatefile("${path.module}/scripts/startup.sh.tftpl", {
    workspace_name              = lower(data.coder_workspace.me.name)
    repo_owner_name             = data.coder_parameter.repo_owner_name.value
    repo_name                   = data.coder_parameter.repo_name.value
    branch_name                 = data.coder_parameter.branch_name.value
    github_authentication_token = data.coder_external_auth.github.access_token
    config_path                 = data.coder_parameter.config_path.value
    workspace_agent_token       = coder_agent.workspace.token
    workspace_agent_script      = coder_agent.workspace.init_script
  })
  startup_script_behavior = "blocking"
  display_apps {
    vscode = false
    vscode_insiders = false
    web_terminal = false
    ssh_helper = false
    port_forwarding_helper = false
  }
}

resource "coder_script" "builder_shutdown" {
  agent_id = coder_agent.builder.id
  display_name = "Builder: Dev Container Shutdown Process"
  run_on_stop = true
  script = file("${path.module}/scripts/shutdown.sh")
}

resource "docker_image" "workspace" {
  name = "registry.mgn901.com:5000/coder-devcontainer-workspace:latest"
  build {
    context    = path.module
    dockerfile = "Dockerfile"
  }
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_volume" "workspace" {
  name = "coder-workspace-${data.coder_workspace.me.id}"
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.owner_id"
    value = data.coder_workspace.me.owner_id
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.workspace_id"
    value = data.coder_workspace.me.id
  }
}

resource "docker_volume" "docker_data" {
  name = "coder-docker-data-${data.coder_workspace.me.id}"
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.owner_id"
    value = data.coder_workspace.me.owner_id
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.workspace_id"
    value = data.coder_workspace.me.id
  }
}

resource "docker_container" "workspace" {
  count   = data.coder_workspace.me.start_count
  image   = docker_image.workspace.name
  name    = "coder-workspace-${data.coder_workspace.me.id}"
  command = ["sh", "-c", "${coder_agent.builder.init_script}"]
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.builder.token}",
    "DOCKER_TLS_CERTDIR=/certs"
  ]
  volumes {
    volume_name    = docker_volume.workspace.name
    container_path = "/workspaces"
  }
  volumes {
    volume_name    = docker_volume.docker_data.name
    container_path = "/var/lib/docker"
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.owner_id"
    value = data.coder_workspace.me.owner_id
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.workspace_id"
    value = data.coder_workspace.me.id
  }
}

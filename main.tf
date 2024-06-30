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
data "coder_parameter" "docker_registry_hostname" {
  order        = 1
  name         = "docker_registry_hostname"
  display_name = "Docker Registry Hostname"
  type         = "string"
  validation {
    regex = "^(http|https):\\/\\/[-\\w\\.]+(:\\d+)?(\\/[^\\s]*)?$"
    error = "Valid Docker Registry Hostname is required."
  }
  default = "https://registry.mgn901.com"
  mutable = true
}

data "coder_parameter" "docker_registry_username" {
  order        = 2
  name         = "docker_registry_username"
  display_name = "Docker Registry Username"
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "docker_registry_password" {
  order        = 3
  name         = "docker_registry_password"
  display_name = "Docker Registry Password"
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "repo_owner_name" {
  order        = 4
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
  order        = 5
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
  order        = 6
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
  order        = 7
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
  arch  = data.coder_provisioner.me.arch
  os    = data.coder_provisioner.me.os
  order = 1
  dir   = "/workspaces/${lower(data.coder_workspace.me.name)}"
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
  display_apps {
    vscode                 = false
    vscode_insiders        = false
    web_terminal           = true
    ssh_helper             = true
    port_forwarding_helper = true
  }
}

# resource "coder_app" "vscode" {
#   agent_id     = coder_agent.workspace.id
#   external     = true
#   icon         = "/icon/code.svg"
#   slug         = "vscode"
#   display_name = "VS Code Desktop"
#   order        = 1
#   url = join("", [
#     "vscode://coder.coder-remote/open",
#     "?owner=",
#     data.coder_workspace.me.owner_name,
#     "&workspace=",
#     data.coder_workspace.me.name,
#     "&folder=/workspaces/${lower(data.coder_workspace.me.name)}",
#     "&url=",
#     data.coder_workspace.me.access_url,
#     "&token=$SESSION_TOKEN",
#   ])
# }

resource "coder_agent" "builder" {
  arch                    = data.coder_provisioner.me.arch
  os                      = data.coder_provisioner.me.os
  order                   = 2
  startup_script          = file("${path.module}/scripts/startup.sh")
  startup_script_behavior = "blocking"
  shutdown_script         = file("${path.module}/scripts/shutdown.sh")
  display_apps {
    vscode                 = false
    vscode_insiders        = false
    web_terminal           = false
    ssh_helper             = false
    port_forwarding_helper = false
  }
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
    "DOCKER_TLS_CERTDIR=/certs",
    "DOCKER_REGISTRY_HOSTNAME=${data.coder_parameter.docker_registry_hostname.value}",
    "DOCKER_REGISTRY_USERNAME=${data.coder_parameter.docker_registry_username.value}",
    "DOCKER_REGISTRY_PASSWORD=${data.coder_parameter.docker_registry_password.value}",
    "WORKSPACE_NAME=${lower(data.coder_workspace.me.name)}",
    "REPO_OWNER_NAME=${data.coder_parameter.repo_owner_name.value}",
    "REPO_NAME=${data.coder_parameter.repo_name.value}",
    "BRANCH_NAME=${data.coder_parameter.branch_name.value}",
    "GITHUB_AUTHENTICATION_TOKEN=${data.coder_external_auth.github.access_token}",
    "CONFIG_PATH=${data.coder_parameter.config_path.value}",
    "WORKSPACE_AGENT_TOKEN=${coder_agent.workspace.token}",
    "WORKSPACE_AGENT_SCRIPT=${coder_agent.workspace.init_script}"
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

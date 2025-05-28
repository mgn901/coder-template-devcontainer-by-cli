terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "2.5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.0"
    }
  }
}

provider "coder" {}
provider "docker" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

## Configure variables on creating a template on Coder Web UI ##

# Template administrators can set a tag of docker container image which hosts dev containers.
variable "docker-workspace-image-tag" {
  description = "Docker container image tag for workspace container"
  default     = "registry.mgn901.com:5000/coder-devcontainer-workspace:latest"
}

# Coder GitHub Authentication Provider may be set for cloning private repository.
variable "coder-github-auth-id" {
  description = "ID of Coder GitHub Authentication Provider to use"
}

## Configure variables on creating a workspace on Coder Web UI ##

# The workspace owner must specify the GitHub repository url and the path to devcontainer.json.
# The workspace owner can set docker registry credentials so that Dev Container host container can retrieve images on private registry.

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

data "coder_parameter" "git_repository_url" {
  order        = 4
  name         = "git_repository_url"
  display_name = "Git Repository URL"
  type         = "string"
  validation {
    regex = "^.+$"
    error = "Path to devcontainer.json is required."
  }
  default = "https://github.com/mgn901/webapp-development-exercise/tree/main"
  mutable = true
}

data "coder_parameter" "config_path" {
  order        = 5
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

## Resource Definitions ##

resource "coder_agent" "workspace" {
  arch                    = data.coder_provisioner.me.arch
  os                      = data.coder_provisioner.me.os
  # The startup_script waits for the dockerd to start and logs in to docker private registry.
  startup_script          = file("${path.module}/scripts/startup.sh")
  startup_script_behavior = "blocking"
  # The shutdown_script teminates the dockerd.
  shutdown_script         = file("${path.module}/scripts/shutdown.sh")
  
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
    vscode                 = true
    vscode_insiders        = false
    web_terminal           = true
    ssh_helper             = true
    port_forwarding_helper = true
  }
}

module "git-clone" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/git-clone/coder"
  agent_id    = coder_agent.workspace.id
  url         = data.coder_parameter.git_repository_url.value
  folder_name = lower(data.coder_workspace.me.name)
  base_dir    = "/workspaces"
}

resource "coder_devcontainer" "workspace" {
  count            = data.coder_workspace.me.start_count
  agent_id         = coder_agent.workspace.id
  workspace_folder = "/workspaces/${lower(data.coder_workspace.me.name)}"
  config_path      = data.coder_parameter.config_path.value
  depends_on       = [module.git-clone]
}

resource "docker_volume" "workspace" {
  name = "coder-workspace-${data.coder_workspace.me.id}"
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.owner_name"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.workspace_name"
    value = data.coder_workspace.me.name
  }
}

resource "docker_volume" "tmp" {
  name = "coder-tmp-${data.coder_workspace.me.id}"
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.owner_name"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.workspace_name"
    value = data.coder_workspace.me.name
  }
}

resource "docker_volume" "docker_data" {
  name = "coder-docker-data-${data.coder_workspace.me.id}"
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.owner_name"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.workspace_name"
    value = data.coder_workspace.me.name
  }
}

resource "docker_container" "workspace" {
  count   = data.coder_workspace.me.start_count
  image   = var.docker-workspace-image-tag
  name    = "coder-workspace-${data.coder_workspace.me.id}"
  command = ["sh", "-c", "${coder_agent.workspace.init_script}"]
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.workspace.token}",
    "CODER_AGENT_DEVCONTAINERS_ENABLE=true",
    "DOCKER_TLS_CERTDIR=/certs",
    "DOCKER_HOST=unix:///var/run/docker.sock", # Manually sets correct DOCKER_HOST path
    "DOCKER_REGISTRY_HOSTNAME=${data.coder_parameter.docker_registry_hostname.value}",
    "DOCKER_REGISTRY_USERNAME=${data.coder_parameter.docker_registry_username.value}",
    "DOCKER_REGISTRY_PASSWORD=${data.coder_parameter.docker_registry_password.value}",
  ]
  volumes {
    volume_name    = docker_volume.workspace.name
    container_path = "/workspaces" # Persists source code tree
  }
  volumes {
    volume_name    = docker_volume.tmp.name
    container_path = "/tmp" # Dev Container Metadata used to set up Dev Container is finally saved on /tmp
  }
  volumes {
    volume_name    = docker_volume.docker_data.name
    container_path = "/var/lib/docker" # Persists Dev Container data
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.owner_name"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "com.mgn901.coder-template-devcontainer-by-cli.workspace_name"
    value = data.coder_workspace.me.name
  }
}

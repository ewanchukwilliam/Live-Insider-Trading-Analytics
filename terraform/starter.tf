terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.98"
    }
  }
}

variable "virtual_environment_endpoint" { type = string }
variable "virtual_environment_secret" { type = string }
variable "ssh_public_key" { type = string }
variable "container_ip" { type = string }


provider "proxmox" {

  endpoint  = var.virtual_environment_endpoint
  api_token = var.virtual_environment_secret
  # TODO: configure a CI/CD pipeline simple ssh onto server git pul and docker compose up --build
  # username =  var.virtual_environment_username
  # password = var.virtual_environment_password
  insecure = true

  ssh {
    agent    = true
    username = "root" # required when using api_token
  }
}

resource "proxmox_virtual_environment_container" "debian" {
  node_name    = "plex" # your proxmox node name
  unprivileged = true

  initialization {
    hostname = "cron-container"
    user_account {
      keys = [var.ssh_public_key]
    }

    ip_config {
      ipv4 {
        address = "${var.container_ip}/24"
        gateway = "192.168.1.254"
      }
    }
  }

  network_interface {
    name = "eth0"
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    type             = "debian"
  }

  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  cpu { cores = 2 }
  memory { dedicated = 4096 }
  features {
    nesting = true
  }

  mount_point {
    path   = "/mnt/backups" # inside VM container
    volume = "/mnt/storage/insidertrading/db-backups" # scoped dir on proxmox host
  }

}

terraform {
  required_providers {
    opnsense = {
      source = "browningluke/opnsense"
    }
    netbox = {
      source = "e-breuninger/netbox"
    }
    proxmox = {
      source = "bpg/proxmox"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}


terraform {
  required_providers {
    # opnsense provider is optional - only required when enable_firewall_config = true
    # Caller must configure the browningluke/opnsense provider if using firewall features
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


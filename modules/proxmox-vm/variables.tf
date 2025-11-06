variable "proxmox_cluster" {
  type = string
}
variable "role" {
  type = string
}
variable "team" {
  type = string
}
variable "project" {
  type = string
}
variable "environment" {
  type = string
}
variable "hostname" {
  type = string
}
variable "memory" {
  type = number
}
variable "cores" {
  type = number
}
variable "disk_size" {
  type = number
}
variable "enable_ceph" {
  type    = bool
  default = false
}
variable "enable_firewall_config" {
  type    = bool
  default = true
}
variable "network_prefix" {
  type = string
}
variable "additional_network_prefixes" {
  type    = list(string)
  default = []

}
variable "ceph_network_prefix" {
  type    = string
  default = ""
}
variable "vrf" {
  type = string
}
variable "expire_date" {
  type = string
  default = ""
}
variable "network_prefix6" {
  type = string
}
variable "gateway_v4" {
  type = string
}
variable "dns_server" {
  type = string
  default = "10.128.2.1"
}
variable "gateway_v6" {
  type = string
}
variable "vlan_id" {
  type = number
  default = 11
}

variable "vm_username" {
  type = string
}

variable "vm_ssh_keys" {
  type    = list(string)
  default = []
}

variable "vm_password" {
  type      = string
  sensitive = true
}


variable "description" {
  type    = string
  default = ""
}
variable "tags" {
  type    = list(string)
  default = []
}

variable "services" {
  type = list(object({
    name  = string
    proto = string
    port = number
    expose_mode = optional(string, "off")
    expose_auth = optional(string, "none")
    expose_ipv4 = optional(string, null)
    internal_only = optional(bool, false)
    teleport_name = optional(string, "")
    expose_domain = optional(list(string), [])
    balance_mode = optional(string, "roundrobin")
  }))
  default = []
  validation {
    condition     = alltrue([for s in var.services : contains(["off", "l4", "l7", "teleport"], s.expose_mode)])
    error_message = "expose_mode must be one of: 'off', 'l4', 'l7' or 'teleport'"
  }
}
variable "configContext" {
  type = string
}

variable "os" {
  type = string
  validation {
    condition     = contains(["debian12","debian13","ubuntu2404"], var.os)
    error_message = "Only debian12, debian13 or ubuntu2404 is supported"
  }
  default = "debian12"

}
variable "storage_optimized" {
  type = bool
  default = false
}

variable "pve_template_host" {
  type = string
  default = "colo-pxe-01"
}
variable "pve_target_storage" {
  type = string
  default = "vm-storage"
}
variable "pve_netowkr_bridge" {
  type = string
  default = "vmbr1"
}

variable "extra_disk_size" {
  type        = number
  description = "Size of the additional disk in GB. Set to null to disable the extra disk."
  default     = null
}

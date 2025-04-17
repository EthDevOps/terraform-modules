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
variable "network_prefix6" {
  type = string
}
variable "gateway_v4" {
  type = string
}
variable "gateway_v6" {
  type = string
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
    ports = list(number)
  }))
  default = []
}
variable "configContext" {
  type = string
}

variable "os" {
  type = string
  validation {
    condition     = contains(["debian12"], var.os)
    error_message = "Only debian 12 is supported"
  }
  default = "debian12"

}

variable "additional_volumes" {
  type = list(object({
    name       = string
    size_in_gb = number
  }))
  default = []
}

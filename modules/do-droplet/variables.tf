variable "team" {
  type = string
}

variable "enable_ipv6" {
  type    = bool
  default = false
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "expire_date" {
  type    = string
  default = ""
}

variable "vm_ssh_keys" {
  type    = list(string)
  default = []
}

variable "region" {
  type = string
}

variable "hostname" {
  type = string
}

variable "role" {
  type = string
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
    name          = string
    proto         = string
    port          = number
    expose_domain = optional(list(string), [])
  }))
  default = []
}

variable "size" {
  type    = string
  default = "s-2vcpu-4gb"
}

variable "configContext" {
  type = string
}

variable "os" {
  type = string
  validation {
    condition     = contains(["debian10", "debian11", "debian12", "debian13", "ubuntu2404", "ubuntuml"], var.os)
    error_message = "Only ubuntu2404 and debian 10 to 13 are supported"
  }
  default = "debian13"

}

variable "additional_volumes" {
  type = list(object({
    name       = string
    size_in_gb = number
  }))
  default = []
}

variable "restrict_ssh" {
  type        = bool
  default     = false
  description = "Restrict inbound SSH (tcp/22) to the warpgate origin via a DigitalOcean CSP firewall. All other inbound traffic remains allowed via catch-all rules."
}

variable "warpgate_origin_v4" {
  type        = list(string)
  default     = ["212.99.218.66/32"]
  description = "IPv4 CIDRs of the warpgate origins allowed to reach SSH when restrict_ssh is enabled."
}

variable "warpgate_origin_v6" {
  type        = string
  default     = null
  description = "Optional IPv6 CIDR of the warpgate origin for SSH when restrict_ssh is enabled."
}

variable "restrict_to_services" {
  type        = bool
  default     = false
  description = "Restrict inbound traffic to the ports defined in services (allowed from 0.0.0.0/0), dropping everything else. Port 22 is ignored here and governed solely by restrict_ssh."
  validation {
    condition     = !var.restrict_to_services || var.restrict_ssh || length([for s in var.services : s if s.port != 22]) > 0
    error_message = "restrict_to_services needs at least one non-SSH service (or restrict_ssh enabled) so the firewall has at least one inbound rule."
  }
}

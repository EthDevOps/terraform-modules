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
    expose_mode   = optional(string, "off")
    expose_auth   = optional(string, "none")
    expose_ipv4   = optional(string, null)
    internal_only = optional(bool, false)
    teleport_name = optional(string, "")
    expose_domain = optional(list(string), [])
    balance_mode  = optional(string, "roundrobin")
    allow_http    = optional(bool, false)
  }))
  default = []
  validation {
    condition     = alltrue([for s in var.services : contains(["off", "l4", "l7", "teleport"], s.expose_mode)])
    error_message = "expose_mode must be one of: 'off', 'l4', 'l7' or 'teleport'"
  }
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
  default = "debian12"

}

variable "additional_volumes" {
  type = list(object({
    name       = string
    size_in_gb = number
  }))
  default = []
}

variable "teleport_groups" {
  type        = list(string)
  default     = []
  description = "Teleport access groups for label-based VM access; rendered as group/group_N agent labels"
}

variable "teleport_allowed_users" {
  type        = list(string)
  default     = []
  description = "Teleport usernames (email addresses of local users) granted direct access via allowed_user/allowed_user_N agent labels. GitHub-SSO usernames are GitHub handles, so direct grants reliably target local users only."
}

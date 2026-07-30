variable "team" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type    = string
  default = "production"
}

variable "region" {
  type = string
}

variable "hostname" {
  type = string
}

variable "expire_date" {
  type    = string
  default = ""
}

variable "role" {
  type    = string
  default = "server"
}

variable "memory_in_mb" {
  type = number
}
variable "cpu_cores" {
  type = number
}

variable "os_disk_size_in_gb" {
  type = number
}

variable "nics" {
  type = list(object({
    name         = string
    is_primary   = bool
    ipv6_enabled = optional(bool, false)
    ipv6_address = optional(string)
    ipv4_address = string
  }))
  default = []
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
  type    = string
  default = "{}"
}

variable "os" {
  type = string
  validation {
    condition     = contains(["debian10", "debian11", "debian12", "debian13", "ubuntu2004", "ubuntu2204", "ubuntu2404", "ubuntu2604"], var.os)
    error_message = "Only ubuntu2004, ubuntu2204, ubuntu2404, ubuntu2604 and debian 10 to 13 are supported"
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

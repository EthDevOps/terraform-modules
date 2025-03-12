variable "team" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
  default = "production"
}

variable "region" {
  type = string
}

variable "hostname" {
  type = string
}

variable "role" {
  type = string
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
  type = string
  default = "{}"
}

variable "os" {
  type = string
  validation {
    condition     = contains(["debian10", "debian11", "debian12", "ubuntu2404"], var.os)
    error_message = "Only ubuntu2404 and debian 10, 11 and 12 are supported"
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

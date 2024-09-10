variable "team" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "htz_ssh_keys" {
  type = list(string)
  default = []
}

variable "region" {
  type = string
  default = "nbg1"
}

variable "hostname" {
  type = string
}

variable "role" {
  type = string
}

variable "description" {
  type = string
  default = ""
} 
variable "tags" {
  type = list(string)
  default = []
}

variable "services" {
  type = list(object({
    name = string
    proto = string
    ports = list(number)
  }))
  default = []
}

variable "size" {
  type = string
  default = "cx21"
}

variable "configContext" {
  type = map(string)
}

variable "os" {
  type = string
  validation {
    condition     = contains(["debian10", "debian11", "debian12"], var.os)
    error_message = "Only debian 10, 11 and 12 are supported"
  }
  default = "debian12"

}

variable "enable_ipv6" {
  type = bool
  default = false
}

variable "additional_volumes" {
  type = list(object({
    name = string
    size_in_gb = number
  }))
  default = []
}

variable "private_network_id" {
  type = string
  default = ""
}

variable "private_network_ipv4" {
  type = string
  default = ""
}

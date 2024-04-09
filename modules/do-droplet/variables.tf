variable "team" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "do_ssh_keys" {
  type = list(string)
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
  default = "s-2vcpu-4gb"
}

variable "configContext" {
  type = string
}

variable "os" {
  type = string
  validation {
    condition     = contains(["debian10", "debian11", "debian12"], var.os)
    error_message = "Only debian 10, 11 and 12 are supported"
  }
  default = "debian12"

}


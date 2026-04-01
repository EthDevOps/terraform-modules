terraform {
  required_providers {
    opnsense = {
      source = "ethdevops/opnsense"
    }
  }
}

variable "services" {
  type = list(object({
    name        = string
    proto       = string
    port        = number
    expose_mode = optional(string, "off")
    public_ipv4 = string
  }))
  default = []
}

variable "hostname" {
  type = string
}

variable "ipv6_address" {
  type        = string
  description = "IPv6 address with prefix (e.g. from module.vm.ipv6)"
}

variable "ipv4_address" {
  type        = string
  description = "IPv4 address with prefix (e.g. from module.vm.ipv4)"
}

locals {
  l4_services = [
    for service in var.services :
    service if service.expose_mode == "l4"
  ]
  safe_hostname = replace(var.hostname, "/[^a-zA-Z0-9]+/", ".")
  no_prefix_v6  = split("/", var.ipv6_address)[0]
  no_prefix_v4  = split("/", var.ipv4_address)[0]
}

# IPv6 WAN rules - direct access
resource "opnsense_firewall_filter" "ipv6_wan_services" {
  for_each = {
    for idx, service in local.l4_services : "${service.name}-${service.port}" => service
  }

  enabled     = true
  description = "Allow ${each.value.name} on ${each.value.port} for ${local.safe_hostname} v6"

  interface = {
    interface = ["wan"]
  }

  filter = {
    action      = "pass"
    direction   = "in"
    ip_protocol = "inet6"

    protocol = upper(each.value.proto)

    source = {
      net = "any"
    }

    destination = {
      net  = "${local.no_prefix_v6}/128"
      port = tostring(each.value.port)
    }
  }
}

# IPv4 port forwards
resource "opnsense_firewall_filter" "ipv4_wan_services" {
  for_each = {
    for idx, service in local.l4_services : "${service.name}-${service.port}" => service
    if service.expose_ipv4 != null
  }

  enabled     = true
  description = "Allow ${each.value.name} on ${each.value.port} for ${local.safe_hostname} v4"

  interface = {
    interface = ["wan"]
  }

  filter = {
    action      = "pass"
    direction   = "in"
    protocol    = upper(each.value.proto)
    ip_protocol = "inet"
    source = {
      net = "any"
    }

    destination = {
      net  = "${local.no_prefix_v4}/32"
      port = tostring(each.value.port)
    }
  }
}

resource "opnsense_firewall_dnat" "port_forward_https" {
  for_each = {
    for idx, service in local.l4_services : "${service.name}-${service.port}" => service
    if service.expose_ipv4 != null
  }
  interface = "wan"
  protocol  = lower(each.value.proto)
  categories = [
    opnsense_firewall_category.terraform.id
  ]

  destination = {
    net  = each.value.public_ipv4
    port = tostring(each.value.port)
  }

  target = {
    ip   = "${local.no_prefix_v4}/32"
    port = tostring(each.value.port)
  }

  description = "Port forward port ${each.value.port} on ${each.value.public_ipv4} to ${local.no_prefix_v4}"
}





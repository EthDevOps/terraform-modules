locals {
  # Filter services where expose_mode is "l4"
  l4_services = [
    for service in var.services :
    service if service.expose_mode == "l4"
  ]

}

# IPv6 WAN rules - direct access
resource "opnsense_firewall_filter" "ipv6_wan_services" {
  for_each = {
    for idx, service in local.l4_services : "${service.name}-${service.port}" => service
  }

  description     = "Allow ${each.value.name} for ${var.hostname} v6"
  action          = "pass"
  direction       = "in"
  enabled         = false

  interface       = ["wan"]
  ip_protocol     = "inet6"

  protocol        = upper(each.value.proto)

  source = {
    net = "any"
  }
  
  destination = {
    net = netbox_available_ip_address.vm_ip6.ip_address
    port = tostring(each.value.port)
  }

}

# IPv4 port forwards
resource "opnsense_firewall_filter" "ipv4_wan_services" {
  for_each = {
    for idx, service in local.l4_services : "${service.name}-${idx}" => service
    if service.expose_ipv4 != null
  }
  
  description     = "Allow ${each.value.name} for ${var.hostname} v4"
  action          = "pass"
  direction       = "in"
  enabled         = false

  interface       = ["wan"]
  ip_protocol     = "inet"

  protocol        = upper(each.value.proto)

  source = {
    net = "any"
  }
  
  destination = {
    net = netbox_available_ip_address.vm_ip.ip_address
    port = tostring(each.value.port)
  }

}

resource "opnsense_firewall_nat" "port_forwards" {
  for_each = {
    for idx, service in local.l4_services : "${service.name}-${idx}" => service
    if service.expose_ipv4 != null
  }

  description        = "Port forward ${each.value.name} for ${var.hostname} v4"
  interface          = "wan"
  protocol          = lower(each.value.proto)
  enabled         = false


  source = {
    net = "any"
  }

  destination = {
    net = each.value.expose_ipv4
    port = tostring(each.value.port)
  }

  target = {
    ip = netbox_available_ip_address.vm_ip.ip_address
    port = tostring(each.value.port)
  }
}


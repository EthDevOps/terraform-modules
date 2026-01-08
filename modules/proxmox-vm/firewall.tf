module "opnsense_firewall" {
  source = "./modules/opnsense-firewall"
  count  = var.enable_firewall_config ? 1 : 0

  services     = var.services
  hostname     = var.hostname
  ipv6_address = netbox_available_ip_address.vm_ip6.ip_address
  ipv4_address = netbox_available_ip_address.vm_ip.ip_address
}

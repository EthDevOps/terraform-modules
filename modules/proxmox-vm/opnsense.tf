resource "opnsense_kea_reservation" "vm" {
  subnet_id = var.kea_subnet

  ip_address =  split("/",netbox_available_ip_address.vm_ip.ip_address)[0]
  mac_address = local.mac_address

  description = var.hostname
}


data "netbox_cluster" "pve" {
  name = var.proxmox_cluster
}

data "netbox_platform" "os" {
  name = lookup(local.platform, var.os)
}

data "netbox_tenant" "team" {
  name = var.team
}

data "netbox_device_role" "role" {
  name = var.role
}

data "netbox_devices" "pve" {
  filter {
    name  = "cluster_id"
    value = data.netbox_cluster.pve.id
  }
}

resource "random_shuffle" "selected_pve_host" {
  input        = local.pvc_nodes
  result_count = 1
}

output "pve_template" {
  value = local.pvc_templates
}

locals {

  # Create a map with hostname as key and template_vm as value
  pvc_templates = {
    for device in data.netbox_devices.pve.devices :
    device.name => try(jsondecode(device.config_context).template_vm, null)
  }

  pvc_nodes = keys(local.pvc_templates)

  platform = {
    debian12 = "Debian 12 - Bookworm"
    ubuntu2404 = "Ubuntu 24.04 LTS"
  }
}

data "netbox_prefix" "prefix" {
  prefix = var.network_prefix
}

data "netbox_prefix" "ceph_prefix" {
  count  = var.enable_ceph ? 1 : 0
  prefix = var.ceph_network_prefix
}

data "netbox_vrf" "dcl" {
  name = var.vrf
}


data "netbox_prefix" "prefix6" {
  prefix = var.network_prefix6
}

resource "netbox_available_ip_address" "vm_ip" {
  prefix_id                    = data.netbox_prefix.prefix.id
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.vm_eth0.id
  description                  = var.hostname
  vrf_id                       = data.netbox_vrf.dcl.id
}

resource "netbox_available_ip_address" "vm_ip6" {
  prefix_id                    = data.netbox_prefix.prefix6.id
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.vm_eth0.id
  description                  = var.hostname
}

resource "netbox_available_ip_address" "vm_ip_ceph" {
  count                        = var.enable_ceph ? 1 : 0
  prefix_id                    = data.netbox_prefix.ceph_prefix[0].id
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.vm_eth1[0].id
  description                  = "CEPH for ${var.hostname}"
  vrf_id                       = data.netbox_vrf.dcl.id
}

resource "netbox_virtual_machine" "vm" {
  cluster_id         = data.netbox_cluster.pve.id
  name               = var.hostname
  memory_mb          = var.memory
  vcpus              = var.cores
  platform_id        = data.netbox_platform.os.id
  tenant_id          = data.netbox_tenant.team.id
  site_id            = data.netbox_devices.pve.devices[0].site_id
  role_id            = data.netbox_device_role.role.id
  local_context_data = var.configContext
  description        = var.description
  tags               = var.tags
  custom_fields = {
    project     = var.project
    environment = var.environment
  }
}

resource "netbox_virtual_disk" "os_disk" {
  name               = "OS Disk"
  size_mb            = var.disk_size * 1024
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_interface" "vm_eth0" {
  name               = "eth0"
  virtual_machine_id = netbox_virtual_machine.vm.id
  mac_address        = local.mac_address
}

resource "netbox_interface" "vm_eth1" {
  count              = var.enable_ceph ? 1 : 0
  name               = "eth1"
  virtual_machine_id = netbox_virtual_machine.vm.id
  mac_address        = local.mac_address_ceph

}

resource "netbox_primary_ip" "vm_primary_ip" {
  ip_address_id      = netbox_available_ip_address.vm_ip.id
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_primary_ip" "vm_primary_ip6" {
  ip_address_id      = netbox_available_ip_address.vm_ip6.id
  virtual_machine_id = netbox_virtual_machine.vm.id
  ip_address_version = 6
}

resource "netbox_service" "svc" {
  for_each           = { for i in var.services : i.name => i }
  name               = each.key
  ports              = [each.value.port]
  protocol           = each.value.proto
  virtual_machine_id = netbox_virtual_machine.vm.id
  custom_fields = {
    expose_mode = each.value.expose_mode
    expose_domain = join(",", each.value.expose_domain)
    expose_auth = each.value.expose_auth
    teleport_name = each.value.teleport_name
  }
}

data "netbox_prefix" "additional_prefix" {
  for_each = toset(var.additional_network_prefixes)
  prefix   = each.value
}

resource "netbox_available_ip_address" "additional_vm_ip" {
  for_each                     = toset(var.additional_network_prefixes)
  prefix_id                    = data.netbox_prefix.additional_prefix[each.key].id
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.vm_eth0.id
  description                  = var.hostname
  vrf_id                       = data.netbox_vrf.dcl.id
}

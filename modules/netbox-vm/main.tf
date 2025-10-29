locals {
  replaced_punctuation   = replace(var.team, "/[.!]/", "")
  replaced_punctuation_p = replace(var.project, "/[.!]/", "")
  team                   = replace(lower(local.replaced_punctuation), " ", "-")
  project                = replace(lower(local.replaced_punctuation_p), " ", "-")
  default_ssh_keys       = ["mkeil", "devops_shared_key"]
}

data "netbox_cluster" "do" {
  name = var.region
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

locals {
  platform = {
    debian10   = "Debian 10 - Buster"
    debian11   = "Debian 11 - Bullseye"
    debian12   = "Debian 12 - Bookworm"
    debian13   = "Debian 13 - Trixie"
    ubuntu2404 = "Ubuntu 24.04 LTS"
  }
}

resource "netbox_virtual_machine" "vm" {
  cluster_id         = data.netbox_cluster.do.id
  name               = var.hostname
  memory_mb          = var.memory_in_mb
  vcpus              = var.cpu_cores
  platform_id        = data.netbox_platform.os.id
  tenant_id          = data.netbox_tenant.team.id
  site_id            = data.netbox_cluster.do.site_id
  role_id            = data.netbox_device_role.role.id
  local_context_data = var.configContext
  description        = var.description
  tags               = var.tags
  custom_fields = {
    project     = var.project
    environment = var.environment
  }
}

resource "netbox_virtual_disk" "example" {
  for_each           = { for i in var.additional_volumes : i.name => i }
  name               = each.key
  description        = "TF-provisioned for ${var.hostname}"
  size_mb            = each.value.size_in_gb * 1024
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_virtual_disk" "os_disk" {
  name               = "OS Disk"
  description        = "Part of the droplet"
  size_mb            = var.os_disk_size_in_gb * 1024
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_interface" "vm_nic" {
  for_each           = { for i in var.nics : i.name => i }
  name               = each.key
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_primary_ip" "vm_primary_ip" {
  for_each           = { for i in var.nics : i.name => i if i.is_primary }
  ip_address_id      = netbox_ip_address.vm_ip4[each.key].id
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_primary_ip" "vm_primary_ip6" {
  for_each           = { for i in var.nics : i.name => i if i.is_primary && i.ipv6_enabled }
  ip_address_id      = netbox_ip_address.vm_ip6[each.key].id
  virtual_machine_id = netbox_virtual_machine.vm.id
  ip_address_version = 6
}

resource "netbox_ip_address" "vm_ip4" {
  for_each = { for i in var.nics : i.name => i }

  ip_address                   = each.value.ipv4_address
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.vm_nic[each.key].id
  dns_name                     = "${var.hostname}.teleport.ethquokkaops.io"
}

resource "netbox_ip_address" "vm_ip6" {
  for_each = { for i in var.nics : i.name => i if i.ipv6_enabled }

  ip_address                   = each.value.ipv6_address
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.vm_nic[each.key].id
  dns_name                     = "${var.hostname}.teleport.ethquokkaops.io"
}

resource "netbox_service" "svc" {
  for_each           = { for i in var.services : i.name => i }
  name               = each.key
  ports              = each.value.ports
  protocol           = each.value.proto
  virtual_machine_id = netbox_virtual_machine.vm.id
}



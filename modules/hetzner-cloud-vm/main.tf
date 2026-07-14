locals {
  replaced_punctuation   = replace(var.team, "/[.!]/", "")
  replaced_punctuation_p = replace(var.project, "/[.!]/", "")
  team                   = replace(lower(local.replaced_punctuation), " ", "-")
  project                = replace(lower(local.replaced_punctuation_p), " ", "-")
  default_ssh_keys       = ["EF SSH Key"]
}

data "netbox_cluster" "htz" {
  name = "hetznercloud-${var.region}"
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

data "hcloud_server_type" "main" {
  name = var.size
}

locals {
  os_images = {
    debian10   = "debian-10"
    debian11   = "debian-11"
    debian12   = "debian-12"
    debian13   = "debian-13"
    ubuntu2404 = "ubuntu-24.04"
  }
  platform = {
    debian10   = "Debian 10 - Buster"
    debian11   = "Debian 11 - Bullseye"
    debian12   = "Debian 12 - Bookworm"
    debian13   = "Debian 13 - Trixie"
    ubuntu2404 = "Ubuntu 24.04 LTS"
  }
  htz_locations = {
    hel = "hel1"
    nbg = "nbg1"
    fsn = "fsn1"
    ash = "ash"
    hil = "hil"
    sin = "sin"
  }
}

resource "hcloud_server" "vm" {
  image       = lookup(local.os_images, var.os)
  name        = var.hostname
  location    = lookup(local.htz_locations, var.region)
  server_type = var.size
  labels = {
    "team" : local.team,
    "project" : local.project,
    "env" : var.environment,
    "created-by" : "tf"
  }
  ssh_keys = concat(local.default_ssh_keys, var.vm_ssh_keys)

  public_net {
    ipv4_enabled = true
    ipv6_enabled = var.enable_ipv6
  }
}

resource "hcloud_server_network" "srvnetwork" {
  count      = var.private_network_id != "" ? 1 : 0
  server_id  = hcloud_server.vm.id
  network_id = var.private_network_id
  ip         = var.private_network_ipv4
}

resource "hcloud_volume" "additional_storage" {
  for_each = { for i in var.additional_volumes : i.name => i }

  name     = "${var.hostname}-vol-${each.key}"
  size     = each.value.size_in_gb
  location = var.region
  format   = "ext4"
}

resource "hcloud_volume_attachment" "additional_storage" {
  for_each = { for i in var.additional_volumes : i.name => i }

  server_id = hcloud_server.vm.id
  volume_id = hcloud_volume.additional_storage[each.key].id
  automount = true
}

resource "netbox_virtual_machine" "vm" {
  cluster_id         = data.netbox_cluster.htz.id
  name               = var.hostname
  memory_mb          = data.hcloud_server_type.main.memory * 1024
  vcpus              = data.hcloud_server_type.main.cores
  platform_id        = data.netbox_platform.os.id
  tenant_id          = data.netbox_tenant.team.id
  site_id            = data.netbox_cluster.htz.site_id
  role_id            = data.netbox_device_role.role.id
  local_context_data = var.configContext
  description        = var.description
  tags               = var.tags
  custom_fields = {
    project                = var.project
    environment            = var.environment
    expire_date            = var.expire_date
    teleport_groups        = join(",", var.teleport_groups)
    teleport_allowed_users = join(",", var.teleport_allowed_users)
  }
}

resource "netbox_virtual_disk" "os_disk" {
  name               = "OS Disk"
  description        = "Part of the server"
  size_mb            = data.hcloud_server_type.main.disk * 1024
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_virtual_disk" "additional" {
  for_each           = { for i in var.additional_volumes : i.name => i }
  name               = each.key
  description        = "TF-provisioned for ${var.hostname}"
  size_mb            = each.value.size_in_gb * 1024
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_interface" "vm_eth0" {
  name               = "eth0"
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_primary_ip" "vm_primary_ip" {
  ip_address_id      = netbox_ip_address.vm_eth0_ip4.id
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_primary_ip" "vm_primary_ip6" {
  count              = var.enable_ipv6 ? 1 : 0
  ip_address_id      = netbox_ip_address.vm_eth0_ip6[0].id
  virtual_machine_id = netbox_virtual_machine.vm.id
  ip_address_version = 6
}

resource "netbox_ip_address" "vm_eth0_ip4" {
  ip_address                   = "${hcloud_server.vm.ipv4_address}/32"
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.vm_eth0.id
  dns_name                     = "${var.hostname}.teleport.ethquokkaops.io"
}

resource "netbox_ip_address" "vm_eth0_ip6" {
  count                        = var.enable_ipv6 ? 1 : 0
  ip_address                   = "${hcloud_server.vm.ipv6_address}/64"
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.vm_eth0.id
  dns_name                     = "${var.hostname}.teleport.ethquokkaops.io"
}

resource "netbox_interface" "vm_priv" {
  count              = var.private_network_id != "" ? 1 : 0
  name               = "enp7s0"
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_ip_address" "vm_priv_ip4" {
  count                        = var.private_network_id != "" ? 1 : 0
  ip_address                   = "${var.private_network_ipv4}/32"
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.vm_priv[0].id
}

resource "netbox_service" "svc" {
  for_each           = { for i in var.services : i.name => i }
  name               = each.key
  ports              = [each.value.port]
  protocol           = each.value.proto
  virtual_machine_id = netbox_virtual_machine.vm.id
  custom_fields = {
    expose_mode   = each.value.expose_mode
    expose_domain = join(",", each.value.expose_domain)
    expose_auth   = each.value.expose_auth
    teleport_name = each.value.teleport_name
    internal_only = each.value.internal_only
    balance_mode  = each.value.balance_mode
  }
}

output "vm_id" {
  value       = hcloud_server.vm.id
  description = "ID of the VM"
}

output "ipv4" {
  value = hcloud_server.vm.ipv4_address
}

output "ipv6" {
  value = var.enable_ipv6 ? hcloud_server.vm.ipv6_address : null
}

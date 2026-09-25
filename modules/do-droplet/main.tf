locals {
  replaced_punctuation   = replace(var.team, "/[.!]/", "")
  replaced_punctuation_p = replace(var.project, "/[.!]/", "")
  team                   = replace(lower(local.replaced_punctuation), " ", "-")
  project                = replace(lower(local.replaced_punctuation_p), " ", "-")
  default_ssh_keys       = ["mkeil", "devops_shared_key"]
}

data "digitalocean_ssh_keys" "keys" {
  filter {
    key    = "name"
    values = concat(local.default_ssh_keys, var.vm_ssh_keys)
  }
}

data "netbox_cluster" "do" {
  name = "digitalocean-${var.region}"
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

data "digitalocean_sizes" "main" {
  filter {
    key    = "slug"
    values = [var.size]
  }
}

locals {
  os_images = {
    debian10   = "debian-10-x64"
    debian11   = "debian-11-x64"
    debian12   = "debian-12-x64"
    debian13   = "debian-13-x64"
    ubuntu2404 = "ubuntu-24-04-x64"
    ubuntuml   = "gpu-h100x1-base"
  }
  platform = {
    debian10   = "Debian 10 - Buster"
    debian11   = "Debian 11 - Bullseye"
    debian12   = "Debian 12 - Bookworm"
    debian13   = "Debian 13 - Trixie"
    ubuntu2404 = "Ubuntu 24.04 LTS"
    ubuntuml   = "Ubuntu 24.04 ML/AI"
  }
}

output "droplet_id" {
  value       = digitalocean_droplet.vm.id
  description = "ID of the DigitalOcean Droplet"
}

output "ipv4" {
  value = digitalocean_droplet.vm.ipv4_address
}

output "ipv6" {
  value = var.enable_ipv6 ? digitalocean_droplet.vm.ipv6_address : null
}

output "firewall_id" {
  value       = local.firewall_enabled ? digitalocean_firewall.ssh_restriction[0].id : null
  description = "ID of the CSP firewall, when restrict_ssh or restrict_to_services is enabled"
}

# Create a new Web Droplet in the nyc2 region
resource "digitalocean_droplet" "vm" {
  image  = lookup(local.os_images, var.os)
  name   = var.hostname
  region = var.region
  size   = var.size
  ipv6   = var.enable_ipv6
  tags = [
    "team-${local.team}",
    "project-${local.project}",
    "env-${var.environment}",
    "created-by-tf"
  ]
  ssh_keys = [for i in data.digitalocean_ssh_keys.keys.ssh_keys : i.id]
}

locals {
  firewall_enabled = var.restrict_ssh || var.restrict_to_services

  # Per-service inbound rules, open from anywhere (IPv4). Port 22 is skipped —
  # SSH is governed solely by restrict_ssh.
  service_rules = flatten([
    for s in var.services : s.port == 22 ? [] : [{
      protocol     = s.proto
      port_range   = tostring(s.port)
      source_addrs = ["0.0.0.0/0"]
    }]
  ])

  # Catch-all rules only in SSH-only mode. DO firewalls are pure allow-lists,
  # so the tcp catch-all is split around port 22 to keep SSH from non-warpgate
  # sources blocked.
  catchall_rules_v4 = var.restrict_to_services ? [] : [
    { protocol = "tcp", port_range = "0-21" },
    { protocol = "tcp", port_range = "23-65535" },
    { protocol = "udp", port_range = "0-65535" },
    { protocol = "sctp", port_range = "0-65535" },
  ]
  catchall_rules_v6 = var.restrict_to_services || !var.enable_ipv6 ? [] : [
    { protocol = "tcp", port_range = "0-21" },
    { protocol = "tcp", port_range = "23-65535" },
    { protocol = "udp", port_range = "0-65535" },
    { protocol = "sctp", port_range = "0-65535" },
  ]
}

resource "digitalocean_firewall" "ssh_restriction" {
  count = local.firewall_enabled ? 1 : 0

  name        = "${var.hostname}-ssh-warpgate"
  droplet_ids = [digitalocean_droplet.vm.id]

  dynamic "inbound_rule" {
    for_each = var.restrict_ssh ? [1] : []

    content {
      protocol         = "tcp"
      port_range       = "22"
      source_addresses = var.warpgate_origin_v4
    }
  }

  dynamic "inbound_rule" {
    for_each = var.restrict_ssh && var.warpgate_origin_v6 != null ? [var.warpgate_origin_v6] : []

    content {
      protocol         = "tcp"
      port_range       = "22"
      source_addresses = [inbound_rule.value]
    }
  }

  dynamic "inbound_rule" {
    for_each = var.restrict_to_services ? local.service_rules : []

    content {
      protocol         = inbound_rule.value.protocol
      port_range       = inbound_rule.value.port_range
      source_addresses = inbound_rule.value.source_addrs
    }
  }

  dynamic "inbound_rule" {
    for_each = local.catchall_rules_v4

    content {
      protocol         = inbound_rule.value.protocol
      port_range       = inbound_rule.value.port_range
      source_addresses = ["0.0.0.0/0"]
    }
  }

  dynamic "inbound_rule" {
    for_each = local.catchall_rules_v6

    content {
      protocol         = inbound_rule.value.protocol
      port_range       = inbound_rule.value.port_range
      source_addresses = ["::/0"]
    }
  }
}

resource "digitalocean_volume" "additional_storage" {

  for_each = { for i in var.additional_volumes : i.name => i }

  region                  = var.region
  name                    = "${var.hostname}-vol-${each.key}"
  size                    = each.value.size_in_gb
  initial_filesystem_type = "ext4"
  description             = "TF-provisioned for ${var.hostname}"
}

resource "digitalocean_volume_attachment" "foobar" {
  for_each = { for i in var.additional_volumes : i.name => i }

  droplet_id = digitalocean_droplet.vm.id
  volume_id  = digitalocean_volume.additional_storage[each.key].id
}

resource "netbox_virtual_machine" "vm" {
  cluster_id         = data.netbox_cluster.do.id
  name               = var.hostname
  memory_mb          = element(data.digitalocean_sizes.main.sizes, 0).memory
  vcpus              = element(data.digitalocean_sizes.main.sizes, 0).vcpus
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
    expire_date = var.expire_date
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
  size_mb            = element(data.digitalocean_sizes.main.sizes, 0).disk * 1024
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_interface" "vm_eth0" {
  name               = "eth0"
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_interface" "vm_eth1" {
  name               = "eth1"
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
  ip_address                   = "${digitalocean_droplet.vm.ipv4_address}/20"
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.vm_eth0.id
}

resource "netbox_ip_address" "vm_eth0_ip6" {
  count                        = var.enable_ipv6 ? 1 : 0
  ip_address                   = "${digitalocean_droplet.vm.ipv6_address}/64"
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.vm_eth0.id
}

resource "netbox_ip_address" "vm_eth1_ip4" {
  ip_address                   = "${digitalocean_droplet.vm.ipv4_address_private}/20"
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.vm_eth1.id
}

resource "netbox_service" "svc" {
  for_each           = { for i in var.services : i.name => i }
  name               = each.key
  ports              = [each.value.port]
  protocol           = each.value.proto
  virtual_machine_id = netbox_virtual_machine.vm.id
  custom_fields = {
    expose_domain = join(",", each.value.expose_domain)
  }
}



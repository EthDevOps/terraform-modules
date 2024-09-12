locals {
  replaced_punctuation = replace(var.team, "/[.!]/", "")
  replaced_punctuation_p = replace(var.project, "/[.!]/", "")
  team = replace(lower(local.replaced_punctuation), " ", "-")
  project = replace(lower(local.replaced_punctuation_p), " ", "-")
  default_ssh_keys = ["EF SSH Key"]
}

data "netbox_cluster" "htz" {
  name = "hetznercloud-${local.team}-${var.region}"
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
    debian10 = "debian-10"
    debian11 = "debian-11"
    debian12 = "debian-12"
  }
  platform = {
    debian10 = "Debian 10 - Buster"
    debian11 = "Debian 11 - Bullseye"
    debian12 = "Debian 12 - Bookworm"
  }
}


# Create a new Web Droplet in the nyc2 region
resource "hcloud_server" "vm" {
  image  = lookup(local.os_images, var.os)
  name   = var.hostname
  location = var.region
  server_type = var.size
  labels   = {
    "team": local.team,
    "project": local.project,
    "env": var.environment,
    "created-by": "tf"
  }
  ssh_keys = concat(local.default_ssh_keys, var.htz_ssh_keys)
  
  public_net {
    ipv4_enabled = true
    ipv6_enabled = var.enable_ipv6
  }
}

output "vm_id" {
  value = hcloud_server.vm.id
  description = "ID of the VM"
}

resource "hcloud_server_network" "srvnetwork" {
  count = var.private_network_id != "" ? 1 : 0
  server_id  = hcloud_server.vm.id
  network_id = var.private_network_id
  ip         = var.private_network_ipv4
}

resource "netbox_virtual_machine" "vm" {
  cluster_id   = data.netbox_cluster.htz.id
  name         = var.hostname
  disk_size_gb = data.hcloud_server_type.main.disk
  memory_mb    = data.hcloud_server_type.main.memory * 1024
  vcpus        = data.hcloud_server_type.main.cores
  platform_id  = data.netbox_platform.os.id
  tenant_id = data.netbox_tenant.team.id
  site_id = data.netbox_cluster.htz.site_id
  role_id = data.netbox_device_role.role.id
  local_context_data = var.configContext
  description = var.description
  tags = var.tags
  custom_fields = {
    project = var.project
    environment = var.environment
  }
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
  count = var.enable_ipv6 ? 1 : 0
  ip_address_id      = netbox_ip_address.vm_eth0_ip6.id
  virtual_machine_id = netbox_virtual_machine.vm.id
  ip_address_version = 6
}

resource "netbox_ip_address" "vm_eth0_ip4" {
  ip_address          = "${hcloud_server.vm.ipv4_address}/32"
  status              = "active"
  virtual_machine_interface_id = netbox_interface.vm_eth0.id
}

resource "netbox_ip_address" "vm_eth0_ip6" {
  count = var.enable_ipv6 ? 1 : 0
  ip_address          = "${hcloud_server.vm.ipv6_address}/64"
  status              = "active"
  virtual_machine_interface_id = netbox_interface.vm_eth0.id
  dns_name = "${var.hostname}.teleport.ethquokkaops.io"
}


resource "netbox_interface" "vm_priv" {
  count = var.private_network_id != "" ? 1 : 0
  name               = "enp7s0"
  virtual_machine_id = netbox_virtual_machine.vm.id
}

resource "netbox_ip_address" "vm_priv_ip4" {
  count = var.private_network_id != "" ? 1 : 0
  ip_address          = "${var.private_network_ipv4}/32"
  status              = "active"
  virtual_machine_interface_id = netbox_interface.vm_priv[0].id
}

resource "netbox_service" "svc" {
  for_each = { for i in var.services : i.name => i }
  name = each.key
  ports = each.value.ports
  protocol = each.value.proto
  virtual_machine_id = netbox_virtual_machine.vm.id
}



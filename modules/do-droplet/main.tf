locals {
  replaced_punctuation = replace(var.team, "/[.!]/", "")
  team = replace(lower(local.replaced_punctuation), " ", "-")
  default_ssh_keys = ["mkeil", "devops_shared_key"]
}

data "digitalocean_ssh_keys" "keys" {
  filter {
    key    = "name"
    values = concat(local.default_ssh_keys, var.do_ssh_keys) 
  }
}

data "netbox_cluster" "do" {
  name = "digitalocean-${local.team}-${var.region}"
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
    debian10 = "debian-10-x64"
    debian11 = "debian-11-x64"
    debian12 = "debian-12-x64"
  }
  platform = {
    debian10 = "Debian 10 - Buster"
    debian11 = "Debian 11 - Bullseye"
    debian12 = "Debian 12 - Bookworm"
  }
}

# Create a new Web Droplet in the nyc2 region
resource "digitalocean_droplet" "vm" {
  image  = lookup(local.os_images, var.os)
  name   = var.hostname
  region = var.region
  size   = var.size
  tags   = [
    "team-${local.team}",
    "project-${local.project}",
    "created-by-tf"
  ]
  ssh_keys = [ for i in data.digitalocean_ssh_keys.keys.ssh_keys: i.id ]
}

resource "netbox_virtual_machine" "vm" {
  cluster_id   = data.netbox_cluster.do.id
  name         = var.hostname
  disk_size_gb = element(data.digitalocean_sizes.main.sizes, 0).disk
  memory_mb    = element(data.digitalocean_sizes.main.sizes, 0).memory
  vcpus        = element(data.digitalocean_sizes.main.sizes, 0).vcpus
  platform_id  = data.netbox_platform.os.id
  tenant_id = data.netbox_tenant.team.id
  site_id = data.netbox_cluster.do.site_id
  role_id = data.netbox_device_role.role.id
  local_context_data = jsonencode(var.configContext)
  description = var.description
  tags = var.tags
  custom_fields = {
    project = var.project
  }
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

resource "netbox_ip_address" "vm_eth0_ip4" {
  ip_address          = "${digitalocean_droplet.vm.ipv4_address}/20"
  status              = "active"
  virtual_machine_interface_id = netbox_interface.vm_eth0.id
}

resource "netbox_ip_address" "vm_eth1_ip4" {
  ip_address          = "${digitalocean_droplet.vm.ipv4_address_private}/20"
  status              = "active"
  virtual_machine_interface_id = netbox_interface.vm_eth1.id
}

resource "netbox_service" "svc" {
  for_each = { for i in var.services : i.name => i }
  name = each.key
  ports = each.value.ports
  protocol = each.value.proto
  virtual_machine_id = netbox_virtual_machine.vm.id
}



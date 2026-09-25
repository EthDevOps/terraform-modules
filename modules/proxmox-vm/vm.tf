

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.hostname
  node_name = random_shuffle.selected_pve_host.result[0]
  vm_id     = netbox_virtual_machine.vm.id + 10000

  lifecycle {
    ignore_changes = [
      node_name,
      vm_id,
      initialization
    ]
  }

  initialization {
    ip_config {
      ipv4 {
        address = netbox_available_ip_address.vm_ip.ip_address
        gateway = var.gateway_v4
      }

      ipv6 {
        address = netbox_available_ip_address.vm_ip6.ip_address
        gateway = var.gateway_v6
      }
    }

    dns {
      domain = "dcl1.ethquokkaops.io"
      servers = [
        var.dns_server
      ]
    }


    user_account {
      username = var.vm_username
      password = var.vm_password
      keys     = var.vm_ssh_keys
    }
  }

  tags = sort(var.tags)

  operating_system {
    type = "l26"
  }

  disk {
    datastore_id = var.pve_target_storage
    interface    = "scsi0"
    discard      = "on"
    aio          = "native"
    iothread     = true
    ssd          = true

    size = var.disk_size
  }

  dynamic "disk" {
    for_each = var.extra_disk_size != null && !var.storage_optimized ? [1] : []
    content {
      datastore_id = var.pve_target_storage
      interface    = "scsi1"
      discard      = "on"
      aio          = "native"
      iothread     = true
      ssd          = true

      size = var.extra_disk_size
    }
  }

  dynamic "disk" {
    for_each = var.storage_optimized && var.extra_disk_size != null ? [1, 2] : []
    content {
      datastore_id = var.pve_target_storage
      interface    = "scsi${disk.value}"
      discard      = "on"
      aio          = "native"
      iothread     = true
      ssd          = true
      cache        = "unsafe"

      size = var.extra_disk_size / 2
    }
  }

  cpu {
    cores = var.cores
    type  = var.storage_optimized ? "host" : "x86-64-v4"
    numa  = var.storage_optimized
  }

  memory {
    dedicated = var.memory
  }

  clone {
    node_name = var.pve_template_host
    vm_id     = lookup(lookup(local.pvc_templates, random_shuffle.selected_pve_host.result[0]), var.os)
    full      = true
  }

  network_device {
    bridge      = var.pve_network_bridge
    mac_address = local.mac_address
    vlan_id     = var.vlan_id
  }

  dynamic "network_device" {
    for_each = var.enable_ceph ? [1] : []
    content {
      bridge      = "cephbr0"
      mac_address = local.mac_address_ceph
      mtu         = 9000
    }
  }

  vga {
    memory = 16
    type   = "std"
  }
}

resource "proxmox_virtual_environment_firewall_options" "ssh_restriction" {
  count = var.restrict_ssh ? 1 : 0

  node_name     = proxmox_virtual_environment_vm.vm.node_name
  vm_id         = proxmox_virtual_environment_vm.vm.vm_id
  enabled       = true
  input_policy  = "ACCEPT"
  output_policy = "ACCEPT"
}

resource "proxmox_virtual_environment_firewall_rules" "ssh_restriction" {
  count = var.restrict_ssh ? 1 : 0

  node_name = proxmox_virtual_environment_vm.vm.node_name
  vm_id     = proxmox_virtual_environment_vm.vm.vm_id

  rule {
    type    = "in"
    action  = "ACCEPT"
    dport   = "22"
    proto   = "tcp"
    source  = join(",", var.warpgate_origin_v4)
    comment = "Allow SSH from warpgate origins (IPv4)"
  }

  dynamic "rule" {
    for_each = var.warpgate_origin_v6 != null ? [var.warpgate_origin_v6] : []

    content {
      type    = "in"
      action  = "ACCEPT"
      dport   = "22"
      proto   = "tcp"
      source  = rule.value
      comment = "Allow SSH from warpgate origin (IPv6)"
    }
  }

  rule {
    type    = "in"
    action  = "DROP"
    dport   = "22"
    proto   = "tcp"
    comment = "Drop SSH from all other sources"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow all other inbound traffic"
  }
}



output "ipv4" {
  value = netbox_available_ip_address.vm_ip.ip_address
}
output "ipv6" {
  value = netbox_available_ip_address.vm_ip6.ip_address
}
output "mac" {
  value = local.mac_address
}

output "firewall_id" {
  value       = var.restrict_ssh ? proxmox_virtual_environment_firewall_rules.ssh_restriction[0].id : null
  description = "ID of the SSH-restriction firewall rules, when restrict_ssh is enabled"
}

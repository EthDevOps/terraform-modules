

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.hostname
  node_name = random_shuffle.selected_pve_host.result[0]

  lifecycle {
    ignore_changes = [
      node_name
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
    iothread = true
    ssd = true

    size = var.disk_size
  }

  dynamic "disk" {
    for_each = var.extra_disk_size != null && !var.storage_optimized ? [1] : []
    content {
      datastore_id = var.pve_target_storage
      interface    = "scsi1"
      discard      = "on"
      aio          = "native"
    iothread = true
    ssd = true

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
      iothread = true
      ssd = true
      cache = "unsafe"

      size = var.extra_disk_size / 2
    }
  }

  cpu {
    cores = var.cores
    type  = var.storage_optimized ? "host" : "x86-64-v4"
    numa = var.storage_optimized
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



output "ipv4" {
  value = netbox_available_ip_address.vm_ip.ip_address
}
output "ipv6" {
  value = netbox_available_ip_address.vm_ip6.ip_address
}
output "mac" {
  value = local.mac_address
}

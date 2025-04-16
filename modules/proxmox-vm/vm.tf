

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
    datastore_id = "vm-storage"
    interface = "scsi0"
    discard = "on"
    aio = "native"

    size = var.disk_size
  }

  cpu {
    cores = var.cores
    type = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory
  }

  clone {
    node_name = "colo-pxe-01"
    vm_id = lookup(lookup(local.pvc_templates, random_shuffle.selected_pve_host.result[0]), var.os)
    full = true
  }

  network_device {
    bridge = "vmbr1"
    mac_address = local.mac_address
    vlan_id = 11
  }

  dynamic "network_device" {
    for_each = var.enable_ceph ? [1] : []
    content {
      bridge = "cephbr0"
    mac_address = local.mac_address_ceph
      mtu = 9000
    }
  }

  vga {
    memory = 16
    type = "std"
  }
}



output "ipv4" {
  value = netbox_available_ip_address.vm_ip.ip_address
}
output "mac" {
  value = local.mac_address
}

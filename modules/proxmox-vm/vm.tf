

resource "random_id" "mac_address_1" {
  byte_length = 1
}
resource "random_id" "mac_address_2" {
  byte_length = 1
}
resource "random_id" "mac_address_3" {
  byte_length = 1
}

locals {
  # Convert the random bytes to a MAC address format
  mac_address = upper(format("BC:24:11:%02x:%02x:%02x",
    random_id.mac_address_1.dec,
    random_id.mac_address_2.dec,
    random_id.mac_address_3.dec
    ))
}


resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.hostname
  node_name = random_shuffle.selected_pve_host.result
  depends_on = [opnsense_kea_reservation.vm]

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = var.vm_username
      password = var.vm_password
      keys     = var.vm_ssh_keys
    }
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = var.cores
    type = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory
  }

  clone {
    vm_id = lookup(lookup(local.pvc_templates, random_shuffle.selected_pve_host.result), var.os)
    full = true
  }


  network_device {
    bridge = "vmbr1"
    mac_address = local.mac_address
    vlan_id = 11
  }

  vga {
    memory = 16
    type = "serial0"
}
}



output "ipv4" {
  value = netbox_available_ip_address.vm_ip.ip_address
}
output "mac" {
  value = local.mac_address
}

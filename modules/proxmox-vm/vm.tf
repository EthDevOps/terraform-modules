

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
    firewall    = true
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

locals {
  firewall_enabled = var.restrict_ssh || var.restrict_to_services

  # Per-service source CIDRs for restrict_to_services, split by IP family
  # (PVE rule sources cannot mix IPv4 and IPv6). Precedence:
  # internal_only -> warpgate origins, expose_mode l4/l7 -> loadbalancers,
  # anything else (off/teleport) -> open.
  svc_sources_v4 = {
    for s in var.services : s.name => (
      s.internal_only ? var.warpgate_origin_v4 :
      contains(["l4", "l7"], s.expose_mode) ? var.loadbalancer_ips :
      ["0.0.0.0/0"]
    )
  }

  svc_sources_v6 = {
    for s in var.services : s.name => (
      s.internal_only && var.warpgate_origin_v6 != null ? [var.warpgate_origin_v6] : []
    )
  }

  # Flat list of accept rule specs, one per (service, IP family). Port 22 is
  # skipped — SSH is governed solely by restrict_ssh.
  service_rule_specs = flatten([
    for s in var.services : s.port == 22 ? [] : concat(
      length(local.svc_sources_v4[s.name]) > 0 ? [{
        proto   = s.proto
        port    = s.port
        source  = join(",", local.svc_sources_v4[s.name])
        comment = "Allow ${s.name} (${s.proto}/${s.port}) from ${join(",", local.svc_sources_v4[s.name])}"
      }] : [],
      length(local.svc_sources_v6[s.name]) > 0 ? [{
        proto   = s.proto
        port    = s.port
        source  = join(",", local.svc_sources_v6[s.name])
        comment = "Allow ${s.name} (${s.proto}/${s.port}) from ${join(",", local.svc_sources_v6[s.name])} (IPv6)"
      }] : []
    )
  ])
}

resource "proxmox_virtual_environment_firewall_options" "restrict" {
  count = local.firewall_enabled ? 1 : 0

  node_name     = proxmox_virtual_environment_vm.vm.node_name
  vm_id         = proxmox_virtual_environment_vm.vm.vm_id
  enabled       = true
  input_policy  = var.restrict_to_services ? "DROP" : "ACCEPT"
  output_policy = "ACCEPT"
}

resource "proxmox_virtual_environment_firewall_rules" "restrict" {
  count = local.firewall_enabled ? 1 : 0

  node_name = proxmox_virtual_environment_vm.vm.node_name
  vm_id     = proxmox_virtual_environment_vm.vm.vm_id

  dynamic "rule" {
    for_each = var.restrict_ssh ? [1] : []

    content {
      type    = "in"
      action  = "ACCEPT"
      dport   = "22"
      proto   = "tcp"
      source  = join(",", var.warpgate_origin_v4)
      comment = "Allow SSH from warpgate origins (IPv4)"
    }
  }

  dynamic "rule" {
    for_each = var.restrict_ssh && var.warpgate_origin_v6 != null ? [var.warpgate_origin_v6] : []

    content {
      type    = "in"
      action  = "ACCEPT"
      dport   = "22"
      proto   = "tcp"
      source  = rule.value
      comment = "Allow SSH from warpgate origin (IPv6)"
    }
  }

  dynamic "rule" {
    for_each = var.restrict_ssh ? [1] : []

    content {
      type    = "in"
      action  = "DROP"
      dport   = "22"
      proto   = "tcp"
      comment = "Drop SSH from all other sources"
    }
  }

  dynamic "rule" {
    for_each = var.restrict_to_services ? local.service_rule_specs : []

    content {
      type    = "in"
      action  = "ACCEPT"
      dport   = tostring(rule.value.port)
      proto   = rule.value.proto
      source  = rule.value.source
      comment = rule.value.comment
    }
  }

  dynamic "rule" {
    for_each = !var.restrict_to_services ? [1] : []

    content {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow all other inbound traffic"
    }
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
  value       = local.firewall_enabled ? proxmox_virtual_environment_firewall_rules.restrict[0].id : null
  description = "ID of the VM firewall rules, when restrict_ssh or restrict_to_services is enabled"
}

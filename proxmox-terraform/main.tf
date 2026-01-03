# ========================================
# Configuration Terraform pour Proxmox
# Provider: bpg/proxmox
# 3 VMs Rancher + 6 VMs Payload + 1 VM CI/CD + 1 VM OPNsense = 11 VMs
# ========================================

# ===== VMs RANCHER (Control Plane) =====
resource "proxmox_virtual_environment_vm" "rancher_1" {
  name        = "rancher-1"
  node_name   = var.proxmox_node
  vm_id       = var.vm_id_start
  description = "Rancher Kubernetes Control Plane Node 1"

  clone {
    vm_id = 9100
    full  = true
  }

  cpu {
    cores = var.rancher_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.rancher_memory
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address_base}.${var.ip_start}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.nameserver]
    }

    user_account {
      username = "root"
      keys     = [var.ssh_public_key]
    }
  }
}

resource "proxmox_virtual_environment_vm" "rancher_2" {
  name        = "rancher-2"
  node_name   = var.proxmox_node
  vm_id       = var.vm_id_start + 1
  description = "Rancher Kubernetes Control Plane Node 2"

  clone {
    vm_id = 9100
    full  = true
  }

  cpu {
    cores = var.rancher_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.rancher_memory
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address_base}.${var.ip_start + 1}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.nameserver]
    }

    user_account {
      username = "root"
      keys     = [var.ssh_public_key]
    }
  }

  depends_on = [proxmox_virtual_environment_vm.rancher_1]
}

resource "proxmox_virtual_environment_vm" "rancher_3" {
  name        = "rancher-3"
  node_name   = var.proxmox_node
  vm_id       = var.vm_id_start + 2
  description = "Rancher Kubernetes Control Plane Node 3"

  clone {
    vm_id = 9100
    full  = true
  }

  cpu {
    cores = var.rancher_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.rancher_memory
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address_base}.${var.ip_start + 2}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.nameserver]
    }

    user_account {
      username = "root"
      keys     = [var.ssh_public_key]
    }
  }

  depends_on = [proxmox_virtual_environment_vm.rancher_2]
}

# ===== VMs PAYLOAD MASTERS =====
resource "proxmox_virtual_environment_vm" "payload_master_1" {
  name        = "payload-master-1"
  node_name   = var.proxmox_node
  vm_id       = var.vm_id_start + 3
  description = "Payload Master Node 1"

  clone {
    vm_id = 9100
    full  = true
  }

  cpu {
    cores = var.payload_master_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.payload_master_memory
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address_base}.${var.ip_start + 3}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.nameserver]
    }

    user_account {
      username = "root"
      keys     = [var.ssh_public_key]
    }
  }

  depends_on = [proxmox_virtual_environment_vm.rancher_3]
}

resource "proxmox_virtual_environment_vm" "payload_master_2" {
  name        = "payload-master-2"
  node_name   = var.proxmox_node
  vm_id       = var.vm_id_start + 4
  description = "Payload Master Node 2"

  clone {
    vm_id = 9100
    full  = true
  }

  cpu {
    cores = var.payload_master_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.payload_master_memory
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address_base}.${var.ip_start + 4}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.nameserver]
    }

    user_account {
      username = "root"
      keys     = [var.ssh_public_key]
    }
  }

  depends_on = [proxmox_virtual_environment_vm.payload_master_1]
}

resource "proxmox_virtual_environment_vm" "payload_master_3" {
  name        = "payload-master-3"
  node_name   = var.proxmox_node
  vm_id       = var.vm_id_start + 5
  description = "Payload Master Node 3"

  clone {
    vm_id = 9100
    full  = true
  }

  cpu {
    cores = var.payload_master_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.payload_master_memory
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address_base}.${var.ip_start + 5}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.nameserver]
    }

    user_account {
      username = "root"
      keys     = [var.ssh_public_key]
    }
  }

  depends_on = [proxmox_virtual_environment_vm.payload_master_2]
}

# ===== VMs PAYLOAD WORKERS =====
resource "proxmox_virtual_environment_vm" "payload_worker_1" {
  name        = "payload-worker-1"
  node_name   = var.proxmox_node
  vm_id       = var.vm_id_start + 6
  description = "Payload Worker Node 1"

  clone {
    vm_id = 9100
    full  = true
  }

  cpu {
    cores = var.payload_worker_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.payload_worker_memory
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address_base}.${var.ip_start + 6}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.nameserver]
    }

    user_account {
      username = "root"
      keys     = [var.ssh_public_key]
    }
  }

  depends_on = [proxmox_virtual_environment_vm.payload_master_3]
}

resource "proxmox_virtual_environment_vm" "payload_worker_2" {
  name        = "payload-worker-2"
  node_name   = var.proxmox_node
  vm_id       = var.vm_id_start + 7
  description = "Payload Worker Node 2"

  clone {
    vm_id = 9100
    full  = true
  }

  cpu {
    cores = var.payload_worker_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.payload_worker_memory
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address_base}.${var.ip_start + 7}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.nameserver]
    }

    user_account {
      username = "root"
      keys     = [var.ssh_public_key]
    }
  }

  depends_on = [proxmox_virtual_environment_vm.payload_worker_1]
}

resource "proxmox_virtual_environment_vm" "payload_worker_3" {
  name        = "payload-worker-3"
  node_name   = var.proxmox_node
  vm_id       = var.vm_id_start + 8
  description = "Payload Worker Node 3"

  clone {
    vm_id = 9100
    full  = true
  }

  cpu {
    cores = var.payload_worker_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.payload_worker_memory
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address_base}.${var.ip_start + 8}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.nameserver]
    }

    user_account {
      username = "root"
      keys     = [var.ssh_public_key]
    }
  }

  depends_on = [proxmox_virtual_environment_vm.payload_worker_2]
}

# ===== VM CI/CD =====
resource "proxmox_virtual_environment_vm" "cicd" {
  name        = "cicd"
  node_name   = var.proxmox_node
  vm_id       = var.vm_id_start + 9
  description = "CI/CD Server"

  clone {
    vm_id = 9100
    full  = true
  }

  cpu {
    cores = var.cicd_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.cicd_memory
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address_base}.${var.ip_start + 9}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.nameserver]
    }

    user_account {
      username = "root"
      keys     = [var.ssh_public_key]
    }
  }

  depends_on = [proxmox_virtual_environment_vm.payload_worker_3]
}



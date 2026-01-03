# ========================================
# Outputs pour le provider bpg/proxmox
# ========================================

# ===== RANCHER VMs =====
output "rancher_vm_names" {
  description = "Noms des VMs Rancher"
  value = [
    proxmox_virtual_environment_vm.rancher_1.name,
    proxmox_virtual_environment_vm.rancher_2.name,
    proxmox_virtual_environment_vm.rancher_3.name
  ]
}

output "rancher_vm_ids" {
  description = "IDs des VMs Rancher"
  value = [
    proxmox_virtual_environment_vm.rancher_1.vm_id,
    proxmox_virtual_environment_vm.rancher_2.vm_id,
    proxmox_virtual_environment_vm.rancher_3.vm_id
  ]
}

# ===== PAYLOAD VMs =====
output "payload_vm_names" {
  description = "Noms des VMs Payload"
  value = [
    proxmox_virtual_environment_vm.payload_master_1.name,
    proxmox_virtual_environment_vm.payload_master_2.name,
    proxmox_virtual_environment_vm.payload_master_3.name,
    proxmox_virtual_environment_vm.payload_worker_1.name,
    proxmox_virtual_environment_vm.payload_worker_2.name,
    proxmox_virtual_environment_vm.payload_worker_3.name
  ]
}

output "payload_vm_ids" {
  description = "IDs des VMs Payload"
  value = [
    proxmox_virtual_environment_vm.payload_master_1.vm_id,
    proxmox_virtual_environment_vm.payload_master_2.vm_id,
    proxmox_virtual_environment_vm.payload_master_3.vm_id,
    proxmox_virtual_environment_vm.payload_worker_1.vm_id,
    proxmox_virtual_environment_vm.payload_worker_2.vm_id,
    proxmox_virtual_environment_vm.payload_worker_3.vm_id
  ]
}

# ===== SERVICES VMs =====
output "cicd_vm_name" {
  description = "Nom de la VM CI/CD"
  value       = proxmox_virtual_environment_vm.cicd.name
}

output "cicd_vm_id" {
  description = "ID de la VM CI/CD"
  value       = proxmox_virtual_environment_vm.cicd.vm_id
}

# ===== TOUTES LES VMs =====
output "all_vm_names" {
  description = "Noms de toutes les VMs"
  value = [
    proxmox_virtual_environment_vm.rancher_1.name,
    proxmox_virtual_environment_vm.rancher_2.name,
    proxmox_virtual_environment_vm.rancher_3.name,
    proxmox_virtual_environment_vm.payload_master_1.name,
    proxmox_virtual_environment_vm.payload_master_2.name,
    proxmox_virtual_environment_vm.payload_master_3.name,
    proxmox_virtual_environment_vm.payload_worker_1.name,
    proxmox_virtual_environment_vm.payload_worker_2.name,
    proxmox_virtual_environment_vm.payload_worker_3.name,
    proxmox_virtual_environment_vm.cicd.name
  ]
}

output "all_vm_ids" {
  description = "IDs de toutes les VMs"
  value = [
    proxmox_virtual_environment_vm.rancher_1.vm_id,
    proxmox_virtual_environment_vm.rancher_2.vm_id,
    proxmox_virtual_environment_vm.rancher_3.vm_id,
    proxmox_virtual_environment_vm.payload_master_1.vm_id,
    proxmox_virtual_environment_vm.payload_master_2.vm_id,
    proxmox_virtual_environment_vm.payload_master_3.vm_id,
    proxmox_virtual_environment_vm.payload_worker_1.vm_id,
    proxmox_virtual_environment_vm.payload_worker_2.vm_id,
    proxmox_virtual_environment_vm.payload_worker_3.vm_id,
    proxmox_virtual_environment_vm.cicd.vm_id
  ]
}

# ===== RÉSUMÉ =====
output "deployment_summary" {
  description = "Résumé du déploiement"
  value = <<-EOT

╔════════════════════════════════════════════════════════╗
║         🚀 DÉPLOIEMENT RÉUSSI - 10 VMs créées          ║
╚════════════════════════════════════════════════════════╝

📦 RANCHER NODES (Control Plane):
  • rancher-1  → ID ${proxmox_virtual_environment_vm.rancher_1.vm_id} → ${var.ip_address_base}.${var.ip_start}
  • rancher-2  → ID ${proxmox_virtual_environment_vm.rancher_2.vm_id} → ${var.ip_address_base}.${var.ip_start + 1}
  • rancher-3  → ID ${proxmox_virtual_environment_vm.rancher_3.vm_id} → ${var.ip_address_base}.${var.ip_start + 2}

🔧 PAYLOAD MASTERS:
  • payload-master-1 → ID ${proxmox_virtual_environment_vm.payload_master_1.vm_id} → ${var.ip_address_base}.${var.ip_start + 3}
  • payload-master-2 → ID ${proxmox_virtual_environment_vm.payload_master_2.vm_id} → ${var.ip_address_base}.${var.ip_start + 4}
  • payload-master-3 → ID ${proxmox_virtual_environment_vm.payload_master_3.vm_id} → ${var.ip_address_base}.${var.ip_start + 5}

⚙️  PAYLOAD WORKERS:
  • payload-worker-1 → ID ${proxmox_virtual_environment_vm.payload_worker_1.vm_id} → ${var.ip_address_base}.${var.ip_start + 6}
  • payload-worker-2 → ID ${proxmox_virtual_environment_vm.payload_worker_2.vm_id} → ${var.ip_address_base}.${var.ip_start + 7}
  • payload-worker-3 → ID ${proxmox_virtual_environment_vm.payload_worker_3.vm_id} → ${var.ip_address_base}.${var.ip_start + 8}

📦 SERVICES:
  • cicd → ID ${proxmox_virtual_environment_vm.cicd.vm_id} → ${var.ip_address_base}.${var.ip_start + 9}

📍 Serveur : ${var.proxmox_node}
💾 Stockage : local-lvm
🌐 Réseau   : ${var.network_bridge}

✅ Total: 10 VMs déployées avec succès !

💡 Prochaines étapes:
   1. Démarrer les VMs depuis Proxmox UI
   2. Se connecter: ssh root@${var.ip_address_base}.${var.ip_start}
   3. Installer RKE2 sur les nodes Rancher
   4. Joindre les Payload nodes au cluster

EOT
}

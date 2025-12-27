#!/bin/bash

# ========================================
# Script de déploiement des 9 VMs Kubernetes
# 3 VMs Rancher (Control Plane) + 6 VMs Payload
# ========================================

set -e  # Arrêter en cas d'erreur

# Configuration
TEMPLATE_ID=9100
TEMPLATE_NAME="rocky-9-cloud-template"
STORAGE="local-lvm"
BRIDGE="vmbr0"
SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDaHjlYm77/7UDnQxsl6kd+cLcN8ZKxdqqJ/3qepSjmYuPK5AZjTc8r9XzUiYjzTtD3rt6tvr4LkXF5hPC0FAc0trjSlqwPzsqtCVh4Zk7YQhf4pYoznMs19eSQibM4n4dZogRhc4CoZf8+bAOLboHD2vdqy+mRE4rI6EdykXQC7BQ6TMzQoRE7l+nT1o38wX/FpNdcovT7CaCJUOm+6Gg8Y0aNUZax/Vg3C7ZbUSJIbvvJLaqiBbsQRs/sbX8iOyftng1yxQPxWJgA1JXYKjrrSsZQkPjdP0HXuywqu8fYFAToEld7szmuTa0qj+woKPoCXzgwaO76/l7qFv3iC/gPd9zaVqtIznycI6vX5gnj8XvMs1HRNS3o/ElyMWgWeeNdvqSwyJWihNrd70spMTvC5JzfglgwXuzIMq6mlbEh6YQvN7SSaH4WEOcNF5/yXjIfDZxg246tMDbQ9JjdQ3QzLq7Kuwdtx/LAhyITpcfbweIPXkWHGuRvjkGX0L7ieFU= nsfab@gaby"

# Réseau
IP_BASE="192.168.1"
IP_START=110
GATEWAY="192.168.1.1"
NAMESERVER="192.168.1.1"

# VMs IDs
VM_ID_START=102

echo "========================================="
echo "Déploiement des 9 VMs Kubernetes"
echo "========================================="
echo ""

# Vérifier que le template existe
if ! qm status $TEMPLATE_ID &>/dev/null; then
    echo "❌ ERREUR: Le template $TEMPLATE_NAME (ID: $TEMPLATE_ID) n'existe pas!"
    echo "Veuillez d'abord exécuter create-rocky9-template.sh"
    exit 1
fi

echo "✓ Template trouvé: $TEMPLATE_NAME (ID: $TEMPLATE_ID)"
echo ""

# Fonction pour créer une VM
create_vm() {
    local VM_ID=$1
    local VM_NAME=$2
    local CORES=$3
    local MEMORY=$4
    local IP_OFFSET=$5

    local IP="${IP_BASE}.$(($IP_START + $IP_OFFSET))"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Création de $VM_NAME (ID: $VM_ID)"
    echo "  - CPU: $CORES cores"
    echo "  - RAM: $MEMORY MB"
    echo "  - IP: $IP"

    # Vérifier si la VM existe déjà
    if qm status $VM_ID &>/dev/null; then
        echo "⚠  La VM $VM_ID existe déjà, destruction..."
        qm stop $VM_ID 2>/dev/null || true
        sleep 2
        qm destroy $VM_ID
    fi

    # Cloner le template
    echo "  → Clonage du template..."
    qm clone $TEMPLATE_ID $VM_ID --name $VM_NAME --full 1 --storage $STORAGE

    # Configurer la VM
    echo "  → Configuration..."
    qm set $VM_ID --cores $CORES
    qm set $VM_ID --memory $MEMORY
    qm set $VM_ID --ipconfig0 "ip=${IP}/24,gw=${GATEWAY}"
    qm set $VM_ID --nameserver $NAMESERVER
    qm set $VM_ID --sshkeys "${SSH_KEY}"

    echo "✓ $VM_NAME créée avec succès!"
    echo ""
}

# ===== RANCHER VMs (Control Plane) =====
echo "📦 CRÉATION DES VMs RANCHER (Control Plane)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

create_vm $((VM_ID_START + 0)) "rancher-1" 2 8192 0
create_vm $((VM_ID_START + 1)) "rancher-2" 2 8192 1
create_vm $((VM_ID_START + 2)) "rancher-3" 2 8192 2

# ===== PAYLOAD MASTER VMs =====
echo "🔧 CRÉATION DES VMs PAYLOAD MASTERS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

create_vm $((VM_ID_START + 3)) "payload-master-1" 2 4096 3
create_vm $((VM_ID_START + 4)) "payload-master-2" 2 4096 4
create_vm $((VM_ID_START + 5)) "payload-master-3" 2 4096 5

# ===== PAYLOAD WORKER VMs =====
echo "⚙️  CRÉATION DES VMs PAYLOAD WORKERS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

create_vm $((VM_ID_START + 6)) "payload-worker-1" 3 8192 6
create_vm $((VM_ID_START + 7)) "payload-worker-2" 3 8192 7
create_vm $((VM_ID_START + 8)) "payload-worker-3" 3 8192 8

# ===== RÉSUMÉ =====
echo "========================================="
echo "✅ DÉPLOIEMENT TERMINÉ AVEC SUCCÈS!"
echo "========================================="
echo ""
echo "📊 RÉSUMÉ DES VMs CRÉÉES:"
echo ""
echo "🎯 RANCHER (Control Plane):"
echo "  • rancher-1        → ID 102 → 192.168.1.110 → 2C/8GB"
echo "  • rancher-2        → ID 103 → 192.168.1.111 → 2C/8GB"
echo "  • rancher-3        → ID 104 → 192.168.1.112 → 2C/8GB"
echo ""
echo "🔧 PAYLOAD MASTERS:"
echo "  • payload-master-1 → ID 105 → 192.168.1.113 → 2C/4GB"
echo "  • payload-master-2 → ID 106 → 192.168.1.114 → 2C/4GB"
echo "  • payload-master-3 → ID 107 → 192.168.1.115 → 2C/4GB"
echo ""
echo "⚙️  PAYLOAD WORKERS:"
echo "  • payload-worker-1 → ID 108 → 192.168.1.116 → 3C/8GB"
echo "  • payload-worker-2 → ID 109 → 192.168.1.117 → 3C/8GB"
echo "  • payload-worker-3 → ID 110 → 192.168.1.118 → 3C/8GB"
echo ""
echo "📋 PROCHAINES ÉTAPES:"
echo "  1. Démarrer les VMs: qm start <ID>"
echo "  2. Se connecter en SSH: ssh root@192.168.1.110"
echo "  3. Installer RKE2 sur les nodes Rancher"
echo "  4. Joindre les Payload nodes au cluster"
echo ""
echo "💡 Pour démarrer toutes les VMs:"
echo "   for i in {102..110}; do qm start \$i; done"
echo ""
echo "========================================="

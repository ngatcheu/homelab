#!/bin/bash

# ========================================
# Script de vérification des prérequis Proxmox
# À exécuter sur le serveur Proxmox AVANT terraform apply
# ========================================

set -e

echo "========================================="
echo "🔍 VÉRIFICATION DES PRÉREQUIS PROXMOX"
echo "========================================="
echo ""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Fonction de check
check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
        ((ERRORS++))
    fi
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# ===== 1. VÉRIFIER VERSION PROXMOX =====
echo "📦 1. Version Proxmox VE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
PVE_VERSION=$(pveversion | grep "pve-manager" | awk '{print $2}')
echo "Version installée: $PVE_VERSION"

if [[ "$PVE_VERSION" =~ ^[89]\. ]]; then
    check "Proxmox VE 8.x ou 9.x détecté"
else
    warn "Version Proxmox < 8.x (recommandé: 8.x ou 9.x)"
fi
echo ""

# ===== 2. VÉRIFIER STOCKAGE =====
echo "💾 2. Stockage disponible"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Vérifier local-lvm
if pvesm status | grep -q "local-lvm"; then
    check "Stockage 'local-lvm' disponible"

    # Vérifier l'espace disponible (min 300GB recommandé pour 11 VMs)
    AVAILABLE=$(pvesm status -storage local-lvm | tail -1 | awk '{print $4}')
    AVAILABLE_GB=$((AVAILABLE / 1024 / 1024 / 1024))

    echo "Espace disponible: ${AVAILABLE_GB} GB"

    if [ $AVAILABLE_GB -lt 300 ]; then
        warn "Espace < 300GB (recommandé pour 11 VMs avec 295GB total)"
    else
        check "Espace suffisant (${AVAILABLE_GB} GB >= 300GB)"
    fi
else
    echo -e "${RED}✗${NC} Stockage 'local-lvm' introuvable"
    ((ERRORS++))
fi
echo ""

# ===== 3. VÉRIFIER BRIDGES RÉSEAU =====
echo "🌐 3. Bridges réseau"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# vmbr0 (existant par défaut)
if ip link show vmbr0 &>/dev/null; then
    check "Bridge vmbr0 existe (réseau principal)"
else
    echo -e "${RED}✗${NC} Bridge vmbr0 introuvable"
    ((ERRORS++))
fi

# vmbr1 (Management - à créer)
if ip link show vmbr1 &>/dev/null; then
    check "Bridge vmbr1 existe (Management 192.168.10.0/24)"
else
    warn "Bridge vmbr1 introuvable - sera nécessaire pour Phase 2 (OPNsense)"
    echo "   Commande: pvesh create /nodes/\$(hostname)/network --iface vmbr1 --type bridge --autostart 1"
fi

# vmbr2 (Production - à créer)
if ip link show vmbr2 &>/dev/null; then
    check "Bridge vmbr2 existe (Production 192.168.20.0/24)"
else
    warn "Bridge vmbr2 introuvable - sera nécessaire pour Phase 2 (OPNsense)"
    echo "   Commande: pvesh create /nodes/\$(hostname)/network --iface vmbr2 --type bridge --autostart 1"
fi
echo ""

# ===== 4. VÉRIFIER TEMPLATE ROCKY LINUX 9 =====
echo "📀 4. Template Rocky Linux 9"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TEMPLATE_ID=9100
if qm status $TEMPLATE_ID &>/dev/null; then
    TEMPLATE_NAME=$(qm config $TEMPLATE_ID | grep "^name:" | awk '{print $2}')
    check "Template trouvé: $TEMPLATE_NAME (ID: $TEMPLATE_ID)"
else
    echo -e "${RED}✗${NC} Template Rocky Linux 9 (ID: $TEMPLATE_ID) introuvable"
    echo "   Exécutez: ./create-rocky9-template.sh"
    ((ERRORS++))
fi
echo ""

# ===== 5. VÉRIFIER ISO OPNSENSE =====
echo "🔒 5. ISO OPNsense (pour Phase 2)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ISO_PATH="/var/lib/vz/template/iso/OPNsense-25.7-dvd-amd64.iso"
if [ -f "$ISO_PATH" ]; then
    check "ISO OPNsense trouvé: $ISO_PATH"
else
    warn "ISO OPNsense introuvable (nécessaire pour Phase 2)"
    echo "   Télécharger: wget -P /var/lib/vz/template/iso https://mirror.ams1.nl.leaseweb.net/opnsense/releases/25.7/OPNsense-25.7-dvd-amd64.iso.bz2"
    echo "   Décompresser: bzip2 -d /var/lib/vz/template/iso/OPNsense-25.7-dvd-amd64.iso.bz2"
fi
echo ""

# ===== 6. VÉRIFIER VMs EXISTANTES =====
echo "🖥️  6. Conflit avec VMs existantes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CONFLICT=0
for VM_ID in {102..111} 200; do
    if qm status $VM_ID &>/dev/null; then
        VM_NAME=$(qm config $VM_ID | grep "^name:" | awk '{print $2}')
        echo -e "${YELLOW}⚠${NC} VM $VM_ID existe déjà: $VM_NAME"
        ((CONFLICT++))
    fi
done

if [ $CONFLICT -eq 0 ]; then
    check "Aucun conflit d'ID de VM (102-111, 200)"
else
    warn "$CONFLICT VM(s) en conflit - seront détruites par terraform apply"
    echo "   Ou exécutez: ./cleanup-vms.sh"
fi
echo ""

# ===== 7. VÉRIFIER RESSOURCES SERVEUR =====
echo "⚙️  7. Ressources serveur"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# CPU
CPU_CORES=$(nproc)
echo "CPU cores disponibles: $CPU_CORES"
if [ $CPU_CORES -ge 16 ]; then
    check "CPU >= 16 cores (requis: 25 cores pour 11 VMs)"
else
    warn "CPU < 16 cores (total requis: 25 cores pour 11 VMs)"
fi

# RAM
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
echo "RAM totale: ${TOTAL_RAM_GB} GB"
if [ $TOTAL_RAM_GB -ge 64 ]; then
    check "RAM >= 64 GB (requis: 70 GB pour 11 VMs)"
else
    warn "RAM < 64 GB (total requis: 70 GB pour 11 VMs)"
fi
echo ""

# ===== 8. VÉRIFIER CONNECTIVITÉ RÉSEAU =====
echo "🌍 8. Connectivité réseau"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Ping vers la gateway
GATEWAY="192.168.1.1"
if ping -c 1 -W 2 $GATEWAY &>/dev/null; then
    check "Gateway $GATEWAY accessible"
else
    echo -e "${RED}✗${NC} Gateway $GATEWAY inaccessible"
    ((ERRORS++))
fi

# Vérifier que les IPs ne sont pas déjà utilisées
echo ""
echo "Vérification des IPs 192.168.1.110-119, 192.168.1.200..."
IP_CONFLICTS=0
for IP_OFFSET in {110..119} 200; do
    IP="192.168.1.${IP_OFFSET}"
    if ping -c 1 -W 1 $IP &>/dev/null; then
        echo -e "${YELLOW}⚠${NC} IP $IP déjà utilisée"
        ((IP_CONFLICTS++))
    fi
done

if [ $IP_CONFLICTS -eq 0 ]; then
    check "Aucun conflit d'IP (192.168.1.110-119, 200)"
else
    warn "$IP_CONFLICTS IP(s) déjà utilisées - risque de conflit réseau"
fi
echo ""

# ===== RÉSUMÉ =====
echo "========================================="
echo "📊 RÉSUMÉ DE LA VÉRIFICATION"
echo "========================================="
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ TOUT EST PRÊT POUR LE DÉPLOIEMENT !${NC}"
    echo ""
    echo "Vous pouvez lancer Terraform:"
    echo "  cd /path/to/proxmox-terraform"
    echo "  terraform init"
    echo "  terraform plan"
    echo "  terraform apply"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  PRÊT AVEC $WARNINGS AVERTISSEMENT(S)${NC}"
    echo ""
    echo "Vous pouvez continuer, mais certaines fonctionnalités"
    echo "nécessiteront une configuration supplémentaire."
else
    echo -e "${RED}❌ $ERRORS ERREUR(S) CRITIQUE(S) DÉTECTÉE(S)${NC}"
    echo ""
    echo "Corrigez les erreurs avant de continuer."
    exit 1
fi

echo ""
echo "========================================="

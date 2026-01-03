#!/bin/bash

# ========================================
# Script de création des bridges réseau Proxmox
# vmbr1 (Management) et vmbr2 (Production)
# À exécuter sur le serveur Proxmox
# ========================================

set -e

echo "========================================="
echo "🌐 CRÉATION DES BRIDGES RÉSEAU"
echo "========================================="
echo ""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NODE=$(hostname)

# ===== 1. VÉRIFIER VMBR0 =====
echo "1️⃣  Vérification du bridge existant (vmbr0)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ip link show vmbr0 &>/dev/null; then
    echo -e "${GREEN}✓${NC} vmbr0 existe (réseau principal)"
else
    echo -e "${RED}✗${NC} vmbr0 introuvable - ERREUR CRITIQUE"
    exit 1
fi
echo ""

# ===== 2. CRÉER VMBR1 (MANAGEMENT) =====
echo "2️⃣  Création de vmbr1 (Management - 192.168.10.0/24)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ip link show vmbr1 &>/dev/null; then
    echo -e "${YELLOW}⚠${NC} vmbr1 existe déjà, skip..."
else
    echo "Création de vmbr1..."

    # Méthode 1 : Via pvesh (API Proxmox)
    if command -v pvesh &>/dev/null; then
        pvesh create /nodes/$NODE/network --iface vmbr1 --type bridge \
            --autostart 1 \
            --comments "Management Network - 192.168.10.0/24 - OPNsense LAN"

        echo -e "${GREEN}✓${NC} vmbr1 créé via pvesh"
    else
        # Méthode 2 : Modification manuelle de /etc/network/interfaces
        echo "pvesh non disponible, modification manuelle..."

        cat >> /etc/network/interfaces <<EOF

# Management Network (vmbr1)
auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # Management Network - 192.168.10.0/24 - OPNsense LAN
EOF

        echo -e "${GREEN}✓${NC} vmbr1 ajouté à /etc/network/interfaces"
    fi
fi
echo ""

# ===== 3. CRÉER VMBR2 (PRODUCTION) =====
echo "3️⃣  Création de vmbr2 (Production - 192.168.20.0/24)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ip link show vmbr2 &>/dev/null; then
    echo -e "${YELLOW}⚠${NC} vmbr2 existe déjà, skip..."
else
    echo "Création de vmbr2..."

    # Méthode 1 : Via pvesh (API Proxmox)
    if command -v pvesh &>/dev/null; then
        pvesh create /nodes/$NODE/network --iface vmbr2 --type bridge \
            --autostart 1 \
            --comments "Production Network - 192.168.20.0/24 - OPNsense OPT1"

        echo -e "${GREEN}✓${NC} vmbr2 créé via pvesh"
    else
        # Méthode 2 : Modification manuelle de /etc/network/interfaces
        echo "pvesh non disponible, modification manuelle..."

        cat >> /etc/network/interfaces <<EOF

# Production Network (vmbr2)
auto vmbr2
iface vmbr2 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # Production Network - 192.168.20.0/24 - OPNsense OPT1
EOF

        echo -e "${GREEN}✓${NC} vmbr2 ajouté à /etc/network/interfaces"
    fi
fi
echo ""

# ===== 4. APPLIQUER LA CONFIGURATION =====
echo "4️⃣  Application de la configuration réseau"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Activer les bridges immédiatement (sans reboot)
if ! ip link show vmbr1 &>/dev/null; then
    echo "Activation de vmbr1..."
    ip link add name vmbr1 type bridge
    ip link set vmbr1 up
    echo -e "${GREEN}✓${NC} vmbr1 activé"
fi

if ! ip link show vmbr2 &>/dev/null; then
    echo "Activation de vmbr2..."
    ip link add name vmbr2 type bridge
    ip link set vmbr2 up
    echo -e "${GREEN}✓${NC} vmbr2 activé"
fi
echo ""

# ===== 5. VÉRIFICATION =====
echo "5️⃣  Vérification des bridges"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Bridges actuels:"
ip -br link show type bridge

echo ""
echo "Détails des bridges:"
for BRIDGE in vmbr0 vmbr1 vmbr2; do
    if ip link show $BRIDGE &>/dev/null; then
        STATE=$(ip link show $BRIDGE | grep -oP 'state \K\w+')
        echo -e "  ${GREEN}✓${NC} $BRIDGE - State: $STATE"
    else
        echo -e "  ${RED}✗${NC} $BRIDGE - ABSENT"
    fi
done
echo ""

# ===== 6. CONFIGURATION FINALE =====
echo "========================================="
echo "✅ CONFIGURATION TERMINÉE"
echo "========================================="
echo ""

echo "📊 Résumé des bridges:"
echo ""
echo "  • vmbr0 → 192.168.1.0/24   (Réseau principal - Internet)"
echo "  • vmbr1 → 192.168.10.0/24  (Management - OPNsense LAN)"
echo "  • vmbr2 → 192.168.20.0/24  (Production - OPNsense OPT1)"
echo ""

echo "⚙️  Architecture réseau après Phase 2 (OPNsense):"
echo ""
echo "  Internet → Box (192.168.1.1) → vmbr0"
echo "                                    ↓"
echo "                               OPNsense (192.168.1.200)"
echo "                                    ↓"
echo "                         ┌──────────┴──────────┐"
echo "                         ↓                     ↓"
echo "                      vmbr1                 vmbr2"
echo "                  (Management)          (Production)"
echo "                 192.168.10.0/24       192.168.20.0/24"
echo ""

echo "📝 IMPORTANT:"
echo ""
echo "  Les bridges sont créés MAIS les IPs seront gérées par OPNsense."
echo "  Configuration OPNsense (Phase 2):"
echo "    • Interface LAN (vtnet0)  → vmbr1 → Gateway 192.168.10.1"
echo "    • Interface OPT1 (vtnet1) → vmbr2 → Gateway 192.168.20.1"
echo "    • Interface OPT2 (vtnet2) → vmbr0 → Uplink 192.168.1.200"
echo ""

echo "🔄 Redémarrage recommandé:"
echo ""
echo "  Pour garantir la persistance de la configuration,"
echo "  redémarrez le serveur Proxmox:"
echo ""
echo "    reboot"
echo ""

echo "✅ Ou appliquez la config réseau sans reboot:"
echo ""
echo "    ifreload -a"
echo ""

echo "========================================="

#!/bin/bash

# ========================================
# Script de nettoyage des VMs existantes
# Supprime les VMs 102-110 pour permettre
# à Terraform de créer les nouvelles VMs
# ========================================

set -e

echo "========================================="
echo "Nettoyage des VMs existantes (102-110)"
echo "========================================="
echo ""

# Fonction pour supprimer une VM
cleanup_vm() {
    local VM_ID=$1

    if qm status $VM_ID &>/dev/null; then
        echo "🗑️  Suppression de la VM $VM_ID..."

        # Arrêter la VM si elle est en cours d'exécution
        qm stop $VM_ID 2>/dev/null || true
        sleep 2

        # Détruire la VM
        qm destroy $VM_ID
        echo "   ✓ VM $VM_ID supprimée"
    else
        echo "⏭️  VM $VM_ID n'existe pas, passage au suivant"
    fi
}

# Supprimer toutes les VMs de 102 à 110
for i in {102..110}; do
    cleanup_vm $i
done

echo ""
echo "========================================="
echo "✅ NETTOYAGE TERMINÉ!"
echo "========================================="
echo ""
echo "Vous pouvez maintenant exécuter:"
echo "  terraform apply"
echo ""

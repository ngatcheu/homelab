#!/bin/bash

# Configuration
TEMPLATE_ID=9100
TEMPLATE_NAME="rocky-9-cloud-template"
STORAGE="local-lvm"
MEMORY=2048
BRIDGE="vmbr0"

echo "========================================="
echo "Création du template Rocky Linux 9"
echo "========================================="

# Vérifier si le template existe déjà
if qm status $TEMPLATE_ID &>/dev/null; then
    echo "✓ Template existe déjà (ID: $TEMPLATE_ID)"
    exit 0
fi

# Télécharger l'image Rocky Linux 9 cloud
echo "Téléchargement de l'image Rocky Linux 9..."
cd /tmp
wget -O rocky9-cloud.qcow2 https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2

# Créer la VM
echo "Création de la VM..."
qm create $TEMPLATE_ID --name $TEMPLATE_NAME --memory $MEMORY --net0 virtio,bridge=$BRIDGE --cores 2 --cpu host

# Importer le disque
echo "Import du disque..."
qm importdisk $TEMPLATE_ID rocky9-cloud.qcow2 $STORAGE

# Configurer la VM
echo "Configuration..."
qm set $TEMPLATE_ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$TEMPLATE_ID-disk-0
qm set $TEMPLATE_ID --ide2 $STORAGE:cloudinit
qm set $TEMPLATE_ID --boot c --bootdisk scsi0
qm set $TEMPLATE_ID --serial0 socket --vga serial0
qm set $TEMPLATE_ID --agent enabled=1
qm set $TEMPLATE_ID --ciuser root
qm set $TEMPLATE_ID --ipconfig0 ip=dhcp

# Convertir en template
echo "Conversion en template..."
qm template $TEMPLATE_ID

# Nettoyer
rm -f /tmp/rocky9-cloud.qcow2

echo "========================================="
echo "✓ Template créé avec succès!"
echo "========================================="

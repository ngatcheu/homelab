# ========================================
# Instructions pour créer le template Rocky Linux 9
# ========================================
#
# AVANT de lancer 'terraform apply', vous devez créer le template Rocky Linux 9.
#
# Exécutez le script suivant sur votre serveur Proxmox:
#   1. Copiez le fichier create-rocky9-template.sh sur votre serveur Proxmox
#   2. Exécutez: chmod +x create-rocky9-template.sh
#   3. Lancez: ./create-rocky9-template.sh
#
# Ou exécutez ces commandes directement dans le Shell Proxmox (Web UI):
#
# TEMPLATE_ID=9100
# TEMPLATE_NAME="rocky-9-cloud-template"
# STORAGE="local-lvm"
#
# cd /tmp
# wget -O rocky9-cloud.qcow2 https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2
#
# qm create $TEMPLATE_ID --name $TEMPLATE_NAME --memory 2048 --net0 virtio,bridge=vmbr0 --cores 2 --cpu host
# qm importdisk $TEMPLATE_ID rocky9-cloud.qcow2 $STORAGE
# qm set $TEMPLATE_ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$TEMPLATE_ID-disk-0
# qm set $TEMPLATE_ID --ide2 $STORAGE:cloudinit
# qm set $TEMPLATE_ID --boot c --bootdisk scsi0
# qm set $TEMPLATE_ID --serial0 socket --vga serial0
# qm set $TEMPLATE_ID --agent enabled=1
# qm set $TEMPLATE_ID --ciuser root
# qm set $TEMPLATE_ID --ipconfig0 ip=dhcp
# qm template $TEMPLATE_ID
# rm -f /tmp/rocky9-cloud.qcow2
#
# ========================================

# Déploiement Kubernetes sur Proxmox avec Terraform

Infrastructure as Code pour déployer un cluster Kubernetes sur Proxmox VE avec 9 VMs :
- 3 VMs Rancher (Control Plane)
- 3 VMs Payload Masters
- 3 VMs Payload Workers

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Proxmox VE Cluster                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  🎯 RANCHER (Control Plane)                                  │
│  ├─ rancher-1      → 102 → 192.168.1.110 → 2C/8GB           │
│  ├─ rancher-2      → 103 → 192.168.1.111 → 2C/8GB           │
│  └─ rancher-3      → 104 → 192.168.1.112 → 2C/8GB           │
│                                                               │
│  🔧 PAYLOAD MASTERS                                          │
│  ├─ payload-master-1 → 105 → 192.168.1.113 → 2C/4GB         │
│  ├─ payload-master-2 → 106 → 192.168.1.114 → 2C/4GB         │
│  └─ payload-master-3 → 107 → 192.168.1.115 → 2C/4GB         │
│                                                               │
│  ⚙️  PAYLOAD WORKERS                                         │
│  ├─ payload-worker-1 → 108 → 192.168.1.116 → 3C/8GB         │
│  ├─ payload-worker-2 → 109 → 192.168.1.117 → 3C/8GB         │
│  └─ payload-worker-3 → 110 → 192.168.1.118 → 3C/8GB         │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Prérequis

### Logiciels requis
- Terraform >= 1.12.2
- Accès à un serveur Proxmox VE
- Connexion réseau au serveur Proxmox

### Infrastructure Proxmox
- Serveur Proxmox VE opérationnel
- Stockage `local-lvm` disponible
- Bridge réseau `vmbr0` configuré
- Accès root au serveur Proxmox

## Installation

### Étape 1 : Créer le template Rocky Linux 9

Avant de déployer les VMs, vous devez créer un template cloud-init Rocky Linux 9 sur votre serveur Proxmox.

**Option A : Via le script fourni**

Copiez et exécutez le script sur votre serveur Proxmox :

```bash
# Copier le script sur Proxmox
scp create-rocky9-template.sh root@192.168.1.100:/tmp/

# Se connecter à Proxmox
ssh root@192.168.1.100

# Exécuter le script
chmod +x /tmp/create-rocky9-template.sh
/tmp/create-rocky9-template.sh
```

**Option B : Via le Shell Proxmox Web UI**

1. Connectez-vous à l'interface web Proxmox : https://192.168.1.100:8006
2. Cliquez sur votre node → Shell
3. Copiez-collez le contenu du script [create-rocky9-template.sh](create-rocky9-template.sh)

Le template créé aura :
- **ID** : 9100
- **Nom** : rocky-9-cloud-template
- **Stockage** : local-lvm

### Étape 2 : Configurer Terraform

Configurez vos variables dans le fichier `terraform.tfvars` :

```hcl
# Mot de passe Proxmox (OBLIGATOIRE)
proxmox_password = "votre-mot-de-passe-root"

# Clé SSH publique pour l'accès aux VMs (OBLIGATOIRE)
ssh_public_key = "ssh-rsa AAAAB3... votre-clé-publique"

# Les autres valeurs ont des valeurs par défaut
```

### Étape 3 : Initialiser Terraform

```bash
# Initialiser Terraform et télécharger le provider
terraform init

# Vérifier la configuration
terraform validate

# Voir le plan de déploiement
terraform plan
```

### Étape 4 : Déployer les VMs

```bash
# Déployer l'infrastructure
terraform apply

# Confirmer avec 'yes' quand demandé
```

Le déploiement prend environ 5-10 minutes.

## Configuration

### Variables disponibles

#### Configuration Proxmox
```hcl
proxmox_node     = "devsecops-dojo"  # Nom du node Proxmox
proxmox_host     = "192.168.1.100"   # IP du serveur Proxmox
proxmox_password = ""                # Mot de passe root (OBLIGATOIRE)
```

#### Configuration VMs
```hcl
vm_id_start = 102                    # Premier ID de VM

# Rancher (Control Plane)
rancher_cpu_cores = 2
rancher_memory    = 8192             # RAM en MB

# Payload Masters
payload_master_cpu_cores = 2
payload_master_memory    = 4096

# Payload Workers
payload_worker_cpu_cores = 3
payload_worker_memory    = 8192
```

#### Configuration Réseau
```hcl
network_bridge   = "vmbr0"           # Bridge réseau
ip_address_base  = "192.168.1"       # Base des IPs
ip_start         = 110               # Première IP : 192.168.1.110
gateway          = "192.168.1.1"     # Passerelle
nameserver       = "192.168.1.1"     # Serveur DNS
```

#### Clé SSH
```hcl
ssh_public_key = "ssh-rsa AAAAB3..."  # Votre clé SSH publique
```

## Gestion de l'infrastructure

### Voir les outputs

Après le déploiement :

```bash
terraform output
```

Outputs disponibles :
- `rancher_vm_names` : Noms des VMs Rancher
- `rancher_vm_ids` : IDs des VMs Rancher
- `payload_vm_names` : Noms des VMs Payload
- `payload_vm_ids` : IDs des VMs Payload
- `deployment_summary` : Résumé complet du déploiement

### Démarrer les VMs

Les VMs sont créées mais non démarrées. Pour les démarrer :

```bash
# Depuis le serveur Proxmox
for i in {102..110}; do qm start $i; done
```

### Se connecter aux VMs

```bash
# Se connecter à la première VM Rancher
ssh root@192.168.1.110

# Ou utiliser l'IP de n'importe quelle VM
ssh root@192.168.1.113  # payload-master-1
```

### Modifier l'infrastructure

1. Modifiez les fichiers `.tf` ou `terraform.tfvars`
2. Planifiez les changements : `terraform plan`
3. Appliquez : `terraform apply`

### Détruire l'infrastructure

```bash
# Supprimer toutes les VMs créées
terraform destroy
```

## Scripts utilitaires

### cleanup-vms.sh

Nettoie les VMs existantes (102-110) en cas de conflit :

```bash
# Sur le serveur Proxmox
bash cleanup-vms.sh
```

Utilisez ce script si vous obtenez l'erreur "config file already exists".

## Prochaines étapes

Une fois les VMs déployées et démarrées :

1. **Installer RKE2 sur les nodes Rancher**
   ```bash
   # Se connecter au premier node Rancher
   ssh root@192.168.1.110

   # Installer RKE2
   curl -sfL https://get.rke2.io | sh -
   systemctl enable rke2-server.service
   systemctl start rke2-server.service
   ```

2. **Joindre les autres nodes Rancher au cluster**

3. **Configurer les Payload nodes**
   - Installer RKE2 en mode agent
   - Joindre au cluster Rancher

4. **Déployer vos applications**

## Structure du projet

```
proxmox-terraform/
├── README.md                      # Ce fichier
├── .gitignore                     # Fichiers à ignorer par git
├── providers.tf                   # Configuration du provider bpg/proxmox
├── variables.tf                   # Définition des variables
├── terraform.tfvars               # Valeurs des variables
├── main.tf                        # Définition des 9 VMs
├── outputs.tf                     # Outputs Terraform
├── create-rocky9-template.sh      # Script de création du template
└── cleanup-vms.sh                 # Script de nettoyage des VMs
```

## Dépannage

### Erreur : "template not found"

Le template Rocky Linux 9 n'existe pas dans Proxmox.

**Solution** : Exécutez [create-rocky9-template.sh](create-rocky9-template.sh) sur votre serveur Proxmox.

### Erreur : "config file already exists"

Des VMs avec les IDs 102-110 existent déjà dans Proxmox.

**Solution** : Exécutez [cleanup-vms.sh](cleanup-vms.sh) sur votre serveur Proxmox pour les supprimer.

### Erreur : "permission denied"

Les permissions root ne sont pas suffisantes.

**Solution** : Vérifiez que vous utilisez bien `root@pam` comme username dans [providers.tf](providers.tf).

### Les VMs ne démarrent pas

**Solution** : Vérifiez les logs Proxmox :
```bash
# Sur le serveur Proxmox
qm status 102
journalctl -xe
```

### Connexion SSH refusée

**Solution** :
1. Vérifiez que la VM est bien démarrée : `qm status 102`
2. Vérifiez que cloud-init a bien configuré votre clé SSH
3. Accédez à la console Proxmox pour vérifier

## Sécurité

- Le fichier `terraform.tfvars` contient des informations sensibles (mot de passe Proxmox)
- Il est automatiquement exclu du dépôt git via `.gitignore`
- Ne committez JAMAIS ce fichier dans git
- Utilisez des secrets managers (Vault, etc.) en production

## Provider

Ce projet utilise le provider **bpg/proxmox** (v0.50.0) :
- Documentation : https://registry.terraform.io/providers/bpg/proxmox/latest/docs
- Plus moderne et stable que telmate/proxmox
- Meilleur support de cloud-init

## Licence

MIT

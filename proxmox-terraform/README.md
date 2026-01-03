# Déploiement Kubernetes sur Proxmox avec Terraform

Infrastructure as Code pour déployer un cluster Kubernetes sur Proxmox VE avec 10 VMs :
- 3 VMs Rancher (Control Plane)
- 3 VMs Payload Masters
- 3 VMs Payload Workers
- 1 VM CI/CD

## Démarrage rapide

**Nouveau ?** Suivez le guide complet : [PHASE1-DEPLOYMENT.md](PHASE1-DEPLOYMENT.md)

**Guide pas à pas Phase 1** :
1. Vérifier prérequis → [check-proxmox-prereqs.sh](check-proxmox-prereqs.sh)
2. Créer template Rocky 9 → [create-rocky9-template.sh](create-rocky9-template.sh)
3. Créer bridges réseau → [create-network-bridges.sh](create-network-bridges.sh)
4. Déployer avec Terraform → `terraform apply`

**Voir aussi** : [ROADMAP-DEVSECOPS.md](../ROADMAP-DEVSECOPS.md) pour la vue d'ensemble complète

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Proxmox VE Cluster                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  🎯 RANCHER (Control Plane)                                  │
│  ├─ rancher-1      → 110 → 192.168.1.110 → 2C/8GB           │
│  ├─ rancher-2      → 111 → 192.168.1.111 → 2C/8GB           │
│  └─ rancher-3      → 112 → 192.168.1.112 → 2C/8GB           │
│                                                               │
│  🔧 PAYLOAD MASTERS                                          │
│  ├─ payload-master-1 → 113 → 192.168.1.113 → 2C/4GB         │
│  ├─ payload-master-2 → 114 → 192.168.1.114 → 2C/4GB         │
│  └─ payload-master-3 → 115 → 192.168.1.115 → 2C/4GB         │
│                                                               │
│  ⚙️  PAYLOAD WORKERS                                         │
│  ├─ payload-worker-1 → 116 → 192.168.1.116 → 3C/8GB         │
│  ├─ payload-worker-2 → 117 → 192.168.1.117 → 3C/8GB         │
│  └─ payload-worker-3 → 118 → 192.168.1.118 → 3C/8GB         │
│                                                               │
│  📦 SERVICES                                                 │
│  └─ cicd           → 119 → 192.168.1.119 → 2C/8GB           │
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

# CI/CD
cicd_cpu_cores = 2
cicd_memory    = 8192
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

Les VMs Kubernetes et CI/CD sont créées mais non démarrées. Pour les démarrer :

```bash
# Depuis le serveur Proxmox - VMs Kubernetes + CI/CD
for i in {102..111}; do qm start $i; done

# OPNsense (VM 200) - Démarrer manuellement après installation
qm start 200
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

## Configuration OPNsense Firewall

### Vue d'ensemble

La VM OPNsense fonctionne comme un **firewall interne** avec 3 interfaces réseau pour segmenter votre infrastructure :

- **VM ID** : 200
- **CPU** : 2 cores
- **RAM** : 2 GB
- **Disque** : 20 GB
- **Boot** : ISO OPNsense-25.7-dvd-amd64.iso

### Architecture Réseau

**IMPORTANT : OPNsense est un firewall INTERNE, pas votre routeur principal !**

```
Internet → Box (192.168.1.1) → vmbr0 (192.168.1.0/24)
                                   ↓                  ↓
                              VMs existantes    OPNsense (192.168.1.200)
                           (Rancher, Payload)           ↓
                             continuent avec        ┌───┴───┐
                             box comme gateway      ↓       ↓
                                              vmbr1 (LAN) vmbr2 (OPT1)
                                           192.168.10.0/24 192.168.20.0/24
                                            Management    Production

Interfaces OPNsense:
  • vtnet0 (LAN)      → vmbr1 → 192.168.10.1/24  (Gateway Management)
  • vtnet1 (OPT1)     → vmbr2 → 192.168.20.1/24  (Gateway Production)
  • vtnet2 (OPT2)     → vmbr0 → 192.168.1.200/24 (Uplink Internet)
```

### Installation OPNsense

**1. Démarrer la VM depuis Proxmox UI**

La VM est créée en mode `started = false`. Démarrez-la manuellement depuis l'interface Proxmox.

**2. Installation depuis le DVD**

```bash
# Login installateur
login: installer
password: opnsense

# Suivre l'assistant d'installation
# - Keymap : fr.kbd (ou us)
# - Install : Option 2 - Install (UFS)
# - Disk : da0
# - Root password : [votre mot de passe sécurisé]
# - Complete Install → Reboot
```

**3. Assignment des interfaces (Premier boot)**

**IMPORTANT : OPNsense n'a PAS d'interface WAN dans cette configuration !**

```
Valid interfaces are:
vtnet0   BC:24:11:00:01:01  (vmbr1 - Management)
vtnet1   BC:24:11:00:01:02  (vmbr2 - Production)
vtnet2   BC:24:11:00:01:00  (vmbr0 - Uplink Internet)

Do you want to configure VLANs now? [y/n]: n

Enter the WAN interface name: [laissez VIDE - Appuyez sur Entrée]
Enter the LAN interface name: vtnet0
Enter the Optional 1 interface name: vtnet1
Enter the Optional 2 interface name: vtnet2
```

**Pourquoi pas de WAN ?** OPNsense est un firewall interne. L'accès Internet passe par vtnet2 (OPT2) qui se connecte à vmbr0 où votre box (192.168.1.1) reste le routeur principal.

**4. Configuration des interfaces (Console OPNsense)**

Menu principal → Option 2: Set interface IP address

**Interface LAN (vtnet0 - vmbr1) :**
```
IPv4 address: 192.168.10.1
Subnet: 24
DHCP server: y
DHCP range: 192.168.10.100 - 192.168.10.200
```

**Interface OPT1 (vtnet1 - vmbr2) :**
```
IPv4 address: 192.168.20.1
Subnet: 24
DHCP server: y
DHCP range: 192.168.20.100 - 192.168.20.200
```

**Interface OPT2 (vtnet2 - vmbr0 Uplink) :**
```
IPv4 address: 192.168.1.200
Subnet: 24
DHCP server: n (PAS de DHCP sur l'uplink !)
```

**5. Configuration Web UI**

Accès : https://192.168.10.1 (depuis une VM sur vmbr1)

```
Login: root
Password: [votre mot de passe]
```

**Configuration Gateway :**
- System → Gateways → Single
- Ajouter : BOX_GW → Interface OPT2 → IP 192.168.1.1
- Marquer comme default gateway

**Règles Firewall :**
- Firewall → Rules → LAN : Allow LAN to any
- Firewall → Rules → OPT1 : Allow OPT1 to any
- Firewall → NAT → Outbound : Mode Automatic

### Résumé des Interfaces

| Interface | Bridge | IP OPNsense | Réseau | DHCP Range | Rôle | Config OPNsense |
|-----------|--------|-------------|---------|------------|------|-----------------|
| vtnet0 | vmbr1 | 192.168.10.1/24 | Management | .100-.200 | Gateway interne | **LAN** |
| vtnet1 | vmbr2 | 192.168.20.1/24 | Production | .100-.200 | Gateway interne | **OPT1** |
| vtnet2 | vmbr0 | 192.168.1.200/24 | Internet | Aucun | Uplink Internet | **OPT2** |

### Points Importants

- OPNsense n'est **PAS** la gateway principale de votre réseau
- Vos VMs existantes sur vmbr0 (Rancher, Payload) continuent d'utiliser votre box comme gateway
- Seules les nouvelles VMs sur vmbr1 (Management) ou vmbr2 (Production) utiliseront OPNsense
- Pas de conflit DHCP car OPNsense ne fait pas de DHCP sur vmbr0

## Prochaines étapes

Une fois les VMs déployées et démarrées :

1. **Installer et configurer OPNsense** (voir section ci-dessus)

2. **Installer RKE2 sur les nodes Rancher**
   ```bash
   # Se connecter au premier node Rancher
   ssh root@192.168.1.110

   # Installer RKE2
   curl -sfL https://get.rke2.io | sh -
   systemctl enable rke2-server.service
   systemctl start rke2-server.service
   ```

3. **Joindre les autres nodes Rancher au cluster**

4. **Configurer les Payload nodes**
   - Installer RKE2 en mode agent
   - Joindre au cluster Rancher

5. **Configurer DNS et Certificats**
   - Installer cert-manager pour certificats automatiques
   - Déployer Pi-hole pour DNS interne
   - Configurer CoreDNS pour résolution .local
   - Voir détails complets dans [ROADMAP-DEVSECOPS.md](ROADMAP-DEVSECOPS.md) (Jour 8)

6. **Déployer vos applications**

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

Des VMs avec les IDs 102-111 ou 200 existent déjà dans Proxmox.

**Solution** :
```bash
# Supprimer les VMs Kubernetes/CI/CD (102-111)
for i in {102..111}; do qm destroy $i; done

# Supprimer OPNsense (200)
qm destroy 200
```

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

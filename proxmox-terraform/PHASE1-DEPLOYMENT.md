# Phase 1 : Déploiement Infrastructure de Base

Guide pas à pas pour déployer les 11 VMs du homelab DevSecOps.

## Vue d'ensemble Phase 1

**Objectif** : Déployer et configurer les 11 VMs sur Proxmox

**Durée estimée** : 1-2 heures

**Résultat attendu** :
- ✅ 11 VMs opérationnelles (3 Rancher, 6 Payload, 1 CI/CD, 1 OPNsense)
- ✅ Réseau configuré sur vmbr0 (192.168.1.0/24)
- ✅ Accès SSH fonctionnel sur toutes les VMs Linux
- ✅ Bases prêtes pour Phase 2 (Cluster Kubernetes)

---

## Prérequis matériels

Avant de commencer, vérifiez que votre serveur Proxmox dispose de:

| Ressource | Minimum | Recommandé |
|-----------|---------|------------|
| CPU | 16 cores | 32+ cores |
| RAM | 64 GB | 128 GB |
| Stockage | 350 GB | 500+ GB SSD NVMe |
| Réseau | 1 Gbps | 10 Gbps |

---

## Étape 1 : Préparer l'environnement de travail

### 1.1 Cloner le dépôt (si ce n'est pas déjà fait)

```bash
# Sur votre machine locale
git clone <votre-repo>
cd homelab/proxmox-terraform
```

### 1.2 Vérifier les fichiers Terraform

```bash
ls -la
```

Fichiers requis :
- ✅ `providers.tf` - Configuration du provider Proxmox
- ✅ `variables.tf` - Définition des variables
- ✅ `main.tf` - Définition des 11 VMs
- ✅ `outputs.tf` - Outputs après déploiement
- ✅ `terraform.tfvars` - Configuration personnalisée
- ✅ `.gitignore` - Protection des secrets

### 1.3 Configurer terraform.tfvars

**IMPORTANT** : Vous devez ajouter le mot de passe Proxmox dans `terraform.tfvars`

Éditez le fichier :

```bash
nano terraform.tfvars
```

Ajoutez cette ligne en haut du fichier :

```hcl
# ========================================
# OBLIGATOIRE : Mot de passe Proxmox
# ========================================
proxmox_password = "VOTRE_MOT_DE_PASSE_ROOT_PROXMOX"

# Le reste du fichier reste inchangé...
```

**⚠️ Sécurité** : Ce fichier est automatiquement exclu de Git via `.gitignore`. Ne le commitez JAMAIS !

---

## Étape 2 : Préparer le serveur Proxmox

### 2.1 Se connecter au serveur Proxmox

```bash
ssh root@192.168.1.100
```

### 2.2 Copier les scripts sur Proxmox

Depuis votre machine locale :

```bash
# Copier le script de vérification
scp check-proxmox-prereqs.sh root@192.168.1.100:/tmp/

# Copier le script de création du template
scp create-rocky9-template.sh root@192.168.1.100:/tmp/

# Optionnel : Script de création des bridges
scp create-network-bridges.sh root@192.168.1.100:/tmp/
```

### 2.3 Vérifier les prérequis Proxmox

Sur le serveur Proxmox :

```bash
cd /tmp
chmod +x check-proxmox-prereqs.sh
./check-proxmox-prereqs.sh
```

Ce script vérifie :
- ✅ Version Proxmox VE (8.x ou 9.x)
- ✅ Stockage `local-lvm` disponible (min 300GB)
- ✅ Bridge réseau `vmbr0` existant
- ⚠️ Bridges `vmbr1` et `vmbr2` (nécessaires pour Phase 2)
- ✅ Template Rocky Linux 9 (ID: 9100)
- ⚠️ ISO OPNsense (nécessaire pour Phase 2)
- ✅ Pas de conflit avec VMs existantes
- ✅ Ressources CPU/RAM suffisantes
- ✅ Connectivité réseau

**Si des erreurs critiques (❌) apparaissent** : corrigez-les avant de continuer.

**Si des avertissements (⚠️) apparaissent** : pas critique, mais à noter.

---

## Étape 3 : Créer le template Rocky Linux 9

### 3.1 Télécharger et créer le template

Sur le serveur Proxmox :

```bash
cd /tmp
chmod +x create-rocky9-template.sh
./create-rocky9-template.sh
```

Le script va :
1. Télécharger l'image Rocky Linux 9 Cloud (~800MB)
2. Créer la VM template (ID: 9100)
3. Configurer cloud-init
4. Convertir en template

**Durée** : 5-10 minutes (selon votre connexion)

### 3.2 Vérifier le template

```bash
qm list | grep 9100
```

Vous devriez voir :

```
9100 rocky-9-cloud-template   0      2048
```

---

## Étape 4 : Créer les bridges réseau (Optionnel - Phase 2)

**Note** : `vmbr1` et `vmbr2` sont nécessaires pour OPNsense (Phase 2). Vous pouvez les créer maintenant ou plus tard.

### 4.1 Via l'interface Web Proxmox (Recommandé)

1. Accédez à https://192.168.1.100:8006
2. Sélectionnez votre node → System → Network
3. Cliquez sur "Create" → "Linux Bridge"

**Bridge vmbr1 (Management)** :
- Name: `vmbr1`
- IPv4/CIDR: (laisser vide - OPNsense gérera)
- Autostart: ✅ Yes
- Comment: Management Network 192.168.10.0/24

**Bridge vmbr2 (Production)** :
- Name: `vmbr2`
- IPv4/CIDR: (laisser vide - OPNsense gérera)
- Autostart: ✅ Yes
- Comment: Production Network 192.168.20.0/24

4. Cliquez sur "Apply Configuration"
5. **Redémarrez le serveur Proxmox** (recommandé)

### 4.2 Via script (Alternative)

```bash
cd /tmp
chmod +x create-network-bridges.sh
./create-network-bridges.sh
```

Puis redémarrer :

```bash
reboot
```

---

## Étape 5 : Déployer les VMs avec Terraform

### 5.1 Initialiser Terraform

Retour sur votre machine locale :

```bash
cd homelab/proxmox-terraform

# Initialiser Terraform
terraform init
```

Terraform va télécharger le provider `bpg/proxmox` v0.50.0.

### 5.2 Valider la configuration

```bash
# Vérifier la syntaxe
terraform validate

# Voir le plan de déploiement
terraform plan
```

Terraform devrait afficher :

```
Plan: 11 to add, 0 to change, 0 to destroy.
```

**Vérifiez attentivement** :
- Les IPs assignées (192.168.1.110-119, 200)
- Les ressources CPU/RAM
- Les noms des VMs

### 5.3 Déployer l'infrastructure

```bash
terraform apply
```

Terraform va demander confirmation :

```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

Tapez `yes` et appuyez sur Entrée.

**Durée** : 10-15 minutes

### 5.4 Voir les outputs

Une fois terminé :

```bash
terraform output
```

Vous verrez un résumé complet :

```
╔════════════════════════════════════════════════════════╗
║         🚀 DÉPLOIEMENT RÉUSSI - 11 VMs créées          ║
╚════════════════════════════════════════════════════════╝

📦 RANCHER NODES (Control Plane):
  • rancher-1  → ID 102 → 192.168.1.110
  • rancher-2  → ID 103 → 192.168.1.111
  • rancher-3  → ID 104 → 192.168.1.112

🔧 PAYLOAD MASTERS:
  • payload-master-1 → ID 105 → 192.168.1.113
  • payload-master-2 → ID 106 → 192.168.1.114
  • payload-master-3 → ID 107 → 192.168.1.115

⚙️  PAYLOAD WORKERS:
  • payload-worker-1 → ID 108 → 192.168.1.116
  • payload-worker-2 → ID 109 → 192.168.1.117
  • payload-worker-3 → ID 110 → 192.168.1.118

📦 SERVICES:
  • cicd → ID 111 → 192.168.1.119

🔒 NETWORK SECURITY:
  • opnsense-fw → ID 200 → WAN/LAN/OPT1 (3 interfaces)
```

---

## Étape 6 : Démarrer et vérifier les VMs

### 6.1 Démarrer les VMs Kubernetes et CI/CD

Sur le serveur Proxmox :

```bash
# Démarrer les VMs 102-111 (Kubernetes + CI/CD)
for i in {102..111}; do qm start $i; done
```

### 6.2 Vérifier le démarrage

```bash
# Vérifier le statut
for i in {102..111}; do echo -n "VM $i: "; qm status $i; done
```

Tous doivent afficher `status: running`.

### 6.3 Attendre l'initialisation cloud-init

Les VMs prennent 1-2 minutes pour démarrer complètement (cloud-init).

```bash
# Attendre 2 minutes
sleep 120
```

### 6.4 Tester la connectivité SSH

Depuis votre machine locale :

```bash
# Test sur rancher-1
ssh root@192.168.1.110 "hostname && uptime"

# Test sur toutes les VMs
for IP in {110..119}; do
  echo "Testing 192.168.1.$IP..."
  ssh -o ConnectTimeout=5 root@192.168.1.$IP "hostname" || echo "FAILED"
done
```

**Toutes les VMs devraient répondre** avec leur hostname.

### 6.5 OPNsense (ne PAS démarrer maintenant)

La VM OPNsense (ID 200) est créée mais **non démarrée** (configuration manuelle requise).

**Ne la démarrez pas maintenant** - elle sera configurée en Phase 2.

---

## Étape 7 : Configuration post-déploiement

### 7.1 Mettre à jour toutes les VMs

Sur chaque VM, mettre à jour le système :

```bash
# Script pour mettre à jour toutes les VMs
for IP in {110..119}; do
  echo "=== Updating 192.168.1.$IP ==="
  ssh root@192.168.1.$IP "dnf update -y && dnf install -y vim wget curl git htop"
done
```

### 7.2 Vérifier les ressources

```bash
# CPU et RAM sur rancher-1
ssh root@192.168.1.110 "nproc && free -h"
```

### 7.3 Configurer le hostname (si nécessaire)

Normalement, cloud-init configure les hostnames. Vérifiez :

```bash
ssh root@192.168.1.110 "hostname"
# Devrait afficher: rancher-1
```

---

## Étape 8 : Checklist de validation Phase 1

Cochez les items suivants :

### Infrastructure Proxmox
- [ ] Proxmox VE 8.x ou 9.x installé
- [ ] Bridge vmbr0 configuré (192.168.1.0/24)
- [ ] Bridges vmbr1 et vmbr2 créés (optionnel, pour Phase 2)
- [ ] Stockage local-lvm avec >300GB disponible
- [ ] Template Rocky Linux 9 (ID 9100) créé
- [ ] ISO OPNsense téléchargé (optionnel, pour Phase 2)

### Déploiement Terraform
- [ ] Terraform initialisé (`terraform init`)
- [ ] Configuration validée (`terraform validate`)
- [ ] Plan vérifié (`terraform plan`)
- [ ] Infrastructure déployée (`terraform apply`)
- [ ] 11 VMs créées (IDs 102-111, 200)

### VMs opérationnelles
- [ ] 3 VMs Rancher démarrées (102-104)
- [ ] 6 VMs Payload démarrées (105-110)
- [ ] 1 VM CI/CD démarrée (111)
- [ ] 1 VM OPNsense créée mais arrêtée (200)
- [ ] Toutes les VMs Linux accessibles en SSH
- [ ] Hostnames configurés correctement
- [ ] Systèmes mis à jour

### Réseau
- [ ] Toutes les VMs ont une IP statique (192.168.1.110-119)
- [ ] Gateway configurée (192.168.1.1)
- [ ] DNS fonctionnel
- [ ] Connectivité Internet depuis les VMs
- [ ] Ping entre VMs fonctionne

---

## Troubleshooting

### Problème : Template Rocky 9 introuvable

**Erreur** :
```
Error: template 9100 not found
```

**Solution** :
```bash
ssh root@192.168.1.100
cd /tmp
./create-rocky9-template.sh
```

### Problème : Conflit VM ID

**Erreur** :
```
Error: VM 102 already exists
```

**Solution** :
```bash
# Sur Proxmox
for i in {102..111} 200; do qm destroy $i; done

# Puis relancer
terraform apply
```

### Problème : Connexion SSH refusée

**Causes possibles** :
1. Cloud-init pas encore terminé → Attendre 2-3 minutes
2. Clé SSH incorrecte → Vérifier `ssh_public_key` dans `terraform.tfvars`
3. Firewall bloquant → Vérifier firewall local

**Debug** :
```bash
# Voir les logs cloud-init
ssh root@192.168.1.100
qm terminal 102
# Login: root / pas de mot de passe
tail -f /var/log/cloud-init.log
```

### Problème : Pas assez de ressources

**Erreur** :
```
Error: insufficient resources
```

**Solution** : Réduire les ressources dans `terraform.tfvars` :

```hcl
# Exemple : Réduire RAM
rancher_memory = 4096       # Au lieu de 8192
payload_worker_memory = 4096  # Au lieu de 8192
```

Puis :
```bash
terraform apply
```

### Problème : Terraform provider fail

**Erreur** :
```
Error: Failed to query available provider packages
```

**Solution** :
```bash
# Nettoyer et réinitialiser
rm -rf .terraform .terraform.lock.hcl
terraform init
```

---

## Commandes utiles

### Gestion des VMs depuis Proxmox

```bash
# Lister toutes les VMs
qm list

# Statut d'une VM
qm status 102

# Démarrer une VM
qm start 102

# Arrêter une VM
qm stop 102

# Redémarrer une VM
qm reboot 102

# Console d'une VM
qm terminal 102

# Voir la config d'une VM
qm config 102

# Détruire une VM
qm destroy 102
```

### Gestion Terraform

```bash
# Voir l'état
terraform show

# Voir les outputs
terraform output

# Rafraîchir l'état
terraform refresh

# Détruire tout
terraform destroy

# Détruire une ressource spécifique
terraform destroy -target=proxmox_virtual_environment_vm.rancher_1
```

---

## Prochaines étapes (Phase 2)

Une fois Phase 1 terminée avec succès :

1. **Configurer OPNsense** (Firewall/Router)
   - Démarrer la VM 200
   - Installer OPNsense depuis ISO
   - Configurer les 3 interfaces réseau
   - Créer les règles firewall

2. **Segmentation réseau**
   - Migrer certaines VMs vers vmbr1/vmbr2
   - Tester la connectivité inter-réseau
   - Configurer NAT et routage

3. **Préparer le cluster Kubernetes** (Phase 3)
   - Installer RKE2 sur rancher-1
   - Joindre rancher-2 et rancher-3
   - Ajouter les workers

**Voir** : [ROADMAP-DEVSECOPS.md](../ROADMAP-DEVSECOPS.md) pour la suite

---

## Résumé

**✅ Phase 1 complétée** : Vous avez maintenant 11 VMs opérationnelles prêtes pour construire votre homelab DevSecOps !

**Architecture actuelle** :
```
Internet → Box (192.168.1.1) → vmbr0 (192.168.1.0/24)
                                   ↓
                    ┌──────────────┴──────────────┐
                    ↓                              ↓
              VMs Kubernetes                  VM OPNsense (arrêtée)
           (rancher + payload + cicd)              ↓
           192.168.1.110-119                  (Phase 2)
```

**Ressources consommées** :
- **CPU** : 25 cores
- **RAM** : 70 GB
- **Stockage** : ~295 GB

Félicitations ! 🎉

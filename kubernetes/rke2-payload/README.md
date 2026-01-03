# RKE2 Payload - Cluster de charge de travail

Playbooks Ansible pour déployer et gérer le cluster Kubernetes RKE2 dédié aux charges de travail applicatives (workloads/payload) dans l'environnement homelab.

## Vue d'ensemble

Ce cluster RKE2 est dédié à l'exécution des applications et services métier, séparé du cluster de gestion Rancher pour une meilleure isolation et sécurité.

### Architecture du cluster

```
┌─────────────────────────────────────────────┐
│      VIP Kubernetes API (Keepalived)        │
│           10.0.20.200:6443                   │
└─────────────────────────────────────────────┘
           │          │          │
    ┌──────┴────┬─────┴────┬────┴──────┐
    │ Payload-1 │Payload-2 │ Payload-3 │
    │192.168.1. │192.168.1.│192.168.1. │
    │   113     │   114    │    115    │
    └───────────┴──────────┴───────────┘
           │          │          │
    ┌──────┴────┬─────┴────┬────┴──────┐
    │ Payload-4 │Payload-5 │ Payload-6 │
    │192.168.1. │192.168.1.│192.168.1. │
    │   116     │   117    │    118    │
    └───────────┴──────────┴───────────┘
```

**Configuration Production :**
- **3 Masters** (payload-1, payload-2, payload-3)
- **3 Workers** (payload-4, payload-5, payload-6)
- **Mode HA** avec Keepalived

## Structure du projet

```
rke2-payload/
├── install_rke2.yml              # Playbook principal d'installation
├── uninstall_rke2.yml           # Désinstallation du cluster
├── update-vms.yml               # Mise à jour du système des VMs
├── reboot.yml                   # Redémarrage contrôlé des nœuds
├── node-maintenance-tasks.yml   # Tâches de maintenance
├── rke2.yaml                    # Configuration globale RKE2
├── ansible.cfg                  # Configuration Ansible
├── inventory-staging.yml        # Inventaire staging
├── inventory-production.yml     # Inventaire production
├── vars/
│   ├── staging/
│   │   ├── variables.yaml      # Variables staging
│   │   └── secrets.yaml        # Secrets staging (Vault)
│   └── production/
│       ├── variables.yaml      # Variables production
│       └── secrets.yaml        # Secrets production (Vault)
├── collections/
│   └── requirements.yml        # Collections Ansible requises
└── UPDATE_VMS.md              # Documentation des mises à jour
```

## Prérequis

### Sur la machine de contrôle Ansible

1. **Ansible** 2.10+
   ```bash
   pip install ansible
   ```

2. **Collections Ansible** (incluant le rôle RKE2)
   ```bash
   ansible-galaxy collection install -r collections/requirements.yml
   ```

3. **Python netaddr**
   ```bash
   pip install netaddr
   ```

4. **Accès SSH** configuré vers tous les nœuds
   ```bash
   ssh-copy-id root@192.168.1.113  # Pour chaque nœud
   ```

### Infrastructure

- VMs provisionnées via Terraform (voir `../../proxmox-terraform/`)
- Configuration réseau Proxmox

## Utilisation

### 1. Installation du cluster RKE2

#### Environnement de staging
```bash
ansible-playbook -i inventory-staging.yml install_rke2.yml -e "ENVIRONNEMENT=staging"
```

#### Environnement de production
```bash
ansible-playbook -i inventory-production.yml install_rke2.yml -e "ENVIRONNEMENT=production"
```

Le playbook effectue :
- Installation de RKE2 sur tous les nœuds
- Configuration du mode HA avec Keepalived
- Configuration du CNI (Canal par défaut)
- Déploiement de l'Ingress Controller (NGINX)
- Configuration des taints sur les masters
- Téléchargement du kubeconfig

### 2. Vérification du déploiement

```bash
# Configurer kubectl
export KUBECONFIG=~/rke2-payload.yaml

# Vérifier les nœuds
kubectl get nodes

# Vérifier les pods système
kubectl get pods -A

# Vérifier les services
kubectl get svc -A
```

### 3. Maintenance des nœuds

```bash
# Exécuter les tâches de maintenance
ansible-playbook -i inventory-production.yml node-maintenance-tasks.yml
```

Inclut :
- Vérification de l'état des services
- Nettoyage des logs
- Vérification de l'espace disque
- Vérification de la connectivité réseau

### 4. Mise à jour des VMs

Voir [UPDATE_VMS.md](UPDATE_VMS.md) pour la documentation complète.

```bash
# Mise à jour du système d'exploitation
ansible-playbook -i inventory-production.yml update-vms.yml

# Avec redémarrage automatique
ansible-playbook -i inventory-production.yml update-vms.yml -e "auto_reboot=true"
```

### 5. Redémarrage des nœuds

```bash
# Redémarrage contrôlé (un nœud à la fois)
ansible-playbook -i inventory-production.yml reboot.yml

# Redémarrage d'un groupe spécifique
ansible-playbook -i inventory-production.yml reboot.yml --limit workers
```

### 6. Désinstallation de RKE2

```bash
# Suppression complète du cluster
ansible-playbook -i inventory-production.yml uninstall_rke2.yml

# Confirmation requise pour production
ansible-playbook -i inventory-production.yml uninstall_rke2.yml -e "confirm_uninstall=yes"
```

## Configuration

### Variables d'environnement

Les variables sont organisées par environnement dans `vars/` :

#### Staging (`vars/staging/variables.yaml`)
- Configuration pour tests et développement
- Ressources limitées
- Rétention de snapshots réduite

#### Production (`vars/production/variables.yaml`)
- Configuration optimisée pour la production
- Haute disponibilité
- Snapshots etcd configurés
- Monitoring et alerting activés

### Secrets (Ansible Vault)

Les fichiers `secrets.yaml` contiennent :
- Tokens RKE2
- Certificats TLS
- Credentials pour registres privés
- Clés API

**Chiffrement des secrets :**
```bash
# Créer/éditer un fichier de secrets
ansible-vault create vars/production/secrets.yaml
ansible-vault edit vars/production/secrets.yaml

# Exécuter un playbook avec secrets
ansible-playbook -i inventory-production.yml install_rke2.yml \
  -e "ENVIRONNEMENT=production" \
  --ask-vault-pass
```

### Configuration RKE2 principale

Le fichier `rke2.yaml` définit la configuration globale :
- Version RKE2
- Mode HA
- CNI (Canal, Calico, Cilium)
- Ingress Controller
- Politiques réseau
- Snapshots etcd

## Différence avec rke2-rancher

| Aspect | rke2-rancher | rke2-payload |
|--------|--------------|--------------|
| **Rôle** | Cluster de gestion | Cluster de workloads |
| **Composants** | Rancher, monitoring | Applications métier |
| **IPs** | 192.168.1.110-112 | 192.168.1.113-118 |
| **VIP** | 10.0.20.100 | 10.0.20.200 |
| **Isolation** | Plan de gestion | Plan applicatif |
| **Accès** | Administrateurs | Applications + Rancher |

Cette séparation permet :
- **Isolation** : Le cluster de gestion reste stable
- **Sécurité** : Séparation des responsabilités
- **Performance** : Ressources dédiées aux workloads
- **Gestion** : Rancher peut gérer le cluster payload

## Gestion via Rancher

Une fois déployé, ce cluster peut être importé dans Rancher :

1. Accéder à Rancher (déployé sur rke2-rancher)
2. Cluster Management → Import Existing
3. Utiliser le kubeconfig du cluster payload
4. Appliquer les manifests d'enregistrement

## Composants installés

Voir [../ansible-role-rke2/README.md](../ansible-role-rke2/README.md#composants-installés) pour la liste complète.

**Principaux composants :**
- **Plan de contrôle** : kube-apiserver, kube-controller-manager, kube-scheduler, kubelet
- **Stockage** : etcd avec snapshots automatiques
- **Réseau** : Canal (Flannel + Calico) ou Cilium
- **DNS** : CoreDNS
- **Métriques** : Metrics Server
- **Ingress** : NGINX Ingress Controller
- **HA** : Keepalived avec VIP

## Sécurité

### Bonnes pratiques

1. **Secrets** : Toujours chiffrer avec Ansible Vault
2. **SSH** : Utiliser des clés SSH (pas de mots de passe)
3. **Accès** : Limiter l'accès aux inventaires de production
4. **Isolation** : Séparer le cluster payload du cluster de gestion
5. **Réseau** : Segmentation réseau appropriée
6. **Tokens** : Rotation régulière des tokens RKE2
7. **Certificats** : Renouvellement automatique des certificats TLS

### CIS Hardening (optionnel)

Pour activer le profil CIS :
```yaml
# Dans vars/production/variables.yaml
rke2_cis_profile: "cis-1.23"
```

## Monitoring et observabilité

### Logs

```bash
# Logs RKE2 sur un nœud
journalctl -u rke2-server -f  # Sur master
journalctl -u rke2-agent -f   # Sur worker

# Logs Keepalived
journalctl -u keepalived -f
```

### Métriques

```bash
# Métriques des nœuds
kubectl top nodes

# Métriques des pods
kubectl top pods -A

# Métriques Keepalived (si kube-vip)
curl http://10.0.20.200:2112/metrics
```

## Dépannage

### Le cluster ne démarre pas

1. **Vérifier les services**
   ```bash
   systemctl status rke2-server  # Sur masters
   systemctl status rke2-agent   # Sur workers
   ```

2. **Vérifier les logs**
   ```bash
   journalctl -u rke2-server -n 100
   ```

3. **Vérifier la VIP Keepalived**
   ```bash
   ip addr show | grep 10.0.20.200
   ping 10.0.20.200
   ```

4. **Vérifier etcd**
   ```bash
   /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml \
     get nodes
   ```

### Les pods ne démarrent pas

1. **Vérifier le CNI**
   ```bash
   kubectl get pods -n kube-system | grep canal
   ```

2. **Vérifier les NetworkPolicies**
   ```bash
   kubectl get networkpolicies -A
   ```

3. **Vérifier le stockage**
   ```bash
   kubectl get pv
   kubectl get pvc -A
   ```

### Problèmes de réseau

Voir [../ansible-role-rke2/README.md](../ansible-role-rke2/README.md#dépannage) pour le guide complet.

**Ports requis :**
- TCP 6443 : Kubernetes API
- TCP 9345 : RKE2 supervisor API
- TCP 2379-2380 : etcd
- UDP 8472 : VXLAN (Canal)
- TCP 10250 : kubelet

## Documentation associée

- [Rôle Ansible RKE2](../ansible-role-rke2/README.md) - Documentation du rôle
- [Phase 3 - Kubernetes](../../PHASE3-KUBERNETES.md) - Plan de déploiement
- [Roadmap DevSecOps](../../ROADMAP-DEVSECOPS.md) - Roadmap globale
- [UPDATE_VMS.md](UPDATE_VMS.md) - Guide de mise à jour des VMs
- [Cluster Rancher](../rke2-rancher/README.md) - Cluster de gestion

## Support et contribution

Pour signaler un problème ou proposer des améliorations, ouvrir une issue dans le dépôt du projet.

## Licence

MIT

## Notes importantes

- Ce cluster utilise le rôle `../ansible-role-rke2` pour la configuration
- Les ajustements post-déploiement Terraform sont appliqués automatiquement
- Le cluster peut être géré via Rancher déployé sur `rke2-rancher`
- Les snapshots etcd sont automatiques en production (configurables)
- La mise à niveau RKE2 se fait par rolling restart sans downtime

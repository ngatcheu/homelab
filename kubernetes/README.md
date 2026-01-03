# Kubernetes RKE2 - Déploiement Homelab

Infrastructure Kubernetes haute disponibilité avec RKE2, déployée via Ansible sur Proxmox.

## Vue d'ensemble

Ce dossier contient l'ensemble de la configuration pour déployer et gérer deux clusters Kubernetes RKE2 :

- **[rke2-rancher](rke2-rancher/)** : Cluster de gestion (3 masters) hébergeant Rancher
- **[rke2-payload](rke2-payload/)** : Cluster de workloads (3 masters + 3 workers) pour les applications

## Architecture

### Infrastructure globale

```
┌─────────────────────────────────────────────────────────┐
│                    Cluster Rancher                       │
│              (Management / Control Plane)                │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │    VIP: 10.0.20.100 (Keepalived)                 │   │
│  │    Rancher UI: rancher.homelab.local             │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│   rancher-1        rancher-2        rancher-3           │
│   192.168.1.110    192.168.1.111    192.168.1.112       │
└─────────────────────────────────────────────────────────┘
                           │
                           │ Gère
                           ▼
┌─────────────────────────────────────────────────────────┐
│                   Cluster Payload                        │
│              (Workloads / Applications)                  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │    VIP: 10.0.20.200 (Keepalived)                 │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│   payload-1 → payload-6                                 │
│   192.168.1.113 → 192.168.1.118                         │
│   (3 masters + 3 workers)                               │
└─────────────────────────────────────────────────────────┘
```

## Composants

### Rôle Ansible RKE2

Le dossier **[ansible-role-rke2/](ansible-role-rke2/)** contient le rôle Ansible complet pour déployer RKE2 :

- Déploiement RKE2 (serveur et agent)
- Configuration HA avec Keepalived ou Kube-VIP
- Support multi-CNI (Canal, Calico, Cilium)
- Ingress controllers (NGINX, Traefik, Istio)
- Snapshots etcd automatiques
- Mode Air-Gap

📖 **[Documentation complète du rôle](ansible-role-rke2/README.md)**

### Cluster Rancher (Management)

Le dossier **[rke2-rancher/](rke2-rancher/)** déploie le cluster de gestion :

**Configuration :**
- 3 nœuds masters uniquement (pas de workers)
- Mode HA avec Keepalived
- VIP : 10.0.20.100
- Héberge : Rancher, Prometheus, Grafana, outils DevOps

**Composants installés :**
- RKE2 (Kubernetes)
- Rancher (gestion multi-cluster)
- cert-manager
- NGINX Ingress Controller
- Monitoring stack (Prometheus/Grafana)

📖 **[Documentation du cluster Rancher](rke2-rancher/README.md)**

### Cluster Payload (Workloads)

Le dossier **[rke2-payload/](rke2-payload/)** déploie le cluster de workloads :

**Configuration :**
- 3 nœuds masters
- 3 nœuds workers
- Mode HA avec Keepalived
- VIP : 10.0.20.200

**Utilisation :**
- Héberge les applications métier
- Géré via Rancher
- Isolation du plan de gestion

📖 **[Documentation du cluster Payload](rke2-payload/README.md)**

## Démarrage rapide

### Prérequis

1. **VMs provisionnées** via Terraform (voir `../proxmox-terraform/`)
2. **Ansible 2.10+** installé
3. **Python netaddr** : `pip install netaddr`
4. **Accès SSH** configuré vers toutes les VMs

### Installation des collections Ansible

```bash
cd kubernetes
ansible-galaxy collection install -r collections/requirements.yml
```

### Déploiement du cluster Rancher

```bash
cd rke2-rancher

# Déployer RKE2 sur les 3 masters
ansible-playbook -i inventory-production.yml install_rke2.yml \
  -e "ENVIRONNEMENT=production"

# Installer Rancher via Helm (après déploiement RKE2)
# Voir rke2-rancher/README.md pour les instructions complètes
```

### Déploiement du cluster Payload

```bash
cd rke2-payload

# Déployer RKE2 (3 masters + 3 workers)
ansible-playbook -i inventory-production.yml install_rke2.yml \
  -e "ENVIRONNEMENT=production"
```

### Vérification

```bash
# Cluster Rancher
export KUBECONFIG=~/rke2-rancher.yaml
kubectl get nodes

# Cluster Payload
export KUBECONFIG=~/rke2-payload.yaml
kubectl get nodes
```

## Organisation des fichiers

```
kubernetes/
├── ansible-role-rke2/              # Rôle Ansible RKE2
│   ├── README.md                   # Documentation du rôle
│   ├── tasks/                      # Tâches Ansible
│   ├── templates/                  # Templates de configuration
│   ├── defaults/                   # Variables par défaut
│   └── handlers/                   # Handlers
│
├── rke2-rancher/                   # Cluster de gestion
│   ├── README.md                   # Documentation
│   ├── install_rke2.yml           # Playbook d'installation
│   ├── inventory-production.yml    # Inventaire production
│   ├── inventory-staging.yml       # Inventaire staging
│   ├── update-vms.yml             # Mise à jour des VMs
│   ├── reboot.yml                 # Redémarrage des nœuds
│   ├── uninstall_rke2.yml         # Désinstallation
│   ├── vars/
│   │   ├── production/
│   │   │   ├── variables.yaml     # Variables production
│   │   │   └── secrets.yaml       # Secrets (Ansible Vault)
│   │   └── staging/
│   │       ├── variables.yaml
│   │       └── secrets.yaml
│   └── collections/
│       └── requirements.yml        # Collections requises
│
├── rke2-payload/                   # Cluster de workloads
│   ├── README.md                   # Documentation
│   ├── install_rke2.yml           # Playbook d'installation
│   ├── inventory-production.yml    # Inventaire production
│   ├── inventory-staging.yml       # Inventaire staging
│   ├── update-vms.yml             # Mise à jour des VMs
│   ├── reboot.yml                 # Redémarrage des nœuds
│   ├── uninstall_rke2.yml         # Désinstallation
│   ├── vars/
│   │   ├── production/
│   │   │   ├── variables.yaml
│   │   │   └── secrets.yaml
│   │   └── staging/
│   │       ├── variables.yaml
│   │       └── secrets.yaml
│   └── collections/
│       └── requirements.yml
│
└── README.md                       # Ce fichier
```

## Playbooks disponibles

Chaque cluster (rancher/payload) dispose des mêmes playbooks :

| Playbook | Description |
|----------|-------------|
| `install_rke2.yml` | Installe et configure RKE2 |
| `uninstall_rke2.yml` | Désinstalle complètement RKE2 |
| `update-vms.yml` | Met à jour le système d'exploitation |
| `reboot.yml` | Redémarre les nœuds de manière contrôlée |
| `node-maintenance-tasks.yml` | Tâches de maintenance |

## Gestion des environnements

Chaque cluster supporte deux environnements :

- **Staging** : Tests et développement
- **Production** : Environnement de production

Configuration via la variable `ENVIRONNEMENT` :

```bash
# Staging
ansible-playbook -i inventory-staging.yml install_rke2.yml \
  -e "ENVIRONNEMENT=staging"

# Production
ansible-playbook -i inventory-production.yml install_rke2.yml \
  -e "ENVIRONNEMENT=production"
```

## Sécurité

### Ansible Vault

Les secrets sont chiffrés avec Ansible Vault :

```bash
# Créer un fichier de secrets
ansible-vault create vars/production/secrets.yaml

# Éditer un fichier existant
ansible-vault edit vars/production/secrets.yaml

# Déployer avec secrets
ansible-playbook -i inventory-production.yml install_rke2.yml \
  -e "ENVIRONNEMENT=production" \
  --ask-vault-pass
```

### Bonnes pratiques

1. **SSH** : Utiliser des clés SSH (pas de mots de passe)
2. **Secrets** : Toujours chiffrer avec Ansible Vault
3. **Tokens** : Rotation régulière des tokens RKE2
4. **RBAC** : Principe du moindre privilège
5. **Isolation** : Séparer les clusters de gestion et de workloads

## Commandes utiles

### Gestion des clusters

```bash
# Lister les nœuds
kubectl get nodes -o wide

# Vérifier tous les pods
kubectl get pods -A

# État du cluster
kubectl cluster-info

# Logs RKE2
journalctl -u rke2-server -f  # Sur master
journalctl -u rke2-agent -f   # Sur worker

# Logs Keepalived
journalctl -u keepalived -f
```

### Ansible

```bash
# Tester la connectivité
ansible -i inventory-production.yml all -m ping

# Lister l'inventaire
ansible-inventory -i inventory-production.yml --list

# Exécuter une commande ad-hoc
ansible -i inventory-production.yml all -a "uptime"
```

## Dépannage

### Les nœuds ne rejoignent pas le cluster

**Vérifier la connectivité :**
```bash
# Tester la connectivité réseau
ping <ip-master>

# Tester les ports RKE2
nc -zv <ip-master> 6443
nc -zv <ip-master> 9345
```

**Vérifier les logs :**
```bash
journalctl -u rke2-server -n 100  # Sur master
journalctl -u rke2-agent -n 100   # Sur worker
```

### Problèmes de VIP Keepalived

```bash
# Vérifier Keepalived
systemctl status keepalived

# Vérifier la VIP
ip addr show | grep <vip>

# Logs Keepalived
journalctl -u keepalived -f
```

### Ansible ne se connecte pas

```bash
# Tester SSH
ssh root@<ip>

# Vérifier l'inventaire
ansible-inventory -i inventory-production.yml --graph

# Mode verbose
ansible-playbook -i inventory-production.yml install_rke2.yml -vvv
```

## Monitoring et observabilité

Une fois Rancher déployé, vous aurez accès à :

- **Rancher UI** : https://rancher.homelab.local
- **Prometheus** : Métriques des clusters
- **Grafana** : Tableaux de bord de monitoring
- **Alertmanager** : Gestion des alertes

## Prochaines étapes

Après le déploiement des clusters :

1. **Accéder à Rancher** et configurer l'authentification
2. **Importer le cluster payload** dans Rancher
3. **Installer Longhorn** pour le stockage persistant
4. **Configurer MetalLB** pour les LoadBalancer
5. **Déployer vos applications** sur le cluster payload

## Documentation associée

- [Rôle Ansible RKE2](ansible-role-rke2/README.md) - Documentation détaillée du rôle
- [Cluster Rancher](rke2-rancher/README.md) - Déploiement du cluster de gestion
- [Cluster Payload](rke2-payload/README.md) - Déploiement du cluster de workloads
- [Roadmap DevSecOps](../ROADMAP-DEVSECOPS.md) - Roadmap complète
- [Terraform Proxmox](../proxmox-terraform/) - Provisioning des VMs
 
## Support

Pour toute question ou problème :

1. Consulter les README spécifiques de chaque composant
2. Vérifier la section Dépannage
3. Consulter la documentation officielle [RKE2](https://docs.rke2.io/)
4. Consulter la documentation [Rancher](https://rancher.com/docs/)

## Licence

nsfabrice2009gmail.com

---

**Note** : Ce déploiement fait partie d'un homelab DevSecOps complet. Voir la [Roadmap DevSecOps](../ROADMAP-DEVSECOPS.md) pour plus de contexte.
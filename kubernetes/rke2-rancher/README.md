# RKE2 Rancher - Cluster de gestion

Playbooks Ansible pour déployer et gérer le cluster Kubernetes RKE2 avec Rancher pour la gestion centralisée de l'infrastructure Kubernetes dans l'environnement homelab.

## Vue d'ensemble

Ce cluster RKE2 est dédié au **plan de gestion** (management plane) et héberge **Rancher** pour l'administration centralisée de tous les clusters Kubernetes, y compris le cluster de workloads (rke2-payload).

### Architecture du cluster

```
┌─────────────────────────────────────────────┐
│      VIP Kubernetes API (Keepalived)        │
│           10.0.20.100:6443                   │
└─────────────────────────────────────────────┘
           │          │          │
    ┌──────┴────┬─────┴────┬────┴──────┐
    │ Rancher-1 │Rancher-2 │ Rancher-3 │
    │192.168.1. │192.168.1.│192.168.1. │
    │   110     │   111    │    112    │
    └───────────┴──────────┴───────────┘
         │
         ├─ Rancher UI (https://rancher.homelab.local)
         ├─ Monitoring Stack (Prometheus, Grafana)
         └─ Gestion multi-cluster
```

**Configuration Production :**
- **3 Masters** (rancher-1, rancher-2, rancher-3) - Pas de workers dédiés
- **Mode HA** avec Keepalived
- **Taints sur masters** : Rancher et composants de gestion uniquement

## Rôle du cluster

Ce cluster héberge :
- **Rancher** : Interface web pour gérer tous les clusters K8s
- **Monitoring** : Prometheus, Grafana pour observer l'infrastructure
- **Outils DevOps** : CI/CD, GitOps (ArgoCD/Flux)
- **Gestion des politiques** : OPA/Gatekeeper
- **Sécurité** : Falco, admission controllers

## Structure du projet

```
rke2-rancher/
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

4. **Helm** (pour installer Rancher)
   ```bash
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   ```

5. **Accès SSH** configuré vers tous les nœuds
   ```bash
   ssh-copy-id root@192.168.1.110  # Pour chaque nœud
   ```

### Infrastructure

- VMs provisionnées via Terraform (voir `../../proxmox-terraform/`)
- Configuration réseau Proxmox
- DNS configuré pour `rancher.homelab.local`

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
- Installation de RKE2 sur tous les nœuds masters
- Configuration du mode HA avec Keepalived
- Configuration du CNI (Canal par défaut)
- Déploiement de l'Ingress Controller (NGINX)
- Configuration des taints pour isolation des workloads
- Téléchargement du kubeconfig

### 2. Installation de Rancher

Après le déploiement du cluster RKE2 :

```bash
# Configurer kubectl
export KUBECONFIG=~/rke2-rancher.yaml

# Ajouter le dépôt Helm de Rancher
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

# Créer le namespace pour Rancher
kubectl create namespace cattle-system

# Installer cert-manager (requis pour Rancher)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Attendre que cert-manager soit prêt
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager

# Installer Rancher
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.homelab.local \
  --set replicas=3 \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=admin@homelab.local \
  --set letsEncrypt.ingress.class=nginx

# Vérifier le déploiement
kubectl -n cattle-system rollout status deploy/rancher
kubectl -n cattle-system get pods
```

### 3. Accès à Rancher

```bash
# Obtenir le mot de passe initial
kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'

# Accéder à l'interface web
# https://rancher.homelab.local
```

**Premier accès :**
1. Accepter les conditions d'utilisation
2. Définir un nouveau mot de passe administrateur
3. Configurer l'URL du serveur Rancher

### 4. Vérification du déploiement

```bash
# Configurer kubectl
export KUBECONFIG=~/rke2-rancher.yaml

# Vérifier les nœuds
kubectl get nodes

# Vérifier les pods système
kubectl get pods -A

# Vérifier Rancher
kubectl get pods -n cattle-system
kubectl get ingress -n cattle-system

# Vérifier cert-manager
kubectl get pods -n cert-manager
```

### 5. Maintenance des nœuds

```bash
# Exécuter les tâches de maintenance
ansible-playbook -i inventory-production.yml node-maintenance-tasks.yml
```

Inclut :
- Vérification de l'état des services
- Nettoyage des logs
- Vérification de l'espace disque
- Vérification de la connectivité réseau

### 6. Mise à jour des VMs

Voir [UPDATE_VMS.md](UPDATE_VMS.md) pour la documentation complète.

```bash
# Mise à jour du système d'exploitation
ansible-playbook -i inventory-production.yml update-vms.yml

# Avec redémarrage automatique
ansible-playbook -i inventory-production.yml update-vms.yml -e "auto_reboot=true"
```

### 7. Redémarrage des nœuds

```bash
# Redémarrage contrôlé (un nœud à la fois)
ansible-playbook -i inventory-production.yml reboot.yml

# Redémarrage d'un nœud spécifique
ansible-playbook -i inventory-production.yml reboot.yml --limit rancher-1
```

### 8. Désinstallation

```bash
# Suppression complète du cluster
ansible-playbook -i inventory-production.yml uninstall_rke2.yml

# Confirmation requise pour production
ansible-playbook -i inventory-production.yml uninstall_rke2.yml -e "confirm_uninstall=yes"
```

## Configuration

### Variables d'environnement

#### Staging (`vars/staging/variables.yaml`)
```yaml
# Exemple de configuration staging
rke2_version: v1.28.5+rke2r1
rke2_ha_mode: true
rke2_ha_mode_keepalived: true
rke2_api_ip: 10.0.20.100
rke2_server_node_taints:
  - 'CriticalAddonsOnly=true:NoExecute'
```

#### Production (`vars/production/variables.yaml`)
- Configuration optimisée pour la production
- Haute disponibilité
- Snapshots etcd automatiques
- Monitoring et alerting activés
- Politiques de sécurité renforcées

### Secrets (Ansible Vault)

Les fichiers `secrets.yaml` contiennent :
- Token RKE2 pour le cluster
- Tokens pour l'ajout de nœuds
- Credentials Rancher
- Certificats TLS personnalisés
- Clés API pour services externes

**Gestion des secrets :**
```bash
# Créer un fichier de secrets
ansible-vault create vars/production/secrets.yaml

# Éditer les secrets
ansible-vault edit vars/production/secrets.yaml

# Déployer avec secrets
ansible-playbook -i inventory-production.yml install_rke2.yml \
  -e "ENVIRONNEMENT=production" \
  --ask-vault-pass
```

### Configuration Rancher

Fichier `rancher-values.yaml` (exemple) :
```yaml
hostname: rancher.homelab.local
replicas: 3
ingress:
  tls:
    source: letsEncrypt
letsEncrypt:
  email: admin@homelab.local
  ingress:
    class: nginx
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 2Gi
```

## Différence avec rke2-payload

| Aspect | rke2-rancher | rke2-payload |
|--------|--------------|--------------|
| **Rôle** | Cluster de gestion | Cluster de workloads |
| **Composants** | Rancher, monitoring, outils DevOps | Applications métier |
| **Nœuds** | 3 masters (pas de workers) | 3 masters + 3 workers |
| **IPs** | 192.168.1.110-112 | 192.168.1.113-118 |
| **VIP** | 10.0.20.100 | 10.0.20.200 |
| **Taints** | Oui (management uniquement) | Oui (masters uniquement) |
| **Workloads** | Infrastructure uniquement | Applications métier |
| **Criticité** | Très élevée | Élevée |
| **Accès** | Administrateurs uniquement | Développeurs + Rancher |

### Avantages de la séparation

1. **Isolation** : Le cluster de gestion reste stable même si les workloads sont instables
2. **Sécurité** : Séparation des privilèges et des accès
3. **Performance** : Pas de contention de ressources entre gestion et applications
4. **Résilience** : Panne du cluster payload n'affecte pas Rancher
5. **Mise à niveau** : Possibilité de mettre à jour indépendamment

## Gestion des clusters via Rancher

### Importer le cluster payload

1. **Accéder à Rancher** : https://rancher.homelab.local
2. **Cluster Management** → **Import Existing**
3. **Nom du cluster** : `payload-production`
4. **Copier la commande** d'enregistrement
5. **Exécuter sur le cluster payload** :
   ```bash
   export KUBECONFIG=~/rke2-payload.yaml
   kubectl apply -f <manifest-url-fourni-par-rancher>
   ```

### Fonctionnalités Rancher

- **Multi-cluster management** : Gérer rke2-payload et autres clusters
- **RBAC** : Gestion fine des permissions
- **Catalogs** : Helm charts et applications pré-configurées
- **Projects & Namespaces** : Organisation logique des ressources
- **Monitoring** : Prometheus/Grafana intégrés
- **Logging** : Centralisation des logs
- **Backup** : Snapshots etcd automatisés
- **GitOps** : Intégration Fleet pour le déploiement continu

## Composants installés

Voir [../ansible-role-rke2/README.md](../ansible-role-rke2/README.md#composants-installés) pour la liste complète.

**Principaux composants RKE2 :**
- **Plan de contrôle** : kube-apiserver, kube-controller-manager, kube-scheduler, kubelet
- **Stockage** : etcd avec snapshots automatiques
- **Réseau** : Canal (Flannel + Calico) ou Cilium
- **DNS** : CoreDNS
- **Métriques** : Metrics Server
- **Ingress** : NGINX Ingress Controller
- **HA** : Keepalived avec VIP

**Composants supplémentaires :**
- **Rancher** : Interface de gestion multi-cluster
- **cert-manager** : Gestion automatique des certificats TLS
- **Prometheus** : Collecte de métriques
- **Grafana** : Visualisation des métriques
- **Alertmanager** : Gestion des alertes

## Sécurité

### Bonnes pratiques

1. **Secrets** : Chiffrer avec Ansible Vault
2. **SSH** : Clés SSH uniquement (pas de mot de passe)
3. **Accès Rancher** : RBAC strict avec SSO (LDAP/OIDC)
4. **Réseau** : Segmentation réseau, NetworkPolicies
5. **Certificats** : Let's Encrypt ou CA privée
6. **Audit** : Activer l'audit logging Kubernetes
7. **Backup** : Snapshots etcd réguliers vers S3

### CIS Hardening

```yaml
# Dans vars/production/variables.yaml
rke2_cis_profile: "cis-1.23"
```

### Politique de sécurité Rancher

- **MFA** : Activer l'authentification multi-facteurs
- **Session timeout** : 30 minutes d'inactivité
- **API tokens** : Rotation régulière
- **RBAC** : Principe du moindre privilège
- **Pod Security** : PSS/PSA activés

## Monitoring et observabilité

### Prometheus

```bash
# Accéder à Prometheus
kubectl port-forward -n cattle-monitoring-system svc/prometheus 9090:9090

# Ouvrir http://localhost:9090
```

### Grafana

```bash
# Accéder à Grafana
kubectl port-forward -n cattle-monitoring-system svc/grafana 3000:3000

# Ouvrir http://localhost:3000
# Credentials par défaut : admin / prom-operator
```

### Logs RKE2

```bash
# Logs RKE2 sur un master
journalctl -u rke2-server -f

# Logs Keepalived
journalctl -u keepalived -f

# Logs Rancher
kubectl logs -n cattle-system -l app=rancher -f
```

### Alerting

Configuration des alertes dans Rancher :
- Cluster down
- Node not ready
- High CPU/Memory usage
- etcd health issues
- Certificate expiration

## Dépannage

### Rancher ne démarre pas

1. **Vérifier cert-manager**
   ```bash
   kubectl get pods -n cert-manager
   kubectl logs -n cert-manager -l app=cert-manager
   ```

2. **Vérifier l'Ingress**
   ```bash
   kubectl get ingress -n cattle-system
   kubectl describe ingress -n cattle-system rancher
   ```

3. **Vérifier les certificats**
   ```bash
   kubectl get certificates -n cattle-system
   kubectl describe certificate -n cattle-system
   ```

4. **Vérifier les logs Rancher**
   ```bash
   kubectl logs -n cattle-system -l app=rancher --tail=100
   ```

### Le cluster ne démarre pas

Voir la section Dépannage dans [../ansible-role-rke2/README.md](../ansible-role-rke2/README.md#dépannage)

### Impossible d'accéder à Rancher UI

1. **Vérifier le DNS**
   ```bash
   nslookup rancher.homelab.local
   ```

2. **Vérifier l'Ingress Controller**
   ```bash
   kubectl get pods -n kube-system | grep ingress
   ```

3. **Vérifier les services**
   ```bash
   kubectl get svc -n cattle-system
   kubectl get svc -n kube-system | grep ingress
   ```

## Backup et restauration

### Backup etcd automatique

Configuration dans `vars/production/variables.yaml` :
```yaml
rke2_etcd_snapshot_schedule: "0 */12 * * *"  # Toutes les 12h
rke2_etcd_snapshot_retention: 5
```

### Backup manuel

```bash
# Créer un snapshot manuel
kubectl exec -n kube-system etcd-rancher-1 -- \
  etcdctl snapshot save /tmp/snapshot-$(date +%Y%m%d-%H%M%S).db
```

### Backup Rancher

```bash
# Utiliser l'outil de backup intégré
# Via l'interface Rancher : Cluster → Snapshots → Create
```

## Documentation associée

- [Rôle Ansible RKE2](../ansible-role-rke2/README.md) - Documentation du rôle
- [Cluster Payload](../rke2-payload/README.md) - Cluster de workloads
- [Phase 3 - Kubernetes](../../PHASE3-KUBERNETES.md) - Plan de déploiement
- [Roadmap DevSecOps](../../ROADMAP-DEVSECOPS.md) - Roadmap globale
- [UPDATE_VMS.md](UPDATE_VMS.md) - Guide de mise à jour des VMs
- [Documentation Rancher](https://rancher.com/docs/rancher/v2.x/en/)

## Ressources utiles

- [Documentation RKE2](https://docs.rke2.io/)
- [Documentation Rancher](https://rancher.com/docs/)
- [Helm Charts Rancher](https://github.com/rancher/rancher)
- [cert-manager](https://cert-manager.io/)

## Support et contribution

Pour signaler un problème ou proposer des améliorations, ouvrir une issue dans le dépôt du projet.

## Licence

MIT

## Notes importantes

- Ce cluster utilise le rôle `../ansible-role-rke2` pour la configuration RKE2
- Rancher est installé via Helm après le déploiement du cluster
- Les snapshots etcd sont automatiques en production
- La mise à niveau RKE2 se fait par rolling restart sans downtime
- Rancher nécessite cert-manager pour la gestion des certificats
- Configuration DNS requise pour `rancher.homelab.local`
- Les masters sont tainted pour héberger uniquement l'infrastructure de gestion

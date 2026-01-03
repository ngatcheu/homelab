# Rôle Ansible RKE2 - Homelab

Rôle Ansible pour déployer un cluster Kubernetes [RKE2](https://docs.rke2.io/) dans un environnement homelab sur Proxmox.

Basé sur le rôle [lablabs/ansible-role-rke2](https://github.com/lablabs/ansible-role-rke2)

## Vue d'ensemble

Ce rôle Ansible déploie un cluster Kubernetes [RKE2](https://docs.rke2.io/). RKE2 sera installé en utilisant la méthode tarball.

## Modes de déploiement

Le rôle supporte 3 modes d'installation :

### 1. Nœud unique
- Un seul nœud qui agit à la fois comme serveur et agent
- Idéal pour tests et environnements de développement

### 2. Cluster standard
- Un nœud serveur (Master) + un ou plusieurs nœuds agent (Worker)
- Configuration simple pour petits clusters

### 3. Cluster haute disponibilité (HA)
- Plusieurs serveurs (Masters) en mode HA + zéro ou plusieurs nœuds agent (Worker)
- Recommandé : 3 nœuds serveur (nombre impair requis)
- Les serveurs exécutent : etcd, l'API Kubernetes avec VIP (Keepalived ou Kube-VIP), et autres services du plan de contrôle
- **Configuration utilisée dans ce homelab**

## Fonctionnalités

- **Mode déconnecté (Air-Gap)** : Installation possible avec artefacts locaux
- **Mise à niveau progressive** : Les nœuds sont redémarrés un par un lors des mises à niveau
- **Vérification d'état** : Le rôle vérifie que chaque nœud est Ready avant de passer au suivant
- **Haute disponibilité** : Support de Keepalived et Kube-VIP pour l'IP virtuelle
- **CNI flexible** : Support de Canal, Calico, Multus, Cilium
- **Ingress Controllers** : NGINX Ingress (par défaut), Traefik, Istio

## Prérequis pour le contrôleur Ansible

* Ansible 2.10+
* Package Python `netaddr`

## Testé sur

* Rocky Linux 9
* Ubuntu 24.04 LTS

## Configuration Homelab

Ce rôle est configuré pour déployer RKE2 sur l'infrastructure Proxmox du homelab avec :

- **Mode HA** activé avec 3 nœuds master
- **Keepalived ou Kube-VIP** pour la VIP du cluster
- **CNI** : Canal (par défaut) ou Cilium selon configuration
- **Ingress Controller** : NGINX Ingress Controller
- **VMs provisionnées** via Terraform sur Proxmox

### Architecture

```
┌─────────────────────────────────────────────┐
│          VIP Kubernetes API (Keepalived)     │
│              10.0.20.100:6443                │
└─────────────────────────────────────────────┘
           │          │          │
    ┌──────┴────┬─────┴────┬────┴──────┐
    │  Master1  │ Master2  │  Master3  │
    │ 10.0.20.11│10.0.20.12│10.0.20.13 │
    └───────────┴──────────┴───────────┘
           │          │          │
    ┌──────┴────┬─────┴────┬────┴──────┐
    │  Worker1  │ Worker2  │  Worker3  │
    │ 10.0.20.21│10.0.20.22│10.0.20.23 │
    └───────────┴──────────┴───────────┘
```

### Variables personnalisées pour le homelab

Voir le fichier `group_vars/all.yml` pour la configuration complète. Principales variables :

```yaml
rke2_ha_mode: true
rke2_ha_mode_keepalived: true
rke2_api_ip: 10.0.20.100  # VIP pour l'API Kubernetes
rke2_version: v1.28.5+rke2r1
rke2_download_kubeconf: true
rke2_server_node_taints:
  - 'CriticalAddonsOnly=true:NoExecute'
```

## Composants installés

### Composants principaux RKE2

#### 1. Plan de contrôle Kubernetes
- **kube-apiserver** : Serveur API Kubernetes (point d'entrée du cluster)
- **kube-controller-manager** : Gestionnaire de contrôleurs Kubernetes
- **kube-scheduler** : Ordonnanceur de pods
- **kubelet** : Agent sur chaque nœud pour gérer les pods

#### 2. Stockage de données
- **etcd** : Base de données distribuée clé-valeur pour l'état du cluster
- **Snapshots etcd** : Sauvegarde/restauration (fichiers locaux ou S3)

#### 3. Réseau CNI (Container Network Interface)
Par défaut : **Canal** (configurable via `rke2_cni`)

Options disponibles :
- **Canal** : Combinaison de Flannel (réseau) + Calico (politique réseau)
- **Calico** : Solution réseau complète avec politiques réseau avancées
- **Cilium** : Réseau basé sur eBPF avec observabilité avancée
- **Multus** : Support multi-réseau (plusieurs interfaces réseau par pod)

Configuration réseau par défaut :
- CIDR des pods : `10.42.0.0/16`
- CIDR des services : `10.43.0.0/16`
- Protocole : VXLAN (UDP 8472)

#### 4. DNS
- **CoreDNS** : Serveur DNS pour la découverte de services Kubernetes
  - Résolution des noms de services : `service.namespace.svc.cluster.local`
  - Peut être désactivé via `rke2_disable: ['rke2-coredns']`

#### 5. Métriques
- **Metrics Server** : Collecteur de métriques de ressources
  - Nécessaire pour HPA (Horizontal Pod Autoscaler)
  - Nécessaire pour VPA (Vertical Pod Autoscaler)
  - Fournit les métriques CPU/mémoire des pods
  - Peut être désactivé via `rke2_disable: ['rke2-metrics-server']`

#### 6. Proxy réseau
- **kube-proxy** : Proxy réseau pour les services Kubernetes
  - Mode iptables (par défaut)
  - Mode IPVS (optionnel via `rke2_kube_proxy_arg: ["proxy-mode=ipvs"]`)
  - Peut être désactivé via `disable_kube_proxy: true`

#### 7. Runtime de conteneurs
- **containerd** : Runtime de conteneurs intégré à RKE2
  - Snapshotter : overlayfs (par défaut)
  - Configuration des registres personnalisés possible

### Contrôleurs Ingress (un seul actif)

Variable : `rke2_ingress_controller`

#### 1. NGINX Ingress Controller (par défaut)
- HelmChart : `rke2-ingress-nginx`
- Namespace : `kube-system`
- Configurable via `rke2_ingress_nginx_values`
- Gère le trafic HTTP/HTTPS vers les services

#### 2. Traefik (optionnel)
- HelmChart : `rke2-traefik`
- Configurable via `rke2_traefik_values`
- Support natif de Let's Encrypt
- Dashboard web intégré

#### 3. Istio (optionnel)
- HelmChart : `rke2-istio`
- Namespace : `istio-system`
- Configurable via `rke2_istio_values`
- Service mesh complet (ingress + mesh)

#### 4. Aucun (optionnel)
- Permet d'installer un ingress controller personnalisé

### Composants de haute disponibilité (HA)

Active si `rke2_ha_mode: true`

#### Option 1 : Keepalived (recommandé)
Active si `rke2_ha_mode_keepalived: true`

- **Keepalived** : Fournit une IP virtuelle (VIP) pour l'API Kubernetes
  - VIP partagée entre les masters
  - Protocole VRRP pour l'élection du master principal
  - Health checks :
    - `check_apiserver.sh` : Vérifie la disponibilité de l'API Kubernetes
    - `check_rke2server.sh` : Vérifie le service RKE2
  - Requiert : iptables/iptables-persistent

Configuration typique homelab :
- VIP : `10.0.20.100`
- Port : `6443` (API Kubernetes)

#### Option 2 : Kube-VIP (alternatif)
Active si `rke2_ha_mode_kubevip: true` (incompatible avec Keepalived)

- **Kube-VIP** : Load balancer et VIP pour l'API Kubernetes
  - DaemonSet sur les nœuds master
  - Images :
    - `ghcr.io/kube-vip/kube-vip:v0.9.2`
    - `ghcr.io/kube-vip/kube-vip-cloud-provider:v0.0.12`
  - Fonctionnalités :
    - VIP pour l'API Kubernetes (ARP ou BGP)
    - Load balancer pour services de type LoadBalancer
    - Cloud provider pour attribution automatique d'IPs
    - Load balancer IPVS pour le plan de contrôle (optionnel)
    - Élection de leader par service
    - Métriques Prometheus (port 2112)

### Composants de stockage

#### 1. Utilitaires NFS
- **nfs-utils** : Installé sur tous les nœuds
- Permet le montage de volumes NFS
- Préparation pour Longhorn ou autres solutions de stockage

#### 2. Support Longhorn (à installer séparément)
- Stockage distribué block storage
- Réplication des données entre nœuds

### Sécurité et durcissement

#### CIS Benchmark (optionnel)
Active via `rke2_cis_profile` (ex: "cis-1.23", "cis-1.6", "cis")

- Création d'utilisateur/groupe système etcd
- Durcissement des paramètres sysctl :
  - `rke2-cis-sysctl.conf`
- Conformité aux standards de sécurité CIS

#### Pare-feu
- Désactivation de firewalld (si présent)
- Activation de nftables
- Gestion des ports requis pour RKE2

#### SELinux
- Support SELinux optionnel via `rke2_selinux: true`

### Prérequis système installés

- **iptables** : Règles de pare-feu pour réseau Kubernetes
- **iptables-persistent** (Ubuntu/Debian) : Persistance des règles
- **iptables-services** (Rocky/CentOS/RedHat) : Service iptables

### Fichiers de configuration générés

#### 1. Configuration RKE2 principale
`/etc/rancher/rke2/config.yaml`
- Configuration serveur/agent
- Sélection du CNI
- Configuration etcd
- Configuration du cloud provider
- Arguments kubelet, kube-controller-manager, kube-scheduler
- TLS SANs supplémentaires

#### 2. Configuration Kubelet
`/etc/rancher/rke2/kubelet-config.yaml` (optionnel)
- Seuils de garbage collection des images
- Réservations de ressources système

#### 3. Configuration des registres
`/etc/rancher/rke2/registries.yaml`
- Miroirs de registres personnalisés
- Authentification aux registres

#### 4. Variables d'environnement
`/etc/systemd/system/rke2-server.service.env` ou `rke2-agent.service.env`
- Configuration du proxy HTTP/HTTPS
- Variables d'environnement personnalisées

### Fonctionnalités optionnelles

#### Mode déconnecté (Air-Gap)
Active via `rke2_airgap_mode: true`

- Déploiement sans connexion Internet
- Artefacts en cache local :
  - `rke2.linux-amd64.tar.gz`
  - `rke2-images.linux-amd64.tar.zst`
  - Tarballs supplémentaires pour CNI

#### Snapshots et restauration etcd
- **Snapshots locaux** : `rke2_etcd_snapshot_file`
- **Snapshots S3** : `rke2_etcd_snapshot_s3_options`
  - Sauvegarde automatique vers S3
  - Restauration depuis S3
  - Rétention configurable

#### Manifests personnalisés
- **Manifests Kubernetes** : `rke2_custom_manifests`
  - Déploiement automatique de manifests YAML
  - Support du templating Jinja2
- **Pods statiques** : `rke2_static_pods`
  - Pods gérés directement par kubelet

#### Intégration cloud provider
- Support natif : AWS, Azure, GCP, OpenStack, vSphere
- Cloud provider externe : `rke2_cloud_provider_name: "external"`
- Désactivation : `rke2_disable_cloud_controller: true`

### Processus de gestion du cluster

#### 1. Initialisation
- Initialisation du premier serveur
- Restauration etcd depuis snapshot (si configuré)
- Création du plan de contrôle

#### 2. Ajout de nœuds
- Jonction des serveurs supplémentaires
- Jonction des agents/workers
- Vérification de l'état Ready

#### 3. Mise à niveau progressive (Rolling Restart)
- Redémarrage des nœuds un par un
- Support du cordon/drain des nœuds
- Vérification de santé avant de continuer
- Pas de downtime du cluster

#### 4. Gestion de la configuration
- Redémarrages automatiques lors de changements de config
- Handlers Ansible pour les services

## Démarrage rapide

### 1. Préparation de l'infrastructure

Les VMs doivent avoir été créées via Terraform (voir `../proxmox-terraform/`).

### 2. Configuration de l'inventaire

Créer/vérifier le fichier `inventory/hosts.ini` :

```ini
[masters]
k8s-master-01 ansible_host=10.0.20.11
k8s-master-02 ansible_host=10.0.20.12
k8s-master-03 ansible_host=10.0.20.13

[workers]
k8s-worker-01 ansible_host=10.0.20.21
k8s-worker-02 ansible_host=10.0.20.22
k8s-worker-03 ansible_host=10.0.20.23

[k8s_cluster:children]
masters
workers
```

### 3. Déploiement du cluster

```bash
# Installer le rôle (si nécessaire)
ansible-galaxy install -r requirements.yml

# Déployer le cluster
ansible-playbook -i inventory/hosts.ini site.yml

# Vérifier le déploiement
export KUBECONFIG=~/rke2.yaml
kubectl get nodes
kubectl get pods -A
```

### 4. Accès au cluster

Le fichier kubeconfig sera téléchargé automatiquement si `rke2_download_kubeconf: true`.

```bash
export KUBECONFIG=~/rke2.yaml
kubectl cluster-info
```

## Variables du rôle

Ceci est une copie de `defaults/main.yml`

```yaml
---
# Détermine si les rétrogradations de la version RKE2 sont autorisées.
# Si défini sur `false`, le rôle empêchera les rétrogradations sauf si explicitement autorisé.
# Définir sur `true` pour autoriser les rétrogradations de la version RKE2.
# Note : Ce paramètre est ignoré en mode check d'Ansible, et la tâche de prévention associée sera ignorée.
rke2_allow_downgrade: false

# Le type de nœud - server ou agent
rke2_type: "{{ 'server' if inventory_hostname in groups[rke2_servers_group_name] else 'agent' if inventory_hostname in groups[rke2_agents_group_name] }}"

# Déployer le plan de contrôle en mode HA
rke2_ha_mode: false

# Installer et configurer Keepalived sur les nœuds serveur
# Peut être désactivé si vous utilisez un équilibreur de charge préconfiguré
rke2_ha_mode_keepalived: true

# Installer et configurer kube-vip LB et VIP pour le cluster
# rke2_ha_mode_keepalived doit être false
rke2_ha_mode_kubevip: false

# Adresse IP de l'API Kubernetes et d'enregistrement RKE2. L'adresse par défaut est l'IPv4 du nœud serveur/Master.
# En mode HA, choisissez une IP statique qui sera définie comme VIP dans keepalived.
# Ou si keepalived est désactivé, utilisez l'adresse IP de votre LB.
rke2_api_ip: "{{ hostvars[groups[rke2_servers_group_name].0]['ansible_default_ipv4']['address'] | default(hostvars[groups[rke2_servers_group_name].0]['ansible_default_ipv6']['address'] ) }}"

# Option optionnelle pour que le serveur RKE2 écoute sur une adresse IP privée et un port
# rke2_api_private_ip:
rke2_api_private_port: 9345

# Option optionnelle pour le sous-réseau IP kubevip
# rke2_api_cidr: 24

# Option optionnelle pour kubevip
# rke2_interface: eth0
# Option optionnelle pour les adresses IPv4/IPv6 à annoncer pour le nœud
# rke2_bind_address: "{{ hostvars[inventory_hostname]['ansible_' + rke2_interface]['ipv4']['address'] }}"

# Plage d'adresses IP de l'équilibreur de charge kubevip
rke2_loadbalancer_ip_range: {}
#  range-global: 192.168.1.50-192.168.1.100
#  cidr-finance: 192.168.0.220/29,192.168.0.230/29

# Installer le fournisseur cloud kubevip si rke2_ha_mode_kubevip est true
rke2_kubevip_cloud_provider_enable: true

# Activer kube-vip pour surveiller les services de type LoadBalancer
rke2_kubevip_svc_enable: true

# Spécifier quelle image est utilisée pour le conteneur kube-vip
rke2_kubevip_image: ghcr.io/kube-vip/kube-vip:v0.9.2

# Spécifier quelle image est utilisée pour le conteneur du fournisseur cloud kube-vip
rke2_kubevip_cloud_provider_image: ghcr.io/kube-vip/kube-vip-cloud-provider:v0.0.12

# Activer l'équilibreur de charge IPVS kube-vip pour le plan de contrôle
rke2_kubevip_ipvs_lb_enable: false
# Activer l'équilibrage de charge de couche 4 pour le plan de contrôle en utilisant le module noyau IPVS
# Doit utiliser kube-vip version 0.4.0 ou ultérieure

rke2_kubevip_service_election_enable: true
# Par défaut, le mode ARP fournit une implémentation HA d'une VIP (l'adresse IP de votre service) qui recevra le trafic sur le leader kube-vip.
# Pour contourner cela, kube-vip a implémenté une nouvelle fonction qui est "élection du leader par service",
# au lieu qu'un nœud devienne le leader pour tous les services, une élection est organisée entre toutes les instances kube-vip et le leader de cette élection devient le détenteur de ce service. En fin de compte,
# cela signifie que chaque service peut se retrouver sur un nœud différent lors de sa création, évitant en théorie un goulot d'étranglement lors du déploiement initial.
# version minimale de kube-vip 0.5.0

# (Optionnel) Modifier les paramètres pour l'élection du leader - voir le lien des drapeaux d'installation en amont ci-dessous
# rke2_kubevip_leaseduration: 5
# rke2_kubevip_renewdeadline: 3
# rke2_kubevip_retryperiod: 1
# rke2_kubevip_loglevel: 4

# (Optionnel) Une liste de drapeaux kube-vip
# Tous les drapeaux peuvent être trouvés ici https://kube-vip.io/docs/installation/flags/
# rke2_kubevip_args: []
# - param: lb_enable
#   value: true
# - param: lb_port
#   value: 6443

# Port des métriques Prometheus pour kube-vip
rke2_kubevip_metrics_port: 2112

# Ajouter des SANs supplémentaires dans le certificat TLS de l'API k8s
rke2_additional_sans: []

# Configurer le domaine du cluster
# rke2_cluster_domain: cluster.example.net

# Port de destination du serveur API
rke2_apiserver_dest_port: 6443

# Taints des nœuds serveur
rke2_server_node_taints: []
  # - 'CriticalAddonsOnly=true:NoExecute'

# Taints des nœuds agent
rke2_agent_node_taints: []

# Jeton secret partagé que les autres nœuds serveur ou agent utiliseront pour s'enregistrer lors de la connexion au cluster
rke2_token: defaultSecret12345

# Version RKE2
rke2_version: v1.25.3+rke2r1

# URL du dépôt RKE2
rke2_channel_url: https://update.rke2.io/v1-release/channels

# URL du script bash d'installation de RKE2
# ex. miroir chinois rancher http://rancher-mirror.rancher.cn/rke2/install.sh
rke2_install_bash_url: https://get.rke2.io

# Répertoire de données local pour RKE2
rke2_data_path: /var/lib/rancher/rke2

# URL par défaut pour récupérer les artefacts
rke2_artifact_url: https://github.com/rancher/rke2/releases/download/

# Chemin local pour stocker les artefacts
rke2_artifact_path: /rke2/artifact

# Artefacts requis pour le mode déconnecté
rke2_artifact:
  - sha256sum-{{ rke2_architecture }}.txt
  - rke2.linux-{{ rke2_architecture }}.tar.gz
  - rke2-images.linux-{{ rke2_architecture }}.tar.zst

# Timeout pour récupérer les artefacts en secondes
rke2_artifact_fetch_timeout: 30

# Change la stratégie de déploiement pour installer en fonction des artefacts locaux
rke2_airgap_mode: false

# Type d'implémentation déconnectée - download, copy ou exists
# - 'download' récupérera les artefacts sur chaque nœud,
# - 'copy' transférera les fichiers locaux dans 'rke2_artifact' vers les nœuds,
# - 'exists' suppose que les fichiers 'rke2_artifact' sont déjà stockés dans 'rke2_artifact_path'
rke2_airgap_implementation: download

# Chemin source local où les artefacts sont stockés
rke2_airgap_copy_sourcepath: local_artifacts

# Images tarball pour les composants supplémentaires à copier depuis rke2_airgap_copy_sourcepath vers les nœuds
# (Les extensions de fichier dans la liste et sur les fichiers réels doivent être conservées)
rke2_airgap_copy_additional_tarballs: []

# Destination des tarballs d'images supplémentaires déconnectées (voir https://docs.rke2.io/install/airgap#tarball-method)
rke2_tarball_images_path: "{{ rke2_data_path }}/agent/images"

# Architecture à télécharger, il existe actuellement des versions pour amd64 et s390x
rke2_architecture: amd64

# Répertoire de destination pour le script d'installation RKE2
rke2_install_script_dir: /var/tmp

# Canal RKE2
rke2_channel: stable

# Ne pas déployer les composants packagés et supprimer tous les composants déployés
# Éléments valides : rke2-canal, rke2-coredns, rke2-ingress-nginx, rke2-metrics-server
rke2_disable: []

# Option pour désactiver kube-proxy
disable_kube_proxy: false

# Option pour désactiver le contrôleur cloud intégré lorsque vous travaillez avec aws, azure, gce, etc.
# Pour un environnement sur site, cela devrait rester false et garder rke2_cloud_provider_name comme "external"
# https://docs.k3s.io/networking/networking-services#deploying-an-external-cloud-controller-manager (identique pour RKE2)
rke2_disable_cloud_controller: false

# Fournisseur cloud à utiliser pour le cluster (aws, azure, gce, openstack, vsphere, external)
# applicable uniquement si rke2_disable_cloud_controller est true
rke2_cloud_provider_name: "external"

# Chemin vers les manifests personnalisés déployés pendant l'installation de RKE2
# Il est possible d'utiliser le templating Jinja2 dans les manifests
rke2_custom_manifests: []

# Chemin vers les pods statiques déployés pendant l'installation de RKE2
rke2_static_pods: []

# Configurer le registre Containerd personnalisé
rke2_custom_registry_mirrors: []
  # - name:
  #   endpoint: {}
#   rewrite: '"^rancher/(.*)": "mirrorproject/rancher-images/$1"'

# Configurer la configuration supplémentaire du registre Containerd personnalisé
rke2_custom_registry_configs: []
#   - endpoint:
#     config:

# Chemin vers le fichier de template de configuration du registre de conteneurs
rke2_custom_registry_path: templates/registries.yaml.j2

# Chemin vers le fichier de template de configuration RKE2
rke2_config: templates/config.yaml.j2

# Répertoire source des snapshots Etcd
rke2_etcd_snapshot_source_dir: etcd_snapshots

# Nom de fichier du snapshot Etcd.
# Lorsque le nom de fichier est défini, l'etcd sera restauré lors de l'exécution initiale du déploiement Ansible.
# L'etcd sera restauré uniquement lors de l'exécution initiale, donc même si vous laissez le nom de fichier spécifié,
# l'etcd restera intact lors des exécutions suivantes.
# Vous pouvez soit utiliser ceci, soit définir les options dans `rke2_etcd_snapshot_s3_options`
rke2_etcd_snapshot_file: ""

# Emplacement du snapshot Etcd
rke2_etcd_snapshot_destination_dir: "{{ rke2_data_path }}/server/db/snapshots"

# Options s3 du snapshot Etcd
# Définir soit toutes ces valeurs, soit `rke2_etcd_snapshot_file` et `rke2_etcd_snapshot_source_dir`

# rke2_etcd_snapshot_s3_options:
  # s3_endpoint: "" # requis
  # access_key: "" # requis
  # secret_key: "" # requis
  # bucket: "" # requis
  # snapshot_name: "" # optionnel - si spécifié, etcd sera restauré lors de la première initialisation, c'est-à-dire lors du démarrage à partir de zéro
  # skip_ssl_verify: false # optionnel
  # endpoint_ca: "" # optionnel. Peut ignorer si utilisation des valeurs par défaut
  # region: "" # optionnel - par défaut us-east-1
  # folder: "" # optionnel - par défaut au niveau supérieur du bucket
  # proxy: "" # optionnel - Serveur proxy à utiliser lors de la connexion à S3, remplaçant toutes les variables d'environnement liées au proxy
  # insecure: false # optionnel - Désactive S3 sur HTTPS
  # timeout: "" # optionnel - Timeout S3 (par défaut : 5m0s)
  # s3_retention: 5 # optionnel - Nombre de snapshots dans S3 à conserver (par défaut : 5)
# Remplacer le snapshotter containerd par défaut
rke2_snapshotter: "{{ rke2_snapshooter }}"
rke2_snapshooter: overlayfs # variable héritée qui n'existe que pour maintenir la rétrocompatibilité avec les configurations précédentes

# Déployer RKE2 avec le CNI canal par défaut
rke2_cni: [canal]

# Valider la configuration du système par rapport au benchmark sélectionné
# (Valeur supportée est "cis-1.23" ou éventuellement "cis-1.6" si vous exécutez RKE2 avant 1.25 ou "cis" pour rke2 1.30+)
rke2_cis_profile: ""

# Télécharger le fichier de configuration Kubernetes sur le contrôleur Ansible
rke2_download_kubeconf: false

# Nom du fichier de configuration Kubernetes qui sera téléchargé sur le contrôleur Ansible
rke2_download_kubeconf_file_name: rke2.yaml

# Répertoire de destination où le fichier de configuration Kubernetes sera téléchargé sur le contrôleur Ansible
rke2_download_kubeconf_path: /tmp

# Nom du groupe d'inventaire Ansible par défaut pour le cluster RKE2
rke2_cluster_group_name: k8s_cluster

# Nom du groupe d'inventaire Ansible par défaut pour les serveurs RKE2
rke2_servers_group_name: masters

# Nom du groupe d'inventaire Ansible par défaut pour les agents RKE2
rke2_agents_group_name: workers

# (Optionnel) Une liste de drapeaux du serveur API Kubernetes
# Tous les drapeaux peuvent être trouvés ici https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver
# rke2_kube_apiserver_args: []

# (Optionnel) Liste des étiquettes de nœud
# k8s_node_label: []

# (Optionnel) Options de configuration du serveur RKE2 supplémentaires
# Vous pouvez trouver les drapeaux sur https://docs.rke2.io/reference/server_config
# rke2_server_options:
#   - "option: value"
#   - "node-ip: {{ rke2_bind_address }}"  # ex : (agent/networking) Adresses IPv4/IPv6 à annoncer pour le nœud

# (Optionnel) Options de configuration de l'agent RKE2 supplémentaires
# Vous pouvez trouver les drapeaux sur https://docs.rke2.io/reference/linux_agent_config
# rke2_agent_options:
#   - "option: value"
#   - "node-ip: {{ rke2_bind_address }}"  # ex : (agent/networking) Adresses IPv4/IPv6 à annoncer pour le nœud

# (Optionnel) Configurer le proxy
# Tous les drapeaux peuvent être trouvés ici https://docs.rke2.io/advanced#configuring-an-http-proxy
# rke2_environment_options: []
#   - "option=value"
#   - "HTTP_PROXY=http://your-proxy.example.com:8888"

# (Optionnel) Personnaliser les arguments par défaut de kube-controller-manager
# Cette fonctionnalité permet d'ajouter l'argument s'il n'est pas présent par défaut ou de le remplacer s'il existe déjà.
# rke2_kube_controller_manager_arg:
#   - "bind-address=0.0.0.0"

# (Optionnel) Personnaliser les arguments par défaut de kube-scheduler
# Cette fonctionnalité permet d'ajouter l'argument s'il n'est pas présent par défaut ou de le remplacer s'il existe déjà.
# rke2_kube_scheduler_arg:
#   - "bind-address=0.0.0.0"

# Configurer le contrôleur Ingress (valeurs autorisées : ingress-nginx, traefik, istio, none)
rke2_ingress_controller: ingress-nginx

# (Optionnel) Configurer nginx via HelmChartConfig : https://docs.rke2.io/networking/networking_services#nginx-ingress-controller
# rke2_ingress_nginx_values:
#   controller:
#     config:
#       use-forwarded-headers: "true"
rke2_ingress_nginx_values: {}

# (Optionnel) Configurer Traefik via HelmChartConfig
# rke2_traefik_values:
#   ports:
#     web:
#       exposedPort: 80
rke2_traefik_values: {}

# (Optionnel) Configurer Istio via HelmChartConfig
# rke2_istio_values:
#   pilot:
#     resources:
#       requests:
#         cpu: 100m
#         memory: 128Mi
rke2_istio_values: {}

# Cordon, drain le nœud qui est en cours de mise à niveau. Uncordon le nœud une fois RKE2 mis à niveau
rke2_drain_node_during_upgrade: false
# Arguments supplémentaires qui seront passés à la commande kubectl drain, par exemple --pod-selector
rke2_drain_additional_args: ""

# Attendre que tous les pods aient un statut running ou succeeded après le redémarrage du service rke2 pendant le redémarrage progressif.
rke2_wait_for_all_pods_to_be_ready: false
# Attendre que tous les pods soient prêts après le redémarrage du service rke2 pendant le redémarrage progressif.
# Nommé "healthy" pour maintenir la rétrocompatibilité avec les noms de variables existants.
rke2_wait_for_all_pods_to_be_healthy: false
# Les arguments passés à la commande kubectl wait
rke2_wait_for_all_pods_to_be_healthy_args: --for=condition=Ready -A --all pod --field-selector=metadata.namespace!=kube-system,status.phase!=Succeeded

# Activer le mode debug (rke2-service)
rke2_debug: false

# (Optionnel) Personnaliser la configuration kubelet en utilisant KubeletConfiguration - https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/
# rke2_kubelet_config:
#   imageGCHighThresholdPercent: 80
#   imageGCLowThresholdPercent: 70
# Notez que vous devez également ajouter ce qui suit aux arguments kubelet :
# rke2_kubelet_arg:
#   - "--config=/etc/rancher/rke2/kubelet-config.yaml"
rke2_kubelet_config: {}

# (Optionnel) Personnaliser les arguments par défaut de kubelet
# rke2_kubelet_arg:
#   - "--system-reserved=cpu=100m,memory=100Mi"

# (Optionnel) Personnaliser les arguments par défaut de kube-proxy
# rke2_kube_proxy_arg:
#   - "proxy-mode=ipvs"

# (Optionnel) Personnaliser les montages supplémentaires par défaut de kube-proxy
# rke2_kube_proxy_extra_mount:
#   - "/lib/modules:/lib/modules:ro"

# La valeur pour l'élément de configuration node-name
rke2_node_name: "{{ inventory_hostname }}"

# Plage de réseau de pods par défaut pour rke2
rke2_cluster_cidr:
  - 10.42.0.0/16

# Plage de réseau de services par défaut pour rke2
rke2_service_cidr:
  - 10.43.0.0/16

# Activer SELinux pour rke2
rke2_selinux: false

```

## Exemple de fichier d'inventaire

Ce rôle repose sur la distribution des nœuds dans les groupes d'inventaire `masters` et `workers`.
Les nœuds master/serveur Kubernetes RKE2 doivent appartenir au groupe `masters` et les nœuds worker/agent doivent être membres du groupe `workers`. Les deux groupes doivent être des enfants du groupe `k8s_cluster`.

```ini
[masters]
master-01 ansible_host=192.168.123.1
master-02 ansible_host=192.168.123.2
master-03 ansible_host=192.168.123.3

[workers]
worker-01 ansible_host=192.168.123.11
worker-02 ansible_host=192.168.123.12
worker-03 ansible_host=192.168.123.13

[k8s_cluster:children]
masters
workers
```

## Exemple de playbook

Ce playbook déploiera RKE2 sur un nœud unique agissant à la fois comme serveur et agent.

```yaml
- name: Deploy RKE2
  hosts: node
  become: yes
  roles:
     - role: lablabs.rke2

```

Ce playbook déploiera RKE2 sur un cluster avec un serveur (master) et plusieurs nœuds agent (worker).

```yaml
- name: Deploy RKE2
  hosts: all
  become: yes
  roles:
     - role: lablabs.rke2

```

Ce playbook déploiera RKE2 sur un cluster avec un serveur (master) et plusieurs nœuds agent (worker) en mode déconnecté. Il utilisera Multus et Calico comme CNI.

```yaml
- name: Deploy RKE2
  hosts: all
  become: yes
  vars:
    rke2_airgap_mode: true
    rke2_airgap_implementation: download
    rke2_cni:
      - multus
      - calico
    rke2_artifact:
      - sha256sum-{{ rke2_architecture }}.txt
      - rke2.linux-{{ rke2_architecture }}.tar.gz
      - rke2-images.linux-{{ rke2_architecture }}.tar.zst
    rke2_airgap_copy_additional_tarballs:
      - rke2-images-multus.linux-{{ rke2_architecture }}
      - rke2-images-calico.linux-{{ rke2_architecture }}
  roles:
     - role: lablabs.rke2

```

Ce playbook déploiera RKE2 sur un cluster avec un plan de contrôle serveur (master) en HA et plusieurs nœuds agent (worker). Les nœuds serveur (master) seront taintés afin que la charge de travail soit distribuée uniquement sur les nœuds worker (agent). Le rôle installera également keepalived sur les nœuds du plan de contrôle et configurera l'adresse VIP où l'API Kubernetes sera accessible. Il téléchargera également le fichier de configuration Kubernetes sur la machine locale.

```yaml
- name: Deploy RKE2
  hosts: all
  become: yes
  vars:
    rke2_ha_mode: true
    rke2_api_ip : 192.168.123.100
    rke2_download_kubeconf: true
    rke2_server_node_taints:
      - 'CriticalAddonsOnly=true:NoExecute'
  roles:
     - role: lablabs.rke2

```

Ce playbook déploiera RKE2 avec Traefik comme contrôleur Ingress.

```yaml
- name: Deploy RKE2
  hosts: all
  become: yes
  vars:
    rke2_ingress_controller: traefik
    rke2_traefik_values:
      ports:
        web:
          exposedPort: 80
        websecure:
          exposedPort: 443
  roles:
     - role: lablabs.rke2

```

Ce playbook déploiera RKE2 avec Istio comme contrôleur Ingress.

```yaml
- name: Deploy RKE2
  hosts: all
  become: yes
  vars:
    rke2_ingress_controller: istio
    rke2_istio_values:
      pilot:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
      global:
        proxy:
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
  roles:
     - role: lablabs.rke2

```

## Avoir un jeton séparé pour les nœuds agent

Selon la [documentation de configuration du serveur](https://docs.rke2.io/reference/server_config), il est possible de définir un jeton agent, qui sera utilisé par les nœuds agent pour se connecter au cluster, leur donnant moins d'accès au cluster que les nœuds serveur.
Les modifications suivantes à la configuration ci-dessus seraient nécessaires :
- supprimer `rke2_token` des variables globales
- ajouter à `group_vars/masters.yml` :
```yaml
rke2_token: defaultSecret12345
rke2_agent_token: agentSecret54321
```
- ajouter à `group_vars/workers.yml` :
```yaml
rke2_token: agentSecret54321
```

Bien que changer le jeton serveur soit problématique, le jeton agent peut être changé à volonté, tant que les serveurs et les agents ont la même valeur et que les services
(`rke2-server` et `rke2-agent`, selon le cas) ont été redémarrés pour s'assurer que les processus utilisent la nouvelle valeur.

## Dépannage

### Le playbook se bloque lors du démarrage du service RKE2 sur les agents

Si le playbook commence à se bloquer à la tâche `Start RKE2 service on the rest of the nodes` puis échoue à la tâche `Wait for remaining nodes to be ready`, vous avez probablement des limitations sur le réseau de vos nœuds.

**Vérifications pour Proxmox/Homelab :**

1. **Vérifier les bridges réseau sur Proxmox** :
   ```bash
   # Sur le nœud Proxmox
   ip link show | grep vmbr
   ```

2. **Ports requis pour RKE2** :

   **Nœuds serveur (masters)** :
   - TCP 6443 : Kubernetes API Server
   - TCP 9345 : RKE2 supervisor API
   - TCP 2379-2380 : etcd client et peer
   - UDP 8472 : Canal/Flannel VXLAN
   - TCP 10250 : kubelet metrics
   - TCP 2112 : Kube-VIP metrics (si utilisé)

   **Nœuds agent (workers)** :
   - TCP 10250 : kubelet
   - UDP 8472 : Canal/Flannel VXLAN
   - TCP 30000-32767 : NodePort Services

3. **Tester la connectivité** :
   ```bash
   # Depuis un worker vers un master
   nc -zv 10.0.20.11 6443
   nc -zv 10.0.20.11 9345

   # Vérifier la VIP Keepalived
   ping 10.0.20.100
   ```

Veuillez vérifier les *règles de trafic entrant requises pour les nœuds serveur RKE2* au lien suivant : <https://docs.rke2.io/install/requirements/#networking>.

### Le playbook de mise à niveau RKE2 a échoué en raison d'une mise à niveau interrompue

Dans le cas où la nouvelle version de RKE2 a été installée mais non démarrée, relancez le playbook avec la variable `rke2_allow_downgrade: true` pour contourner la vérification de prévention de rétrogradation.

### Les nœuds ne peuvent pas atteindre la VIP Keepalived

Si les nœuds ne peuvent pas atteindre l'IP virtuelle (10.0.20.100) :

1. **Vérifier Keepalived sur les masters** :
   ```bash
   systemctl status keepalived
   ip addr show | grep 10.0.20.100
   ```

2. **Vérifier les logs Keepalived** :
   ```bash
   journalctl -u keepalived -f
   ```

3. **Vérifier la priorité** :
   - Master 1 doit avoir la priorité la plus haute
   - En cas de problème, vérifier la configuration dans `/etc/keepalived/keepalived.conf`

### Problèmes de stockage / Longhorn

Si vous utilisez Longhorn :

1. **Vérifier la connectivité réseau** :
   ```bash
   # Tester la connectivité entre les nœuds
   ping <ip-autre-noeud>
   ```

2. **Vérifier les disques** :
   ```bash
   lsblk
   df -h /var/lib/longhorn
   ```

## Documentation associée

- [Phase 1 - Déploiement Proxmox Terraform](../../proxmox-terraform/PHASE1-DEPLOYMENT.md)
- [Phase 3 - Déploiement Kubernetes](../../PHASE3-KUBERNETES.md)
- [Roadmap DevSecOps](../../ROADMAP-DEVSECOPS.md)
- [Configuration réseau Proxmox](../../proxmox-terraform/README-NETWORK.md)

## Licence

MIT

## Informations sur l'auteur

Créé en 2021 par Labyrinth Labs

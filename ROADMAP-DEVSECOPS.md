# Roadmap Homelab DevSecOps

Guide simplifié de mise en place d'un homelab DevSecOps sur Proxmox avec Kubernetes.

---

## Vue d'ensemble du projet

**Objectif** : Créer un environnement DevSecOps complet avec :
- Infrastructure as Code (Terraform)
- Cluster Kubernetes haute disponibilité (RKE2)
- Pipeline CI/CD (GitLab/ArgoCD)
- Monitoring & Observabilité (Prometheus/Grafana/Loki)
- Sécurité (OPNsense, Trivy, Vault, Falco)
- Segmentation réseau (3 réseaux isolés)

---

## Architecture finale

```
┌────────────────────────────────────────────────────────────────┐
│                         INTERNET                                │
└───────────────────────────┬────────────────────────────────────┘
                            │
                     ┌──────▼──────┐
                     │ Box Internet │
                     │ 192.168.1.1  │
                     └──────┬───────┘
                            │
┌───────────────────────────▼────────────────────────────────────┐
│                    vmbr0 (192.168.1.0/24)                       │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌──────┐  ┌────────┐ │
│  │Rancher-1│  │Rancher-2│  │Rancher-3│  │ CI/CD│  │OPNsense│ │
│  │  .110   │  │  .111   │  │  .112   │  │ .119 │  │  .200  │ │
│  └─────────┘  └─────────┘  └─────────┘  └──────┘  └────┬───┘ │
│                                                          │      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐               │      │
│  │Payload-M1│ │Payload-M2│ │Payload-M3│               │      │
│  │   .113   │ │   .114   │ │   .115   │               │      │
│  └──────────┘ └──────────┘ └──────────┘               │      │
│                                                          │      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐               │      │
│  │Payload-W1│ │Payload-W2│ │Payload-W3│               │      │
│  │   .116   │ │   .117   │ │   .118   │               │      │
│  └──────────┘ └──────────┘ └──────────┘               │      │
└────────────────────────────────────────────────────────┼──────┘
                                                          │
                    ┌─────────────────────────────────────┤
                    ↓                                     ↓
        ┌───────────────────────┐         ┌──────────────────────┐
        │ vmbr1 Management      │         │ vmbr2 Production     │
        │ 192.168.10.0/24       │         │ 192.168.20.0/24      │
        │                       │         │                      │
        │ - Monitoring          │         │ - Applications Prod  │
        │ - Logs (ELK)          │         │ - Bases de données   │
        │ - Grafana             │         │ - Services métiers   │
        └───────────────────────┘         └──────────────────────┘
```

---

## Stack technologique complète

### Infrastructure (Jour 1-3)
- **Virtualisation** : Proxmox VE 9.x
- **IaC** : Terraform (provider bpg/proxmox)
- **OS** : Rocky Linux 9 (Cloud-init)
- **Réseau** : OPNsense 25.7 (Firewall/Router)

### Orchestration Kubernetes (Jour 4-5)
- **Distribution K8s** : RKE2 (Rancher Kubernetes Engine 2)
- **Management UI** : Rancher 2.x
- **Ingress** : Nginx Ingress Controller
- **Storage** : Longhorn (distributed block storage)
- **Load Balancer** : MetalLB

### CI/CD (Jour 6-7)
- **Git** : GitLab CE (auto-hébergé)
- **CI/CD** : GitLab CI + GitLab Runner
- **GitOps** : ArgoCD
- **Registry** : Harbor (container registry)
- **Artifacts** : Nexus Repository

### Monitoring & Observabilité (Jour 9-10)
- **Metrics** : Prometheus + Node Exporter + Kube State Metrics
- **Dashboards** : Grafana (avec plugins)
- **Logs** : Loki + Promtail (recommandé) OU ELK Stack (optionnel)
- **Tracing** : Jaeger (optionnel)
- **Alerting** : AlertManager + Slack/Discord/Email

### Sécurité (Jour 10-12)
- **Firewall** : OPNsense
- **Network Policies** : Calico
- **Secrets** : HashiCorp Vault
- **Scanning** : Trivy (vulnerabilities)
- **SAST/DAST** : SonarQube
- **Runtime Security** : Falco
- **RBAC** : Kubernetes RBAC + Keycloak (SSO)
- **Backup** : Velero

### Outils additionnels
- **DNS** : CoreDNS (K8s internal) + Bind9 (réseau)
- **Certificates** : cert-manager + Let's Encrypt
- **Service Mesh** : Istio (optionnel)
- **ChatOps** : Mattermost

---

## Planning par phases

### Phase 1 : Infrastructure de base

**Objectif** : Préparer Proxmox et déployer les VMs

**Étapes** :
1. Installer/Mettre à jour Proxmox VE 9.x
2. Créer les bridges réseau (vmbr1, vmbr2)
3. Télécharger ISO OPNsense et créer template Rocky Linux 9
4. Configurer Terraform et déployer les 11 VMs
5. Vérifier connectivité SSH sur toutes les VMs

**Résultat** : 11 VMs opérationnelles avec réseau configuré

---

### Phase 2 : Réseau et sécurité

**Objectif** : Configurer OPNsense pour segmentation réseau

**Étapes** :
1. Installer OPNsense depuis ISO (VM ID 200)
2. Configurer les 3 interfaces réseau
3. Configurer règles firewall et NAT
4. Tester connectivité entre réseaux

**Configuration réseau** :
- LAN (vmbr1): 192.168.10.1/24 - Management
- OPT1 (vmbr2): 192.168.20.1/24 - Production
- OPT2 (vmbr0): 192.168.1.200/24 - Internet

**Résultat** : Segmentation réseau sécurisée opérationnelle

---

### Phase 3 : Cluster Kubernetes

**Objectif** : Déployer cluster RKE2 haute disponibilité

**Étapes** :
1. Installer RKE2 sur rancher-1 (premier master)
2. Joindre rancher-2 et rancher-3 au cluster
3. Ajouter les 6 worker nodes (payload-*)
4. Installer Longhorn pour le stockage
5. Installer MetalLB et Nginx Ingress

**Résultat** : Cluster K8s avec 3 masters + 6 workers opérationnel

---

### Phase 4 : CI/CD

**Objectif** : Mettre en place la chaîne CI/CD

**Étapes** :
1. Installer GitLab CE sur VM cicd
2. Configurer GitLab Runner dans K8s
3. Installer ArgoCD (recommandé) ou FluxCD
4. Installer Harbor (container registry)
5. Créer une application de démo

**Résultat** : Pipeline CI/CD complet avec GitOps

---

### Phase 5 : Monitoring et observabilité

**Objectif** : Mettre en place monitoring complet

**Étapes** :
1. Installer cert-manager pour certificats SSL/TLS
2. Installer Bind9 pour DNS local
3. Installer Prometheus + Grafana (kube-prometheus-stack)
4. Installer Loki + Promtail pour les logs
5. Configurer dashboards et alertes

**Résultat** : Observabilité complète (métriques + logs + alertes)

---

### Phase 6 : Sécurité avancée

**Objectif** : Renforcer la sécurité

**Étapes** :
1. Installer HashiCorp Vault pour les secrets
2. Installer Trivy Operator pour scanner les vulnérabilités
3. Installer SonarQube pour analyse de code
4. Installer Falco pour sécurité runtime
5. Configurer Velero pour backups

**Résultat** : Infrastructure sécurisée avec backup

---

## Guides de référence rapide

### ArgoCD vs FluxCD - Quel outil GitOps choisir?

| Critère | ArgoCD | FluxCD |
|---------|--------|--------|
| Interface UI | ✅ Web UI intuitive | ❌ CLI uniquement |
| Facilité | ⭐⭐⭐⭐⭐ Débutant friendly | ⭐⭐⭐ Plus technique |
| Ressources | RAM: 512MB-1GB | RAM: 256-512MB |
| Rollback | ✅ Via UI | Manuel (git revert) |

**Recommandation** : ArgoCD pour homelab (interface visuelle)

---

### Commandes essentielles par composant

#### Installation ArgoCD

```bash
# 1. Installer ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Exposer via LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# 3. Récupérer mot de passe
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 4. Accéder à l'UI
# URL: https://[IP-LOADBALANCER]
# User: admin / Password: [ci-dessus]
```

#### Installation RKE2

```bash
# Sur le premier master (rancher-1)
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service

# Récupérer token
cat /var/lib/rancher/rke2/server/node-token

# Sur les autres masters (rancher-2/3)
mkdir -p /etc/rancher/rke2/
cat > /etc/rancher/rke2/config.yaml <<EOF
server: https://192.168.1.110:9345
token: [VOTRE_TOKEN]
EOF
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service

# Configurer kubectl
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export PATH=$PATH:/var/lib/rancher/rke2/bin
```

#### Installation Monitoring (Prometheus + Grafana + Loki)

```bash
# 1. Installer kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring

# 2. Installer Loki
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki --namespace monitoring

# 3. Installer Promtail
helm install promtail grafana/promtail --namespace monitoring

# 4. Accéder Grafana
kubectl get svc -n monitoring kube-prometheus-grafana
# User: admin / Password: prom-operator
```

#### Installation GitLab

```bash
# Sur VM cicd (192.168.1.119)
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | bash
EXTERNAL_URL="http://192.168.1.119" dnf install -y gitlab-ce

# Récupérer mot de passe
cat /etc/gitlab/initial_root_password
```

---

## Ressources matérielles requises

| Composant | VMs | CPU | RAM | Stockage |
|-----------|-----|-----|-----|----------|
| Rancher (Masters) | 3 | 6 | 24 GB | 75 GB |
| Payload Masters | 3 | 6 | 12 GB | 75 GB |
| Payload Workers | 3 | 9 | 24 GB | 75 GB |
| CI/CD | 1 | 2 | 8 GB | 50 GB |
| OPNsense | 1 | 2 | 2 GB | 20 GB |
| **TOTAL** | **11** | **25** | **70 GB** | **295 GB** |

**Minimum recommandé pour le serveur Proxmox** :
- CPU: 16 cores
- RAM: 64 GB (128 GB recommandé)
- Stockage: 500 GB SSD NVMe

---

## Checklist de validation

### Infrastructure de base
- [ ] Proxmox opérationnel avec 3 bridges réseau
- [ ] 11 VMs créées via Terraform
- [ ] OPNsense configuré (3 réseaux segmentés)
- [ ] Connectivité réseau validée

### Kubernetes
- [ ] Cluster RKE2 avec 3 masters + 6 workers
- [ ] Longhorn pour stockage persistant
- [ ] MetalLB pour LoadBalancer
- [ ] Nginx Ingress opérationnel

### CI/CD
- [ ] GitLab accessible
- [ ] GitLab Runner dans K8s
- [ ] ArgoCD synchronise les apps
- [ ] Harbor registry fonctionnel

### Monitoring
- [ ] Prometheus collecte métriques
- [ ] Grafana avec dashboards
- [ ] Loki centralise logs
- [ ] Alerting configuré

### Sécurité
- [ ] Vault pour secrets
- [ ] Trivy scan vulnérabilités
- [ ] Certificats SSL/TLS automatiques
- [ ] Backup Velero configuré

---

## Évolutions futures

### Phase 2 (optionnel)
- Service Mesh (Istio)
- Chaos Engineering (Litmus)
- API Gateway (Kong/Traefik)
- Bases de données HA
- Message Broker (Kafka/RabbitMQ)

### Phase 3 (avancé)
- Multi-cluster avec Rancher Fleet
- Edge Computing (K3s)
- Hybrid Cloud
- Disaster Recovery

---

## Ressources utiles

**Documentation** :
- [RKE2 Docs](https://docs.rke2.io/)
- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [Prometheus Docs](https://prometheus.io/docs/)

**Certifications** :
- CKA (Certified Kubernetes Administrator)
- CKS (Certified Kubernetes Security Specialist)

---

## Prochaines étapes

1. Commencer par la **Phase 1** (Infrastructure de base)
2. Tester chaque composant avant de passer au suivant
3. Documenter les configurations spécifiques à votre environnement
4. Créer des snapshots réguliers des VMs importantes

**Note** : Ce roadmap est un guide. Adaptez-le selon vos besoins et ressources disponibles.

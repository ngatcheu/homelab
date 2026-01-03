# 🚀 Update VMs - Playbook de Maintenance Zero-Downtime

## 📋 Description

Le playbook `update-vms.yml` automatise la maintenance des nœuds d'un cluster Kubernetes RKE2 avec **zéro interruption de service**.

## 🎯 Objectifs

- ✅ **Zero-downtime** : Maintenir les services disponibles pendant la maintenance
- ✅ **Sécurité** : Évacuation gracieuse des pods avant maintenance
- ✅ **Automatisation** : Processus complet automatisé

## 🏗️ Prérequis

- **Cluster RKE2** opérationnel
- **Accès root** sur tous les nœuds
- **Connectivité SSH** entre le contrôleur Ansible et les nœuds

### **Structure de l'inventaire :**
```yaml
all:
  children:
    k8s_cluster:
      children:
        masters:
          vars:
            rke2_type: "server"
          hosts:
            master-1:
              ansible_host: devsecops-kub-p-5
            master-2:
              ansible_host: ip-master-2
            master-3:
              ansible_host: ip-master-3
        workers:
          vars:
            rke2_type: "agent"
          hosts:
            agent-1:
              ansible_host: ip-agent-1
            agent-2:
              ansible_host: ip-agent-2
            agent-3:
              ansible_host: ip-agent-3
```

## ⚙️ Configuration

| Variable | Défaut | Description |
|----------|--------|-------------|
| `drain_timeout` | 600s | Timeout pour l'évacuation des pods |
| `grace_period` | 300s | Délai d'arrêt gracieux des pods |
| `node_ready_timeout` | 180s | Timeout pour que le nœud soit Ready |
| `pod_ready_timeout` | 300s | Timeout pour que tous les pods soient Ready |

## 🔄 Workflow

**Exécution séquentielle** : Un nœud à la fois (`serial: 1`)

### **Pour les Workers :**
1. **Cordon** : Marque le nœud comme non-planifiable
2. **Drain** : Évacuation gracieuse des pods (300s grace period)
3. **Vérification** : Seuls DaemonSets et Static pods restent
4. **Maintenance** : Mise à jour système (à activer)
5. **Uncordon** : Réactive la planification
6. **Attente** : Tous les pods du cluster Ready

### **Pour les Masters :**
- Skip cordon/drain → Maintenance directe

## 🚀 Utilisation

### **Commande de base :**
```bash
ansible-playbook -i inventory-staging.yml --user ansible --private-key ~/.ssh/ansible update-vms.yml
```
Précision : il faut ajouter l'authentification : user + clé ssh

**🎯 Résultat** : Maintenance automatisée et sécurisée de votre cluster RKE2 avec préservation de la disponibilité des services !

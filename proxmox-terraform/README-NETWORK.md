# Configuration Réseau et OPNsense Firewall

Guide complet pour configurer l'architecture réseau segmentée avec OPNsense comme firewall interne.

---

## 📋 Table des matières

- [Architecture Réseau](#architecture-réseau)
- [Prérequis](#prérequis)
- [Configuration Proxmox](#configuration-proxmox)
- [Déploiement OPNsense](#déploiement-opnsense)
- [Configuration OPNsense](#configuration-opnsense)
- [Tests et Validation](#tests-et-validation)
- [Dépannage](#dépannage)

---

## Architecture Réseau

### Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET                                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                    ┌──────▼──────┐
                    │ Box Internet │
                    │ 192.168.1.1  │
                    └──────┬───────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    vmbr0 (Bridge Proxmox)                        │
│                     192.168.1.0/24                               │
│                                                                   │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌──────────┐ │
│  │ Rancher-1  │  │ Rancher-2  │  │ Rancher-3  │  │   CI/CD  │ │
│  │ .110       │  │ .111       │  │ .112       │  │   .119   │ │
│  └────────────┘  └────────────┘  └────────────┘  └──────────┘ │
│                                                                   │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                │
│  │ Payload-M1 │  │ Payload-M2 │  │ Payload-M3 │                │
│  │ .113       │  │ .114       │  │ .115       │                │
│  └────────────┘  └────────────┘  └────────────┘                │
│                                                                   │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                │
│  │ Payload-W1 │  │ Payload-W2 │  │ Payload-W3 │                │
│  │ .116       │  │ .117       │  │ .118       │                │
│  └────────────┘  └────────────┘  └────────────┘                │
│                                                                   │
│  ┌──────────────────────────────────────────────┐               │
│  │         OPNsense Firewall (VM 200)           │               │
│  │  ┌────────────────────────────────────────┐  │               │
│  │  │ vtnet2 (Uplink) → 192.168.1.200       │◄─┼───────────────┤
│  │  └────────────────────────────────────────┘  │               │
│  │  ┌────────────────────────────────────────┐  │               │
│  │  │ vtnet0 (LAN)    → 192.168.10.1        │  │               │
│  │  └───┬────────────────────────────────────┘  │               │
│  │  ┌───┴────────────────────────────────────┐  │               │
│  │  │ vtnet1 (OPT1)   → 192.168.20.1        │  │               │
│  │  └───┬────────────────────────────────────┘  │               │
│  └──────┼──────────────┼──────────────────────┘               │
│         │              │                                         │
└─────────┼──────────────┼─────────────────────────────────────────┘
          │              │
          │              │
┌─────────▼──────────────┼─────────────────────────────────────────┐
│     vmbr1 (Management) │                                          │
│     192.168.10.0/24    │                                          │
│                        │                                          │
│  ┌────────────────┐    │                                          │
│  │  VM Management │    │                                          │
│  │  DHCP .100-.200│    │                                          │
│  └────────────────┘    │                                          │
└────────────────────────┼──────────────────────────────────────────┘
                         │
┌────────────────────────▼──────────────────────────────────────────┐
│                   vmbr2 (Production)                               │
│                   192.168.20.0/24                                  │
│                                                                    │
│  ┌────────────────┐  ┌────────────────┐                          │
│  │ VM Production  │  │ VM Production  │                          │
│  │ DHCP .100-.200 │  │ DHCP .100-.200 │                          │
│  └────────────────┘  └────────────────┘                          │
└────────────────────────────────────────────────────────────────────┘
```

### Segmentation Réseau

| Réseau | Bridge | Subnet | Gateway | DHCP | Usage |
|--------|--------|--------|---------|------|-------|
| **Principal** | vmbr0 | 192.168.1.0/24 | Box (192.168.1.1) | Box | VMs Kubernetes, CI/CD |
| **Management** | vmbr1 | 192.168.10.0/24 | OPNsense (192.168.10.1) | OPNsense (.100-.200) | Admin, Monitoring |
| **Production** | vmbr2 | 192.168.20.0/24 | OPNsense (192.168.20.1) | OPNsense (.100-.200) | Applications |

### Flux Réseau

```
┌─────────────────┐
│ VM sur vmbr0    │ → Gateway: Box (192.168.1.1) → Internet Direct
└─────────────────┘

┌─────────────────┐
│ VM sur vmbr1    │ → Gateway: OPNsense (192.168.10.1) → Uplink (192.168.1.200) → Box → Internet
└─────────────────┘

┌─────────────────┐
│ VM sur vmbr2    │ → Gateway: OPNsense (192.168.20.1) → Uplink (192.168.1.200) → Box → Internet
└─────────────────┘
```

---

## Prérequis

### Logiciels

- Proxmox VE 9.x
- Terraform >= 1.12.2
- ISO OPNsense 25.7 (téléchargé sur Proxmox)

### Proxmox

Avant de déployer, assurez-vous que :

1. **L'ISO OPNsense est téléchargé**
   ```bash
   # Se connecter au serveur Proxmox
   ssh root@192.168.1.100

   # Télécharger OPNsense
   cd /var/lib/vz/template/iso
   wget https://mirror.ams1.nl.leaseweb.net/opnsense/releases/25.7/OPNsense-25.7-dvd-amd64.iso
   ```

2. **Les bridges réseau existent**
   ```bash
   # Vérifier les bridges
   ip link show | grep vmbr

   # Résultat attendu :
   # vmbr0: <BROADCAST,MULTICAST,UP,LOWER_UP>
   # vmbr1: <BROADCAST,MULTICAST,UP,LOWER_UP>  (à créer si absent)
   # vmbr2: <BROADCAST,MULTICAST,UP,LOWER_UP>  (à créer si absent)
   ```

---

## Configuration Proxmox

### Créer les bridges réseau

**⚠️ PRÉREQUIS OBLIGATOIRE** : Avant de déployer avec Terraform, vous devez créer les bridges vmbr1 et vmbr2 dans Proxmox.

#### Méthode 1 : Via l'Interface Web Proxmox (Recommandé)

**Interface Web** : https://192.168.1.100:8006

**Étapes :**

1. **Se connecter à Proxmox Web UI**
   - Utilisateur : `root@pam`
   - Mot de passe : votre mot de passe root

2. **Accéder à la configuration réseau**
   ```
   Datacenter → Node (devsecops-dojo) → System → Network
   ```

3. **Créer vmbr1 (Management Network)**
   - Cliquer sur **Create** → **Linux Bridge**
   - Remplir les champs :
     ```
     Name: vmbr1
     IPv4/CIDR: [LAISSER VIDE]
     IPv6/CIDR: [LAISSER VIDE]
     Autostart: ✅ (coché)
     VLAN aware: ☐ (décoché)
     Bridge ports: [LAISSER VIDE]
     Comment: Management Network - OPNsense LAN
     ```
   - Cliquer sur **Create**

4. **Créer vmbr2 (Production Network)**
   - Cliquer sur **Create** → **Linux Bridge**
   - Remplir les champs :
     ```
     Name: vmbr2
     IPv4/CIDR: [LAISSER VIDE]
     IPv6/CIDR: [LAISSER VIDE]
     Autostart: ✅ (coché)
     VLAN aware: ☐ (décoché)
     Bridge ports: [LAISSER VIDE]
     Comment: Production Network - OPNsense OPT1
     ```
   - Cliquer sur **Create**

5. **Appliquer la configuration**
   - Cliquer sur **Apply Configuration** en haut
   - ⚠️ **ATTENTION** : Ceci peut brièvement interrompre la connexion réseau
   - Un redémarrage du node n'est **PAS nécessaire** dans la plupart des cas

6. **Vérifier la création**
   - Vous devriez voir 3 bridges dans la liste :
     ```
     vmbr0 (Active) - Proxmox Management Bridge
     vmbr1 (Active) - Management Network - OPNsense LAN
     vmbr2 (Active) - Production Network - OPNsense OPT1
     ```

#### Méthode 2 : Via CLI (Alternative)

Si vous préférez utiliser la ligne de commande :

```bash
# Se connecter au serveur Proxmox
ssh root@192.168.1.100

# Éditer le fichier de configuration réseau
nano /etc/network/interfaces

# Ajouter à la fin du fichier :

# Management Network Bridge
auto vmbr1
iface vmbr1 inet manual
	bridge-ports none
	bridge-stp off
	bridge-fd 0
	# Management Network - OPNsense LAN

# Production Network Bridge
auto vmbr2
iface vmbr2 inet manual
	bridge-ports none
	bridge-stp off
	bridge-fd 0
	# Production Network - OPNsense OPT1

# Sauvegarder (Ctrl+O, Entrée, Ctrl+X)

# Appliquer la configuration (sans reboot)
ifreload -a

# Vérifier la création
ip link show | grep vmbr
```

**Résultat attendu :**
```
3: vmbr0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
4: vmbr1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
5: vmbr2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
```

#### Vérification finale

Avant de continuer avec Terraform :

```bash
# Vérifier que les 3 bridges existent
pvesh get /nodes/devsecops-dojo/network

# Ou depuis n'importe où
ssh root@192.168.1.100 "ip link show | grep vmbr"
```

**Points importants :**
- ✅ Ne PAS assigner d'IP aux bridges vmbr1 et vmbr2 (OPNsense le fera)
- ✅ Ne PAS attacher de port physique à vmbr1/vmbr2 (bridges virtuels)
- ✅ Les bridges doivent être en "Autostart"
- ✅ vmbr0 reste votre bridge principal avec connexion physique

---

## Déploiement OPNsense

### Étape 1 : Déployer via Terraform

```bash
# Dans le répertoire proxmox-terraform
terraform init
terraform plan
terraform apply
```

La VM OPNsense sera créée avec :
- **ID** : 200
- **Nom** : opnsense-fw
- **État** : Arrêtée (started = false)
- **Interfaces** : 3 (vmbr0, vmbr1, vmbr2)

### Étape 2 : Démarrer la VM

```bash
# Option 1 : Via Proxmox UI
# VM 200 → Start → Console

# Option 2 : Via CLI
ssh root@192.168.1.100
qm start 200
```

---

## Configuration OPNsense

### Installation Initiale

**1. Boot depuis DVD**

La VM démarre automatiquement sur l'ISO OPNsense.

**2. Login Installateur**

```
Welcome to OPNsense!

login: installer
password: opnsense
```

**3. Assistant d'Installation**

```
┌─────────────────────────────────────────┐
│ OPNsense Installer                      │
├─────────────────────────────────────────┤
│ 1. Select Keymap                        │
│    → fr.kbd (ou us.kbd)                 │
│                                          │
│ 2. Install (UFS)                        │
│    → Disk: da0                          │
│    → Partition: Auto (GPT)              │
│                                          │
│ 3. Root Password                        │
│    → Choisir un mot de passe fort       │
│                                          │
│ 4. Complete Install                     │
│    → Reboot                             │
└─────────────────────────────────────────┘
```

**⚠️ IMPORTANT** : Après le reboot, retirer le CD depuis Proxmox UI ou via :
```bash
qm set 200 --ide2 none
```

### Configuration des Interfaces

**Premier Boot - Assignment des Interfaces**

```
Valid interfaces are:

vtnet0   BC:24:11:00:01:01  (down)  → vmbr1 (Management)
vtnet1   BC:24:11:00:01:02  (down)  → vmbr2 (Production)
vtnet2   BC:24:11:00:01:00  (down)  → vmbr0 (Uplink)

Do you want to configure LAGGs now? [y/n]: n
Do you want to configure VLANs now? [y/n]: n

⚠️ CONFIGURATION CRITIQUE - NE PAS SE TROMPER !

Enter the WAN interface name or 'a' for auto-detection
(vtnet0 vtnet1 vtnet2 or a): [LAISSER VIDE - APPUYER SUR ENTRÉE]

Enter the LAN interface name or 'a' for auto-detection
NOTE: this enables the first two interfaces found
(vtnet0 vtnet1 vtnet2 or a): vtnet0

Enter the Optional interface 1 name or 'a' for auto-detection
(vtnet0 vtnet1 vtnet2 or a): vtnet1

Enter the Optional interface 2 name or 'a' for auto-detection
(vtnet0 vtnet1 vtnet2 or a): vtnet2

Do you want to proceed? [y/n]: y

The interfaces will be assigned as follows:

WAN  ->
LAN  -> vtnet0 (vmbr1 - Management)
OPT1 -> vtnet1 (vmbr2 - Production)
OPT2 -> vtnet2 (vmbr0 - Uplink vers Internet)
```

### Configuration IP des Interfaces

**Menu Principal OPNsense**

```
┌─────────────────────────────────────────┐
│  0) Logout                              │
│  1) Assign interfaces                   │
│  2) Set interface IP address            │ ← UTILISER CETTE OPTION
│  3) Reset the root password             │
│  4) Reset to factory defaults           │
│  5) Power off system                    │
│  6) Reboot system                       │
│  7) Ping host                           │
│  8) Shell                               │
│  9) pfTop                               │
│ 10) Firewall log                        │
│ 11) Reload all services                 │
│ 12) Update from console                 │
│ 13) Restore a backup                    │
│ 14) Configure console menu options      │
│ 15) Factory reset (without backup)      │
└─────────────────────────────────────────┘
```

**Sélectionner : 2**

#### Configuration LAN (vtnet0 - vmbr1)

```
Enter the number of the interface to configure: 2

Configure IPv4 address LAN interface via DHCP? [y/n]: n
Configure IPv6 address LAN interface via DHCP6? [y/n]: n

Enter the new LAN IPv4 address: 192.168.10.1
Enter the new LAN IPv4 subnet bit count (1 to 32): 24

For a LAN, press <ENTER> for none:
Upstream gateway IPv4 address: [ENTRÉE]

Configure IPv6 address LAN interface via DHCP6? [y/n]: n

Do you want to enable the DHCP server on LAN? [y/n]: y

Enter the start address of the IPv4 client address range: 192.168.10.100
Enter the end address of the IPv4 client address range: 192.168.10.200

Do you want to revert to HTTP as the web GUI protocol? [y/n]: n

✅ Configuration LAN sauvegardée
```

#### Configuration OPT1 (vtnet1 - vmbr2)

```
Enter the number of the interface to configure: 3

Configure IPv4 address OPT1 interface via DHCP? [y/n]: n

Enter the new OPT1 IPv4 address: 192.168.20.1
Enter the new OPT1 IPv4 subnet bit count (1 to 32): 24

Upstream gateway IPv4 address: [ENTRÉE]

Do you want to enable the DHCP server on OPT1? [y/n]: y

Enter the start address of the IPv4 client address range: 192.168.20.100
Enter the end address of the IPv4 client address range: 192.168.20.200

✅ Configuration OPT1 sauvegardée
```

#### Configuration OPT2 (vtnet2 - vmbr0 - UPLINK)

```
Enter the number of the interface to configure: 4

⚠️ ATTENTION - CONFIGURATION UPLINK VERS BOX

Configure IPv4 address OPT2 interface via DHCP? [y/n]: n

Enter the new OPT2 IPv4 address: 192.168.1.200
Enter the new OPT2 IPv4 subnet bit count (1 to 32): 24

⚠️ NE PAS CONFIGURER DE DHCP SERVER ICI !
Do you want to enable the DHCP server on OPT2? [y/n]: n

✅ Configuration OPT2 sauvegardée
```

**Résumé de la configuration console**

```
Interface  Bridge  IP Address       DHCP Server  Role
─────────────────────────────────────────────────────────
LAN        vmbr1   192.168.10.1/24  Oui (.100-.200)  Gateway Management
OPT1       vmbr2   192.168.20.1/24  Oui (.100-.200)  Gateway Production
OPT2       vmbr0   192.168.1.200/24 NON              Uplink Internet
```

---

## Configuration Web UI

### Accès à l'interface Web

**⚠️ IMPORTANT** : Pour accéder à OPNsense, vous devez être sur le réseau vmbr1 (Management).

**Option 1 : Créer une VM temporaire sur vmbr1**

```bash
# Créer une VM Ubuntu/Rocky Linux simple
# Network: vmbr1
# IP: DHCP (obtiendra 192.168.10.x automatiquement)

# Depuis cette VM :
firefox https://192.168.10.1
# ou
curl -k https://192.168.10.1
```

**Option 2 : Utiliser la console Proxmox**

```bash
# Menu OPNsense → Option 8: Shell
# Puis configurer via CLI ou lynx
```

### Configuration Initiale Web

**URL** : https://192.168.10.1

```
Username: root
Password: [votre mot de passe configuré]
```

### Configuration de la Gateway (CRITIQUE)

**System → Gateways → Configuration**

1. **Cliquer sur "Add"**

```
Name: BOX_GW
Description: Gateway vers Box Internet
Interface: OPT2
Address Family: IPv4
IP Address: 192.168.1.1
Far Gateway: ✅ (cocher cette case)
Disable Gateway Monitoring: ☐ (laisser décoché)
Monitor IP: 8.8.8.8
Mark as default gateway: ✅
```

2. **Save** → **Apply Changes**

### Configuration des Interfaces

**Interfaces → OPT2 (Uplink)**

```
Enable: ✅
Description: WAN_Uplink
IPv4 Configuration Type: Static IPv4
IPv4 Address: 192.168.1.200 / 24
IPv4 Upstream Gateway: BOX_GW
```

**Save** → **Apply Changes**

### Configuration des Règles Firewall

**Firewall → Rules → LAN**

1. **Ajouter une règle "Allow All"**

```
Action: Pass
Interface: LAN
Direction: in
TCP/IP Version: IPv4
Protocol: any
Source: LAN net
Destination: any
Description: Allow LAN to Internet
```

**Save** → **Apply Changes**

**Firewall → Rules → OPT1**

1. **Ajouter une règle "Allow All"**

```
Action: Pass
Interface: OPT1
Direction: in
TCP/IP Version: IPv4
Protocol: any
Source: OPT1 net
Destination: any
Description: Allow OPT1 to Internet
```

**Save** → **Apply Changes**

### Configuration NAT

**Firewall → NAT → Outbound**

```
Mode: Automatic outbound NAT rule generation
```

**Save** → **Apply Changes**

---

## Tests et Validation

### Checklist de Validation

#### 1. Interfaces OPNsense

```bash
# Depuis la console OPNsense (Menu → 8: Shell)

# Vérifier les interfaces
ifconfig

# Résultat attendu :
# vtnet0: 192.168.10.1/24
# vtnet1: 192.168.20.1/24
# vtnet2: 192.168.1.200/24
```

#### 2. Connectivité OPNsense

```bash
# Depuis OPNsense Shell

# Test gateway box
ping -c 4 192.168.1.1

# Test Internet
ping -c 4 8.8.8.8
ping -c 4 google.com
```

#### 3. VM Test sur vmbr1

**Créer une VM test**

```bash
# Depuis Proxmox
# Créer une VM Ubuntu/Rocky
# Network: vmbr1
# Démarrer la VM
```

**Tests depuis la VM**

```bash
# Vérifier IP DHCP
ip addr show
# Devrait obtenir 192.168.10.x

# Vérifier route
ip route
# default via 192.168.10.1 dev eth0

# Test gateway OPNsense
ping 192.168.10.1

# Test uplink
ping 192.168.1.1

# Test Internet
ping 8.8.8.8
ping google.com

# Test DNS
nslookup google.com
```

#### 4. VM Test sur vmbr2

```bash
# Créer une VM sur vmbr2
# Network: vmbr2

# Vérifier IP DHCP
ip addr show
# Devrait obtenir 192.168.20.x

# Vérifier route
ip route
# default via 192.168.20.1 dev eth0

# Tests ping identiques
```

#### 5. Isolation Réseau

```bash
# Depuis une VM sur vmbr1
ping 192.168.20.100  # VM sur vmbr2
# Devrait fonctionner si règles firewall le permettent

# Depuis une VM sur vmbr0 (Rancher)
ping 192.168.10.100  # VM sur vmbr1
# Ne devrait PAS fonctionner (réseaux séparés)
```

---

## Dépannage

### Problème : Pas d'accès Internet depuis vmbr1/vmbr2

**Diagnostic**

```bash
# Depuis la VM sur vmbr1
traceroute 8.8.8.8

# Résultat attendu :
# 1  192.168.10.1       # OPNsense LAN
# 2  192.168.1.1        # Box
# 3  [IP FAI]
```

**Solutions**

1. **Vérifier la gateway sur OPNsense**
   ```bash
   # System → Gateways → Single
   # BOX_GW doit être Online
   ```

2. **Vérifier le routage**
   ```bash
   # Depuis OPNsense Shell
   netstat -rn
   # Vérifier route par défaut via 192.168.1.1
   ```

3. **Vérifier le NAT**
   ```bash
   # Firewall → NAT → Outbound
   # Mode: Automatic
   # Règles générées automatiquement pour LAN et OPT1
   ```

### Problème : VM ne reçoit pas d'IP DHCP

**Diagnostic**

```bash
# Depuis la VM
dhclient -v eth0
# ou
dhcpcd -d eth0
```

**Solutions**

1. **Vérifier DHCP sur OPNsense**
   ```
   Services → DHCPv4 → [LAN ou OPT1]
   Enable: ✅
   Range: 192.168.10.100 - 192.168.10.200
   ```

2. **Vérifier les logs DHCP**
   ```
   Status → System Logs → DHCP
   ```

### Problème : Pas d'accès à l'interface Web OPNsense

**Solutions**

1. **Vérifier que la VM test est bien sur vmbr1**
   ```bash
   ip addr show
   # Doit avoir une IP 192.168.10.x
   ```

2. **Vérifier le service Web OPNsense**
   ```bash
   # Depuis OPNsense Shell
   service nginx status
   ```

3. **Tester en HTTP (temporaire)**
   ```bash
   # System → Settings → Administration
   # Protocol: HTTP (temporaire pour debug)
   # Puis accéder à http://192.168.10.1
   ```

### Problème : OPNsense n'a pas accès Internet

**Diagnostic**

```bash
# Depuis OPNsense Shell
ping 192.168.1.1  # Box
ping 8.8.8.8       # Internet
```

**Solutions**

1. **Vérifier IP de l'uplink**
   ```bash
   ifconfig vtnet2
   # Doit afficher 192.168.1.200/24
   ```

2. **Vérifier la gateway**
   ```bash
   # Interfaces → OPT2
   # Gateway: BOX_GW (192.168.1.1)
   ```

3. **Tester la route**
   ```bash
   traceroute 8.8.8.8
   # Premier hop doit être 192.168.1.1
   ```

---

## Annexes

### Tableau récapitulatif des adresses

| Élément | Interface | Bridge | Adresse IP | Gateway | DHCP |
|---------|-----------|--------|------------|---------|------|
| Box Internet | - | - | 192.168.1.1 | - | 192.168.1.2-254 |
| OPNsense LAN | vtnet0 | vmbr1 | 192.168.10.1/24 | - | .100-.200 |
| OPNsense OPT1 | vtnet1 | vmbr2 | 192.168.20.1/24 | - | .100-.200 |
| OPNsense Uplink | vtnet2 | vmbr0 | 192.168.1.200/24 | 192.168.1.1 | Non |
| Rancher-1 | eth0 | vmbr0 | 192.168.1.110/24 | 192.168.1.1 | Non (static) |
| CI/CD | eth0 | vmbr0 | 192.168.1.119/24 | 192.168.1.1 | Non (static) |

### Commandes utiles

**Proxmox**

```bash
# Lister les VMs
qm list

# Démarrer OPNsense
qm start 200

# Console OPNsense
qm terminal 200

# Vérifier les bridges
ip link show | grep vmbr

# Redémarrer le réseau
systemctl restart networking
```

**OPNsense**

```bash
# Relancer tous les services
/usr/local/etc/rc.reload_all

# Vérifier les interfaces
ifconfig

# Vérifier les routes
netstat -rn

# Logs temps réel
tail -f /var/log/system.log

# Redémarrer firewall
/usr/local/etc/rc.filter_configure
```

---

## Support

Pour toute question ou problème :

1. Vérifier les logs OPNsense : **Status → System Logs**
2. Vérifier la documentation OPNsense : https://docs.opnsense.org
3. Forum OPNsense : https://forum.opnsense.org

---

**Version** : 1.0
**Date** : 2025
**Auteur** : Homelab DevSecOps Project

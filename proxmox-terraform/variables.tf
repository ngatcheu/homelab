variable "proxmox_node" {
  description = "Nom du nœud Proxmox cible"
  type        = string
  default     = "devsecops-dojo"
}

variable "proxmox_host" {
  description = "Adresse IP ou hostname du serveur Proxmox"
  type        = string
  default     = "192.168.1.100"
}

variable "proxmox_password" {
  description = "Mot de passe root Proxmox"
  type        = string
  sensitive   = true
}

variable "vm_id_start" {
  description = "ID de départ pour les VMs dans Proxmox"
  type        = number
  default     = 110
}

variable "template_name" {
  description = "Nom du template à cloner (laisser vide si pas de template)"
  type        = string
  default     = ""
}

# === Configuration Rancher ===
variable "rancher_cpu_cores" {
  description = "Nombre de cœurs CPU pour les VMs Rancher"
  type        = number
  default     = 2
}

variable "rancher_memory" {
  description = "Mémoire RAM en MB pour les VMs Rancher"
  type        = number
  default     = 8192
}

variable "rancher_disk_size" {
  description = "Taille du disque pour les VMs Rancher"
  type        = string
  default     = "25G"
}

# === Configuration Payload ===
variable "payload_cpu_cores" {
  description = "Nombre de cœurs CPU pour les VMs Payload"
  type        = number
  default     = 2
}

variable "payload_memory" {
  description = "Mémoire RAM en MB pour les VMs Payload"
  type        = number
  default     = 4096
}

variable "payload_disk_size" {
  description = "Taille du disque pour les VMs Payload"
  type        = string
  default     = "25G"
}

# === Configuration Payload Masters ===
variable "payload_master_cpu_cores" {
  description = "Nombre de cœurs CPU pour les VMs Payload Masters"
  type        = number
  default     = 2
}

variable "payload_master_memory" {
  description = "Mémoire RAM en MB pour les VMs Payload Masters"
  type        = number
  default     = 4096
}

# === Configuration Payload Workers ===
variable "payload_worker_cpu_cores" {
  description = "Nombre de cœurs CPU pour les VMs Payload Workers"
  type        = number
  default     = 3
}

variable "payload_worker_memory" {
  description = "Mémoire RAM en MB pour les VMs Payload Workers"
  type        = number
  default     = 8192
}

# === Configuration commune ===
variable "vm_storage" {
  description = "Stockage Proxmox pour les disques des VMs"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Bridge réseau"
  type        = string
  default     = "vmbr0"
}

variable "ip_address_base" {
  description = "Base des adresses IP (ex: 192.168.1)"
  type        = string
  default     = "192.168.1"
}

variable "ip_start" {
  description = "Première IP à utiliser"
  type        = number
  default     = 110
}

variable "gateway" {
  description = "Passerelle réseau"
  type        = string
  default     = "192.168.1.1"
}

variable "nameserver" {
  description = "Serveur DNS"
  type        = string
  default     = "192.168.1.1"
}

variable "ssh_public_key" {
  description = "Clé SSH publique pour l'accès aux VMs"
  type        = string
  default     = ""
}

variable "iso_file" {
  description = "Fichier ISO pour l'installation (format: storage:iso/filename.iso)"
  type        = string
  default     = ""
}

# === Configuration CI/CD ===
variable "cicd_cpu_cores" {
  description = "Nombre de cœurs CPU pour la VM CI/CD"
  type        = number
  default     = 2
}

variable "cicd_memory" {
  description = "Mémoire RAM en MB pour la VM CI/CD"
  type        = number
  default     = 8192
}


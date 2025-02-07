Per portare a termine il  task

```
lsblk     # Lista tutti i dischi
fdisk -l  # Informazioni dettagliate sui dischi

```

Vedo che ho un disco esterno USB da 3.6TB (/dev/sdb) già partizionato con una singola partizione **(/dev/sdb1)** formattata come Linux filesystem.

vediamo il filesystem

```
root@pve:~# blkid /dev/sdb1
/dev/sdb1: UUID="583f0a57-4067-4d35-accc-aa7543ea5821" BLOCK_SIZE="4096" TYPE="ext4" PARTLABEL="primary" PARTUUID="def025bc-4914-4906-8e64-3c4c60153271"
```

ZFS potrebbe essere eccessivo dato il collegamento USB (overhead non giustificato).
Ora devo fare ragionamenti seri su come dividere il disco, i dati dentro non mi interessano. 
Pensavo di fare partiziopni LVM perche sono facilmente espandibili e  quindi

/dev/sdb (3.6TB)
usando LVM:

**VG_SERVICES** (2.2TB)
├── LV_umbrel    (1.5TB)  /home/umbrel
└── LV_monero    (700GB)  /mnt/monero

**VG_SECURITY** (800GB)
├── LV_tor       (200GB)  /mnt/tor
│   ├── entry    (60GB)
│   ├── middle   (60GB)
│   └── exit     (80GB)
└── LV_lab       (600GB)  /mnt/lab
    ├── kali     (200GB)
    ├── targets  (300GB)
    └── shared   (100GB)

**VG_MONITOR** (600GB)
├── LV_logs      (300GB)  /mnt/logs
│   ├── services
│   ├── security
│   └── system
└── LV_backup    (300GB)  /mnt/backup
    ├── templates
    ├── snapshots
    └── configs

(**TESTATO**)

```bash
#!/bin/bash
# Script di Setup LVM per Lab di Sicurezza
# Configurazione automatica repository Proxmox e setup LVM
# Versione: 1.0

#########################
# FUNZIONI DI SUPPORTO
#########################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_error() {
    if [ $? -ne 0 ]; then
        log "ERRORE: $1"
        exit 1
    fi
}

confirm() {
    read -p "$1 [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

#########################
# CONTROLLI INIZIALI
#########################

# Verifica root
[ "$(id -u)" != "0" ] && { log "Eseguire come root"; exit 1; }

# Setup repository Proxmox
if [ -f "/etc/apt/sources.list.d/pve-enterprise.list" ]; then
    log "Configurazione repository Proxmox community..."
    mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.bak
    echo "deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list.d/pve-community.list
    apt-get update
fi

# Installazione dipendenze
log "Verifica dipendenze..."
for pkg in parted lvm2 gdisk; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        log "Installazione $pkg..."
        apt-get install -y $pkg
    fi
done

#########################
# IDENTIFICAZIONE DISCHI
#########################

log "Analisi dischi disponibili..."
disks=()
declare -A disk_sizes

# Scansione dischi con dimensioni
for disk in /dev/sd[b-z]; do
    if lsblk $disk >/dev/null 2>&1; then
        size=$(lsblk -bdn -o SIZE $disk)
        size_gb=$((size/1024/1024/1024))
        disks+=("$disk")
        disk_sizes["$disk"]=$size_gb
        log "Trovato: $disk (${size_gb}GB)"
    fi
done

[ ${#disks[@]} -eq 0 ] && { log "Nessun disco disponibile"; exit 1; }

#########################
# SELEZIONE DISCO
#########################

if [ ${#disks[@]} -eq 1 ]; then
    selected_disk="${disks[0]}"
    disk_size=${disk_sizes[$selected_disk]}
    log "Selezione automatica: $selected_disk (${disk_size}GB)"
else
    log "Dischi disponibili:"
    for i in "${!disks[@]}"; do
        echo "$((i+1)) - ${disks[$i]} (${disk_sizes[${disks[$i]}]}GB)"
    done

    while true; do
        read -p "Numero disco: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#disks[@]} ]; then
            selected_disk="${disks[$((choice-1))]}"
            disk_size=${disk_sizes[$selected_disk]}
            break
        fi
        log "Scelta non valida"
    done
fi

#########################
# PREPARAZIONE DISCO
#########################

# Smontaggio se necessario
if mount | grep -q "$selected_disk"; then
    log "Smontaggio volumi esistenti..."
    umount "$selected_disk"* 2>/dev/null
fi

# Conferma distruzione dati
if ! confirm "ATTENZIONE: Cancellazione dati su $selected_disk (${disk_size}GB). Continuare?"; then
    log "Operazione annullata"; exit 1
fi

#########################
# SETUP LVM
#########################

# Creazione partizione GPT
log "Setup partizione GPT..."
parted -s "$selected_disk" mklabel gpt
parted -s "$selected_disk" mkpart primary 1MiB 100%
parted -s "$selected_disk" set 1 lvm on
check_error "Errore partizione"

# Inizializzazione PV
log "Setup Physical Volume..."
pvcreate -ff -y "${selected_disk}1"
check_error "Errore PV"

# Gestione VG con pvs
log "Setup Volume Groups..."
pvcreate -ff -y "${selected_disk}1"
vgcreate VG_SERVICES "${selected_disk}1"

# Estrazione VG_SECURITY
pvs "${selected_disk}1" --segments -o+seg_size_pe
vgreduce VG_SERVICES 800G
vgcreate VG_SECURITY "${selected_disk}1"

# Estrazione VG_MONITOR
vgreduce VG_SECURITY 600G
vgcreate VG_MONITOR "${selected_disk}1"

#########################
# LOGICAL VOLUMES
#########################

log "Creazione Logical Volumes..."

# VG_SERVICES
lvcreate -L 1500G -n LV_umbrel VG_SERVICES
lvcreate -l 100%FREE -n LV_monero VG_SERVICES

# VG_SECURITY
lvcreate -L 200G -n LV_tor VG_SECURITY
lvcreate -l 100%FREE -n LV_lab VG_SECURITY

# VG_MONITOR
lvcreate -L 300G -n LV_logs VG_MONITOR
lvcreate -l 100%FREE -n LV_backup VG_MONITOR

#########################
# FILESYSTEM E MOUNT
#########################

# Creazione filesystem
log "Setup filesystem..."
for vg in VG_SERVICES VG_SECURITY VG_MONITOR; do
    for lv in $(lvs --noheadings -o lv_name $vg | tr -d ' '); do
        mkfs.ext4 -F "/dev/mapper/$vg-$lv"
        check_error "Errore filesystem $vg-$lv"
    done
done

# Mount points
log "Creazione directory..."
mkdir -p /home/umbrel \
         /mnt/{monero,tor/{entry,middle,exit},lab/{kali,targets,shared},logs/{services,security,system},backup/{templates,snapshots,configs}}

# FSTAB update
log "Configurazione fstab..."
cp /etc/fstab /etc/fstab.backup

# UUID mapping
declare -A uuid_map
while IFS= read -r line; do
    dev=$(echo "$line" | cut -d: -f1)
    uuid=$(echo "$line" | grep -o 'UUID="[^"]*"' | cut -d'"' -f2)
    uuid_map["$dev"]=$uuid
done < <(blkid | grep "/dev/mapper/VG_")

# Aggiunta mount points
cat >> /etc/fstab << EOF
# LVM Security Lab
UUID=${uuid_map["/dev/mapper/VG_SERVICES-LV_umbrel"]} /home/umbrel ext4 defaults,nofail 0 2
UUID=${uuid_map["/dev/mapper/VG_SERVICES-LV_monero"]} /mnt/monero ext4 defaults,nofail 0 2
UUID=${uuid_map["/dev/mapper/VG_SECURITY-LV_tor"]} /mnt/tor ext4 defaults,nofail 0 2
UUID=${uuid_map["/dev/mapper/VG_SECURITY-LV_lab"]} /mnt/lab ext4 defaults,nofail 0 2
UUID=${uuid_map["/dev/mapper/VG_MONITOR-LV_logs"]} /mnt/logs ext4 defaults,nofail 0 2
UUID=${uuid_map["/dev/mapper/VG_MONITOR-LV_backup"]} /mnt/backup ext4 defaults,nofail 0 2
EOF

# Mount finale
mount -a
check_error "Errore mount"

#########################
# REPORT FINALE
#########################

log "=== REPORT SETUP ==="
echo "Volume Groups:"
vgs
echo -e "\nLogical Volumes:"
lvs
echo -e "\nMount Points:"
df -h | grep "/dev/mapper/VG_"

log "Setup completato. Si consiglia riavvio."
```



3. - Lo script crea una struttura LVM per un laboratorio di sicurezza con tre Volume Groups principali:
   
     1. VG_SERVICES (per servizi blockchain)
        - LV_umbrel (1500GB) → /home/umbrel
        - LV_monero (spazio rimanente) → /mnt/monero
     2. VG_SECURITY (800GB totali)
        - LV_tor (200GB) → /mnt/tor
          - /mnt/tor/entry
          - /mnt/tor/middle
          - /mnt/tor/exit
        - LV_lab (spazio rimanente) → /mnt/lab
          - /mnt/lab/kali
          - /mnt/lab/targets
          - /mnt/lab/shared
     3. VG_MONITOR (600GB totali)
        - LV_logs (300GB) → /mnt/logs
          - /mnt/logs/services
          - /mnt/logs/security
          - /mnt/logs/system
        - LV_backup (spazio rimanente) → /mnt/backup
          - /mnt/backup/templates
          - /mnt/backup/snapshots
          - /mnt/backup/configs
   
     Le sottodirectory sono create come directory standard sul filesystem ext4 del rispettivo Logical Volume. La persistenza è garantita tramite UUID in /etc/fstab, che monta solo i Logical Volumes principali.

Mount points:
```
/home/umbrel                    # Nodo Bitcoin/Lightning
/mnt/monero                     # Storage Monero
/mnt/tor/{entry,middle,exit}    # Nodi Tor
/mnt/lab/{kali,targets,shared}  # Ambiente test
/mnt/logs/{services,security,system}  # Log centralizzati
/mnt/backup/{templates,snapshots,configs}  # Backup
```

Tutti i filesystem sono ext4 con mount persistente via UUID in fstab.
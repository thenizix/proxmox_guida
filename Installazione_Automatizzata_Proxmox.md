### **Parte 1: Preparazione e Installazione Automatizzata**

#### **Obiettivo**

Questo script automatizza la preparazione dell'ambiente di installazione per Proxmox VE. L'obiettivo è evitare interventi manuali non necessari durante il setup, garantendo una procedura ripetibile e sicura.

#### **Spiegazione e Codice**

```bash
#!/bin/bash
# Script di preparazione per l'installazione di Proxmox VE
# Questo script verifica i requisiti hardware, identifica il disco di sistema e prepara il partizionamento.

# Costanti globali:
readonly LOG_FILE="/var/log/proxmox-setup.log"  # File di log per tracciare le operazioni
readonly MIN_RAM_GB=8                           # RAM minima richiesta (in GB)
readonly MIN_DISK_GB=32                         # Dimensione minima del disco (in GB)

# Funzione log: registra messaggi di INFO, WARN ed ERROR con timestamp.
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    if [ "$level" = "ERROR" ]; then
        exit 1
    fi
}

# Funzione analyze_hardware: controlla la RAM installata.
analyze_hardware() {
    local total_ram_kb
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_gb=$(( total_ram_kb / 1024 / 1024 ))
    if [ "$total_ram_gb" -lt "$MIN_RAM_GB" ]; then
        log "ERROR" "RAM insufficiente: ${total_ram_gb}GB (minimo richiesto: ${MIN_RAM_GB}GB)"
    fi
    log "INFO" "RAM disponibile: ${total_ram_gb}GB"
    echo "$total_ram_gb"
}

# Funzione identify_system_disk: cerca il disco adatto per l'installazione.
identify_system_disk() {
    # Vengono elencati i dischi escludendo dispositivi removibili, loop e altri indesiderati.
    local disks
    readarray -t disks < <(lsblk -dpno NAME,SIZE,ROTA,TRAN | grep -Ev "usb|loop|sr0" | sort -k4)
    for disk in "${disks[@]}"; do
        local disk_name
        disk_name=$(echo "$disk" | awk '{print $1}')
        local disk_size
        disk_size=$(blockdev --getsize64 "$disk_name")
        local disk_gb=$(( disk_size / 1024 / 1024 / 1024 ))
        if [ "$disk_gb" -ge "$MIN_DISK_GB" ]; then
            log "INFO" "Disco selezionato: $disk_name (${disk_gb}GB)"
            echo "$disk_name"
            return 0
        fi
    done
    log "ERROR" "Nessun disco adatto trovato"
}

# Funzione prepare_installation: prepara il disco per l'installazione creando le partizioni.
prepare_installation() {
    local system_disk="$1"
    local total_ram_gb="$2"
    if [ -z "$system_disk" ]; then
        log "ERROR" "Variabile system_disk non valorizzata"
    fi

    # Calcola lo swap: metà della RAM, minimo 4GB.
    local swap_size_gb=$(( total_ram_gb / 2 ))
    if [ "$swap_size_gb" -lt 4 ]; then
        swap_size_gb=4
    fi

    # Avviso all'utente: il disco verrà cancellato.
    log "WARN" "ATTENZIONE: il disco $system_disk verrà partizionato e tutti i dati andranno persi."
    read -p "Procedere senza intervento manuale? (yes per continuare): " confirm
    if [ "$confirm" != "yes" ]; then
        log "INFO" "Operazione annullata dall'utente."
        exit 0
    fi

    log "INFO" "Preparazione disco di sistema: $system_disk"
    # Crea una tabella GPT sul disco
    parted -s "$system_disk" mklabel gpt

    # Definisce le dimensioni delle partizioni in MiB:
    local efi_size=512    # 512MB per EFI
    local boot_size=1024  # 1GB per /boot
    local root_size=30720 # 30GB per la partizione root
    local swap_size_mib=$(( swap_size_gb * 1024 ))

    # Crea le partizioni: ESP, /boot, root, swap.
    parted -s "$system_disk" \
        mkpart ESP fat32 1MiB ${efi_size}MiB \
        mkpart primary ext4 ${efi_size}MiB $((efi_size + boot_size))MiB \
        mkpart primary ext4 $((efi_size + boot_size))MiB $((efi_size + boot_size + root_size))MiB \
        mkpart primary linux-swap $((efi_size + boot_size + root_size))MiB $((efi_size + boot_size + root_size + swap_size_mib))MiB \
        set 1 esp on

    # Formatta le partizioni.
    mkfs.fat -F32 "${system_disk}1"
    mkfs.ext4 "${system_disk}2"
    mkfs.ext4 "${system_disk}3"
    mkswap "${system_disk}4"

    log "INFO" "Partizioni create e formattate correttamente su $system_disk"
}

# Esecuzione sequenziale delle funzioni
ram=$(analyze_hardware)
disk=$(identify_system_disk)
prepare_installation "$disk" "$ram"
```

#### **Perché questo approccio?**

- **Automazione completa:** Non richiede interventi manuali dopo il setup iniziale (l'unico intervento è la conferma per sicurezza).
- **Gestione errori:** Ogni funzione usa il logging per indicare errori critici, interrompendo lo script se necessario.
- **Struttura modulare:** Funzioni separate per hardware, disco e partizionamento permettono una facile manutenzione e riuso del codice.

#### **Esercizio 1: Verifica e Modifica del Disco Selezionato**

**Obiettivo:**
Modificare la funzione `identify_system_disk` per includere un controllo che consenta di selezionare manualmente un disco in caso di più dischi idonei.

**Istruzioni:**

1. Modifica la funzione in modo che, se trova più di un disco idoneo, chieda all'utente di scegliere tra una lista numerata.
2. Aggiungi commenti al codice per spiegare ogni passaggio.

**Soluzione Proposta:**

```bash
identify_system_disk() {
    # Estrae tutti i dischi idonei
    local disks
    readarray -t disks < <(lsblk -dpno NAME,SIZE,ROTA,TRAN | grep -Ev "usb|loop|sr0" | sort -k4)
    local eligible=()
    for disk in "${disks[@]}"; do
        local disk_name
        disk_name=$(echo "$disk" | awk '{print $1}')
        local disk_size
        disk_size=$(blockdev --getsize64 "$disk_name")
        local disk_gb=$(( disk_size / 1024 / 1024 / 1024 ))
        if [ "$disk_gb" -ge "$MIN_DISK_GB" ]; then
            eligible+=("$disk_name")
        fi
    done

    # Se nessun disco è idoneo, esce con un errore.
    if [ ${#eligible[@]} -eq 0 ]; then
        log "ERROR" "Nessun disco idoneo trovato"
    fi

    # Se esiste un solo disco idoneo, lo restituisce.
    if [ ${#eligible[@]} -eq 1 ]; then
        log "INFO" "Disco selezionato automaticamente: ${eligible[0]}"
        echo "${eligible[0]}"
        return 0
    fi

    # Se ci sono più dischi, chiede all'utente di scegliere.
    echo "Sono stati trovati più dischi idonei:"
    local i=1
    for disk in "${eligible[@]}"; do
        echo "$i) $disk"
        ((i++))
    done
    read -p "Inserisci il numero del disco da utilizzare: " choice
    # Controllo semplice per un input valido.
    if ! [[ "$choice" =~ ^[1-9][0-9]*$ ]] || [ "$choice" -gt "${#eligible[@]}" ]; then
        log "ERROR" "Scelta non valida"
    fi
    local selected="${eligible[$((choice - 1))]}"
    log "INFO" "Disco selezionato manualmente: $selected"
    echo "$selected"
}
```

**Spiegazione della Soluzione:**

- La funzione raccoglie tutti i dischi idonei in un array `eligible`.
- Se c'è un solo disco, lo restituisce automaticamente; se ce ne sono di più, li elenca e richiede all'utente di scegliere.
- Viene effettuato un controllo dell’input per assicurare che la scelta sia valida.

------

### **Parte 2: Configurazione Network Automatizzata**

#### **Obiettivo**

Questo script configura in maniera automatica la rete di Proxmox VE creando dei bridge dedicati per management, storage e VM. L’obiettivo è quello di avere una rete stabile e pronta per l’uso senza interventi successivi, garantendo al contempo chiarezza e modularità nella configurazione.

#### **Spiegazione e Codice**

```
#!/bin/bash
# Script di configurazione iniziale della rete per Proxmox VE
# Lo script identifica l'interfaccia fisica principale, estrae l'IP corrente e configura tre bridge:
# - vmbr0: per la gestione (management)
# - vmbr1: per lo storage
# - vmbr2: per le VM, con NAT abilitato

# Costanti di configurazione:
readonly VLAN_RANGE="2-4094"  # Range di VLAN supportate
readonly BRIDGE_PREFIX="vmbr" # Prefisso per i nomi dei bridge
readonly MANAGEMENT_VLAN=1    # VLAN per il management (indicativa)
readonly STORAGE_VLAN=2       # VLAN per lo storage (indicativa)
readonly VM_VLAN=3            # VLAN per le VM (indicativa)

# Funzione per configurare i bridge di rete
configure_network_bridges() {
    # Identifica l'interfaccia fisica principale, escludendo quelle virtuali e interfacce di loop.
    local physical_interface
    physical_interface=$(ip -o link show | grep -Ev "lo|$BRIDGE_PREFIX|docker|veth" | head -1 | awk -F': ' '{print $2}')
    if [ -z "$physical_interface" ]; then
        log "ERROR" "Nessuna interfaccia fisica trovata; verifica la configurazione di rete."
    fi

    # Ottieni la configurazione IP corrente dell'interfaccia selezionata.
    local current_config
    current_config=$(ip -4 addr show "$physical_interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')
    if [ -z "$current_config" ]; then
        log "ERROR" "Impossibile ottenere la configurazione IP per $physical_interface."
    fi
    # Separiamo l'indirizzo IP dalla maschera (prefix)
    local current_ip=${current_config%/*}
    local current_prefix=${current_config#*/}

    # Calcola indirizzi per i bridge modificando l'ultimo ottetto dell'IP corrente.
    local management_ip="${current_ip%.*}.1"
    local storage_ip="${current_ip%.*}.2"
    local vm_ip="${current_ip%.*}.3"

    # Genera il file di configurazione per /etc/network/interfaces.
    cat > /etc/network/interfaces << EOL
auto lo
iface lo inet loopback

# Bridge principale per management
auto ${BRIDGE_PREFIX}0
iface ${BRIDGE_PREFIX}0 inet static
    address ${management_ip}/${current_prefix}
    bridge-ports ${physical_interface}
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids ${VLAN_RANGE}

# Bridge per storage
auto ${BRIDGE_PREFIX}1
iface ${BRIDGE_PREFIX}1 inet static
    address ${storage_ip}/${current_prefix}
    bridge-ports none
    bridge-stp off
    bridge-fd 0

# Bridge per VM con NAT
auto ${BRIDGE_PREFIX}2
iface ${BRIDGE_PREFIX}2 inet static
    address ${vm_ip}/${current_prefix}
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # Abilita l'inoltro IP per il NAT
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    # Imposta la regola NAT per il traffico in uscita dalla rete interna
    post-up iptables -t nat -A POSTROUTING -s "${current_ip%.*}.0/24" -o ${BRIDGE_PREFIX}0 -j MASQUERADE
EOL

    # Imposta un hostname basato sull'IP, utile per identificare il nodo in rete.
    local hostname="pve-$(echo $current_ip | tr '.' '-')"
    echo "$hostname" > /etc/hostname

    log "INFO" "Configurazione di rete completata per l'interfaccia $physical_interface."
}

# Esecuzione della funzione di configurazione rete.
configure_network_bridges
```

#### **Perché  questo approccio?**

- **Identificazione automatica:**
  Lo script estrae automaticamente l'interfaccia principale e la configurazione IP, riducendo errori di configurazione manuale.
- **Bridge dedicati:**
  I bridge separati per management, storage e VM garantiscono un isolamento logico del traffico, utile in ambienti complessi.
- **Persistenza della configurazione:**
  La scrittura diretta nel file `/etc/network/interfaces` permette di avere una configurazione persistente che si applica ad ogni riavvio.
- **Automazione NAT:**
  L’inoltro IP e la regola NAT vengono impostati direttamente, garantendo che le VM possano comunicare con la rete esterna senza ulteriori configurazioni.

#### **Esercizio 2: Estendere la Configurazione del Bridge**

**Obiettivo:**
Modificare lo script per aggiungere un parametro opzionale che consenta di definire un IP statico per il bridge di management (vmbr0) invece di derivarlo dall’IP dell’interfaccia fisica.

**Istruzioni:**

1. Aggiungi una variabile (ad esempio `CUSTOM_MGMT_IP`) all'inizio dello script.
2. Se la variabile è valorizzata (non vuota), usala come indirizzo per il bridge vmbr0; altrimenti, calcola l'indirizzo come già fatto.
3. Aggiungi commenti per spiegare il nuovo flusso.

**Soluzione Proposta:**

```bash
#!/bin/bash
# Aggiunta opzionale: definire un IP statico per il bridge di management.
# Se CUSTOM_MGMT_IP è valorizzato, verrà usato come indirizzo per vmbr0.
readonly CUSTOM_MGMT_IP=""  # Es.: "192.168.1.100" oppure lasciare vuoto per il calcolo automatico

configure_network_bridges() {
    local physical_interface
    physical_interface=$(ip -o link show | grep -Ev "lo|$BRIDGE_PREFIX|docker|veth" | head -1 | awk -F': ' '{print $2}')
    if [ -z "$physical_interface" ]; then
        log "ERROR" "Nessuna interfaccia fisica trovata."
    fi

    local current_config
    current_config=$(ip -4 addr show "$physical_interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')
    if [ -z "$current_config" ]; then
        log "ERROR" "Impossibile ottenere la configurazione IP per $physical_interface."
    fi
    local current_ip=${current_config%/*}
    local current_prefix=${current_config#*/}

    # Se CUSTOM_MGMT_IP è definito, usalo per il bridge management.
    if [ -n "$CUSTOM_MGMT_IP" ]; then
        local management_ip="$CUSTOM_MGMT_IP"
    else
        management_ip="${current_ip%.*}.1"
    fi

    # Per storage e VM, si usa il calcolo automatico.
    local storage_ip="${current_ip%.*}.2"
    local vm_ip="${current_ip%.*}.3"

    cat > /etc/network/interfaces << EOL
auto lo
iface lo inet loopback

# Bridge principale per management
auto ${BRIDGE_PREFIX}0
iface ${BRIDGE_PREFIX}0 inet static
    address ${management_ip}/${current_prefix}
    bridge-ports ${physical_interface}
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids ${VLAN_RANGE}

# Bridge per storage
auto ${BRIDGE_PREFIX}1
iface ${BRIDGE_PREFIX}1 inet static
    address ${storage_ip}/${current_prefix}
    bridge-ports none
    bridge-stp off
    bridge-fd 0

# Bridge per VM con NAT
auto ${BRIDGE_PREFIX}2
iface ${BRIDGE_PREFIX}2 inet static
    address ${vm_ip}/${current_prefix}
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up iptables -t nat -A POSTROUTING -s "${current_ip%.*}.0/24" -o ${BRIDGE_PREFIX}0 -j MASQUERADE
EOL

    # Imposta hostname basato sull'indirizzo IP
    local hostname="pve-$(echo $current_ip | tr '.' '-')"
    echo "$hostname" > /etc/hostname

    log "INFO" "Configurazione di rete completata per l'interfaccia $physical_interface."
}
```

**Spiegazione della Soluzione:**

- Abbiamo introdotto la variabile `CUSTOM_MGMT_IP` che, se definita, sostituisce l’indirizzo calcolato automaticamente per il bridge di management.
- Questo permette all’utente di avere flessibilità: in ambienti dove è richiesto un IP fisso per il management, basta impostare la variabile.

------

  **Parte 3: Configurazione Storage e Template** con spiegazioni dettagliate ed un esercizio pratico.

------

- # Configurazione Storage e Template

  ## Obiettivi del Capitolo
  - Configurare lo storage locale e condiviso
  - Creare e ottimizzare template per le macchine virtuali
  - Implementare best practices per la gestione dello storage
  - Integrare con l'ambiente di rete esistente

  ## 3.1 Configurazione Storage Base

  ```bash
  #!/bin/bash
  # Nome: configure_storage.sh
  # Descrizione: Configurazione storage base per Proxmox VE
  
  # Costanti di configurazione
  readonly STORAGE_CONF="/etc/pve/storage.cfg"
  readonly MIN_STORAGE_SIZE=100  # GB
  readonly ZFS_MIN_RAM=16        # GB
  
  # Funzione di logging
  log() {
      local level="$1"
      local message="$2"
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  }
  
  # Verifica prerequisiti di base
  verify_prerequisites() {
      log "INFO" "Verifica prerequisiti storage"
      
      # Verifica rete configurata nel Capitolo 1
      if ! ip link show vmbr0 >/dev/null 2>&1; then
          log "ERROR" "Bridge vmbr0 non configurato"
          exit 1
      }
      
      # Verifica spazio disponibile
      local root_space
      root_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
      if [ "$root_space" -lt "$MIN_STORAGE_SIZE" ]; then
          log "ERROR" "Spazio insufficiente: $root_space GB"
          exit 1
      }
  }
  
  # Analisi capacità hardware
  analyze_storage_capabilities() {
      local total_ram_gb
      total_ram_gb=$(free -g | awk '/^Mem:/{print $2}')
      local has_aesni
      has_aesni=$(grep -c aes /proc/cpuinfo)
      
      if [ "$total_ram_gb" -ge "$ZFS_MIN_RAM" ] && [ "$has_aesni" -gt 0 ]; then
          echo "zfs"
      else
          echo "lvm"
      fi
  }
  
  # Configurazione ZFS
  configure_zfs_storage() {
      local disks=("$@")
      local pool_name="tank"
      
      # Installa ZFS
      apt install -y zfsutils-linux
      
      # Determina configurazione RAID
      local raid_config
      case ${#disks[@]} in
          1) raid_config="" ;;
          2) raid_config="mirror" ;;
          [3-5]) raid_config="raidz1" ;;
          *) raid_config="raidz2" ;;
      esac
      
      # Crea e ottimizza pool
      if [ -n "$raid_config" ]; then
          zpool create -f "$pool_name" $raid_config "${disks[@]}"
      else
          zpool create -f "$pool_name" "${disks[0]}"
      fi
      
      # Ottimizzazioni ZFS
      zfs set atime=off "$pool_name"
      zfs set compression=lz4 "$pool_name"
      zfs set recordsize=128k "$pool_name"
      
      # Dataset specifici
      zfs create "$pool_name/vm-disks"
      zfs create "$pool_name/ct-disks"
      zfs create "$pool_name/backup"
  }
  
  # Configurazione LVM
  configure_lvm_storage() {
      local disks=("$@")
      local vg_name="pve_storage"
      
      apt install -y lvm2
      
      # Prepara dischi
      for disk in "${disks[@]}"; do
          sgdisk -Z "$disk"
          sgdisk -n 1:0:0 "$disk"
          pvcreate "${disk}1"
      done
      
      # Crea volume group
      vgcreate "$vg_name" $(for disk in "${disks[@]}"; do echo "${disk}1"; done)
      
      # Crea logical volumes
      lvcreate -l 80%VG -T "$vg_name/vm_storage_pool"
      lvcreate -l 20%VG -n backup "$vg_name"
  }
  
  # Preparazione template base
  prepare_template() {
      local template_id=9000
      local template_name="ubuntu-template"
      local iso_url="https://releases.ubuntu.com/jammy/ubuntu-22.04.5-live-server-amd64.iso"
      
      # Download ISO
      wget -O "/var/lib/vz/template/iso/$(basename $iso_url)" "$iso_url"
      
      # Crea template
      qm create $template_id \
          --name "$template_name" \
          --memory 2048 \
          --cores 2 \
          --net0 "virtio,bridge=vmbr0" \
          --bootdisk scsi0 \
          --scsihw virtio-scsi-pci \
          --scsi0 local-lvm:32 \
          --ide2 "local:iso/$(basename $iso_url),media=cdrom" \
          --ostype l26 \
          --cpu host \
          --machine q35
  
      # Abilita QEMU guest agent
      qm set $template_id --agent enabled=1
  }
  
  # Main
  main() {
      log "INFO" "Avvio configurazione storage"
      
      verify_prerequisites
      local storage_type
      storage_type=$(analyze_storage_capabilities)
      
      # Identifica dischi disponibili
      readarray -t available_disks < <(lsblk -dpno NAME,SIZE,TYPE | \
          grep -v "$(mount | grep ' / ' | cut -d' ' -f1 | sed 's/[0-9]*$//')" | \
          grep "disk")
      
      if [ ${#available_disks[@]} -eq 0 ]; then
          log "ERROR" "Nessun disco disponibile"
          exit 1
      }
      
      case $storage_type in
          "zfs") configure_zfs_storage "${available_disks[@]}" ;;
          "lvm") configure_lvm_storage "${available_disks[@]}" ;;
      esac
      
      prepare_template
      
      log "INFO" "Configurazione completata"
  }
  
  main
  ```

  ## 3.2 Esercizi Pratici

  ### Esercizio 1: Gestione Storage
  1. Verifica lo stato dello storage:
     ```bash
     pvesm status
     ```
  2. Crea un nuovo volume:
     ```bash
     # Per ZFS
     zfs create tank/test
     # Per LVM
     lvcreate -L 10G -n test pve_storage
     ```
  3. Monitora le performance:
     ```bash
     iostat -x 1
     ```

  ### Esercizio 2: Gestione Template
  1. Clona il template base:
     ```bash
     qm clone 9000 101 --name "vm-test"
     ```
  2. Personalizza le risorse:
     ```bash
     qm set 101 --memory 4096
     qm set 101 --cores 4
     ```
  3. Verifica la configurazione:
     ```bash
     qm config 101
     ```

  (non sono riuscito obiettivamente ad attivare copia-incolla nelle finestre dei terminali)

  ## 3.3 Best Practices

  1. Mantenere backup regolari della configurazione
  2. Monitorare l'utilizzo dello storage
  3. Ottimizzare i template in base all'uso
  4. Documentare le modifiche

  ### Note Finali
  - Il tipo di storage (ZFS/LVM) va scelto in base alle risorse
  - I template vanno aggiornati regolarmente
  - Monitorare le performance dello storage

------



### **Parte 4: Configurazione della Sicurezza Avanzata**

#### **Obiettivo**

Questo script implementa una serie di misure di sicurezza per proteggere il sistema

- Hardening del kernel
- Configurazione sicura di SSH
- Impiego di fail2ban per prevenire attacchi brute-force
- Configurazione di un firewall tramite iptables con regole persistenti

L’obiettivo è automatizzare la sicurezza in modo da non dover intervenire manualmente dopo il setup, garantendo un ambiente protetto e ben documentato.

#### **Spiegazione del Codice**

```bash
#!/bin/bash
# Script per la configurazione avanzata della sicurezza in Proxmox VE

# Definizione dei file di configurazione usati per applicare le regole di sicurezza
readonly SYSCTL_SECURITY="/etc/sysctl.d/99-security.conf"  # Configurazione kernel
readonly SSH_CONFIG="/etc/ssh/sshd_config.d/security.conf"   # Configurazione SSH
readonly FAIL2BAN_CONFIG="/etc/fail2ban/jail.local"           # Configurazione fail2ban
readonly IPTABLES_RULES="/etc/iptables/rules.v4"              # File per salvare le regole iptables

# Funzione configure_kernel_security:
# Applica una serie di parametri al kernel per ridurre il rischio di attacchi.
configure_kernel_security() {
    cat > "$SYSCTL_SECURITY" << 'EOL'
# Abilita il filtro inverso per prevenire IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
# Abilita syncookies per proteggere contro SYN flood
net.ipv4.tcp_syncookies = 1
# Disabilita reindirizzamenti non necessari
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
# Impedisci l'accettazione di pacchetti con routing sorgente
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
# Rafforza la sicurezza della memoria
kernel.randomize_va_space = 2
vm.mmap_min_addr = 65536
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
# Abilita il controllo del traffico in ambienti virtualizzati
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOL
    # Applica immediatamente le modifiche
    sysctl -p "$SYSCTL_SECURITY"
    log "INFO" "Sicurezza kernel configurata"
}

# Funzione configure_secure_ssh:
# Modifica la configurazione SSH per disabilitare login con password e impostare parametri di sicurezza.
configure_secure_ssh() {
    # Effettua un backup della configurazione SSH esistente
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    # Genera chiavi ED25519 se non esistono già
    if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
        ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
    fi
    cat > "$SSH_CONFIG" << 'EOL'
# Impedisci l'accesso diretto come root tramite password
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
# Parametri di timeout e limiti di accesso per ridurre i tentativi forzati
LoginGraceTime 30
MaxAuthTries 3
MaxSessions 5
ClientAliveInterval 300
ClientAliveCountMax 2
# Disabilita funzionalità non necessarie
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitEmptyPasswords no
# Imposta algoritmi crittografici sicuri
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
EOL
    # Riavvia il servizio SSH per applicare le modifiche
    systemctl restart sshd
    log "INFO" "Configurazione SSH sicura applicata"
}

# Funzione configure_fail2ban:
# Installa e configura fail2ban per monitorare e bloccare tentativi di accesso sospetti.
configure_fail2ban() {
    apt install -y fail2ban
    cat > "$FAIL2BAN_CONFIG" << 'EOL'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
banaction = iptables-multiport

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[proxmox]
enabled = true
port = 8006
filter = proxmox
logpath = /var/log/daemon.log
maxretry = 3

[proxmox-ddos]
enabled = true
port = 8006
filter = proxmox-ddos
logpath = /var/log/daemon.log
maxretry = 30
findtime = 60
bantime = 7200
EOL
    # Crea filtri personalizzati per Proxmox
    cat > /etc/fail2ban/filter.d/proxmox.conf << 'EOL'
[Definition]
failregex = pvedaemon\[.*\]: authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
EOL
    cat > /etc/fail2ban/filter.d/proxmox-ddos.conf << 'EOL'
[Definition]
failregex = pveproxy\[.*\]: connection refused; too many connections from <HOST>
ignoreregex =
EOL
    systemctl restart fail2ban
    log "INFO" "Fail2ban configurato"
}

# Funzione configure_firewall:
# Configura iptables per impostare regole di base, includendo NAT e rate limiting per SSH.
configure_firewall() {
    # Recupera la rete di management dal routing (esclude IP particolari)
    local mgmt_net
    mgmt_net=$(ip route | grep -v default | grep -v '169.254.0.0/16' | head -1 | awk '{print $1}')
    # Svuota le regole esistenti
    iptables -F
    iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    # Consenti tutto il traffico di loopback
    iptables -A INPUT -i lo -j ACCEPT
    # Consenti traffico già stabilito
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    # Consenti accesso al WebUI di Proxmox (porta 8006) dalla rete di management
    iptables -A INPUT -p tcp --dport 8006 -s "$mgmt_net" -j ACCEPT
    # Rate limiting per SSH: limita i nuovi tentativi di connessione
    iptables -A INPUT -p tcp --dport 22 -s "$mgmt_net" -m state --state NEW -m recent --set --name SSH
    iptables -A INPUT -p tcp --dport 22 -s "$mgmt_net" -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --rttl --name SSH -j DROP
    # Consenti traffico per SPICE/VNC (console delle VM)
    iptables -A INPUT -p tcp --dport 3128 -s "$mgmt_net" -j ACCEPT
    iptables -A INPUT -p tcp --dport 5900:5999 -s "$mgmt_net" -j ACCEPT
    # Consenti traffico per Corosync (clustering)
    iptables -A INPUT -p udp --dport 5404:5405 -s "$mgmt_net" -j ACCEPT
    # Installa iptables-persistent per salvare le regole e renderle persistenti al riavvio
    apt install -y iptables-persistent
    iptables-save > "$IPTABLES_RULES"
    log "INFO" "Firewall configurato e regole salvate"
}

# Esecuzione sequenziale delle funzioni di sicurezza
configure_kernel_security
configure_secure_ssh
configure_fail2ban
configure_firewall
```

#### **Perché questo approccio?**

- **Automazione completa:**
  Tutte le configurazioni vengono applicate in sequenza senza bisogno di interventi manuali successivi, garantendo un ambiente sicuro fin da subito.
- **Hardening sistematico:**
  Il kernel, SSH, il firewall e fail2ban sono configurati per ridurre le superfici d'attacco, migliorando la sicurezza complessiva del sistema.
- **Persistenza e monitoraggio:**
  Le regole di iptables vengono salvate in modo da essere ripristinate al riavvio, e la configurazione di fail2ban monitora attivamente i log per bloccare accessi sospetti.

#### **Esercizio 4: Personalizzare la Configurazione del Firewall**

**Obiettivo:**
Modificare la funzione `configure_firewall` per aggiungere una regola che consenta l'accesso alla porta 443 (HTTPS) solo da un range IP definito, ad esempio dalla rete aziendale.

**Istruzioni:**

1. Aggiungi una variabile `ALLOWED_HTTPS_NET` all'inizio dello script (esempio: `"192.168.100.0/24"`).
2. Inserisci una nuova regola iptables per consentire il traffico TCP sulla porta 443 solo da tale range.
3. Commenta il codice per spiegare la logica.

**Soluzione Proposta:**

```bash
#!/bin/bash
# Aggiunta della variabile per definire il range IP autorizzato per HTTPS.
readonly ALLOWED_HTTPS_NET="192.168.100.0/24"

configure_firewall() {
    local mgmt_net
    mgmt_net=$(ip route | grep -v default | grep -v '169.254.0.0/16' | head -1 | awk '{print $1}')
    iptables -F
    iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport 8006 -s "$mgmt_net" -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -s "$mgmt_net" -m state --state NEW -m recent --set --name SSH
    iptables -A INPUT -p tcp --dport 22 -s "$mgmt_net" -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --rttl --name SSH -j DROP
    iptables -A INPUT -p tcp --dport 3128 -s "$mgmt_net" -j ACCEPT
    iptables -A INPUT -p tcp --dport 5900:5999 -s "$mgmt_net" -j ACCEPT
    iptables -A INPUT -p udp --dport 5404:5405 -s "$mgmt_net" -j ACCEPT

    # Regola aggiuntiva: consente traffico HTTPS (porta 443) solo dalla rete definita
    iptables -A INPUT -p tcp --dport 443 -s "$ALLOWED_HTTPS_NET" -j ACCEPT

    apt install -y iptables-persistent
    iptables-save > "$IPTABLES_RULES"
    log "INFO" "Firewall configurato con regola HTTPS per $ALLOWED_HTTPS_NET e regole salvate"
}
```

**Spiegazione della Soluzione:**

- La variabile `ALLOWED_HTTPS_NET` contiene il range di IP autorizzato a connettersi sulla porta 443.
- La regola iptables aggiunta consente solo le connessioni provenienti da questo range per la porta 443, integrando la configurazione del firewall con restrizioni più specifiche.

------

### **Parte 5: Configurazione Cluster e Alta Disponibilità**

#### **Obiettivo**

Questo script configura un cluster Proxmox VE e abilita l’alta disponibilità (HA) tramite Corosync, fencing e monitoraggio. L’obiettivo è garantire che i nodi possano lavorare in sinergia e, in caso di guasto di uno, il servizio continui a funzionare senza interruzioni.

#### **Spiegazione del Codice**

```bash
#!/bin/bash
# Script per configurare il clustering e l'alta disponibilità (HA) in Proxmox VE.
# Lo script:
# 1. Configura la rete dedicata al cluster.
# 2. Inizializza il cluster se il nodo non ne fa già parte.
# 3. Configura gruppi HA e fencing per prevenire split-brain.
# 4. Abilita il monitoraggio del cluster.

# Costanti e variabili di configurazione
readonly COROSYNC_CONF="/etc/pve/corosync.conf"  # File di configurazione per Corosync
readonly HA_GROUP_CONF="/etc/pve/ha/groups.cfg"     # File per i gruppi HA
readonly QUORUM_NODES=2                             # Numero minimo di nodi per il quorum

# Funzione detect_cluster_network:
# Seleziona l'interfaccia con maggiore throughput per il traffico cluster e ne estrae la subnet.
detect_cluster_network() {
    local best_interface
    best_interface=$(ip -o link show | grep -Ev "lo|vmbr|docker|veth" | \
        while read -r line; do
            iface=$(echo "$line" | awk -F': ' '{print $2}')
            speed=$(cat /sys/class/net/"$iface"/speed 2>/dev/null || echo "0")
            echo "$iface $speed"
        done | sort -k2 -nr | head -1 | awk '{print $1}')
    if [ -z "$best_interface" ]; then
        log "ERROR" "Interfaccia per cluster non trovata"
    fi
    local ip_info
    ip_info=$(ip -4 addr show "$best_interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')
    local subnet
    subnet=$(ipcalc -n "$ip_info" | awk '/Network/ {print $2}')
    echo "$subnet"
}

# Funzione prepare_cluster_network:
# Configura una VLAN dedicata per il traffico cluster sul bridge principale (vmbr0) e applica tuning di rete.
prepare_cluster_network() {
    local cluster_net
    cluster_net=$(detect_cluster_network)
    # Ottiene l'indirizzo IP del nodo (escludendo loopback)
    local node_ip
    node_ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -1)
    # Aggiunge una sezione al file /etc/network/interfaces per la VLAN dedicata al cluster
    cat >> /etc/network/interfaces << EOL

# Interfaccia dedicata al traffico cluster (VLAN 4000)
auto vmbr0.4000
iface vmbr0.4000 inet static
    address ${node_ip}
    netmask 255.255.255.0
    vlan-raw-device vmbr0
    mtu 9000  # Abilita jumbo frames per miglior throughput
EOL

    # Applica ottimizzazioni per il traffico di rete cluster
    cat >> /etc/sysctl.d/99-network-tuning.conf << 'EOL'
# Ottimizzazioni per il traffico cluster
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 50000
net.ipv4.tcp_mtu_probing = 1
EOL
    sysctl -p /etc/sysctl.d/99-network-tuning.conf
    ifup vmbr0.4000
    log "INFO" "Rete cluster configurata (VLAN 4000) su vmbr0"
}

# Funzione initialize_cluster:
# Inizializza il cluster se il nodo non fa già parte di uno.
initialize_cluster() {
    if pvecm status &>/dev/null; then
        log "INFO" "Nodo già membro di un cluster; salto inizializzazione"
        return
    fi
    local cluster_name="pve-cluster"
    local node_name
    node_name=$(hostname)
    # Usa l'IP configurato sulla VLAN dedicata al cluster
    local node_ip
    node_ip=$(ip -4 addr show vmbr0.4000 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    # Crea il cluster con pvecm
    pvecm create "$cluster_name"
    # Configura Corosync con parametri ottimizzati per il traffico cluster
    cat > "$COROSYNC_CONF" << EOL
totem {
    version: 2
    secauth: 1
    cluster_name: $cluster_name
    transport: knet
    interface {
        linknumber: 0
        bindnetaddr: ${node_ip%.*}.0
        mcastport: 5405
        ttl: 1
    }
    token: 3000
    token_retransmits_before_loss_const: 10
    join: 60
    consensus: 3600
    max_messages: 20
}
nodelist {
    node {
        ring0_addr: $node_ip
        nodeid: 1
        name: $node_name
    }
}
quorum {
    provider: corosync_votequorum
    expected_votes: $QUORUM_NODES
    two_node: 1
}
logging {
    to_logfile: yes
    logfile: /var/log/corosync/corosync.log
    to_syslog: yes
    debug: off
    timestamp: on
}
EOL
    log "INFO" "Cluster inizializzato: $cluster_name"
}

# Funzione configure_ha:
# Configura gruppi HA e il manager HA, poi chiama la funzione di fencing.
configure_ha() {
    if ! pvecm status &>/dev/null; then
        log "ERROR" "Il cluster non è attivo; inizializza il cluster prima di configurare HA"
    fi
    cat > "$HA_GROUP_CONF" << EOL
group: preferred_node1
    nodes node1:100 node2:80
    nofailback: 1
    restricted: 0

group: preferred_node2
    nodes node2:100 node1:80
    nofailback: 1
    restricted: 0
EOL
    # Configurazione del manager HA con watchdog
    cat > /etc/pve/ha/manager.cfg << EOL
checktime: 60
max_restart: 3
min_quorum: $QUORUM_NODES
watchdog: {
    module: softdog
    timeout: 60
}
EOL
    configure_fencing
}

# Funzione configure_fencing:
# Configura il fencing per prevenire split-brain, installando agenti fence e impostando politiche per i nodi.
configure_fencing() {
    apt install -y fence-agents
    cat > /etc/pve/ha/fence.d/stonith.conf << EOL
stonith {
    mode: automatic
    timeout: 60
    priority: 1
    devices: standard-fence
}

device {
    name: standard-fence
    agent: fence_pve
    options {
        delay: 5
        timeout: 60
        retry: 3
    }
}
EOL
    # Per ogni nodo del cluster, aggiunge una configurazione specifica
    for node in $(pvecm nodes | awk 'NR>2 {print $2}'); do
        cat >> /etc/pve/ha/fence.d/nodes.conf << EOL
node $node {
    device: standard-fence
    port: $node
    action: reboot
    timeout: 60
}
EOL
    done
    log "INFO" "Fencing configurato per il cluster"
}

# Funzione setup_cluster_monitoring:
# Crea uno script e un servizio systemd per monitorare lo stato e le prestazioni del cluster.
setup_cluster_monitoring() {
    cat > /usr/local/bin/cluster-monitor.sh << 'EOL'
#!/bin/bash
LOG_FILE="/var/log/cluster-monitor.log"
# Funzione per monitorare lo stato del cluster
monitor_cluster_status() {
    local cluster_status
    cluster_status=$(pvecm status)
    echo "[$(date)] Cluster Status:" >> "$LOG_FILE"
    echo "$cluster_status" >> "$LOG_FILE"
}
# Funzione per monitorare la latenza tra i nodi
monitor_cluster_performance() {
    for node in $(pvecm nodes | awk 'NR>2 {print $2}'); do
        local ping_time
        ping_time=$(ping -c 1 $node | grep time= | cut -d= -f4)
        echo "[$(date)] Node $node latency: $ping_time" >> "$LOG_FILE"
    done
}
while true; do
    monitor_cluster_status
    monitor_cluster_performance
    sleep 60
done
EOL
    chmod +x /usr/local/bin/cluster-monitor.sh
    cat > /etc/systemd/system/cluster-monitor.service << EOL
[Unit]
Description=Cluster Monitoring Service
After=pve-cluster.service

[Service]
ExecStart=/usr/local/bin/cluster-monitor.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOL
    systemctl enable cluster-monitor
    systemctl start cluster-monitor
    log "INFO" "Monitoraggio cluster attivato"
}

# Esecuzione sequenziale:
prepare_cluster_network
initialize_cluster
configure_ha
setup_cluster_monitoring
```

#### **Perché   questo approccio?**

- **Rilevamento e configurazione automatica della rete cluster:**
  La funzione `detect_cluster_network` individua automaticamente l'interfaccia migliore e configura una VLAN dedicata, ottimizzando il traffico interno del cluster.
- **Inizializzazione condizionale:**
  La funzione `initialize_cluster` verifica se il nodo fa già parte di un cluster, evitando ripetute inizializzazioni.
- **Fencing e HA:**
  Il fencing previene split-brain e, insieme alla configurazione HA, assicura che il cluster possa gestire guasti in maniera automatica.
- **Monitoraggio integrato:**
  La creazione di uno script di monitoraggio e un servizio systemd consente di tenere sotto controllo lo stato del cluster in modo continuo.

#### **Esercizio 5: Personalizzare il Monitoraggio del Cluster**

**Obiettivo:**
Modificare lo script di monitoraggio (`cluster-monitor.sh`) per includere anche un controllo sull’utilizzo della CPU di ogni nodo remoto (ad esempio, usando `ssh` per eseguire `top` o `mpstat`).
Inoltre, aggiungere una notifica (ad es. un semplice echo) se l’utilizzo supera una soglia definita (es. 80%).

**Istruzioni:**

1. Aggiungi una funzione `monitor_cpu_usage` nello script di monitoraggio.
2. Per ogni nodo, esegui il comando remoto per ottenere il carico della CPU.
3. Se il carico supera la soglia (definita in una variabile, es. `CPU_THRESHOLD=80`), scrivi un messaggio di avviso sul log.
4. Commenta il codice per spiegare ogni passaggio.

**Soluzione Proposta (modifica dello script di monitoraggio):**

```bash
#!/bin/bash
LOG_FILE="/var/log/cluster-monitor.log"
CPU_THRESHOLD=80

# Funzione per monitorare lo stato del cluster
monitor_cluster_status() {
    local cluster_status
    cluster_status=$(pvecm status)
    echo "[$(date)] Cluster Status:" >> "$LOG_FILE"
    echo "$cluster_status" >> "$LOG_FILE"
}

# Funzione per monitorare la latenza tra i nodi
monitor_cluster_performance() {
    for node in $(pvecm nodes | awk 'NR>2 {print $2}'); do
        local ping_time
        ping_time=$(ping -c 1 $node | grep time= | cut -d= -f4)
        echo "[$(date)] Node $node latency: $ping_time" >> "$LOG_FILE"
    done
}

# Funzione per monitorare l'utilizzo CPU di ogni nodo remoto
monitor_cpu_usage() {
    for node in $(pvecm nodes | awk 'NR>2 {print $2}'); do
        # Esegue un comando remoto via ssh per ottenere l'utilizzo medio della CPU
        # Nota: Assicurarsi che l'accesso SSH sia configurato senza password per l'automazione
        cpu_usage=$(ssh $node "mpstat 1 1 | awk '/Average/ {print 100 - \$12}'")
        echo "[$(date)] Node $node CPU usage: $cpu_usage%" >> "$LOG_FILE"
        # Se l'utilizzo supera la soglia, segnala un avviso
        if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
            echo "[$(date)] ALERT: Node $node CPU usage high: $cpu_usage%" >> "$LOG_FILE"
        fi
    done
}

while true; do
    monitor_cluster_status
    monitor_cluster_performance
    monitor_cpu_usage
    sleep 60
done
```

**Spiegazione della Soluzione:**

- Abbiamo aggiunto la funzione `monitor_cpu_usage` che, per ogni nodo, usa `ssh` per eseguire `mpstat` e calcolare l’utilizzo medio della CPU.
- Se il valore supera la soglia definita in `CPU_THRESHOLD`, viene registrato un messaggio di avviso nel log.
- I commenti spiegano il flusso e la logica del monitoraggio remoto.

'Appendice, con azioni pratiche e suggerimenti per gestire Proxmox da remoto via SSH o HTTP (Chrome).

------

## Appendice A:  Azioni di Amministrazione e Gestione Remota

### **1. Accesso Remoto via SSH**

#### **Obiettivo:**

Gestire Proxmox da terminale in remoto, eseguendo comandi, monitorando lo stato e applicando aggiornamenti.

#### **Azioni Possibili:**

- **Connessione SSH:**

  ```bash
  ssh root@<indirizzo-ip-proxmox>
  ```

  Usa chiavi SSH per connessioni senza password.

- **Monitoraggio dei Servizi:**
  Verifica lo stato dei principali servizi Proxmox:

  ```bash
  systemctl status pvedaemon pveproxy pvestatd pve-cluster corosync
  ```

- **Gestione Backup e Ripristino:**
  Crea backup della configurazione:

  ```bash
  tar czf /root/proxmox-config-$(date +%Y%m%d).tar.gz /etc/pve
  ```

  Ripristina un backup copiando i file nella cartella /etc/pve (da eseguire con attenzione).

- **Aggiornamento del Sistema:**
  Esegui aggiornamenti:

  ```
  apt update && apt upgrade -y
  ```

- **Controllo Storage:**
  Verifica lo stato degli storage:

  ```
  pvesm status
  zpool status    # Se usi ZFS
  vgdisplay     # Se usi LVM
  ```

- **Script di Monitoraggio e Manutenzione:**
  Avvia script di monitoraggio o manutenzione già creati:

  ```
  /usr/local/bin/performance-monitor.sh
  /usr/local/bin/cluster-monitor.sh
  ```

### **2. Accesso e Gestione via HTTP (Chrome)**

#### **Obiettivo:**

Utilizzare l'interfaccia web di Proxmox per amministrare VM, container, il cluster e le risorse di storage.

#### **Azioni Possibili:**

- **Accesso alla Web GUI:**
  Inserisci nell'URL del browser:

  ```
  https://<indirizzo-ip-proxmox>:8006
  ```

  Accedi con le credenziali amministrative.

- **Gestione VM e Container:**

  - **Creazione e clonazione:** Usa la sezione "Create VM" o "Clone" per creare nuove macchine virtuali o container.
  - **Console Remota:** Accedi alle console direttamente via browser per operazioni di diagnostica.
  - **Aggiornamento Risorse:** Modifica CPU, memoria, e storage delle VM tramite l'interfaccia grafica.

- **Monitoraggio del Cluster e HA:**
  Verifica lo stato del cluster e delle risorse HA nella sezione "Datacenter" > "Cluster" e "HA".

- **Configurazione di Backup:**
  Pianifica e avvia backup per VM e container dalla sezione "Backup".
  Configura job di backup automatici e imposta notifiche in caso di errori.

- **Gestione Storage:**
  Visualizza lo stato degli storage, aggiungi nuovi dischi, o configura nuovi volumi attraverso l'interfaccia "Storage".

### **3. Esercizi Pratici**

#### **Esercizio A:**

**Obiettivo:** Verifica e riporta lo stato del cluster via SSH.
**Istruzioni:**

1. Collegati via SSH al nodo Proxmox.

2. Esegui:

   ```
   pvecm status
   ```

3. Riporta il risultato e verifica il quorum.

**Soluzione:**
Il comando mostrerà la lista dei nodi, il quorum e lo stato del cluster. Se il quorum è inferiore al minimo, analizza i log in `/var/log/corosync/corosync.log`.

------

#### **Esercizio B:**

**Obiettivo:** Pianifica un backup tramite l'interfaccia web.
**Istruzioni:**

1. Accedi alla Web GUI (Chrome) su `https://<ip-proxmox>:8006`.
2. Naviga in "Datacenter" > "Backup".
3. Crea un job di backup per una VM specifica, impostando il tempo di esecuzione e la destinazione.

**Soluzione:**
Il job pianificato apparirà nella lista backup e verrà eseguito all'orario stabilito. Verifica lo stato del backup dalla sezione "Tasks" e consulta i log in caso di errori.

------



# Configurazione del Server Proxmox VE

by TheNizix  02/2025 


## Panoramica del Sistema

Dopo aver eseguito gli script di installazione e configurazione dalla guida, avrai un server Proxmox VE completamente configurato con i seguenti componenti:

### Configurazione Base del Sistema
- Sistema Operativo: Proxmox VE (basato su Debian)
- Struttura dello Storage:
  - Partizione di sistema (30GB) con filesystem ext4
  - Partizione EFI (512MB)
  - Partizione di boot (1GB)
  - Partizione swap (dimensionata alla metà della RAM di sistema, minimo 4GB)
- Configurazione di Rete:
  - Bridge di gestione (vmbr0) con supporto VLAN
  - Bridge isolato per laboratorio (vmbr1) sulla rete 192.168.100.0/24
  - VLAN 4000 per la rete del cluster per comunicazioni ad alta disponibilità

### Configurazione della Sicurezza
- Accesso SSH blindato:
  - Login root limitato all'autenticazione con chiave
  - Autenticazione con password disabilitata
  - Parametri di sicurezza personalizzati per cifratura e timeout
- Firewall attivo con:
  - Accesso di gestione limitato a reti specifiche
  - Limitazione delle connessioni SSH
  - Interfaccia web Proxmox protetta (porta 8006)
  - Configurazione NAT per le reti delle VM
- Protezione Fail2ban contro attacchi brute force
- Parametri di sicurezza del kernel ottimizzati per ambiente di virtualizzazione

### Configurazione Alta Disponibilità
- Comunicazione cluster Corosync configurata
- Meccanismi di fencing per prevenire split-brain
- Gruppi HA definiti per il failover delle VM
- Monitoraggio automatizzato e rilevamento guasti

## Accesso al Server

### Accesso Interfaccia Web
- URL: https://[ip-server]:8006
- Credenziali predefinite:
  - Nome utente: root
  - Password: [impostata durante l'installazione]
- Browser supportati: Versioni recenti di Chrome, Firefox, Safari

### Accesso SSH
- Comando: `ssh root@[ip-server]`
- Autenticazione: Richiesta chiave SSH (autenticazione password disabilitata)
- Porta: 22 (con protezione rate limiting)

### Accesso di Rete per le VM
- Rete interna: 192.168.100.0/24
- Gateway predefinito: 192.168.100.1
- NAT abilitato per accesso internet
- DHCP non configurato di default (consigliato IP statico)

## Risorse Disponibili

### Sistemi di Storage
- Pool di storage Local-LVM per dischi VM
- Posizione backup: /var/lib/vz/dump
- Storage ISO: /var/lib/vz/template/iso
- Storage template: /var/lib/vz/template/cache

### Template Macchine Virtuali
- Template base Ubuntu Server (ID: 9000)
  - 2GB RAM (modificabile)
  - 2 vCPU (modificabile)
  - 32GB disco
  - Interfaccia di rete su vmbr1
  - QEMU Guest Agent abilitato

## Utilizzo del Sistema

### Creazione Nuove Macchine Virtuali
1. Accedere all'interfaccia web
2. Selezionare 'Crea VM' o clonare il template 9000
3. Regolare le risorse secondo necessità
4. Scegliere il bridge di rete (vmbr1 per rete laboratorio)
5. Avviare la VM e accedere alla console tramite interfaccia web

### Gestione Macchine Virtuali
- Accesso console: Tramite interfaccia web o client SPICE
- Configurazione rete: Consigliato IP statico nel range 192.168.100.0/24
- Operazioni di backup: Disponibili tramite interfaccia web o comando `vzdump`
- Modifica risorse: Possibile durante l'esecuzione della VM per la maggior parte dei parametri

### Monitoraggio
- Stato sistema: Disponibile tramite dashboard interfaccia web
- Salute cluster: Accessibile via comando `pvecm status`
- Utilizzo risorse: Grafici in tempo reale nell'interfaccia web
- Log: Localizzati in /var/log/pve/
- Demone di monitoraggio personalizzato: In esecuzione come servizio systemd

### Operazioni di Backup
- Servizio di backup automatizzato configurato
- Posizione backup: /mnt/backup
- Periodo di conservazione: 30 giorni
- Processo di verifica automatizzato

## Procedure di Manutenzione

### Aggiornamenti Sistema
```bash
apt update
apt full-upgrade
```

### Verifica Backup
```bash
# Controlla stato backup
ls -l /mnt/backup/dump
# Verifica integrità backup
vzdump --verify [file-backup]
```

### Gestione Storage
```bash
# Controlla stato storage
pvesm status
# Verifica utilizzo disco
df -h
```

### Monitoraggio Sicurezza
```bash
# Controlla tentativi di accesso falliti
fail2ban-client status
# Visualizza regole firewall
iptables -L
```

## Operazioni Comuni

### Creazione Nuova VM da Template
```bash
# Clona template 9000 in nuova VM ID 101
qm clone 9000 101 --name nuova-vm
# Avvia la nuova VM
qm start 101
```

### Gestione Stati VM
```bash
# Ferma VM
qm stop [vmid]
# Avvia VM
qm start [vmid]
# Riavvia VM
qm reset [vmid]
```

### Backup Singola VM
```bash
vzdump [vmid] --compress zstd --mode snapshot
```

## Risoluzione Problemi

### Problemi Comuni
1. Accesso Interfaccia Web
   - Controllare regole firewall
   - Verificare stato servizio pveproxy
   - Confermare connettività di rete

2. Problemi Rete VM
   - Verificare configurazione bridge
   - Controllare impostazioni rete VM
   - Confermare regole NAT

3. Problemi Storage
   - Controllare stato pool storage
   - Verificare spazio disco
   - Esaminare log di sistema

### Posizione Log
- Log Proxmox: /var/log/pve/
- Log cluster: /var/log/corosync/
- Log sistema: /var/log/syslog
- Log sicurezza: /var/log/auth.log

### Risorse di Supporto
- Documentazione ufficiale: https://pve.proxmox.com/wiki/
- Forum comunità: https://forum.proxmox.com/
- Documentazione locale: Disponibile tramite sistema di aiuto dell'interfaccia web


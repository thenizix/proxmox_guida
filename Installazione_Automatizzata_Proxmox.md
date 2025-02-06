### **Parte 1: Preparazione e Installazione Automatizzata**

#### **Obiettivo**

Questo script automatizza la preparazione dell'ambiente di installazione per Proxmox VE. L'obiettivo è evitare interventi manuali non necessari durante il setup, garantendo una procedura ripetibile e sicura.

#### **Spiegazione e Codice**

```bash
#!/bin/bash
# Script di configurazione dello storage per Proxmox VE
# Verifica l'installazione di Proxmox, registra gli storage esistenti e controlla il disco esterno.

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

# Verifica se Proxmox è installato
check_proxmox_installed() {
    if ! command -v pveversion &> /dev/null; then
        log "ERROR" "Proxmox VE non risulta installato."
    fi
    log "INFO" "Proxmox VE rilevato. Versione: $(pveversion)"
}

# Funzione analyze_hardware: controlla la RAM installata.
analyze_hardware() {
    local total_ram_kb total_ram_gb
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_ram_gb=$(( total_ram_kb / 1024 / 1024 ))
    log "INFO" "RAM disponibile: ${total_ram_gb}GB"
    echo "$total_ram_gb"
}

# Funzione per registrare gli storage esistenti in Proxmox
list_existing_storage() {
    log "INFO" "Storage registrati su Proxmox:"
    pvesm status | tee -a "$LOG_FILE"
}

# Funzione identify_external_disk: individua un disco esterno adatto come storage dati.
identify_external_disk() {
    local disks disk_name disk_size disk_gb
    readarray -t disks < <(lsblk -dpno NAME,SIZE | grep -Ev "usb|loop|sr0")
    for disk in "${disks[@]}"; do
        disk_name=$(echo "$disk" | awk '{print $1}')
        disk_size=$(blockdev --getsize64 "$disk_name")
        disk_gb=$(( disk_size / 1024 / 1024 / 1024 ))
        if [ "$disk_gb" -ge "$MIN_DISK_GB" ]; then
            log "INFO" "Disco esterno rilevato: $disk_name (${disk_gb}GB)"
            echo "$disk_name"
            return 0
        fi
    done
    log "WARN" "Nessun disco esterno adatto trovato"
}

# Funzione per verificare e configurare lo storage dati
configure_storage() {
    local external_disk="$1"
    if [ -z "$external_disk" ]; then
        log "WARN" "Nessun disco esterno configurabile trovato."
        return
    fi
    
    local mount_point="/mnt/external_storage"
    if ! mount | grep -q "$external_disk"; then
        log "INFO" "Montaggio del disco $external_disk in $mount_point"
        mkdir -p "$mount_point"
        mount "$external_disk" "$mount_point"
    fi
    log "INFO" "Disco esterno pronto all'uso in $mount_point"
}

# Esecuzione sequenziale delle funzioni
check_proxmox_installed
ram=$(analyze_hardware)
list_existing_storage
disk=$(identify_external_disk)
configure_storage "$disk"

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

```bash
#!/bin/bash
# Script di configurazione iniziale della rete per Proxmox VE

# Funzione di logging per tracciare le operazioni
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
    if [ "$level" = "ERROR" ]; then
        exit 1
    fi
}

# Funzione per disegnare una linea della tabella
draw_line() {
    printf '+%*s+%*s+%*s+%*s+\n' "-20" "" "-15" "" "-15" "" "-25" "" | tr ' ' '-'
}

# Funzione per visualizzare la riga della tabella
print_row() {
    printf "| %-18s | %-13s | %-13s | %-23s |\n" "$1" "$2" "$3" "$4"
}

# Funzione per mostrare la configurazione di rete
display_network_config() {
    local mgmt_ip="$1"
    local mgmt_prefix="$2"
    local storage_net="192.168.100.1/24"
    local vm_net="192.168.200.1/24"
    
    echo -e "\nConfigurazione di Rete Proxmox VE"
    echo "=================================="
    draw_line
    print_row "Interfaccia" "Indirizzo IP" "Subnet Mask" "Funzione"
    draw_line
    print_row "vmbr0" "$mgmt_ip" "/$mgmt_prefix" "Management & External"
    print_row "vmbr1" "192.168.100.1" "/24" "Storage Network"
    print_row "vmbr2" "192.168.200.1" "/24" "VM Network (NAT)"
    draw_line
    
    echo -e "\nDettagli Aggiuntivi:"
    echo "=================="
    echo "1. Bridge Management (vmbr0):"
    echo "   - Interfaccia fisica: enp0s31f6"
    echo "   - VLAN support: Yes (${VLAN_RANGE})"
    echo "   - STP: Disabled"
    
    echo -e "\n2. Bridge Storage (vmbr1):"
    echo "   - Tipo: Isolato"
    echo "   - Range IP: 192.168.100.0/24"
    echo "   - Gateway: 192.168.100.1"
    
    echo -e "\n3. Bridge VM (vmbr2):"
    echo "   - Tipo: NAT"
    echo "   - Range IP: 192.168.200.0/24"
    echo "   - Gateway: 192.168.200.1"
    echo "   - NAT: Enabled verso vmbr0"
}

# Costanti di configurazione
readonly VLAN_RANGE="2-4094"
readonly BRIDGE_PREFIX="vmbr"
readonly MANAGEMENT_VLAN=1
readonly STORAGE_VLAN=2
readonly VM_VLAN=3

# Funzione per configurare i bridge di rete
configure_network_bridges() {
    local physical_interface="enp0s31f6"
    local current_ip="192.168.1.33"
    local current_prefix="24"

    # Backup existing configuration
    cp /etc/network/interfaces /etc/network/interfaces.backup
    
    # Genera la configurazione di rete
    cat > /etc/network/interfaces << EOL
auto lo
iface lo inet loopback

# Bridge principale per management
auto ${BRIDGE_PREFIX}0
iface ${BRIDGE_PREFIX}0 inet static
    address ${current_ip}/${current_prefix}
    bridge-ports ${physical_interface}
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids ${VLAN_RANGE}

# Bridge per storage
auto ${BRIDGE_PREFIX}1
iface ${BRIDGE_PREFIX}1 inet static
    address 192.168.100.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0

# Bridge per VM con NAT
auto ${BRIDGE_PREFIX}2
iface ${BRIDGE_PREFIX}2 inet static
    address 192.168.200.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up iptables -t nat -A POSTROUTING -s "192.168.200.0/24" -o ${BRIDGE_PREFIX}0 -j MASQUERADE
EOL

    # Imposta hostname basato sull'IP
    local hostname="pve-$(echo $current_ip | tr '.' '-')"
    echo "$hostname" > /etc/hostname

    log "INFO" "Configurazione di rete completata per l'interfaccia $physical_interface"
    log "INFO" "Un backup della configurazione precedente è stato salvato in /etc/network/interfaces.backup"
    
    # Mostra la tabella di configurazione
    display_network_config "$current_ip" "$current_prefix"
    
    echo -e "\nNota: Per applicare le modifiche, riavviare il sistema o eseguire 'systemctl restart networking'"
}

# Esecuzione della funzione principale
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

1. # Capitolo 3.1: Configurazione Storage e Template Kali Linux

   ## Introduzione

   In questo capitolo configureremo lo storage Proxmox e creeremo un template basato su Kali Linux, perfetto per il nostro ambiente di laboratorio isolato. Utilizzeremo la rete isolata (192.168.100.0/24) configurata nel capitolo precedente.

   ## Script di Configurazione Completo

   ```bash
   #!/bin/bash
   # =============================================================================
   # Script di Configurazione Proxmox con Kali Linux
   # Versione: 1.0
   #
   # Questo script automatizza:
   # - Configurazione storage Proxmox
   # - Download e verifica Kali Linux
   # - Creazione template ottimizzato
   # - Gestione VM in ambiente isolato
   # =============================================================================
   
   # -----------------------------------------------------------------------------
   # Configurazione Globale
   # -----------------------------------------------------------------------------
   # File di log per tracciare tutte le operazioni
   readonly LOG_FILE="/var/log/proxmox-setup.log"
   
   # Configurazione rete isolata dal capitolo precedente
   readonly NETWORK_BRIDGE="vmbr1"
   readonly NETWORK_SUBNET="192.168.100.0/24"
   readonly NETWORK_GATEWAY="192.168.100.1"
   
   # Configurazione template e ISO
   readonly TEMPLATE_ID=9000
   readonly TEMPLATE_NAME="kali-template"
   readonly KALI_URL="https://old.kali.org/base-images/kali-2024.1/kali-linux-2024.1-installer-amd64.iso"
   readonly KALI_SHA256_URL="https://old.kali.org/base-images/kali-2024.1/SHA256SUMS"
   readonly ISO_FILE="/var/lib/vz/template/iso/kali-linux-2024.1-installer-amd64.iso"
   
   # Requisiti minimi sistema
   readonly MIN_SPACE_GB=50
   
   # Directory necessarie per Proxmox
   readonly STORAGE_PATHS=(
       "/var/lib/vz/template/iso"     # Directory per le ISO
       "/var/lib/vz/template/cache"   # Cache per i template
       "/var/lib/vz/dump"            # Directory per i backup
       "/mnt/backup"                 # Backup esterni
   )
   
   # -----------------------------------------------------------------------------
   # Funzioni di Utilità
   # -----------------------------------------------------------------------------
   
   # Funzione per logging centralizzato
   # Parametri: 
   # $1 = livello (INFO, WARN, ERROR)
   # $2 = messaggio
   log() {
       local level="$1"
       local message="$2"
       local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
       echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
       
       # Termina lo script in caso di errore
       if [ "$level" = "ERROR" ]; then
           exit 1
       fi
   }
   
   # Verifica che tutti i prerequisiti siano soddisfatti
   check_prerequisites() {
       log "INFO" "Verifica prerequisiti di sistema..."
   
       # Verifica che lo script sia eseguito come root
       if [ "$(id -u)" != "0" ]; then
           log "ERROR" "Questo script richiede privilegi root"
       fi
   
       # Verifica presenza comandi necessari
       local required_commands="pvesm qm pct vgs pvs lvs wget sha256sum"
       for cmd in $required_commands; do
           if ! command -v "$cmd" &>/dev/null; then
               log "ERROR" "Comando $cmd non trovato. Installare il pacchetto necessario."
           fi
       done
   }
   
   # Verifica configurazione di rete dal capitolo precedente
   check_network() {
       log "INFO" "Verifica configurazione di rete..."
   
       # Verifica presenza bridge
       if ! ip link show "$NETWORK_BRIDGE" &>/dev/null; then
           log "ERROR" "Bridge $NETWORK_BRIDGE non trovato. Eseguire prima il capitolo 2."
       fi
   
       # Verifica IP forwarding
       if ! sysctl net.ipv4.ip_forward | grep -q "= 1"; then
           log "ERROR" "IP forwarding non abilitato. Eseguire prima il capitolo 2."
       fi
   
       # Verifica regole NAT
       if ! iptables -t nat -L | grep -q "MASQUERADE.*$NETWORK_SUBNET"; then
           log "ERROR" "Regola NAT per rete isolata non trovata. Eseguire prima il capitolo 2."
       fi
   }
   
   # Verifica spazio disco disponibile
   check_storage() {
       log "INFO" "Verifica spazio disco..."
       
       local available_space=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
       
       if [ "$available_space" -lt "$MIN_SPACE_GB" ]; then
           log "ERROR" "Spazio insufficiente: ${available_space}GB (minimo ${MIN_SPACE_GB}GB)"
       fi
   }
   
   # -----------------------------------------------------------------------------
   # Configurazione Storage
   # -----------------------------------------------------------------------------
   
   # Configurazione storage base di Proxmox
   configure_storage() {
       log "INFO" "Configurazione storage base..."
   
       # Creazione directory con permessi appropriati
       for path in "${STORAGE_PATHS[@]}"; do
           mkdir -p "$path"
           chmod 700 "$path"
           log "INFO" "Creata directory: $path"
       done
   
       # Aggiunta storage backup a Proxmox
       if ! pvesm status | grep -q "backup"; then
           pvesm add dir backup --path /mnt/backup --content backup
           log "INFO" "Storage backup configurato in Proxmox"
       fi
   
       # Configurazione LVM se presente
       configure_lvm
   }
   
   # Configurazione e ottimizzazione LVM
   configure_lvm() {
       log "INFO" "Configurazione LVM..."
   
       if vgs | grep -q "pve"; then
           # Conversione a thin pool se necessario
           if ! lvs | grep -q "thin"; then
               lvconvert --type thin-pool pve/data
           fi
   
           # Configurazione monitoraggio LVM
           cat > /etc/lvm/lvm.conf << 'EOL'
   activation {
       monitoring = 1
       thin_pool_autoextend_threshold = 80
       thin_pool_autoextend_percent = 20
   }
   EOL
   
           systemctl restart lvm2-monitor
           log "INFO" "LVM configurato e ottimizzato"
       fi
   }
   
   # -----------------------------------------------------------------------------
   # Gestione ISO e Template
   # -----------------------------------------------------------------------------
   
   # Download e verifica ISO Kali Linux
   download_kali() {
       log "INFO" "Download Kali Linux ISO..."
   
       if [ ! -f "$ISO_FILE" ]; then
           # Creazione directory se non esiste
           mkdir -p "$(dirname "$ISO_FILE")"
           
           # Download ISO con barra di progresso
           log "INFO" "Download ISO da $KALI_URL"
           wget --progress=bar:force -O "$ISO_FILE" "$KALI_URL" || {
               log "ERROR" "Download ISO fallito"
               rm -f "$ISO_FILE"
               return 1
           }
   
           # Download checksum
           log "INFO" "Download checksum da $KALI_SHA256_URL"
           wget -q -O "/tmp/SHA256SUMS" "$KALI_SHA256_URL" || {
               log "ERROR" "Download SHA256SUMS fallito"
               rm -f "$ISO_FILE" "/tmp/SHA256SUMS"
               return 1
           }
   
           # Verifica checksum
           log "INFO" "Verifica integrità ISO..."
           local expected_checksum=$(grep "kali-linux-2024.1-installer-amd64.iso" "/tmp/SHA256SUMS" | cut -d' ' -f1)
           local actual_checksum=$(sha256sum "$ISO_FILE" | cut -d' ' -f1)
           
           if [ "$expected_checksum" != "$actual_checksum" ]; then
               log "ERROR" "Verifica checksum fallita"
               log "ERROR" "Atteso:   $expected_checksum"
               log "ERROR" "Ricevuto: $actual_checksum"
               rm -f "$ISO_FILE" "/tmp/SHA256SUMS"
               return 1
           fi
           
           log "INFO" "Download e verifica completati con successo"
           rm -f "/tmp/SHA256SUMS"
       else
           log "INFO" "ISO già presente in $(dirname "$ISO_FILE")"
           log "INFO" "Per forzare un nuovo download, eliminare il file esistente"
       fi
   }
   
   # Creazione template base Kali
   create_template() {
       log "INFO" "Creazione template Kali Linux..."
   
       # Verifica se il template esiste già
       if qm status $TEMPLATE_ID &>/dev/null; then
           log "ERROR" "Template $TEMPLATE_ID già esistente"
       fi
   
       # Creazione VM template con parametri ottimizzati per Kali
       qm create $TEMPLATE_ID \
           --memory 4096 \
           --cores 2 \
           --name "$TEMPLATE_NAME" \
           --net0 "virtio,bridge=$NETWORK_BRIDGE" \
           --bootdisk scsi0 \
           --scsihw virtio-scsi-pci \
           --scsi0 "local-lvm:50" \
           --ostype "l26" \
           --tablet 1 \
           --machine q35 \
           --agent 1 \
           --cpu host \
           --numa 1
   
       # Preparazione rete template
       prepare_template_network
   
       log "INFO" "Template base creato con successo"
   }
   
   # Configurazione rete per il template
   prepare_template_network() {
       cat > /tmp/netplan-template.yaml << EOL
   network:
     version: 2
     ethernets:
       ens18:
         dhcp4: false
         addresses: [192.168.100.2/24]
         routes:
           - to: default
             via: 192.168.100.1
         nameservers:
           addresses: [8.8.8.8]
   EOL
   }
   
   # Ottimizzazione template con strumenti Kali
   optimize_template() {
       log "INFO" "Ottimizzazione template Kali..."
   
       # Configurazione base template
       qm set $TEMPLATE_ID --delete ide2
       qm set $TEMPLATE_ID --boot c --bootdisk scsi0
       qm set $TEMPLATE_ID --keyboard it
   
       # Script di ottimizzazione per l'OS guest
       cat > /tmp/optimize-kali.sh << 'EOL'
   #!/bin/bash
   # Aggiornamento sistema
   apt update
   apt full-upgrade -y
   
   # Installazione strumenti essenziali
   apt install -y qemu-guest-agent \
       kali-linux-default \
       openssh-server \
       htop \
       iftop \
       tmux
   
   # Configurazione servizi
   systemctl enable qemu-guest-agent
   systemctl enable ssh
   
   # Configurazione sicurezza base
   echo "root:kali" | chpasswd
   sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
   EOL
   
       log "INFO" "Template ottimizzato con strumenti Kali"
   }
   
   # -----------------------------------------------------------------------------
   # Gestione VM
   # -----------------------------------------------------------------------------
   
   # Creazione VM da template
   create_vm() {
       local vm_id="$1"
       local vm_name="$2"
       local memory="${3:-8192}"  # Default 8GB per Kali
   
       # Validazione parametri
       if [ -z "$vm_id" ] || [ -z "$vm_name" ]; then
           log "ERROR" "Specificare VM ID e nome"
       fi
   
       # Verifica range ID valido
       if [ "$vm_id" -lt 101 ] || [ "$vm_id" -gt 199 ]; then
           log "ERROR" "VM ID deve essere tra 101 e 199"
       fi
   
       log "INFO" "Creazione VM Kali $vm_name (ID: $vm_id)..."
   
       # Clonazione e configurazione
       qm clone $TEMPLATE_ID $vm_id --name "$vm_name" --full
       qm set $vm_id --memory "$memory"
       qm set $vm_id --net0 "virtio,bridge=$NETWORK_BRIDGE"
   
       # Configurazione IP basato su ID
       local vm_ip="192.168.100.$vm_id"
       configure_vm_network $vm_id "$vm_ip"
   
       log "INFO" "VM $vm_name creata con IP $vm_ip"
   }
   
   # Configurazione rete VM
   configure_vm_network() {
       local vm_id="$1"
       local vm_ip="$2"
   
       cat > /tmp/netplan-vm.yaml << EOL
   network:
     version: 2
     ethernets:
       ens18:
         dhcp4: false
         addresses: [$vm_ip/24]
         routes:
           - to: default
             via: $NETWORK_GATEWAY
         nameservers:
           addresses: [8.8.8.8]
   EOL
   }
   
   # -----------------------------------------------------------------------------
   # Menu Interattivo
   # -----------------------------------------------------------------------------
   
   show_menu() {
       while true; do
           echo -e "\n=== Configurazione Storage e Template Kali Linux ==="
           echo "1. Verifica Ambiente"
           echo "2. Configura Storage"
           echo "3. Scarica ISO Kali"
           echo "4. Crea Template Kali"
           echo "5. Ottimizza Template"
           echo "6. Crea VM Kali"
           echo "7. Esci"
           
           read -p "Scelta: " choice
           
           case "$choice" in
               1)
                   check_prerequisites
                   check_network
                   check_storage
                   ;;
               2)
                   configure_storage
                   ;;
               3)
                   download_kali
                   ;;
               4)
                   create_template
                   ;;
               5)
                   optimize_template
                   ;;
               6)
                   read -p "VM ID (101-199): " vm_id
                   read -p "VM Nome: " vm_name
                   read -p "RAM (MB) [8192]: " vm_ram
                   create_vm "$vm_id" "$vm_name" "${vm_ram:-8192}"
                   ;;
               7)
                   log "INFO" "Uscita..."
                   exit 0
                   ;;
               *)
                   echo "Scelta non valida"
                   ;;
           esac
       done
   }
   
   # -----------------------------------------------------------------------------
   # Funzione Principale
   # -----------------------------------------------------------------------------
   
   main() {
       log "INFO" "Avvio configurazione Proxmox con Kali Linux..."
       
       # Verifiche iniziali
       check_prerequisites
       check_network
       check_storage
       
       # Avvio menu interattivo
       show_menu
   }
   
   # Avvio script
   main
   ```

   ## Utilizzo dello Script

   1. Salvare lo script come `proxmox-kali-setup.sh`
   2. Rendere lo script eseguibile:

   ```bash
   chmod +x proxmox-kali-setup.sh
   ```

   3. Eseguire come root:

   ```bash
   ./proxmox-kali-setup.sh
   ```

   ## Note Importanti

   1. **Modifiche per Kali Linux:**
      - Aumentata RAM predefinita a 8GB
      - Aumentato spazio disco a 50GB
      - Aggiunti strumenti Kali essenziali
      - Configurato SSH per accesso root

   2. **Rete Isolata:**
      - Tutte le VM sulla rete 192.168.100.0/24
      - Template usa 192.168.100.2
      - VM usano IP basati su ID (101-199)

   3. **Storage:**
      - Struttura ottimizzata per laboratorio
      - Backup configurato
      - Monitoraggio LVM attivo

   4. **Sicurezza:**
      - Password root template: "kali"
      - SSH abilitato per accesso remoto
      - Rete completamente isolata

   ## Prossimi Passi

   - Personalizzazione strumenti Kali
   - Configurazione backup
   - Hardening sicurezza
   - Configurazione VPN per accesso remoto

   ## Troubleshooting

   1. **Problemi Download:**

      ```bash
      # Verifica download manuale
      wget https://cdimage.kali.org/kali-2024.1/kali-linux-2024.1-installer-amd64.iso
      ```

   2. **Problemi Template:**

      ```bash
      # Verifica stato template
      qm status 9000
      ```

   3. **Problemi Rete:**

      ```bash
      # Verifica bridge
      ip a show vmbr1
      ```

   4. **Log Proxmox:**

      ```bash
      # Consulta log
      tail -f /var/log/proxmox-setup.log
      ```

------



### **Parte 4: Configurazione Avanzata della Sicurezza**

#### **Obiettivo**

Questo script automatizza l'hardening del sistema attraverso configurazioni avanzate di sicurezza:

- Rafforzamento dei parametri del kernel Linux per mitigare exploit e attacchi di rete
- Configurazione di OpenSSH per ridurre le superfici d'attacco
- Implementazione di `fail2ban` con regole specifiche per mitigare brute-force
- Creazione di un firewall con `iptables` con persistenza delle regole
- Logging avanzato per auditing e troubleshooting

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

- **Minimizzazione della superficie di attacco**: tutte le configurazioni limitano il numero di entry point vulnerabili.
- **Persistenza e gestione centralizzata**: ogni configurazione viene salvata e può essere facilmente ripristinata.
- **Logging e auditing**: impostazioni avanzate permettono di tracciare attività sospette.

#### **Esercizi Avanzati**

**1. Rafforzare la protezione del kernel**
Modificare lo script per includere:

- Disabilitazione della possibilità di caricare moduli del kernel dopo il boot (`kernel.modules_disabled=1`)
- Restrizione dell'accesso alla memoria (`kernel.yama.ptrace_scope=2`)
- Configurazione dei limiti di file descriptor (`fs.file-max=2097152`)

**2. Implementazione di un sistema di monitoraggio proattivo**
Aggiungere una funzione che utilizza `auditd` per monitorare modifiche ai file critici (`/etc/shadow`, `/etc/passwd`, `/etc/ssh/sshd_config`) e genera un alert in caso di variazioni.

**3. Configurazione avanzata di fail2ban**

- Creare un filtro personalizzato per individuare tentativi di brute-force tramite API su Proxmox.
- Modificare `fail2ban` per attivare notifiche via email quando un IP viene bannato.

**4. Firewall con regole granulari**
Estendere `configure_firewall` per:

- Permettere connessioni HTTPS (porta 443) solo da un set specifico di IP aziendali.
- Limitare il numero massimo di connessioni simultanee sulla porta 22 per prevenire attacchi DDoS.
- Bloccare tentativi di scansione delle porte con `iptables` e `portsentry`.

Questi esercizi richiedono una comprensione approfondita della sicurezza Linux e forniscono un livello di protezione superiore rispetto alla configurazione standard

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


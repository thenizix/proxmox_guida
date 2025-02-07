1. # Guida Proxmox VE

   ### Requisiti di Sistema
   
   Prima di iniziare l'installazione, è necessario verificare che il sistema soddisfi i seguenti requisiti minimi:
   
   - **CPU**: processore 64-bit (Intel EMT64 o AMD64) con supporto per virtualizzazione
     - Intel: tecnologia VT-x
     - AMD: tecnologia AMD-V
   - **RAM**: minimo 8GB per uso base, consigliati 16GB per ambienti di produzione
   - **Storage**:
     - Sistema operativo: minimo 32GB
     - Spazio aggiuntivo per VM/Container: in base alle necessità
   
   ## Capitolo 1: Verifica e Preparazione del Sistema
   
   ### Script di Verifica Prerequisiti
   Prima dell'installazione, è fondamentale eseguire una verifica completa del sistema.
   
   nano verifica.sh           # *incolla qui lo script, poi digita Ctl+o , enter, Ctl+x.*
   chmod +x verifica.sh
   ./verifica.sh**(Testato)**
   
   ```bash
   #!/bin/bash 
   #verifica.sh
   echo "=== Verifica Prerequisiti Proxmox VE ==="
   
   # Verifica del supporto per la virtualizzazione CPU
   if grep -E 'svm|vmx' /proc/cpuinfo > /dev/null; then
       echo "[✓] Supporto virtualizzazione CPU attivo"
       if grep -q 'vmx' /proc/cpuinfo; then
           echo "    Tipo: Intel VT-x"
       elif grep -q 'svm' /proc/cpuinfo; then
           echo "    Tipo: AMD-V"
       fi
       
       # Verifica IOMMU (importante per il passthrough PCI)
       if dmesg | grep -i -e DMAR -e IOMMU > /dev/null; then
           echo "[✓] IOMMU attivo"
       else
           echo "[!] IOMMU non rilevato - necessario per il passthrough PCI"
       fi
   else
       echo "[✗] Virtualizzazione CPU non disponibile"
       echo "    Attivare VT-x/AMD-V nel BIOS"
       exit 1
   fi
   
   # Verifica della memoria disponibile
   mem_total=$(free -g | awk '/^Mem:/{print $2}')
   if [ $mem_total -ge 16 ]; then
       echo "[✓] RAM ottimale: ${mem_total}GB"
   elif [ $mem_total -ge 8 ]; then
       echo "[!] RAM sufficiente ma limitata: ${mem_total}GB"
       echo "    Consigliato upgrade a 16GB+ per ambienti di produzione"
   else
       echo "[✗] RAM insufficiente: ${mem_total}GB"
       echo "    Minimo raccomandato: 8GB"
       exit 1
   fi
   
   # Analisi configurazione dischi
   echo "=== Analisi Configurazione Dischi ==="
   lsblk -d -o NAME,SIZE,MODEL,ROTA | grep -v loop
   echo "Verificare la presenza di almeno due dischi separati:"
   echo "1. Disco Sistema: minimo 32GB"
   echo "2. Disco Storage: dimensionamento in base alle necessità"
   
   # Verifica connettività di rete
   echo "=== Analisi Configurazione Rete ==="
   for iface in $(ls /sys/class/net/ | grep -v lo); do
       speed=$(cat /sys/class/net/$iface/speed 2>/dev/null)
       if [ ! -z "$speed" ]; then
           if [ $speed -ge 1000 ]; then
               echo "[✓] $iface: $speed Mbps"
           else
               echo "[!] $iface: $speed Mbps (consigliato Gigabit)"
           fi
       fi
   done
   ```
   
   ### Preparazione dell'Ambiente di Installazione
   
   Prima di procedere con l'installazione vera e propria, è necessario preparare l'ambiente. Ecco i passaggi fondamentali:
   
   1. **Download dell'ISO**
      - Scaricare l'ultima versione di [Proxmox VE](https://enterprise.proxmox.com/iso/proxmox-ve_8.3-1.iso) dal sito ufficiale
      - Verificare l'integrità del file tramite checksum SHA256
      
        ```
        SHA256SUM
        b5c2d10d6492d2d763e648bc8562d0f77a90c39fac3a664e676e795735198b45
        ```
      
        
      
   2. **Preparazione del Supporto di Installazione**
      Per sistemi Linux:
      
      ```bash
      # Creazione chiavetta USB avviabile
      dd if=proxmox-ve_*.iso of=/dev/sdX bs=1M status=progress
      ```
      Per sistemi Windows:
      - Utilizzare Rufus in modalità DD image
      - Selezionare la modalità di scrittura diretta dell'immagine
      
   3. **Configurazione del BIOS/UEFI**
      - Abilitare le tecnologie di virtualizzazione (VT-x/AMD-V)
      - Attivare IOMMU se si prevede di utilizzare il passthrough PCI
      - **Configurare l'ordine di boot** per avviare da USB
      - Se possibile, abilitare la modalità UEFI
   
   
   
   
   
   Una volta  installato (10 minuti)
   Riavviare senza la chiavetta.
   
   Andare al PC 2 e connettersi all ip del server :8006
   
   
   Da subito, vi accorgerete che non serve scrivere sudo ,
    va aperta una shell e
    magari uno script con shebang, va fatto l update dalla repo enterprise a quella free:
   
   ```bash
   # Rimozione repository enterprise e aggiunta repository free
   if [ -f "/etc/apt/sources.list.d/pve-enterprise.list" ]; then
       rm /etc/apt/sources.list.d/pve-enterprise.list
   fi
   
   if [ -f "/etc/apt/sources.list.d/ceph.list" ]; then
       rm /etc/apt/sources.list.d/ceph.list
   fi
   
   echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
   echo "deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription" > /etc/apt/sources.list.d/ceph.list
   
   # Aggiorna chiavi repository
   wget -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg http://download.proxmox.com/debian/proxmox-release-bookworm.gpg
   
   # Aggiorna repository
   apt-get update
   ```
   
   
**2/2025  Backlog di studio di Daniele Nencini**

Ci sono un sacco di tutorials e video, ma  Proxmox non e' cosi banale, e nulla come sporcarsi le mani.
Mi sono fatto aiutare da Claude per riscrivere le mie note e l'impaginazione e per velocizzare  la scrittura di Bash.
Questa roba e' per mio uso ma la condivido di cuore, magari aiuta.



Proxmox , perche’?

E’ open source per prima cosa,ha una WebUI basata su debian, licenza GNU, supporta cluster fisici, puo migrare vm online e Containers LXC

Proxmox VE `e Software Libero e ha un’ampia Wiki https://pve.proxmox.com/wiki/Main_Page.

ha un forum pubblico molto attivo https://forum.proxmox.com/.

Proxmox VE supporta nativamente solo LXC. Il supporto a Docker/Podman `e dato da Debian. Se volete Kubernetes il suggerimento `e di installarlo dentro ad una o più VM.

Proxmox VE è basato su Debian GNU/Linux Stable con un Kernel Custom sopra al quale hanno aggiunto la Web UI. Nessun supporto per architetture diverse da x86-64. La Web UI  e' basata su ExtJS, non e responsive ed e' atroce su schermi piccoli. Proxmox VE e' un wrapper attorno a KVM.

L’installazione di default non contempla storage condiviso (Ceph, GlusterFS, NFS. . . ). Occorre stare attenti che tutti i nodi di un cluster abbiano il medesimo layer di storage locale (ad es. tutti LVM o tutti BTRFS o tutti ZFS). 

Il filesystem locale di default `e ext4 su LVM



**IPERCONVERGENZA**

- Un’infrastruttura di virtualizzazione si dice iperconvergente quando calcolo (vCPU), rete (SDN) e storage (vSAN) sono ospitati in un unico cluster di macchine tutte uguali (Brutta cosa)
- Pro : Riduzione dei Single Point of Failure. Miglior possibilit`a di bilanciamento del carico. Scalabilit`a orizzontale. Contro Costo. Maggiore complessit`a architetturale. Parte delle risorse vanno ”perse” nel mantenere l’iperconvergenza.

**Iperconvergenza in Proxmox VE Compute: KVM. SDN: VXLAN. Storage: Ceph.**

Ceph Ceph richiede un sacco di risorse, principalmente RAM ma anche CPU. Attivare Ceph su un cluster Proxmox VE significa rinunciare ad una fetta significativa di RAM potenzialmente ottenendo performance peggiori che non da una SAN con iSCSI

**SR-IOV** è una tecnologia che permette di condividere una singola scheda hardware (come una scheda di rete o una scheda grafica) tra più macchine virtuali in modo efficiente. È come avere una torta (la scheda fisica) e poterla dividere in fette (funzioni virtuali) da distribuire a 

![img](https://lh7-rt.googleusercontent.com/docsz/AD_4nXemOT4fYGmymW98iAKGr17KqdLrb5nzYuNr_rOyE2uCp3kjIjC8oMY3QCxjUrtNkyWJzWyabdDNxxEfESeJPoVcTJ4lKxLNbZ5ZQekFuIu9Du0Buxt9kejNCi6YrPiO8-FtvNrZRw?key=YuzoM_JW3_bF4iL2iUTHJKEI)

- Vediamo i componenti principali:
  1. Physical Function (PF) - È la scheda hardware reale con tutte le sue funzionalità complete. Come se fosse il "genitore".
  2. Virtual Functions (VF) - Sono delle "copie leggere" della scheda fisica che possono essere assegnate alle macchine virtuali. Come dei "figli" che ereditano alcune caratteristiche del genitore.
  3. IOMMU - È come un "vigile urbano" che gestisce il traffico di dati tra la scheda fisica e le sue versioni virtuali, assicurandosi che:
     - Ogni macchina virtuale acceda solo alla sua porzione di risorse
- Non ci siano conflitti tra le varie funzioni virtuali
- La comunicazione avvenga in modo sicuro ed efficiente

Un esempio pratico: Immagina di avere una scheda di rete da 40Gbps con SR-IOV. Puoi:

- Lasciare la Physical Function al sistema operativo principale
- Creare 4 Virtual Functions da 10Gbps ciascuna
- Assegnare ogni VF a una macchina virtuale diversa

I vantaggi principali sono:

- Prestazioni migliori rispetto alla virtualizzazione software
- Isolamento più sicuro tra le macchine virtuali
- Utilizzo più efficiente dell'hardware

Nell installer e’ compreso **proxmox backup**

L’integrazione tra Proxmox Virtual Environment (**PVE**) e Veeam Backup & Replication (**VBR**) rappresenta un passo significativo per ottimizzare le politiche di backup e recupero.

Molte informazioni interessanti riguardanti backup e implementazioni varie sul sito di [Gabriele Pellizzari](https://www.gable.it/)

# Capitolo 1: Introduzione a Proxmox VE e Configurazione Iniziale

## Obiettivi del Capitolo
- Comprendere cos'è Proxmox Virtual Environment (VE)
- Eseguire l'installazione base di Proxmox VE
- Familiarizzare con l'interfaccia web di gestione
- Configurare le impostazioni di rete di base

## 1.1 Cos'è Proxmox VE?
Proxmox Virtual Environment (VE) è una piattaforma di virtualizzazione open source che combina due potenti tecnologie di virtualizzazione:
- KVM (Kernel-based Virtual Machine) per macchine virtuali
- LXC (Linux Containers) per la containerizzazione

La piattaforma offre un'interfaccia web centralizzata per gestire tutte le risorse virtualizzate, rendendola ideale per l'apprendimento e la gestione di ambienti virtuali.

## 1.2 Requisiti di Sistema
Per la nostra installazione su disco da 465GB, questi sono i requisiti minimi:
- CPU: 64 bit (Intel EMT64 o AMD64)
- RAM: minimo 4GB (consigliati 8GB o più)
- Disco rigido: 465GB disponibili
- Scheda di rete
- BIOS/UEFI con supporto per virtualizzazione abilitato

## 1.3 Procedura di Installazione Base
1. Scaricare l'ISO di [Proxmox VE dal sito ufficiale](https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso/proxmox-ve-8-3-iso-installer)
2. Creare una chiavetta USB avviabile con l'ISO e RUFUS
3. Avviare il computer (server) dal dispositivo USB (abilitato nel BIOS)
4. Seguire la procedura guidata di installazione di Ubuntu:
   - Selezionare il disco di destinazione (465GB)
   - Configurare l hostname
   - Impostare password root
   - Configurare le impostazioni di rete iniziali

## 1.4 Primo Accesso all'Interfaccia Web
1. Aprire il browser e inserire: https://[IP-DEL-SERVER]:8006
2. Accedere con:
   - Username: root
   - Password: (quella impostata durante l'installazione)
   - Realm: pam

## 1.5 Verifiche Post-Installazione
- [ ] Verificare la connettività di rete
- [ ] Controllare che l'interfaccia web sia accessibile ip locale :8006
- [ ] Verificare che la virtualizzazione sia abilitata nel BIOS
- [ ] Controllare lo spazio disco disponibile

## Esercizi Pratici
1. Accedere all'interfaccia web di Proxmox e spippolare
2. Esplorare le sezioni principali del menu
3. Identificare dove si trovano:
   - Gestione dei nodi
   - Gestione dello storage
   - Gestione della rete
   - Monitor delle risorse

## Prossimi Passi
Nel prossimo capitolo ci concentreremo sulla configurazione di rete avanzata, prerequisito fondamentale per la creazione di un circuito Tor e della VPN.

## Note Importanti
- Conservare le credenziali di accesso in un luogo sicuro
- Annotare l'indirizzo IP del server Proxmox ( configurato statico)
- Fare un backup della configurazione iniziale

# Capitolo 2: Gestione da Terminale e Setup Ambiente Base

## Obiettivi del Capitolo
- Padroneggiare i comandi base da terminale di Proxmox
- Configurare un ambiente di lavoro strutturato
- Preparare l'infrastruttura per il laboratorio di sicurezza
- Creare la prima VM template che useremo come base

## 2.1 Accesso e Gestione Base del Sistema

### Accesso SSH
```bash
# Accesso SSH al server Proxmox
ssh root@<ip-del-server>
# Verifica della versione di Proxmox
pveversion
# Visualizzazione dello stato del sistema
pvesh get /nodes/<nome-nodo>/status
```

### Gestione Repository
```bash
# Visualizzazione repository configurati
cat /etc/apt/sources.list
cat /etc/apt/sources.list.d/pve-enterprise.list
#La versione non a pagamento richiede l'aggiunta di una repo apposita..
# Aggiunta repository community (non-enterprise)
echo "deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list.d/pve-community.list
# Aggiornamento del sistema
apt update
apt full-upgrade
```

## 2.2 Preparazione Storage

### Configurazione Storage Locale
```bash
#successivamente vederemo come usare dischi esterni per ora impariamo le basi
# Creazione directory per ISO e template
mkdir -p /var/lib/vz/template/iso
mkdir -p /var/lib/vz/template/cache
# Verifica spazio disco
df -h
pvesm status
```

### Download ISO Ubuntu Server (base per il nostro template)
```bash
cd /var/lib/vz/template/iso
wget https://old-releases.ubuntu.com/releases/22.04/ubuntu-22.04-live-server-amd64.iso

# Verifica dell'integrità del file
sha256sum ubuntu-22.04-live-server-amd64.iso
```

## 2.3 Configurazione Rete Base

### Verifica Configurazione Attuale
```bash
# Visualizzazione interfacce di rete
ip a
# Visualizzazione bridge virtuali
brctl show
# Configurazione bridge Proxmox
cat /etc/network/interfaces
```

### Creazione Bridge Isolato per Lab

Prima di fare pasticci fare un backup e' sempre igienico
   **cp /etc/network/interfaces /etc/network/interfaces.backup**

 crea un filesetup_lab_network.sh , dai chmod +X ed esegui questo script:

Con questo script:

1. **Controllo preventivo**: verifica che il bridge non esista già
2. **IP Forwarding**: abilitazione del forwarding dei pacchetti
3. **NAT**: configurazione del NAT per permettere la connettività (se necessaria)
4. **Pulizia**: regole post-down per rimuovere le configurazioni quando il bridge viene disattivato

```bash
#!/bin/bash
# Nome: setup_lab_network.sh
# Descrizione: Script per configurare il bridge di rete isolato per il laboratorio

# Funzione per verificare se il comando è stato eseguito con successo
check_error() {
    if [ $? -ne 0 ]; then
        echo "Errore: $1"
        exit 1
    fi
}

# Funzione per pulire le regole NAT esistenti
# Funzione per pulire le regole NAT esistenti
clean_nat_rules() {
    echo "Pulizia regole NAT esistenti..."
    # Trova e rimuovi le regole MASQUERADE esistenti per la rete specificata
    while iptables -t nat -D POSTROUTING -s '192.168.100.0/24' -o vmbr0 -j MASQUERADE 2>/dev/null; do
        echo "Rimossa regola NAT esistente"
    done
}

# Verifica privilegi di root
if [ "$(id -u)" != "0" ]; then
    echo "Questo script deve essere eseguito come root"
    exit 1
fi

echo "=== Inizio configurazione bridge di rete ==="

# 1. Installazione dipendenze
echo "Installing iptables-persistent..."
DEBIAN_FRONTEND=noninteractive apt update
DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent
check_error "Installazione iptables-persistent fallita"

# 2. Creazione directory per le regole
echo "Creazione directory iptables..."
mkdir -p /etc/iptables
check_error "Creazione directory iptables fallita"

# 3. Backup della configurazione di rete esistente
echo "Backup configurazione esistente..."
cp /etc/network/interfaces /etc/network/interfaces.backup
check_error "Backup configurazione fallito"

# 4. Rimozione bridge esistente se presente
echo "Rimozione configurazioni precedenti..."
ip link set vmbr1 down 2>/dev/null
brctl delbr vmbr1 2>/dev/null
# Ignoriamo eventuali errori qui perché il bridge potrebbe non esistere

# 5. Creazione nuovo bridge
echo "Creazione nuovo bridge vmbr1..."
brctl addbr vmbr1
check_error "Creazione bridge fallita"
ip link set vmbr1 up
check_error "Attivazione bridge fallita"
ip addr add 192.168.100.1/24 dev vmbr1
check_error "Configurazione IP bridge fallita"

# 6. Configurazione IP forwarding
echo "Configurazione IP forwarding..."
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
check_error "Configurazione IP forwarding fallita"

# 7. Configurazione NAT
echo "Configurazione regole NAT..."
clean_nat_rules
iptables -t nat -A POSTROUTING -s '192.168.100.0/24' -o vmbr0 -j MASQUERADE
check_error "Configurazione NAT fallita"

# 8. Salvataggio regole iptables
echo "Salvataggio regole iptables..."
iptables-save > /etc/iptables/rules.v4
check_error "Salvataggio regole iptables fallito"

# 9. Aggiunta configurazione interfaces
echo "Aggiunta configurazione a interfaces..."
# Rimuovi configurazione vmbr1 esistente se presente
sed -i '/# Bridge per laboratorio isolato/,/post-down.*vmbr0.*MASQUERADE/d' /etc/network/interfaces

# Aggiungi nuova configurazione
cat >> /etc/network/interfaces << 'EOL'

# Bridge per laboratorio isolato
auto vmbr1
iface vmbr1 inet static
        address 192.168.100.1/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0
        post-up   echo 1 > /proc/sys/net/ipv4/ip_forward
        post-up   iptables -t nat -A POSTROUTING -s '192.168.100.0/24' -o vmbr0 -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s '192.168.100.0/24' -o vmbr0 -j MASQUERADE
EOL
check_error "Aggiunta configurazione interfaces fallita"

# 10. Verifica configurazione
echo "=== Verifica configurazione ==="
echo "Stato bridge:"
ip a show vmbr1
echo -e "\nRegole NAT:"
iptables -t nat -L POSTROUTING -n -v
echo -e "\nStato IP forwarding:"
sysctl net.ipv4.ip_forward

echo "=== Configurazione completata con successo ==="
echo "Il bridge vmbr1 è configurato con IP 192.168.100.1/24"
echo "NAT e forwarding sono attivi"
echo "Le configurazioni sono state salvate e persisteranno dopo il riavvio"
echo "Backup della configurazione precedente salvato in /etc/network/interfaces.backup"
```





Il terminale restituisce tutte le indicazioni necessarie a comprendere il forwarding :

```bash
Aggiunta configurazione a interfaces...
=== Verifica configurazione ===
Stato bridge:
22: vmbr1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether ca:36:96:59:20:49 brd ff:ff:ff:ff:ff:ff
    inet 192.168.100.1/24 scope global vmbr1
       valid_lft forever preferred_lft forever
    inet6 fe80::c836:96ff:fe59:2049/64 scope link tentative 
       valid_lft forever preferred_lft forever

Regole NAT:
Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 MASQUERADE  0    --  *      vmbr0   192.168.100.0/24     0.0.0.0/0           
    0     0 MASQUERADE  0    --  *      vmbr0   192.168.100.0/24     0.0.0.0/0 

Stato IP forwarding:
net.ipv4.ip_forward = 1
=== Configurazione completata con successo ===
Il bridge vmbr1 è configurato con IP 192.168.100.1/24
```



## 2.4 Creazione Template Base

### Creazione VM Iniziale
```bash
# Creazione VM Ubuntu
qm create 9000 --memory 2048 --cores 2 --name ubuntu-template \
--net0 virtio,bridge=vmbr0 --bootdisk scsi0 --scsihw virtio-scsi-pci \
--scsi0 local-lvm:32 --ide2 local:iso/ubuntu-22.04-live-server-amd64.iso \
--boot c --boot order=ide2 \
--ostype l26

# Abilitazione QEMU Guest Agent
qm set 9000 --agent enabled=1
```

### Installazione Sistema Base
1. Avviare la VM dalla GUI di Proxmox
2. Seguire l'installazione di Ubuntu Server dalla Console con queste specifiche:
   - Username: labuser
   - Hostname: template
   - Installazione minima
   - No snap packages
     ![image-20250205120513929](C:\Users\danie\AppData\Roaming\Typora\typora-user-images\image-20250205120513929.png)

mancano pochi passaggi, va disconnesso il disco installer e selezionato il disco SCSI0
Sulla base dei problemi riscontrati, ecco le modifiche necessarie alla sezione di creazione del modello

```
qm stop 9000
# After VM creation, add these steps:
qm set 9000 --delete serial0  # Remove problematic serial console
qm set 9000 --boot c --bootdisk scsi0  # Set correct boot order
qm set 9000 --ide2 none      # Remove ISO after installation
qm set 9000 --vga qxl
qm set 9000 --machine q35
qm set 9000 --tablet 1
qm set 9000 --keyboard en-us

# Network configuration during template prep:
sudo nano /etc/netplan/00-installer-config.yaml
# Add static config:
network:
  ethernets:
    ens18:
      dhcp4: false
      addresses: [192.168.100.2/24]
      routes:
        - to: default
          via: 192.168.100.1
      nameservers:
        addresses: [8.8.8.8]
  version: 2

sudo netplan apply
#Start the VM:
qm start 9000
```

### Preparazione Template

```bash
# Dopo l'installazione, entrare nella VM 9000 e loggarsi con labuser/pass...
#passando dal teminale di proxmox non sara possibile fare copia incolla.
#er ottenerlo  scarica apt install virt-viewer.
#Accedi alla console usando SPICE viewer invece di noVNC per un supporto completo di copia/incolla. salva il file dd e aprico con virt-viewer
# All'interno della VM, eseguire:
sudo apt update
sudo apt upgrade

sudo apt install qemu-guest-agent
# Create a systemd service file
sudo nano /etc/systemd/system/qemu-guest-agent.service

# Add this content:
[Unit]
Description=QEMU Guest Agent
BindsTo=dev-virtio\x2dports-org.qemu.guest_agent.0.device
After=dev-virtio\x2dports-org.qemu.guest_agent.0.device

[Service]
ExecStart=/usr/sbin/qemu-ga
Restart=always

[Install]
WantedBy=multi-user.target

# Then enable and start:
sudo systemctl daemon-reload
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent

# Pulizia sistema
sudo apt autoremove
sudo apt clean
history -c
```

### Conversione in Template
```bash
# Spegnimento VM
qm shutdown 9000

# Conversione in template
qm template 9000
```

## 2.5 Creazione Prima VM di Lavoro

la chiamiamo 101     lab-vm1

```bash
# Clonazione del template
qm clone 9000 101 --name lab-vm1 --full

# Personalizzazione
qm set 101 --memory 4096
qm set 101 --net0 virtio,bridge=vmbr1
# When cloning, increment last IP octet for each new VM
# Example: VM 101 uses 192.168.100.101, VM 102 uses 192.168.100.102, etc.
```

## Esercizi Pratici
1. Creare un secondo bridge (vmbr2) con subnet 192.168.200.0/24
2. Clonare il template in una seconda VM (101) e collegarla al nuovo bridge
3. Verificare la connettività tra le VM
4. Creare uno script bash che automatizzi la creazione di nuove VM dal template

## Note per i Prossimi Capitoli
- Il template creato servirà come base per le VM del circuito Tor
- I bridge isolati verranno utilizzati per separare il traffico di rete
- Le VM create saranno la base per il laboratorio di pentesting

## Troubleshooting Comune
- Se la VM non si avvia: verificare i permessi del file ISO

- Se la rete non funziona: controllare la configurazione dei bridge

- Se il template non si converte: verificare che la VM sia spenta

  

  ## 2.6 APPENDICE

  ## Template di Default in Proxmox

  Proxmox contiene di default dei Templates utilizzabili, che per ora vediamo e basta

  ### Container Templates (LXC)
  ```bash
  # Visualizzazione dei template LXC disponibili
  pveam update
  pveam available
  # Lista dei template scaricati
  pveam list local
  # Esempio di download template Alpine
  pveam download local alpine-3.18-default_20230830_amd64.tar.xz
  ```

  Proxmox offre diversi template LXC preconfigurati:

  1. **Alpine Linux**
     - Dimensioni ridotte (~5MB)
     - Ideale per: microservizi, container leggeri
     - Uso comune: servizi di rete, firewall, proxy

  2. **Ubuntu**
     - Template completo e supportato
     - Ideale per: servizi generici, sviluppo
     - Versioni LTS disponibili

  3. **Debian**
     - Base stabile e leggera
     - Ideale per: server di produzione
     - Compatibilità ottimale con Proxmox

  4. **CentOS/Rocky Linux**
     - Alternative enterprise-grade
     - Ideale per: ambienti enterprise
     - Compatibilità con software enterprise

  ### Vantaggi dei Container Template
  - Avvio rapido
  - Consumo risorse ridotto
  - Gestione semplificata
  - Ideali per servizi isolati

  ### Quando NON Usare i Template di Default
  1. **Scenari di Test di Sicurezza**
     - I container condividono il kernel con l'host
     - Limitazioni nei test di penetrazione
     - Impossibilità di modificare parametri kernel

  2. **Virtualizzazione Completa**
     - Necessità di kernel personalizzati
     - Test di driver o moduli kernel
     - Simulazione hardware specifica

  3. **Isolamento Totale**
     - Sicurezza a livello hardware
     - Separazione completa delle risorse
     - Test di vulnerabilità kernel

  ### Utilizzo Pratico dei Template
  ```bash
  # Creazione container da template
  pct create 200 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname ubuntu-ct \
  --memory 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp
  
  # Lista dei container
  pct list
  
  # Start/Stop container
  pct start 200
  pct stop 200
  
  # Accesso al container
  pct enter 200
  ```

  
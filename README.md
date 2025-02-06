# Configurazione del Server Proxmox VE 8.8.3

**by TheNizix  02/2025** 

> [!TIP]
>
>  Lo script dal Capitolo 1 è pensato per automatizzare il partizionamento del disco dopo l'installazione base di Proxmox, ma prima dobbiamo effettivamente installare Proxmox sul server. i:
>
> 1. Prima di tutto, devi scaricare l'ISO di Proxmox VE dal sito ufficiale (https://www.proxmox.com/downloads)
> 2. Crea una chiavetta USB avviabile con l'ISO di Proxmox usando
>    - Rufus (su Windows)
>    - balenaEtcher (su qualsiasi sistema operativo)
>    - dd (su Linux/Mac)
> 3. Avvia il server dalla chiavetta USB e segui la procedura di installazione grafica di Proxmox, 

Solo DOPO aver completato questa installazione base di Proxmox potrai avviare queste automazioni dalla CLI di Proxmox



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

---------------------------------------------------------------------------------------------------------------------------

La Creazione di questa guida e' un backlog di 2 giorni di lavoro per padroneggiare il sistema.
Incolonnato malamente, stralciato e corretto con  un Ai.

Ho incluso degli esercizi semplici con soluzione.
Nella Repo ci sono alcuni scripts in bash AutoEsplicativi che eseguono piccole funzioni base.
Questo prima che preso da un assalto di automazionite abbia deciso di andare oltre..
...
Troverete degli errori, e qualcosa sara' da installare, ma dopo smanettamenti minimi a me funziona tutto :)

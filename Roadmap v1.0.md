# Roadmap Modulare - Lab Security & Crypto

## Fase 0: Preparazione Base

### 0.1 Setup Iniziale

- [x] Installazione Proxmox pulita
- [x] Test funzionalità base CPU/RAM
- [x] Verifica supporto virtualizzazione
- [x] Setup bridge principale (vmbr0)

### 0.2 Storage Learning Path

1. Storage Locale
   - [x] Analisi partizioni disponibili
   - [x] Test performance disco locale
   - [x] Creazione storage locale base

2. Storage Esterno (4TB)
   - [ ] Studio opzioni montaggio (ext4, ZFS, etc)
   - [ ] Test varie configurazioni mount
   - [ ] Valutazione impatto performance
   - [ ] Decisione: mount point ottimale

## Fase 1: Single Node Security Lab

### 1.1 Kali Base Setup

1. Network Isolation
   - [ ] Creazione bridge dedicato (vmbr1)
   - [ ] Test isolamento
   - [ ] Documentazione configurazione

2. VM Base
   - [ ] Deploy Kali minimal (4GB RAM, 4 threads)
   - [ ] Test tools essenziali
   - [ ] Snapshot base pulito
   - [ ] Decisione: storage locale vs esterno

3. Target VM
   - [ ] Deploy Metasploitable
   - [ ] Network isolation test
   - [ ] Penetration test base
   - [ ] Decisione: storage location

### 1.2 Punti Decisionali

- Storage allocation strategy
- Network isolation level
- Resource allocation
- Backup strategy

## Fase 2: Tor Infrastructure

### 2.1 Base Circuit

1. Network Setup
   - [ ] Bridge dedicato (vmbr2)
   - [ ] Pianificazione subnet
   - [ ] Test isolamento

2. Nodi Base
   - [ ] Entry node (1.5GB RAM)
   - [ ] Middle node (1GB RAM)
   - [ ] Exit node (1.5GB RAM)
   - [ ] Decisione: storage requirements

3. Testing
   - [ ] Circuit validation
   - [ ] Performance testing
   - [ ] Security verification

### 2.2 Integration Points (Opzionali)

- Connessione con Kali lab
- Bridge per altri servizi
- Logging setup

## Fase 3: Crypto Infrastructure

### 3.1 Storage Planning

1. Analisi Requisiti
   - [ ] Calcolo spazio blockchain
   - [ ] Performance requirements
   - [ ] Backup strategy

2. Disk Setup
   - [ ] Mount disco esterno
   - [ ] Test performance
   - [ ] Setup backup

### 3.2 Node Deployment

1. UmbrelOS
   - [ ] Network isolation (vmbr3)
   - [ ] VM setup (4GB RAM)
   - [ ] Blockchain sync test
   - [ ] Storage monitoring

2. Monero Setup
   - [ ] VM deployment
   - [ ] Storage allocation
   - [ ] Performance testing

### 3.3 Decision Points

- Storage allocation
- Network connectivity
- Resource scaling
- Backup frequency

## Fase 4: Monitoring Infrastructure

### 4.1 Base Setup

1. Network Configuration
   - [ ] Bridge dedicato (vmbr4)
   - [ ] Subnet planning
   - [ ] Access rules

2. Security Onion Light
   - [ ] VM deployment
   - [ ] Basic configuration
   - [ ] Storage allocation
   - [ ] Test monitoring

### 4.2 Integration Decisions

- Servizi da monitorare
- Storage per logs
- Alert configuration
- Retention policy

## Note Importanti

1. **Storage Decisions**
   - Ogni fase include decisioni sullo storage
   - Test performance prima dell'allocazione
   - Possibilità di riallocazione

2. **Network Isolation**
   - Bridges separati per ogni modulo
   - Interconnessione opzionale
   - Documentazione routing

3. **Resource Management**
   - Allocazione dinamica possibile
   - Test prima del commit
   - Monitoraggio impatto

4. **Learning Points**
   - Storage management
   - Network isolation
   - Performance tuning
   - Security hardening
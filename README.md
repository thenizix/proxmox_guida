# Configurazione del Server Proxmox VE 8.8.3

**by TheNizix  06/02/2025** 

Updated 09.00  7/2/25



# **UNA DURA LEZIONE**



###### Ho dovuto riinstallare proxmox, e **spero di non aver causato danni  a nessuno**  

Un errore nelle ip-tables, la cancellazione di una chiave criptata, un errore di scrittura dell ip...
E sono rimasto fuori dal network.
Avavo uno scriptino bellino che funzionava, ma dopo averlo dato in pasto a claude e' diventato un mostro.... troppa roba tutta insieme, ripartmeno foga. 
**Tutto il codice fuori dalla cartella trash, funziona.**.. lo giuro!
*Questo e' un backlog di alcuni giorni di lavoro per padroneggiare il sistema.*
*Inizialmente essenziale e funzionante, .. ma FALLITO complicato e pasticciato con l'apporto di un AI. 
Ripartendo da zero ho riscritto e debuggato il codice e  fa quello che dice.
*Ogni passaggio e' funzionante e numerato.*

----------------------------------------------------------------------------------------------



### Accesso Interfaccia Web

- URL: https://192.168.1.33:8006
- Credenziali predefinite:
  - Nome utente: root
  - Password: [impostata durante l'installazione]
- Browser supportati: Versioni recenti di Chrome, Firefox, Safari

### Accesso SSH

- Comando: `ssh root@192.168.1.33`
- Autenticazione: Richiesta chiave SSH (autenticazione password disabilitata)
- Porta: 22 (con protezione rate limiting)

## Utilizzo del Sistema

### Creazione Nuove Macchine Virtuali

1. Accedere all'interfaccia web
2. Selezionare 'Crea VM' o clonare un template  
3. Regolare le risorse secondo necessità
4. Scegliere il bridge di rete
5. Avviare la VM e accedere alla console tramite interfaccia web

### Risorse di Supporto

- Documentazione ufficiale: https://pve.proxmox.com/wiki/
- Forum comunità: https://forum.proxmox.com/
- Documentazione locale: Disponibile tramite sistema di aiuto dell'interfaccia web

---------------------------------------------------------------------------------------------------------------------------


 

 

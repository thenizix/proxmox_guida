#!/bin/bash

# Backup della configurazione SSH
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Crea la directory sshd_config.d e imposta le relative permissioni
mkdir -p /etc/ssh/sshd_config.d
chown root:root /etc/ssh/sshd_config.d
chmod 755 /etc/ssh/sshd_config.d

# Crea il file di configurazione per l'hardening
cat > /etc/ssh/sshd_config.d/hardening.conf << 'EOL'
PermitRootLogin prohibit-password
PasswordAuthentication no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOL

chown root:root /etc/ssh/sshd_config.d/hardening.conf
chmod 644 /etc/ssh/sshd_config.d/hardening.conf

# Crea l'utente di test
TEST_USER="testuser_ssh"
useradd -m -s /bin/bash "$TEST_USER"
# Imposta la password per l'utente di test
passwd "$TEST_USER"

# Riavvia il servizio SSH
systemctl restart sshd

# Test della connessione SSH con l'utente di test (da un terminale/macchina DIVERSA)
echo "Test della connessione SSH con l'utente '$TEST_USER' da un terminale/macchina DIVERSA..."

# ***IMPORTANTE: Sostituisci questa riga con il tuo comando di test SSH***
# Esempio (con password, SOLO per test iniziale):
# ssh "$TEST_USER"@tuo_indirizzo_ip
# Esempio (con chiave - RACCOMANDATO):
# ssh -i /percorso/alla/chiave_privata_utente_test "$TEST_USER"@tuo_indirizzo_ip

# ***Devi eseguire il test manualmente in un terminale separato***
read -p "Il test di login SSH con l'utente '$TEST_USER' è andato a buon fine? (si/no): " TEST_RESULT

if [[ "$TEST_RESULT" == "si" ]]; then
  echo "Test SSH riuscito. Procedo con la pulizia."

  # Rimuovi l'utente di test
  userdel -r "$TEST_USER"

  echo "Hardening SSH completato."
else
  echo "Test SSH FALLITO. Investiga e risolvi il problema. Ripristino della configurazione SSH originale."

  # Ripristina la configurazione SSH dal backup
  cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
  systemctl restart sshd
  exit 1  # Esce con codice di errore
fi

# Avviso finale
echo "Ricorda di configurare il tuo firewall!"
# Backup della configurazione originale
cp /etc/apt/sources.list /etc/apt/sources.list.backup
cp /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.backup

# Configurazione repository no-subscription
echo "deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > \
    /etc/apt/sources.list.d/pve-community.list

# Disabilitazione repository enterprise
sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/pve-enterprise.list

# Aggiornamento del sistema
apt update && apt full-upgrade -y
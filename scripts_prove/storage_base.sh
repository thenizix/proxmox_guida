# Creazione directory per ISO e template
mkdir -p /var/lib/vz/template/iso
mkdir -p /var/lib/vz/template/cache
chmod 755 /var/lib/vz/template/iso

# Configurazione storage in Proxmox
pvesm add dir iso --path /var/lib/vz/template/iso --content iso
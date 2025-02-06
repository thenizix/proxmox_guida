# Configurazione firewall Proxmox
cat > /etc/pve/firewall/cluster.fw << 'EOL'
[OPTIONS]
enable: 1
log_level_in: info
log_level_out: info
protection_synflood: 1
protection_boguscheck: 1

[RULES]
# Accesso WebUI
IN ACCEPT -p tcp -dport 8006
# SSH (solo da rete locale)
IN ACCEPT -p tcp -dport 22 -source 192.168.1.0/24
# ICMP (ping)
IN ACCEPT -p icmp
# Blocco tutto il resto
IN DROP
OUT ACCEPT
EOL
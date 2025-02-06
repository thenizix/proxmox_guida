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
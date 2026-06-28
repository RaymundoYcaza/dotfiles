#!/bin/bash
# network-setup.sh — Configura IP estática con systemd-networkd
# =============================================================
# 
# Este script aplica una IP estática al servidor para que funcione
# con IP fija en la red local. Usa systemd-networkd como gestor.
#
# La IP se lee de la variable STATIC_IP (configurable) y se inyecta
# en el template packages/network/20-ethernet.network.
#
# Uso:
#   ./network-setup.sh                          # Usa STATIC_IP por defecto
#   STATIC_IP=192.168.100.99 ./network-setup.sh  # IP personalizada
#   ./network-setup.sh --status                   # Mostrar IP actual
#   ./network-setup.sh --dhcp                     # Volver a DHCP temporal
#
# Dependencias: sudo, systemd-networkd, sed

set -euo pipefail

# ─── Configuración ───────────────────────────────────────────────────────────

# IP estática por defecto. Cambiar aquí si se necesita otra.
STATIC_IP="${STATIC_IP:-192.168.100.81}"

DOTFILES_DIR="${HOME}/.dotfiles"
TEMPLATE="${DOTFILES_DIR}/packages/network/20-ethernet.network"
TARGET="/etc/systemd/network/20-ethernet.network"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Funciones ───────────────────────────────────────────────────────────────

check_prerequisites() {
    if [ ! -f "${TEMPLATE}" ]; then
        log_error "No se encuentra el template: ${TEMPLATE}"
        log_info "Ejecutá esto primero:"
        log_info "  cd ~/.dotfiles && git pull"
        exit 1
    fi

    if ! systemctl is-active systemd-networkd &>/dev/null; then
        log_error "systemd-networkd no está activo."
        log_info "Este sistema usa systemd-networkd. Verificá el gestor de red."
        exit 1
    fi
}

show_status() {
    echo ""
    echo "=== Estado actual de red ==="
    echo ""
    echo "Interfaz activa:"
    ip -br addr show | grep UP | grep -v lo
    echo ""
    echo "IP actual:"
    ip addr show | grep 'inet ' | grep -v 127.0.0.1
    echo ""
    echo "Gateway:"
    ip route show default
    echo ""
    echo "DNS:"
    resolvectl status 2>/dev/null | grep -E 'DNS Server|Current DNS' | head -3
    echo ""
    echo "Archivo de config actual:"
    if [ -f "${TARGET}" ]; then
        grep -E 'Address=|Gateway=|DNS=' "${TARGET}"
    else
        echo "  ${TARGET} — NO EXISTE"
    fi
}

apply_static_ip() {
    log_info "Aplicando IP estática: ${STATIC_IP}..."
    
    # Copiar template y reemplazar placeholder
    sudo cp "${TEMPLATE}" "${TARGET}"
    sudo sed -i "s/__STATIC_IP__/${STATIC_IP}/g" "${TARGET}"
    
    log_ok "Config escrito en ${TARGET}"
    
    # Verificar que el reemplazo funcionó
    if grep -q "__STATIC_IP__" "${TARGET}"; then
        log_error "El placeholder no se reemplazó. Revisá el template."
        exit 1
    fi
    
    log_info "Reiniciando systemd-networkd..."
    sudo systemctl restart systemd-networkd
    
    # Esperar a que la red se estabilice
    sleep 2
    
    log_ok "Red reiniciada."
    
    # Mostrar IP actual
    echo ""
    echo "IP asignada:"
    ip addr show | grep 'inet ' | grep -v 127.0.0.1
    echo ""
    
    # Verificar conectividad
    if ping -c 1 -W 2 192.168.100.1 &>/dev/null; then
        log_ok "✅ Gateway reachable — red funcionando"
    else
        log_warn "⚠️  Gateway no responde ping. Verificá la configuración."
    fi
}

switch_to_dhcp() {
    log_warn "Cambiando a DHCP temporal..."
    
    cat | sudo tee "${TARGET}" > /dev/null << 'DHCPEOF'
[Match]
Name=en*
Name=eth*

[Link]
RequiredForOnline=routable

[Network]
DHCP=yes
MulticastDNS=yes

[DHCPv4]
RouteMetric=100

[IPv6AcceptRA]
RouteMetric=100
DHCPEOF
    
    sudo systemctl restart systemd-networkd
    sleep 2
    log_ok "Cambiado a DHCP. IP actual:"
    ip addr show | grep 'inet ' | grep -v 127.0.0.1
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
        --status|-s)
            show_status
            exit 0
            ;;
        --dhcp)
            switch_to_dhcp
            exit 0
            ;;
        --help|-h)
            echo "Uso: $0 [--status|--dhcp|--help]"
            echo ""
            echo "  (sin args)   Aplicar IP estática (STATIC_IP=${STATIC_IP})"
            echo "  --status     Mostrar estado actual de red"
            echo "  --dhcp       Volver a DHCP temporalmente"
            echo "  --help       Esta ayuda"
            echo ""
            echo "Variable de entorno:"
            echo "  STATIC_IP    IP a asignar (defecto: ${STATIC_IP})"
            exit 0
            ;;
    esac
    
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   🌐 Configuración de Red Estática            ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    check_prerequisites
    show_status
    echo ""
    echo "Se aplicará: IP=${STATIC_IP} Gateway=192.168.100.1 DNS=9.9.9.9"
    echo ""
    apply_static_ip
    
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   ✅ Red configurada: ${STATIC_IP}          ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    echo "   Para cambiar la IP en el futuro:"
    echo "   STATIC_IP=192.168.100.X ~/.dotfiles/scripts/network-setup.sh"
    echo ""
}

main "$@"

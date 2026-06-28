#!/bin/bash
# samba-setup.sh — Configura Samba para compartir disco externo con Windows
# ==========================================================================
# 
# Instala y configura Samba para compartir /mnt/disc-a00 en la red local.
# Las PCs Windows se conectan con:
#   Ruta: \\192.168.100.81\disc-a00
#   Usuario: inorizonti
#
# Uso:
#   sudo ./samba-setup.sh                         # Setup completo
#   ./samba-setup.sh --status                      # Mostrar estado de Samba
#   sudo ./samba-setup.sh --password               # Cambiar password de inorizonti
#   sudo ./samba-setup.sh --restart                # Reiniciar servicio Samba
#
# Dependencias: sudo, systemd

set -euo pipefail

# ─── Configuración ───────────────────────────────────────────────────────────

SMB_USER="inorizonti"
# SMB_PASS se obtiene de variable de entorno SAMBA_PASSWORD
# Si no está definida, el script pedirá el password interactivamente

declare -a REQUIRED_PACKAGES=("samba")

# Detectar home del usuario real incluso bajo sudo
if [ -n "${SUDO_USER:-}" ]; then
    REAL_USER="${SUDO_USER}"
    REAL_HOME=$(getent passwd "${REAL_USER}" | cut -d: -f6)
else
    REAL_USER="${USER}"
    REAL_HOME="${HOME}"
fi

DOTFILES_DIR="${REAL_HOME}/.dotfiles"
TEMPLATE="${DOTFILES_DIR}/packages/samba/smb.conf"
TARGET="/etc/samba/smb.conf"

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

check_sudo() {
    if [ -z "${SUDO_USER:-}" ]; then
        log_error "Este comando requiere sudo:"
        log_info "  sudo $0"
        exit 1
    fi
}

install_packages() {
    log_info "Instalando paquetes necesarios..."
    pacman -S --needed --noconfirm "${REQUIRED_PACKAGES[@]}" 2>&1 || {
        log_error "Error al instalar paquetes."
        exit 1
    }
    log_ok "Paquetes instalados."
}

create_user() {
    # Crear usuario del sistema si no existe
    if id "${SMB_USER}" &>/dev/null; then
        log_info "Usuario del sistema ${SMB_USER} ya existe."
    else
        log_info "Creando usuario del sistema: ${SMB_USER}..."
        useradd -M -s /usr/sbin/nologin -G "${REAL_USER}" "${SMB_USER}"
        log_ok "Usuario del sistema creado: ${SMB_USER}"
    fi

    # Configurar password Samba
    log_info "Configurando password Samba para ${SMB_USER}..."
    if [ -z "${SAMBA_PASSWORD:-}" ]; then
        log_warn "SAMBA_PASSWORD no definida. Configurá manualmente despues:"
        log_info "  sudo smbpasswd ${SMB_USER}"
    else
        echo -e "${SAMBA_PASSWORD}
${SAMBA_PASSWORD}" | smbpasswd -a -s "${SMB_USER}" 2>/dev/null || echo -e "${SAMBA_PASSWORD}
${SAMBA_PASSWORD}" | smbpasswd -s "${SMB_USER}" 2>/dev/null || true
        log_ok "Password Samba configurado para ${SMB_USER}."
    fi
    log_ok "Password Samba configurado para ${SMB_USER}."
}

apply_config() {
    if [ ! -f "${TEMPLATE}" ]; then
        log_error "No se encuentra el template: ${TEMPLATE}"
        log_info "Ejecutá: cd ~/.dotfiles && git pull"
        exit 1
    fi

    log_info "Copiando configuración Samba..."
    mkdir -p /etc/samba
    
    # Backup si existe
    if [ -f "${TARGET}" ]; then
        cp "${TARGET}" "${TARGET}.bak.$(date +%Y%m%d_%H%M%S)"
        log_info "Backup de smb.conf anterior guardado."
    fi

    cp "${TEMPLATE}" "${TARGET}"
    log_ok "Configuración copiada a ${TARGET}"

    # Validar configuración
    if testparm -s "${TARGET}" &>/dev/null; then
        log_ok "Configuración validada con testparm."
    else
        log_error "La configuración tiene errores. Revisá el template."
        exit 1
    fi
}

enable_service() {
    log_info "Habilitando e iniciando servicio Samba..."
    systemctl enable smb.service
    systemctl start smb.service || systemctl restart smb.service
    
    # Abrir puertos en firewall (si existe)
    if command -v firewall-cmd &>/dev/null; then
        firewall-cmd --add-service=samba --permanent 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
    fi
    
    log_ok "Servicio Samba iniciado."
}

show_status() {
    echo ""
    echo "=== Estado de Samba ==="
    echo ""
    
    if command -v smbd &>/dev/null; then
        echo "Paquete: samba instalado"
    else
        echo "Paquete: samba NO instalado"
    fi
    
    echo "Servicio:"
    systemctl is-active smb.service 2>/dev/null || echo "  inactivo"
    
    echo ""
    echo "Usuarios Samba:"
    pdbedit -L 2>/dev/null | awk '{print "  " $1}' || echo "  (ninguno)"
    
    echo ""
    echo "Puertos escuchando:"
    ss -tlnp 2>/dev/null | grep -E '445|139' || echo "  (ninguno)"
    
    echo ""
    echo "Shares configurados:"
    if [ -f /etc/samba/smb.conf ]; then
        grep -E '^\[|path =' /etc/samba/smb.conf | paste - - | sed 's/\t/ /g'
    else
        echo "  (sin config)"
    fi
}

change_password() {
    check_sudo
    log_info "Cambiando password Samba para ${SMB_USER}..."
    smbpasswd "${SMB_USER}"
    log_ok "Password actualizado."
}

restart_service() {
    check_sudo
    log_info "Reiniciando Samba..."
    systemctl restart smb.service
    log_ok "Samba reiniciado."
    show_status
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
        --status|-s)
            show_status
            exit 0
            ;;
        --password|-p)
            change_password
            exit 0
            ;;
        --restart|-r)
            restart_service
            exit 0
            ;;
        --help|-h)
            echo "Uso: $0 [--status|--password|--restart|--help]"
            echo ""
            echo "  sudo $0              Setup completo de Samba"
            echo "  $0 --status           Mostrar estado de Samba"
            echo "  sudo $0 --password    Cambiar password de ${SMB_USER}"
            echo "  sudo $0 --restart     Reiniciar servicio Samba"
            echo "  $0 --help             Esta ayuda"
            exit 0
            ;;
    esac

    check_sudo

    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   🗂️  Configuración Samba                     ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    echo "   Share: \\\\192.168.100.81\disc-a00"
    echo "   Usuario: ${SMB_USER}"
    echo ""

    install_packages
    create_user
    apply_config
    enable_service

    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   ✅ Samba configurado                        ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    echo "   Conectate desde Windows:"
    echo "   Explorador de archivos → \\\\192.168.100.81\disc-a00"
    echo "   Usuario: ${SMB_USER}"
    echo "   Password: (el configurado)"
    echo ""
    echo "   Para cambiar el password:"
    echo "   sudo $0 --password"
    echo ""
}

main "$@"

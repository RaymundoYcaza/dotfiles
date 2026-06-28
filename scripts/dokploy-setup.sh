#!/bin/bash
# dokploy-setup.sh — Instalación y configuración de Dokploy
# ========================================================
# 
# Dokploy es una PaaS auto-gestionada que usa Docker Swarm + Traefik.
# Panel web en puerto 3000 (deshabilitable post-configuración).
# Tráfico HTTP/HTTPS en puertos 80/443 vía Traefik.
#
# Volúmenes Docker apuntan a /mnt/disc-a00/Z01-DEVOPS/state/
#
# Uso:
#   sudo ./dokploy-setup.sh                     # Instalación completa
#   ./dokploy-setup.sh --status                  # Estado de Dokploy
#   sudo ./dokploy-setup.sh --post-install       # Pasos post-instalación
#
# Dependencias: sudo, docker, curl

set -euo pipefail

# ─── Configuración ───────────────────────────────────────────────────────────

DOKPLOY_DATA="/mnt/disc-a00/Z01-DEVOPS/state/dokploy"
DOKPLOY_INSTALL_URL="https://dokploy.com/install.sh"

# Detectar home del usuario real incluso bajo sudo
if [ -n "${SUDO_USER:-}" ]; then
    REAL_USER="${SUDO_USER}"
    REAL_HOME=$(getent passwd "${REAL_USER}" | cut -d: -f6)
else
    REAL_USER="${USER}"
    REAL_HOME="${HOME}"
fi

DOTFILES_DIR="${REAL_HOME}/.dotfiles"

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

check_prerequisites() {
    log_info "Verificando prerequisitos..."

    if ! command -v docker &>/dev/null; then
        log_error "Docker no está instalado."
        log_info "El instalador de Dokploy puede instalarlo automáticamente."
        exit 1
    fi

    # Verificar puertos
    for port in 80 443 3000; do
        if ss -tlnp | grep -q ":${port} "; then
            log_error "Puerto ${port} está ocupado. Dokploy lo necesita."
            exit 1
        fi
    done

    log_ok "Prerequisitos OK."
}

install_dokploy() {
    log_info "Descargando e instalando Dokploy..."
    log_info "Esto puede tomar varios minutos."
    log_info ""
    log_info "IMPORTANTE: El instalador es interactivo."
    log_info "Cuando pregunte, configurás:"
    log_info "  - Email: (el que uses para SSL de Traefik)"
    log_info "  - Dominio: (opcional, podés configurar después)"
    log_info ""

    curl -sSL "${DOKPLOY_INSTALL_URL}" | sh

    log_ok "Dokploy instalado."
}

post_install() {
    log_info "=== Post-instalación de Dokploy ==="
    echo ""
    echo "  1. Accedé al panel en: http://192.168.100.81:3000"
    echo ""
    echo "  2. Crear cuenta de administrador"
    echo ""
    echo "  3. Configurar backup S3 en: Web Server → Backups"
    echo ""
    echo "  4. Opcional: Deshabilitar puerto 3000 público:"
    echo "     docker service update --publish-rm "published=3000,target=3000,mode=host" dokploy"
    echo ""
    echo "  5. Volúmenes Docker persistentes:"
    echo "     Se almacenan en /mnt/disc-a00/Z01-DEVOPS/state/"
    echo "     Respaldados por backup.sh --full"
    echo ""
}

show_status() {
    echo ""
    echo "=== Estado de Dokploy ==="
    echo ""

    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        echo "Docker Swarm: activo ✅"
    else
        echo "Docker Swarm: inactivo ❌"
    fi

    echo ""
    echo "Servicios:"
    docker service ls 2>/dev/null | grep dokploy || echo "  No hay servicios dokploy"

    echo ""
    echo "Contenedores:"
    docker ps 2>/dev/null | grep dokploy || echo "  No hay contenedores dokploy"

    echo ""
    echo "Puertos:"
    ss -tlnp 2>/dev/null | grep -E ':80 |:443 |:3000 ' || echo "  Puertos 80/443/3000 libres"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
        --status|-s)
            show_status
            exit 0
            ;;
        --post-install|-p)
            post_install
            exit 0
            ;;
        --help|-h)
            echo "Uso: $0 [--status|--post-install|--help]"
            echo ""
            echo "  sudo $0               Instalación completa de Dokploy"
            echo "  $0 --status            Estado de Dokploy"
            echo "  sudo $0 --post-install Mostrar pasos post-instalación"
            echo "  $0 --help              Esta ayuda"
            exit 0
            ;;
    esac

    check_sudo

    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   🐳 Dokploy Installation                    ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""

    check_prerequisites
    install_dokploy
    post_install

    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   ✅ Dokploy instalado                       ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    echo "   Panel: http://192.168.100.81:3000"
    echo ""
    echo "   No olvides ejecutar los pasos post-instalación"
    echo "   visible en el panel web."
    echo ""
}

main "$@"

#!/bin/bash
# restore.sh — Restauración completa del sistema Omarchy
#
# Uso:
#   ./restore.sh                    # Restauración interactiva
#   ./restore.sh --auto             # Restauración automática (sin preguntas)
#   ./restore.sh --dry-run          # Solo mostrar qué se haría
#
# Este script asume:
#   1. Omarchy (o Arch Linux) recién instalado
#   2. Git y Stow instalados (sudo pacman -S git stow)
#   3. El repo clonado en ~/.dotfiles
#   4. El disco externo montado en /mnt/disc-a00/

set -euo pipefail

# ─── Configuración ───────────────────────────────────────────────────────────

DOTFILES_DIR="${HOME}/.dotfiles"
BACKUP_BASE="/mnt/disc-a00/Z01_BACKUPS/omarchy-backups"
DOTFILES_REPO="git@github.com:RaymundoYcaza/dotfiles.git"

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

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    if [ "${AUTO_MODE}" = "true" ]; then
        return 0
    fi
    read -r -p "${prompt} [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# ─── Funciones ───────────────────────────────────────────────────────────────

check_prerequisites() {
    log_info "Verificando prerrequisitos..."

    local missing=0
    for cmd in git stow pacman; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Falta: $cmd"
            missing=1
        fi
    done

    if [ "$missing" -eq 1 ]; then
        log_error "Instalá los prerequisitos: sudo pacman -S git stow"
        exit 1
    fi

    if [ ! -d "${DOTFILES_DIR}" ]; then
        if confirm "No existe ~/.dotfiles. ¿Clonar de GitHub?"; then
            git clone "${DOTFILES_REPO}" "${DOTFILES_DIR}" || {
                log_error "No se pudo clonar el repositorio."
                log_info "Usá: git clone ${DOTFILES_REPO} ~/.dotfiles"
                exit 1
            }
        else
            log_info "Usá: git clone ${DOTFILES_REPO} ~/.dotfiles"
            exit 1
        fi
    fi

    log_ok "Prerrequisitos OK."
}

restore_packages() {
    log_info "=== Restaurando paquetes ==="

    if [ ! -f "${DOTFILES_DIR}/packages/pacman-official.txt" ]; then
        log_warn "No se encontró packages/pacman-official.txt. Omitiendo..."
        return
    fi

    local count=$(wc -l < "${DOTFILES_DIR}/packages/pacman-official.txt")

    if confirm "¿Instalar ${count} paquetes oficiales de Pacman?"; then
        log_info "Instalando paquetes oficiales..."
        sudo pacman -S --needed --noconfirm - < "${DOTFILES_DIR}/packages/pacman-official.txt" || \
            log_warn "Algunos paquetes oficiales no se pudieron instalar."
        log_ok "Paquetes oficiales instalados."
    fi

    if [ -f "${DOTFILES_DIR}/packages/pacman-aur.txt" ] && [ -s "${DOTFILES_DIR}/packages/pacman-aur.txt" ]; then
        local aur_count=$(wc -l < "${DOTFILES_DIR}/packages/pacman-aur.txt")
        if confirm "¿Instalar ${aur_count} paquetes AUR? (requiere yay o paru)"; then
            if command -v yay &>/dev/null; then
                yay -S --needed --noconfirm - < "${DOTFILES_DIR}/packages/pacman-aur.txt" || \
                    log_warn "Algunos paquetes AUR no se pudieron instalar."
                log_ok "Paquetes AUR instalados."
            elif command -v paru &>/dev/null; then
                paru -S --needed --noconfirm - < "${DOTFILES_DIR}/packages/pacman-aur.txt" || \
                    log_warn "Algunos paquetes AUR no se pudieron instalar."
                log_ok "Paquetes AUR instalados."
            else
                log_warn "No se encontró yay ni paru. Instalá yay primero."
            fi
        fi
    fi

    if [ -f "${DOTFILES_DIR}/packages/flatpak.txt" ] && [ -s "${DOTFILES_DIR}/packages/flatpak.txt" ]; then
        if confirm "¿Instalar paquetes Flatpak?"; then
            xargs -a "${DOTFILES_DIR}/packages/flatpak.txt" flatpak install -y || \
                log_warn "Algunos Flatpaks no se pudieron instalar."
            log_ok "Flatpaks instalados."
        fi
    fi
}

restore_dotfiles_stow() {
    log_info "=== Restaurando dotfiles (Stow) ==="

    if [ ! -d "${DOTFILES_DIR}/stow_packages" ]; then
        log_warn "No se encontró stow_packages/. Omitiendo..."
        return
    fi

    cd "${DOTFILES_DIR}/stow_packages"

    for pkg in */; do
        pkg_name="${pkg%/}"
        log_info "  Stow: ${pkg_name}"
        stow --restow --target="${HOME}" "${pkg_name}" 2>/dev/null && \
            log_ok "  → ${pkg_name}" || \
            log_warn "  → ${pkg_name} (error, puede que ya existan archivos)"
    done

    cd "${DOTFILES_DIR}"
    log_ok "Dotfiles restaurados con Stow."
}

restore_etc_backup() {
    log_info "=== Restaurando /etc ==="

    local latest_etc=$(ls -t "${BACKUP_BASE}/etc/etcbak-"*.tar.gz 2>/dev/null | head -1)

    if [ -z "$latest_etc" ]; then
        log_warn "No hay backups de /etc en ${BACKUP_BASE}/etc/"
        return
    fi

    if confirm "¿Restaurar /etc desde ${latest_etc}?"; then
        log_warn "Esto sobreescribirá configs de sistema. Asegurate de tener bash disponible."
        sudo tar -xzf "$latest_etc" -C / 2>/dev/null || \
            log_warn "Error al restaurar /etc (pueden haber conflictos menores)"
        log_ok "/etc restaurado."
    fi
}

restore_omarchy_hooks() {
    log_info "=== Hooks de Omarchy ==="

    local hook_src="${DOTFILES_DIR}/packages/omarchy-hooks"
    local hook_dst="${HOME}/.config/omarchy/hooks/post-update.d/"

    if [ ! -d "${hook_src}" ]; then
        log_info "No hay hooks personalizados para restaurar."
        return
    fi

    if [ ! -d "${hook_dst}" ]; then
        log_info "No existe el directorio de hooks de Omarchy. Omitiendo..."
        return
    fi

    if confirm "¿Restaurar hooks personalizados de Omarchy?"; then
        log_info "Copiando hooks personalizados a ${hook_dst}"
        cp -r "${hook_src}"/* "${hook_dst}/" 2>/dev/null
        chmod +x "${hook_dst}"/* 2>/dev/null || true
        log_ok "Hooks restaurados."
    fi
}

restore_network_config() {
    log_info "=== Configuración de red estática ==="

    if [ ! -f "${DOTFILES_DIR}/scripts/network-setup.sh" ]; then
        log_warn "No se encontró scripts/network-setup.sh. Omitiendo configuración de red."
        return
    fi

    if confirm "¿Configurar IP estática del servidor?"; then
        log_info "Ejecutando network-setup.sh (requiere sudo)..."
        if sudo bash "${DOTFILES_DIR}/scripts/network-setup.sh"; then
            log_ok "Red configurada exitosamente."
        else
            log_warn "Error al configurar red. Podés hacerlo manualmente después:"
            log_info "  STATIC_IP=192.168.100.X ${DOTFILES_DIR}/scripts/network-setup.sh"
        fi
    else
        log_info "Omitiendo configuración de red. La IP se asignará por DHCP."
        log_info "Para configurar después:"
        log_info "  cd ~/.dotfiles && bash scripts/network-setup.sh"
    fi
}

restore_samba() {
    log_info "=== Samba (compartir disco con Windows) ==="

    if [ ! -f "${DOTFILES_DIR}/scripts/samba-setup.sh" ]; then
        log_warn "No se encontró scripts/samba-setup.sh. Omitiendo Samba."
        return
    fi

    if confirm "¿Configurar Samba para compartir /mnt/disc-a00 con Windows?"; then
        log_info "Ejecutando samba-setup.sh (requiere sudo)..."
        if sudo bash "${DOTFILES_DIR}/scripts/samba-setup.sh"; then
            log_ok "Samba configurado."
        else
            log_warn "Error al configurar Samba. Para hacerlo manual:"
            log_info "  sudo ~/.dotfiles/scripts/samba-setup.sh"
        fi
    fi
}

install_gentleman_dots() {
    log_info "=== Gentleman.Dots ==="

    if confirm "¿Instalar Gentleman.Dots? (configura Alacritty, Neovim, Fish/Zsh, Starship, Tmux)"; then
        log_info "Descargando e instalando Gentleman.Dots..."
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/Gentleman-Programming/Gentleman.Dots/main/install.sh)" || \
            log_error "Error en la instalación de Gentleman.Dots."
        log_ok "Gentleman.Dots instalado."
    fi
}

restore_omarchy_theme() {
    log_info "=== Restaurando tema Omarchy ==="

    if confirm "¿Reaplicar tema Tokyo Night de Omarchy?"; then
        omarchy theme set "Tokyo Night" 2>/dev/null && \
            log_ok "Tema Tokyo Night aplicado." || \
            log_warn "No se pudo aplicar el tema (¿Omarchy instalado?)"
    fi

    if confirm "¿Reiniciar Waybar?"; then
        omarchy restart waybar 2>/dev/null || \
            log_warn "No se pudo reiniciar Waybar."
    fi
}

final_instructions() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   ✅ Restauración completada                  ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    echo "   📋 Checklist post-restauración:"
    echo "   ┌─────────────────────────────────────────────┐"
    echo "   │ 1. 🔑 Verificar claves SSH/GPG              │"
    echo "   │ 2. 💾 Verificar montaje disco externo       │"
    echo "   │    → /mnt/disc-a00/                         │"
    echo "   │ 3. 🌐 Verificar IP estática:                │"
    echo "   │    ip addr show                             │"
    echo "   │ 4. 🐳 Configurar Dokploy y contenedores     │"
    echo "   │ 5. 📦 Revisar packages restantes:           │"
    echo "   │    cat ~/.dotfiles/packages/*.txt           │"
    echo "   │ 6. 🔄 git pull (últimos cambios)            │"
    echo "   │ 7. 🚀 Disfrutar tu sistema                  │"
    echo "   └─────────────────────────────────────────────┘"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    AUTO_MODE="false"
    DRY_RUN="false"

    for arg in "$@"; do
        case "$arg" in
            --auto)   AUTO_MODE="true" ;;
            --dry-run) DRY_RUN="true" ;;
            --help|-h)
                echo "Uso: $0 [--auto] [--dry-run]"
                exit 0
                ;;
        esac
    done

    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   🔄 Omarchy Restore — $(date +%Y-%m-%d)     ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""

    if [ "$DRY_RUN" = "true" ]; then
        log_info "=== DRY RUN — Solo mostrando lo que se haría ==="
        echo ""
        echo "  1. Verificar prerequisitos (git, stow, ~/.dotfiles)"
        echo "  2. Restaurar paquetes desde packages/*.txt"
        echo "  3. Restaurar dotfiles vía Stow"
        echo "  4. Restaurar /etc desde backup externo"
        echo "  5. Configurar IP estática"
        echo "  6. Configurar Samba (compartir disco con Windows)"
        echo "  7. Restaurar hooks personalizados de Omarchy"
        echo "  8. Instalar Gentleman.Dots (opcional)"
        echo "  9. Reaplicar tema Omarchy"
        exit 0
    fi

    check_prerequisites
    restore_packages
    restore_dotfiles_stow
    restore_etc_backup
    restore_network_config
    restore_samba
    restore_omarchy_hooks
    install_gentleman_dots
    restore_omarchy_theme
    final_instructions
}

main "$@"

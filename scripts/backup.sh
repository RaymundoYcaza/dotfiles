#!/bin/bash
# backup.sh — Backup de dotfiles, paquetes y configs de sistema
# 
# Uso:
#   ./backup.sh                    # Backup rápido: dotfiles + paquetes
#   ./backup.sh --full             # Backup completo (+ /etc, Docker, push)
#   ./backup.sh --packages-only    # Solo regenerar listas de paquetes
#   ./backup.sh --pre-gentleman    # Backup previo a instalar Gentleman.Dots
#   ./backup.sh --push             # Backup rápido + git push
#   ./backup.sh --full --push      # Backup completo + git push
#
# Dependencias: git, stow, rsync (para --full)

set -euo pipefail

# ─── Configuración ───────────────────────────────────────────────────────────

DOTFILES_DIR="${HOME}/.dotfiles"
BACKUP_BASE="/mnt/disc-a00/Z01_BACKUPS/omarchy-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE_TAG=$(date +%Y-%m-%d)
GENTLEMAN_PRE_BACKUP="${HOME}/gentleman-prev-backup-${DATE_TAG}"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Funciones ───────────────────────────────────────────────────────────────

check_dependencies() {
    local missing=0
    for cmd in git stow; do
        if ! command -v "$cmd" &>/dev/null; then
            log_warn "Falta dependencia: $cmd. Instalá con: sudo pacman -S $cmd"
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        log_error "Instalá las dependencias faltantes y volvé a intentar."
        exit 1
    fi
}

backup_packages() {
    log_info "Respaldando lista de paquetes..."
    mkdir -p "${DOTFILES_DIR}/packages"

    # Paquetes oficiales (instalados explícitamente)
    pacman -Qqn > "${DOTFILES_DIR}/packages/pacman-official.txt" 2>/dev/null || \
        log_warn "No se pudo generar pacman-official.txt"

    # Paquetes AUR (instalados explícitamente)
    pacman -Qqm > "${DOTFILES_DIR}/packages/pacman-aur.txt" 2>/dev/null || \
        log_warn "No se pudo generar pacman-aur.txt (no hay AUR packages)"

    # Flatpaks (si existen)
    if command -v flatpak &>/dev/null; then
        flatpak list --app --columns=application > "${DOTFILES_DIR}/packages/flatpak.txt" 2>/dev/null || true
    fi

    log_ok "Packages respaldados en ${DOTFILES_DIR}/packages/"
}

backup_dotfiles() {
    log_info "Actualizando symlinks de Stow..."
    cd "${DOTFILES_DIR}/stow_packages"

    for pkg in */; do
        pkg_name="${pkg%/}"
        log_info "  Stow: ${pkg_name}"
        stow --restow --target="${HOME}" "${pkg_name}" 2>/dev/null || \
            log_warn "  Error al stow ${pkg_name}"
    done

    cd "${DOTFILES_DIR}"
    log_ok "Dotfiles actualizados con Stow."
}

git_commit_and_push() {
    cd "${DOTFILES_DIR}"

    # Verificar si hay cambios
    if git diff --quiet && git diff --cached --quiet && [[ -z $(git status --porcelain) ]]; then
        log_info "No hay cambios nuevos para commit."
        return 0
    fi

    git add -A
    git commit -m "backup: ${DATE_TAG} — dotfiles + packages" --allow-empty-message 2>/dev/null || true

    if git remote -v | grep -q origin; then
        log_info "Haciendo push a GitHub..."
        git push origin main 2>/dev/null || git push origin master 2>/dev/null || \
            log_warn "No se pudo hacer push. Verificá la conexión a GitHub."
        log_ok "Push a GitHub completado."
    else
        log_warn "No hay remote origin configurado. No se hizo push."
    fi
}

backup_etc() {
    local etc_backup_dir="${BACKUP_BASE}/etc"
    mkdir -p "${etc_backup_dir}"

    log_info "Respaldando /etc (configs de sistema)..."
    # Solo archivos planos, excluyendo cosas grandes/irrelevantes
    sudo tar -czf "${etc_backup_dir}/etcbak-${TIMESTAMP}.tar.gz" \
        --exclude='/etc/pacman.d/gnupg' \
        --exclude='/etc/ssl' \
        --exclude='/etc/ca-certificates' \
        --exclude='/etc/fonts' \
        /etc/ 2>/dev/null || log_warn "Error al respaldar /etc"

    # Rotar: mantener solo los últimos 5 backups
    ls -t "${etc_backup_dir}/etcbak-"*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm

    log_ok "/etc respaldado en ${etc_backup_dir}/"
}

backup_to_external() {
    local ext_backup_dir="${BACKUP_BASE}/dotfiles"
    mkdir -p "${ext_backup_dir}"

    log_info "Copiando dotfiles al disco externo..."
    rsync -a --delete "${DOTFILES_DIR}/" "${ext_backup_dir}/dotfiles-${TIMESTAMP}/"
    # Symlink "latest" para siempre tener la última versión accesible
    ln -snf "dotfiles-${TIMESTAMP}" "${ext_backup_dir}/latest"

    log_ok "Dotfiles copiados a ${ext_backup_dir}/"
}

backup_pre_gentleman() {
    log_info "Backup previo a instalación de Gentleman.Dots..."
    mkdir -p "${GENTLEMAN_PRE_BACKUP}"

    for dir in alacritty nvim; do
        if [ -d "${HOME}/.config/${dir}" ]; then
            cp -r "${HOME}/.config/${dir}" "${GENTLEMAN_PRE_BACKUP}/"
            log_ok "  Backup de ~/.config/${dir}"
        fi
    done

    if [ -f "${HOME}/.config/starship.toml" ]; then
        cp "${HOME}/.config/starship.toml" "${GENTLEMAN_PRE_BACKUP}/"
        log_ok "  Backup de ~/.config/starship.toml"
    fi

    log_ok "Backup pre-Gentleman completado: ${GENTLEMAN_PRE_BACKUP}"
    echo ""
    echo "   Si algo sale mal, restaurá con:"
    echo "   cp -r ${GENTLEMAN_PRE_BACKUP}/* ~/.config/"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    local do_full=false
    local do_push=false
    local do_packages_only=false
    local do_pre_gentleman=false

    for arg in "$@"; do
        case "$arg" in
            --full)     do_full=true ;;
            --push)     do_push=true ;;
            --packages-only) do_packages_only=true ;;
            --pre-gentleman) do_pre_gentleman=true ;;
            --help|-h)
                echo "Uso: $0 [--full] [--push] [--packages-only] [--pre-gentleman]"
                exit 0
                ;;
            *)
                log_error "Argumento desconocido: $arg"
                exit 1
                ;;
        esac
    done

    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   🔄 Omarchy Backup — ${DATE_TAG}            ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""

    # ─── Pre-Gentleman ───
    if [ "$do_pre_gentleman" = true ]; then
        backup_pre_gentleman
        exit 0
    fi

    check_dependencies

    # ─── Packages only ───
    backup_packages
    if [ "$do_packages_only" = true ]; then
        log_ok "Modo packages-only completado."
        exit 0
    fi

    # ─── Dotfiles ───
    backup_dotfiles

    # ─── Git ───
    if [ "$do_push" = true ]; then
        git_commit_and_push
    else
        # Commit local sin push
        cd "${DOTFILES_DIR}"
        if ! git diff --quiet || ! git diff --cached --quiet || [[ -n $(git status --porcelain) ]]; then
            git add -A
            git commit -m "backup: ${DATE_TAG} — dotfiles + packages" 2>/dev/null || true
            log_ok "Commit local creado (sin push). Usá --push para subir a GitHub."
        else
            log_info "Sin cambios nuevos."
        fi
    fi

    # ─── Full ───
    if [ "$do_full" = true ]; then
        echo ""
        log_info "=== Backup completo ==="
        backup_etc
        backup_to_external

        # Volúmenes Docker (si existen)
        if [ -d "/mnt/disc-a00/DOCKER_VOLUMES" ]; then
            log_info "Respaldando volúmenes Docker..."
            local docker_backup="${BACKUP_BASE}/docker-volumes"
            mkdir -p "${docker_backup}"
            rsync -av --delete /mnt/disc-a00/DOCKER_VOLUMES/ "${docker_backup}/" 2>/dev/null || \
                log_warn "Error al respaldar volúmenes Docker"
            log_ok "Volúmenes Docker respaldados."
        fi
    fi

    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   ✅ Backup completado: ${DATE_TAG}         ║"
    echo "╚═══════════════════════════════════════════════╝"
}

main "$@"

#!/bin/bash
# ollama-setup.sh — Instalación y configuración de Ollama (Docker)
# ================================================================
#
# Ollama es un servidor local de inferencia de modelos de lenguaje.
# Corre en Docker con soporte GPU NVIDIA.
#
# API compatible con OpenAI: http://192.168.100.81:11434/v1
#
# Uso:
#   sudo ./ollama-setup.sh                       # Instalación completa
#   ./ollama-setup.sh --status                   # Estado de Ollama
#   ./ollama-setup.sh --post-install             # Post-instalación (importar modelos)
#   ./ollama-setup.sh --test                     # Probar API
#
# Dependencias: sudo, docker, nvidia-container-toolkit

set -euo pipefail

# ─── Configuración ───────────────────────────────────────────────────────────

BASE_DIR="/mnt/disc-a00/Z01-DEVOPS"
OLLAMA_DIR="${BASE_DIR}/containers/ollama"
OLLAMA_STATE="${BASE_DIR}/state/ollama"
OLLAMA_LOGS="${BASE_DIR}/logs/ollama"
COMPOSE_FILE="${OLLAMA_DIR}/docker-compose.yml"
NETWORK_DIR="/mnt/blackpearl/lmstudio_models"
OLLAMA_PORT="11434"

# Detectar home del usuario real incluso bajo sudo
if [ -n "${SUDO_USER:-}" ]; then
    REAL_USER="${SUDO_USER}"
    REAL_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
    REAL_USER="${USER}"
    REAL_HOME="${HOME}"
fi

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ─── Helper: confirmación ────────────────────────────────────────────────────

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local answer

    if [ "${AUTO_MODE:-false}" = "true" ]; then
        return 0
    fi

    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "[DRY-RUN] Confirmación saltada: $prompt"
        return 0
    fi

    if [ "$default" = "y" ]; then
        read -r -p "$prompt [Y/n] " answer
        [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
    else
        read -r -p "$prompt [y/N] " answer
        [[ "$answer" =~ ^[Yy] ]]
    fi
}

# ─── Prerequisitos ──────────────────────────────────────────────────────────

check_prerequisites() {
    log_info "Verificando prerequisitos..."

    # Docker
    if ! command -v docker &>/dev/null; then
        log_error "Docker no está instalado. Ejecutar: sudo pacman -S docker"
        return 1
    fi
    log_ok "Docker: $(docker --version)"

    # Docker Compose
    if ! docker compose version &>/dev/null; then
        log_error "Docker Compose no está disponible"
        return 1
    fi
    log_ok "Docker Compose: $(docker compose version 2>&1)"

    # nvidia-container-toolkit
    if ! docker info 2>/dev/null | grep -q "Runtimes.*nvidia"; then
        log_warn "nvidia-container-toolkit no detectado en Docker"
        log_info "Ejecutar: sudo pacman -S nvidia-container-toolkit && sudo systemctl restart docker"
        if confirm "¿Instalar nvidia-container-toolkit?"; then
            sudo pacman -S --noconfirm nvidia-container-toolkit
            sudo systemctl restart docker
            log_ok "nvidia-container-toolkit instalado. Docker reiniciado."
        else
            log_warn "Continuando sin GPU (CPU mode)"
        fi
    else
        log_ok "nvidia-container-toolkit detectado"
    fi

    # GPU
    if nvidia-smi &>/dev/null; then
        local gpu_info
        gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1)
        log_ok "GPU detectada: ${gpu_info}"
    else
        log_warn "No se detectó GPU NVIDIA. Ollama correrá en CPU."
    fi

    # Directorios
    for dir in "$OLLAMA_DIR" "$OLLAMA_STATE" "$OLLAMA_LOGS"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_ok "Directorio creado: $dir"
        fi
    done

    # Carpeta de modelos
    if [ -d "$NETWORK_DIR" ]; then
        log_ok "Modelos disponibles en: $NETWORK_DIR ($(du -sh "$NETWORK_DIR" 2>/dev/null | cut -f1))"
    else
        log_warn "Carpeta de modelos no encontrada: $NETWORK_DIR"
    fi

    # Puerto
    if ss -tlnp 2>/dev/null | grep -qE "[: ]${OLLAMA_PORT}[ :]"; then
        log_warn "Puerto ${OLLAMA_PORT} ya está en uso"
        ss -tlnp 2>/dev/null | grep -E "[: ]${OLLAMA_PORT}[ :]"
    else
        log_ok "Puerto ${OLLAMA_PORT} libre"
    fi

    # docker-compose.yml
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "No se encontró docker-compose.yml en ${COMPOSE_FILE}"
        log_info "Copiando desde dotfiles..."
        if [ -f "${REAL_HOME}/.dotfiles/packages/ollama/docker-compose.yml" ]; then
            cp "${REAL_HOME}/.dotfiles/packages/ollama/docker-compose.yml" "$COMPOSE_FILE"
            log_ok "docker-compose.yml copiado"
        else
            return 1
        fi
    else
        log_ok "docker-compose.yml encontrado"
    fi

    return 0
}

# ─── Instalación ─────────────────────────────────────────────────────────────

install_ollama() {
    log_info "Iniciando contenedor Ollama..."

    cd "$OLLAMA_DIR"

    if docker compose ps 2>/dev/null | grep -q "Up"; then
        log_warn "Ollama ya está corriendo"
        docker compose ps
        return 0
    fi

    docker compose pull 2>&1
    docker compose up -d 2>&1

    # Esperar que arranque
    log_info "Esperando que Ollama inicie..."
    for i in $(seq 1 15); do
        if docker compose ps 2>/dev/null | grep -q "Up"; then
            log_ok "Ollama iniciado correctamente"
            docker compose ps
            return 0
        fi
        sleep 1
    done

    log_error "Ollama no inició después de 15 segundos"
    docker compose logs --tail=20 2>&1
    return 1
}

# ─── Post-instalación ────────────────────────────────────────────────────────

post_install() {
    log_info "=== Post-instalación ==="
    echo ""
    log_info "Verificando API..."
    if curl -s http://localhost:${OLLAMA_PORT}/api/tags &>/dev/null; then
        log_ok "API de Ollama respondiendo en http://192.168.100.81:${OLLAMA_PORT}"
        echo ""

        log_info "Modelos disponibles en /models/:"
        docker compose exec ollama ls /models/ 2>/dev/null | head -20 || echo "(ninguno)"

        echo ""
        log_info "Para importar un modelo GGUF:"
        echo "  cd ${OLLAMA_DIR}"
        echo "  docker compose exec ollama ollama create <nombre> -f /Modelfiles/<modelfile>"
        echo ""
        log_info "Para probar un modelo existente:"
        echo "  curl http://192.168.100.81:${OLLAMA_PORT}/api/generate -d '{"
        echo '    "model": "<modelo>",'
        echo '    "prompt": "Hola, ¿cómo estás?"'
        echo "  }'"
    else
        log_warn "API de Ollama no responde aún"
        docker compose logs --tail=10 2>&1
    fi
}

# ─── Estado ──────────────────────────────────────────────────────────────────

show_status() {
    echo "=== Estado de Ollama ==="
    echo ""

    if [ -f "$COMPOSE_FILE" ]; then
        cd "$OLLAMA_DIR"
        echo "Contenedor:"
        docker compose ps 2>&1 || echo "  No corriendo"
        echo ""

        if docker compose ps 2>/dev/null | grep -q "Up"; then
            echo "API:"
            curl -s http://localhost:${OLLAMA_PORT}/api/tags 2>/dev/null | python3 -m json.tool 2>/dev/null | head -20 || echo "  API no responde"
            echo ""
            echo "GPU en uso:"
            nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader 2>/dev/null || echo "  No disponible"
        fi
    else
        echo "  No configurado (falta docker-compose.yml)"
    fi

    echo ""
    echo "Modelos en /mnt/blackpearl/lmstudio_models/:"
    ls /mnt/blackpearl/lmstudio_models/ 2>/dev/null || echo "  No accesible"
}

# ─── Test API ────────────────────────────────────────────────────────────────

test_api() {
    log_info "Probando API de Ollama..."

    if ! curl -s http://localhost:${OLLAMA_PORT}/api/tags &>/dev/null; then
        log_error "API no responde en puerto ${OLLAMA_PORT}"
        return 1
    fi

    log_ok "API disponible en http://192.168.100.81:${OLLAMA_PORT}"

    local models
    models=$(curl -s http://localhost:${OLLAMA_PORT}/api/tags 2>/dev/null)

    if echo "$models" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('models',[])))" 2>/dev/null; then
        log_info "Modelos registrados:"
        echo "$models" | python3 -m json.tool 2>/dev/null | grep -E '"name"' | head -10
    fi

    log_ok "Endpoint compatible con OpenAI: http://192.168.100.81:${OLLAMA_PORT}/v1"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
        --auto)
            AUTO_MODE="true"
            # Fall through to install
            ;&  # bash 4+ fall-through
        --dry-run)
            DRY_RUN="true"
            # Fall through to install
            ;&
        --status)
            show_status
            ;;
        --post-install)
            post_install
            ;;
        --test)
            test_api
            ;;
        --help|-h)
            echo "Uso: $0 [OPCIÓN]"
            echo ""
            echo "Opciones:"
            echo "  Sin argumentos    Instalación completa (prereq + install + post)"
            echo "  --auto            Modo automático (sin confirmaciones)"
            echo "  --dry-run         Vista previa"
            echo "  --status          Mostrar estado"
            echo "  --post-install    Solo pasos post-instalación"
            echo "  --test            Probar API"
            echo "  --help            Esta ayuda"
            ;;
        "")
            log_info "=== Instalación de Ollama ==="
            echo ""

            if ! check_prerequisites; then
                log_error "Prerequisitos no cumplidos"
                exit 1
            fi

            echo ""
            if confirm "¿Instalar Ollama?"; then
                install_ollama
            fi

            echo ""
            if confirm "¿Ejecutar post-instalación?"; then
                post_install
            fi

            log_ok "Instalación completada"
            echo ""
            echo "Panel:       http://192.168.100.81:${OLLAMA_PORT}"
            echo "API OpenAI:  http://192.168.100.81:${OLLAMA_PORT}/v1"
            echo "Modelos:     ${NETWORK_DIR}"
            echo ""
            echo "Para administrar:"
            echo "  cd ${OLLAMA_DIR} && docker compose logs -f"
            echo "  cd ${OLLAMA_DIR} && docker compose exec ollama ollama list"
            ;;
        *)
            log_error "Opción desconocida: $1"
            echo "Use: $0 [--status|--post-install|--test|--help]"
            exit 1
            ;;
    esac
}

main "$@"

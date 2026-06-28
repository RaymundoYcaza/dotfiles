# Makefile — Gestión de configuración Omarchy
#
# Comandos de uso diario:
#   make backup          Respaldo rápido (dotfiles + paquetes)
#   make backup-full     Respaldo completo (+ /etc, discos, Git push)
#   make push            Commit y push a GitHub
#   make packages        Regenerar listas de paquetes
#   make status          Mostrar estado del repo
#   make diff            Mostrar cambios pendientes
#
# Una sola vez:
#   make bootstrap       Inicializar repo desde cero (USAR CON CUIDADO)
#   make bootstrap-dry   Vista previa del bootstrap
#
# Restauración (en máquina nueva):
#   make restore         Restauración interactiva
#   make restore-auto    Restauración automática

SCRIPTS := $(shell pwd)/scripts

.PHONY: backup backup-full push packages status diff bootstrap bootstrap-dry restore restore-auto

# ─── Backup ──────────────────────────────────────────────────────────────────

backup:
	@echo "📦 Backup rápido..."
	@$(SCRIPTS)/backup.sh

backup-full:
	@echo "📦 Backup completo..."
	@$(SCRIPTS)/backup.sh --full --push

push:
	@echo "📤 Push a GitHub..."
	@cd ~/.dotfiles && git add -A && git commit -m "update: $(shell date +%Y-%m-%d_%H%M)" || true
	@cd ~/.dotfiles && git push

packages:
	@echo "📋 Regenerando listas de paquetes..."
	@$(SCRIPTS)/backup.sh --packages-only

# ─── Estado ──────────────────────────────────────────────────────────────────

status:
	@echo "📊 Estado de ~/.dotfiles/"
	@cd ~/.dotfiles && git status
	@echo ""
	@echo "📦 Paquetes gestionados por Stow:"
	@ls ~/.dotfiles/stow_packages/

diff:
	@cd ~/.dotfiles && git diff --stat
	@cd ~/.dotfiles && git diff --cached --stat

# ─── Bootstrap (una sola vez) ────────────────────────────────────────────────

bootstrap:
	@echo "🚀 Inicializando dotfiles..."
	@$(SCRIPTS)/bootstrap.sh

bootstrap-dry:
	@echo "🚀 Vista previa del bootstrap..."
	@$(SCRIPTS)/bootstrap.sh --dry-run

# ─── Restauración ────────────────────────────────────────────────────────────

restore:
	@echo "🔄 Restauración interactiva..."
	@$(SCRIPTS)/restore.sh

restore-auto:
	@echo "🔄 Restauración automática..."
	@$(SCRIPTS)/restore.sh --auto

# ─── Red estática ──────────────────────────────────────────────────────────────

network:
	@echo "🌐 Configurando IP estática..."
	@$(SCRIPTS)/network-setup.sh

network-status:
	@$(SCRIPTS)/network-setup.sh --status

# ─── Ollama ────────────────────────────────────────────────────────────────────

ollama:
	@echo "🤖 Configurando Ollama..."
	@sudo $(SCRIPTS)/ollama-setup.sh

ollama-status:
	@$(SCRIPTS)/ollama-setup.sh --status

ollama-logs:
	@cd /mnt/disc-a00/Z01-DEVOPS/containers/ollama && docker compose logs -f

# ─── Samba ──────────────────────────────────────────────────────────────────────

samba:
	@echo "🗂️ Configurando Samba..."
	@sudo $(SCRIPTS)/samba-setup.sh

samba-status:
	@$(SCRIPTS)/samba-setup.sh --status

# ─── Ayuda ────────────────────────────────────────────────────────────────────

help:
	@echo "📖 Comandos disponibles:"
	@echo ""
	@echo "  make backup            Respaldo rápido"
	@echo "  make backup-full       Respaldo completo + push"
	@echo "  make push              Commit y push a GitHub"
	@echo "  make packages          Regenerar listas de paquetes"
	@echo "  make status            Estado del repo de dotfiles"
	@echo "  make diff              Cambios pendientes"
	@echo "  make bootstrap         Inicializar repo (UNA VEZ)"
	@echo "  make bootstrap-dry     Vista previa del bootstrap"
	@echo "  make restore           Restauración interactiva"
	@echo "  make restore-auto      Restauración automática"
	@echo "  make network           Configurar IP estática"
	@echo "  make network-status    Mostrar estado de red"
	@echo "  make ollama            Configurar Ollama"
	@echo "  make ollama-status     Estado de Ollama"
	@echo "  make ollama-logs       Logs de Ollama en tiempo real"
	@echo "  make samba             Configurar Samba"
	@echo "  make samba-status      Estado de Samba"

# AGENTS.md — Convenciones de Configuración Omarchy

> **Propósito:** Este archivo define la filosofía, arquitectura y convenciones del proyecto de configuración de sistema Omarchy (Arch Linux + Hyprland). Sirve como **system prompt para agentes AI** y como **SDD Harness** de referencia.
>
> **Proyecto:** `configuracion-omarchy`
> **CWD:** `/home/jabes/Work/2026-06-27_configuracion-omarchy/`
> **Dotfiles repo:** `~/.dotfiles/` — Git remote: `origin/main` (GitHub)

---

## ═══════════════════════════════════════════════
## PARTE 1 — SYSTEM PROMPT PARA AGENTES AI
## ═══════════════════════════════════════════════

### 1.1 Identidad del Proyecto

Este es un sistema **Omarchy** (distro Arch Linux preconfigurada con Hyprland, Waybar, Walker, Mako) combinado con **Gentleman.Dots** (herramienta dev: Alacritty, Neovim/LazyVim, Fish, Starship, Tmux). La gestión de dotfiles usa **GNU Stow** + **Git** con backups al **disco externo NTFS**.

### 1.2 Principios Rectores

1. **Separación de dominios:** Omarchy = visual/ventanas. Gentleman.Dots = terminal/editor/shell. No mezclar.
2. **Stow para lo permanente:** Archivos de config que NO gestiona Gentleman.Dots van a `stow_packages/` y se activan con symlinks.
3. **Git como fuente de verdad:** `~/.dotfiles/` es un repo Git. Todo cambio se commitea y pushea.
4. **Disco externo para backups físicos:** `/mnt/disc-a00/Z01_BACKUPS/omarchy-backups/` con estructura de timestamps.
5. **Restauración en 3 comandos:** `git clone + stow + restore.sh`.
6. **No interactividad en scripts:** Usar flags `--auto` para evitar `read` prompts que bloquean en freebuff.

### 1.3 Mapa de Pertenencia

| Config | Dueño | Repo | Backup |
|--------|-------|------|--------|
| Hyprland (WM) | Omarchy | ❌ No versionar | Disco externo |
| Waybar | Omarchy | ❌ No versionar | Disco externo |
| Walker | Omarchy | ❌ No versionar | Disco externo |
| Mako | Omarchy | ❌ No versionar | Disco externo |
| Omarchy themes | Omarchy | ❌ No versionar | Disco externo |
| **btop** | **Stow** | ✅ `stow_packages/btop/` | Git + disco |
| **fastfetch** | **Stow** | ✅ `stow_packages/fastfetch/` | Git + disco |
| **git** | **Stow** | ✅ `stow_packages/git/` | Git + disco |
| **lazygit** | **Stow** | ✅ `stow_packages/lazygit/` | Git + disco |
| **starship** | **Stow** | ✅ `stow_packages/starship/` | Git + disco |
| **Red estática** | **Template** | ✅ `packages/network/` (template) | Git + script |
| Alacritty | Gentleman.Dots | ❌ No versionar | Backup pre-instalación |
| Neovim | Gentleman.Dots | ❌ No versionar | Backup pre-instalación |
| Fish/Zsh | Gentleman.Dots | ❌ No versionar | Backup pre-instalación |
| Tmux | Gentleman.Dots | ❌ No versionar | Backup pre-instalación |

**REGLAS:**
- Si Gentleman.Dots lo gestiona → NO tocar, NO stow, NO versionar.
- Si Omarchy lo provee pero Gentleman.Dots NO lo toca → Stow + Git.
- Si es config del sistema (`/etc/`) → backup tar.gz al disco externo.

### 1.4 Árbol de Decisión para Agentes AI

```
¿El usuario quiere cambiar/configurar algo?
├── ¿Es de Omarchy (Hyprland, Waybar, Walker, Mako, temas)?
│   └── → Usar comandos `omarchy`, modificar en ~/.config/omarchy/
│       → Backupear con backup.sh si es cambio importante
│
├── ¿Es de Gentleman.Dots (Alacritty, Neovim, Fish, Tmux)?
│   └── → Modificar directamente (Gentleman.Dots gestiona)
│       → No stow, no versionar. Hacer backup manual si aplica.
│
├── ¿Es un config de btop, fastfetch, git, lazygit, starship?
│   └── → Modificar dentro de ~/.dotfiles/stow_packages/<pkg>/
│       → Re-stow: cd ~/.dotfiles/stow_packages && stow --restow --target=$HOME <pkg>
│       → Committear y pushear
│
├── ¿Es agregar un NUEVO paquete a Stow?
│   └── → Crear ~/.dotfiles/stow_packages/<pkg>/.config/<pkg>/
│       → Mover/copiar archivos ahí
│       → Stow --restow
│       → Agregar a STOW_PACKAGES en bootstrap.sh
│
├── ¿Es config de red estática (IP fija)?
│   └── → Editar STATIC_IP en scripts/network-setup.sh
│       → O pasar STATIC_IP=192.168.100.X como variable de entorno
│       → Ejecutar: sudo ~/.dotfiles/scripts/network-setup.sh
│       → El template está en packages/network/20-ethernet.network
│       → Committear cambios a Git
│
├── ¿Es backup?
│   └── → Usar scripts/backup.sh con flags:
│       → --full --push  (completo + GitHub)
│       → --packages-only (solo listas)
│       → --pre-gentleman (antes de instalar Gentleman.Dots)
│
└── ¿Es restauración?
    └── → Ejecutar scripts/restore.sh
        → --auto para evitar prompts interactivos
        → Incluye paso de configuración de red estática
```

### 1.5 Comandos Frecuentes

```bash
# Backup rápido (dotfiles + paquetes + commit local)
cd ~/.dotfiles && ./scripts/backup.sh

# Backup completo + push a GitHub
cd ~/.dotfiles && ./scripts/backup.sh --full --push

# Solo regenerar listas de paquetes
cd ~/.dotfiles && ./scripts/backup.sh --packages-only

# Re-stow un paquete específico
cd ~/.dotfiles/stow_packages && stow --restow --target=$HOME <pkg>

# Estado del repo
cd ~/.dotfiles && git status

# Commit y push rápido
cd ~/.dotfiles && git add -A && git commit -m "update: $(date +%Y-%m-%d)" && git push

# Configurar IP estática del servidor
sudo ~/.dotfiles/scripts/network-setup.sh

# Con IP personalizada (sin modificar el script)
STATIC_IP=192.168.100.99 sudo ~/.dotfiles/scripts/network-setup.sh

# Ver estado actual de la red
~/.dotfiles/scripts/network-setup.sh --status

# Makefile shortcuts (desde el proyecto)
make backup
make backup-full
make status
make push
```

### 1.6 Restricciones para Agentes

1. **NO ejecutar scripts interactivos** con `read -r -p` sin el flag `--auto`. El usuario no puede escribir en la interfaz de freebuff.
2. **NO instalar paquetes globalmente** sin confirmación. Usar `sudo pacman -S` o AUR helper solo cuando el usuario lo autorice.
3. **NO mezclar dominios:** no poner configs de Gentleman.Dots en Stow ni viceversa.
4. **Siempre verificar el estado actual** antes de hacer cambios: `git status`, `stow --no`, `fc-list`, etc.
5. **Symlinks de Stow:** No editar archivos directamente en `~/.config/` si son symlinks. Editar el target en `~/.dotfiles/stow_packages/` y re-stow.
6. **Escritura en disco externo:** El disco NTFS montado en `/mnt/disc-a00` puede requerir permisos (`chmod o+w`) o `sudo` para escribir. Verificar antes.

### 1.7 Stack Tecnológico

| Componente | Tecnología |
|-----------|-----------|
| Sistema base | Arch Linux (Omarchy) |
| Window Manager | Hyprland |
| Barra/AppLauncher | Waybar / Walker |
| Notificaciones | Mako |
| Terminal | Alacritty (Gentleman.Dots) |
| Shell | Fish (Gentleman.Dots) |
| Editor | Neovim + LazyVim (Gentleman.Dots) |
| Prompt | Starship (Stow) |
| Gestor dotfiles | GNU Stow |
| Gestor de red | systemd-networkd + systemd-resolved |
| IP estática | `192.168.100.81` (template en `packages/network/`) |
| Versionado | Git → GitHub |
| Shell scripts | Bash |
| Disco externo | NTFS, montado en `/mnt/disc-a00` |
| Contenedores | Docker / Dokploy (futuro) |

---

## ═══════════════════════════════════════════════
## PARTE 2 — SDD HARNESS: Arquitectura Arch/Omarchy
## ═══════════════════════════════════════════════

### 2.1 Estructura de Directorios

```
/home/jabes/
├── .dotfiles/                       ← REPO GIT PRINCIPAL
│   ├── stow_packages/               ← Paquetes gestionados con symlinks
│   │   ├── btop/.config/btop/       → ~/.config/btop -> symlink
│   │   ├── fastfetch/.config/fastfetch/
│   │   ├── git/.config/git/
│   │   ├── lazygit/.config/lazygit/
│   │   └── starship/.config/starship.toml
│   ├── packages/                    ← Listas de paquetes y configs
│   │   ├── pacman-official.txt
│   │   ├── pacman-aur.txt
│   │   ├── flatpak.txt
│   │   └── network/                 ← Template de red estática
│   │       └── 20-ethernet.network
│   ├── scripts/                     ← Scripts automatizados
│   │   ├── backup.sh
│   │   ├── restore.sh
│   │   ├── bootstrap.sh
│   │   └── network-setup.sh         ← Configuración IP estática
│   └── .gitignore
│
├── .config/                         ← CONFIGURACIONES ACTIVAS
│   ├── hypr/                        ← OMARCHY (NO VERSIONAR)
│   ├── waybar/                      ← OMARCHY (NO VERSIONAR)
│   ├── walker/                      ← OMARCHY (NO VERSIONAR)
│   ├── mako/                        ← OMARCHY (NO VERSIONAR)
│   ├── omarchy/                     ← OMARCHY (NO VERSIONAR)
│   ├── alacritty/                   ← GENTLEMAN.DOTS (NO VERSIONAR)
│   ├── nvim/                        ← GENTLEMAN.DOTS (NO VERSIONAR)
│   ├── fish/                        ← GENTLEMAN.DOTS (NO VERSIONAR)
│   ├── btop/ → symlink             ← STOW
│   ├── fastfetch/ → symlink        ← STOW
│   ├── git/ → symlink              ← STOW
│   ├── lazygit/ → symlink          ← STOW
│   └── starship.toml → symlink     ← STOW
│
└── Work/
    └── 2026-06-27_configuracion-omarchy/   ← PROYECTO (este repo)
        ├── AGENTS.md               ← Este archivo
        ├── README.md               ← Plan detallado
        ├── Makefile                ← Shortcuts
        └── scripts/
            ├── bootstrap.sh
            ├── backup.sh
            └── restore.sh

/mnt/disc-a00/Z01_BACKUPS/
└── omarchy-backups/                 ← BACKUPS FÍSICOS
    ├── dotfiles/
    │   ├── dotfiles-YYYYMMDD_HHMMSS/
    │   └── latest → symlink
    ├── etc/
    │   └── etcbak-YYYYMMDD_HHMMSS.tar.gz
    └── docker-volumes/              ← (futuro)
```

### 2.2 GNU Stow — Convenciones

**Estructura de un paquete Stow:**
```
stow_packages/<package>/
└── .config/
    └── <package>/
        ├── config
        └── otros-archivos
```

**Comandos:**

```bash
# Crear symlinks (primera vez)
cd ~/.dotfiles/stow_packages && stow --target=$HOME <package>

# Recrear symlinks (después de editar)
cd ~/.dotfiles/stow_packages && stow --restow --target=$HOME <package>

# Eliminar symlinks sin borrar archivos fuente
cd ~/.dotfiles/stow_packages && stow --delete --target=$HOME <package>

# Vista previa (dry-run)
cd ~/.dotfiles/stow_packages && stow --no --target=$HOME <package>

# Stow todo de una
cd ~/.dotfiles/stow_packages && for pkg in */; do stow --restow --target=$HOME "${pkg%/}"; done
```

**REGLAS:**
- El path dentro de `stow_packages/<pkg>/` debe reflejar exactamente el path desde `$HOME`.
- No incluir archivos que gestiona Gentleman.Dots (alacritty, nvim, fish, tmux).

### 2.3 Backup — Estrategia

**Frecuencia:**
| Contenido | Frecuencia | Destino |
|-----------|-----------|---------|
| Dotfiles (Stow) | Post-cambio | Git + disco externo |
| Paquetes | Semanal / post-cambio | Git + disco externo |
| /etc/ | Semanal | Disco externo (tar.gz) |
| Docker volumes | Diario (futuro) | Disco externo (rsync) |

**Comandos:**

```bash
# Backup completo + push
./scripts/backup.sh --full --push

# Backup rápido (dotfiles + packages)
./scripts/backup.sh

# Solo regenerar listas de paquetes
./scripts/backup.sh --packages-only

# Backup pre-Gentleman.Dots
./scripts/backup.sh --pre-gentleman
```

**Rotación:** Se mantienen solo los últimos 5 backups de `/etc/`.

### 2.4 Restauración — Procedimiento

Desde una instalación limpia de Omarchy:

```bash
# 1. Prerequisitos
sudo pacman -S git stow

# 2. Clonar
git clone git@github.com:RaymundoYcaza/dotfiles.git ~/.dotfiles

# 3. Restaurar
cd ~/.dotfiles && ./scripts/restore.sh

# O automático (sin prompts)
cd ~/.dotfiles && ./scripts/restore.sh --auto
```

**Lo que hace restore.sh:**
1. Verifica prerequisitos (git, stow, pacman, ~/.dotfiles)
2. Restaura paquetes desde `packages/pacman-official.txt`
3. Stow todos los dotfiles
4. Restaura `/etc/` desde backup externo (opcional)
5. Configura IP estática del servidor (opcional)
6. Instala Gentleman.Dots (opcional)
7. Reaplica tema Omarchy

### 2.5 Gentleman.Dots — Integración

**Qué instala:**
- Alacritty (terminal)
- Neovim + LazyVim (editor)
- Fish (shell) — **recomendado: elegir Fish en el instalador**
- Tmux (multiplexor)
- Starship (prompt) — **Nota: Starship se gestiona con Stow, no Gentleman.Dots**
- IosevkaTerm Nerd Font

**Qué NO toca:**
- Hyprland, Waybar, Walker, Mako, Omarchy themes

**Backup previo requerido:**
```bash
./scripts/backup.sh --pre-gentleman
```
Esto guarda `alacritty/`, `nvim/`, `starship.toml` en `~/gentleman-prev-backup-YYYY-MM-DD/`.

**Post-instalación:**
```bash
omarchy theme set "Tokyo Night"
omarchy restart waybar
```

### 2.6 Configuración de Red Estática

**Gestor:** `systemd-networkd` + `systemd-resolved`
**Interfaz:** `enp3s0` (ethernet)
**IP por defecto:** `192.168.100.81/24`
**Gateway:** `192.168.100.1`
**DNS:** `9.9.9.9` (Quad9), `2620:fe::9`

**Archivos involucrados:**
- `packages/network/20-ethernet.network` — Template versionado en Git (contiene placeholder `__STATIC_IP__`)
- `scripts/network-setup.sh` — Script que aplica la configuración (usa `sudo`)

**Cómo cambiar la IP:**
```bash
# Opción 1: Variable de entorno (no modifica archivos)
STATIC_IP=192.168.100.99 sudo ~/.dotfiles/scripts/network-setup.sh

# Opción 2: Editar valor por defecto en el script
#   Editar STATIC_IP en scripts/network-setup.sh
#   sudo ~/.dotfiles/scripts/network-setup.sh

# Opción 3: Editar template directamente
#   Editar packages/network/20-ethernet.network
#   sudo systemctl restart systemd-networkd
```

**Cómo volver a DHCP (temporal):**
```bash
sudo ~/.dotfiles/scripts/network-setup.sh --dhcp
```

**Ver estado de red:**
```bash
~/.dotfiles/scripts/network-setup.sh --status
```

**Convención:**
- El template de red se versiona en Git (dentro de `packages/network/`)
- La IP es configurable via `STATIC_IP` (variable de entorno)
- El script `network-setup.sh` se encarga de: copiar template a `/etc/systemd/network/`, reemplazar placeholder, reiniciar systemd-networkd
- Durante restauración, `restore.sh` pregunta si se desea configurar la IP estática
- El backup de `/etc/` (`backup.sh --full`) también respalda la config activa en `/etc/systemd/network/`

### 2.7 Disco Externo — Montaje

**UUID:** `70FEE01EFEDFDB04`
**Tipo:** `ntfs` (driver `ntfs3`)
**Punto de montaje:** `/mnt/disc-a00`
**Entrada fstab:**
```
UUID=70FEE01EFEDFDB04	/mnt/disc-a00	ntfs3	rw,noatime,uid=1000,gid=1000,iocharset=utf8,prealloc	0	0
```

**Nota:** Si el disco da error de permisos al escribir, verificar con `ls -la /mnt/disc-a00/`. Puede requerir `chmod o+w`.

### 2.8 Estructura de Scripts

**bootstrap.sh — Una sola vez (setup inicial):**
- Crea `~/.dotfiles/` con estructura
- Migra configs existentes a Stow
- Genera listas de paquetes
- Crea primer commit Git
- `--dry-run` para vista previa
- `--auto` para modo no interactivo

**backup.sh — Uso diario:**
- Respalda dotfiles (re-stow + git commit)
- Regenera listas de paquetes
- Opcional: backup de `/etc/`, push a GitHub, copia a disco externo
- `--full --push` para backup completo
- `--packages-only` para solo paquetes
- `--pre-gentleman` para backup pre-instalación

**restore.sh — En máquina nueva:**
- Restaura paquetes, dotfiles, /etc
- Configura IP estática del servidor (opcional)
- Instala Gentleman.Dots (opcional)
- Reaplica tema Omarchy
- `--auto` para modo no interactivo
- `--dry-run` para vista previa

**network-setup.sh — Configuración de red:**
- Aplica IP estática con systemd-networkd
- IP configurable via `STATIC_IP` (variable de entorno)
- `--status` muestra estado actual de red
- `--dhcp` vuelve a DHCP temporalmente
- Requiere `sudo` (escribe en `/etc/systemd/network/`)

### 2.9 Makefile — Shortcuts

```makefile
make backup         # backup rápido
make backup-full    # backup completo + push
make push           # commit + push a GitHub
make packages       # regenerar listas
make status         # git status del repo
make diff           # cambios pendientes
make bootstrap      # setup inicial (una vez)
make restore        # restauración interactiva
make restore-auto   # restauración automática
make network        # configurar IP estática
make network-status # mostrar estado de red
```

### 2.10 Notas Técnicas

- **Starship:** El archivo `~/.config/starship.toml` fue corregido para ser symlink de Stow (no lo gestiona Gentleman.Dots).
- **Rama Git:** `main` (local y remoto). Rama `master` eliminada.
- **GitHub:** Repositorio `RaymundoYcaza/dotfiles`. Autenticación con token `ghp_...`.
- **Contenedores (futuro):** Dokploy + Docker volumes en disco externo.
- **Omarchy hooks:** Se puede agregar hook `post-update.d/99-backup-dotfiles` para backup automático.

### 2.11 Glosario

| Término | Significado |
|---------|------------|
| Omarchy | Distro Arch Linux preconfigurada con Hyprland + tooling visual |
| Gentleman.Dots | Suite de configuración dev (Alacritty, Neovim, Fish, Tmux, Starship) |
| Stow | GNU Stow — gestor de symlinks para dotfiles |
| Stow package | Directorio dentro de `stow_packages/` que se activa con symlinks |
| Dotfiles | Archivos de configuración del sistema (`~/.config/`, etc.) |
| freebuff | Interfaz de chat con el agente AI (no tiene input interactivo) |

---

*Documento generado el 2026-06-27. Actualizar cuando cambien las convenciones o se agreguen nuevos componentes.*

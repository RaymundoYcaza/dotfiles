# Especificación de Recuperación ante Desastres — Omarchy

> **Propósito:** Documentar el estado actual del sistema, las brechas entre el plan (AGENTS.md)
> y la implementación real, los cambios realizados, y su cobertura en los procesos de
> backup/restore. Sirve como guía para recuperar el sistema completo desde cero.
>
> **Fecha:** 2026-06-28
> **Sistema:** Omarchy (Arch Linux + Hyprland)
> **Usuario:** jabes
> **Dotfiles repo:** `~/.dotfiles/` (GitHub: `RaymundoYcaza/dotfiles`)
> **Disco externo:** `/mnt/disc-a00/` (NTFS, 3.6TB)
> **Backups físicos:** `/mnt/disc-a00/Z01_BACKUPS/omarchy-backups/`

---

## Índice

1. [Estado Actual del Sistema](#1-estado-actual-del-sistema)
2. [Lo que YA está cubierto por Backup/Restore](#2-lo-que-ya-está-cubierto-por-backuprestore)
3. [Brechas: Lo que NO está cubierto](#3-brechas-lo-que-no-está-cubierto)
4. [Cambios Realizados en esta Sesión](#4-cambios-realizados-en-esta-sesión)
5. [Plan para Cerrar Brechas](#5-plan-para-cerrar-brechas)
6. [Checklist de Recuperación ante Desastres](#6-checklist-de-recuperación-ante-desastres)
7. [Diagrama de Cobertura](#7-diagrama-de-cobertura)

---

## 1. Estado Actual del Sistema

### Hardware

| Componente | Modelo | Detalle |
|-----------|--------|---------|
| CPU | Intel Core i5-7400 | 4C/4T @ 3.0GHz (Kaby Lake) |
| RAM | 23GB DDR4 | ~2400 MT/s |
| GPU 1 | Intel HD Graphics 630 | Integrada (i915 driver) |
| GPU 2 | NVIDIA GeForce GTX 1050 Ti | 4GB VRAM (nvidia driver) |
| Storage OS | 447GB SSD SATA | /dev/sdb |
| Storage datos | 931GB HDD | /dev/sda — `/mnt/blackpearl` (ext4) |
| Storage externo | 3.6TB HDD NTFS | /dev/sdc — `/mnt/disc-a00` |
| PSU | 500W OEM | Genérico |

### Software — Servicios Críticos

| Servicio | Estado | Puerto |
|----------|--------|--------|
| Hyprland (WM) | ✅ Corriendo | — |
| systemd-networkd | ✅ Corriendo | — |
| systemd-resolved | ✅ Corriendo | 53 |
| smb.service (Samba) | ✅ Corriendo | 139, 445 |
| nmb.service (NetBIOS) | ✅ Corriendo | 137, 138 |
| docker.service | ✅ Corriendo | — |
| Ollama (Docker) | ✅ Corriendo | 11434 |
| Dokploy (Docker) | ✅ Corriendo | 3000 |
| Traefik (Docker) | ✅ Corriendo | 80, 443 |
| UFW (firewall) | ✅ Activo | SMB, Localnet |

### Software — Paquetes Instalados Clave

| Paquete | Versión | Instalado |
|---------|---------|-----------|
| samba | 2:4.24.2-1 | ✅ |
| obs-studio | 32.1.2-3 | ✅ |
| audacity | 1:3.7.7-2 | ✅ |
| chromium | 148.0.7778.178-1 | ✅ |
| brave-bin | 1:1.91.180-1 | ✅ (AUR) |

### Red

| Configuración | Valor |
|--------------|-------|
| IP estática | 192.168.100.81/24 |
| Gateway | 192.168.100.1 |
| DNS | 9.9.9.9 (Quad9) |
| Interfaz | enp3s0 |
| Samba share | `\\192.168.100.81\disc-a00` |

---

## 2. Lo que YA está cubierto por Backup/Restore

### ✅ Cubierto por Git (GitHub) — `~/.dotfiles/`

| Componente | Ruta en Git | Restaurable vía |
|-----------|-------------|----------------|
| **Scripts** | `scripts/backup.sh`, `restore.sh`, `bootstrap.sh`, `samba-setup.sh`, `ollama-setup.sh`, `network-setup.sh`, `dokploy-setup.sh` | `git clone` + `restore.sh` |
| **Stow packages** | `stow_packages/{btop,fastfetch,git,lazygit,starship}/` | `git clone` + Stow |
| **Samba template** | `packages/samba/smb.conf` | `restore.sh` → `samba-setup.sh` |
| **Network template** | `packages/network/20-ethernet.network` | `restore.sh` → `network-setup.sh` |
| **Ollama config** | `packages/ollama/docker-compose.yml`, `Modelfiles/` | `restore.sh` → `ollama-setup.sh` |
| **Omarchy hooks** | `packages/omarchy-hooks/99-backup-dotfiles` | `restore.sh` |
| **Package lists** | `packages/pacman-official.txt`, `pacman-aur.txt` | `restore.sh` → `pacman -S` |
| **AGENTS.md** | `AGENTS.md` (documentación + system prompt) | `git clone` |
| **Spec DR** | `DISASTER_RECOVERY_SPEC.md` (este archivo) | `git clone` |

### ✅ Cubierto por backup físico en disco externo

| Componente | Cobertura | Script |
|-----------|-----------|--------|
| `/etc/` (incluye `/etc/samba/smb.conf`, `/etc/fstab`, configs de red) | `backup.sh --full` → tar.gz en disco externo (rotación: últimos 5) | `backup_etc()` |
| Dotfiles (copia completa del repo) | `backup.sh --full` → rsync a disco externo | `backup_to_external()` |
| Ollama blobs (modelos importados) | `backup.sh --full` → rsync a disco externo | `backup_ollama_state()` |
| Gentleman.Dots configs personales | `backup.sh --full` → rsync a disco externo | `backup_gentleman_dots()` |

---

## 3. Brechas: Lo que NO está cubierto

### 🔴 Brecha 1: `starship.toml` no es symlink de Stow

| Atributo | Valor |
|----------|-------|
| **Plan** | `~/.config/starship.toml → symlink ← STOW` |
| **Realidad** | Archivo regular (no symlink) en `~/.config/starship.toml` |
| **Impacto** | No está versionado en Git. Si se pierde, no se recupera. |
| **Cobertura DR** | ❌ Solo respaldo físico si se corre `backup.sh --full` (backup_gentleman_dots) |
| **Solución** | Mover a `~/.dotfiles/stow_packages/starship/.config/starship.toml` y re-stow |
| **Prioridad** | 🔴 **Alta** — pérdida de configuración del prompt |

### 🟡 Brecha 2: README.md desactualizado

| Atributo | Valor |
|----------|-------|
| **Plan** | Documento de planificación inicial |
| **Realidad** | No refleja Samba, Ollama, Goose, network-setup, ni los cambios actuales |
| **Impacto** | Bajo — el AGENTS.md es la fuente de verdad actualizada |
| **Solución** | Actualizar README.md o redirigir a AGENTS.md como documento principal |
| **Prioridad** | 🟡 Media |

### 🟡 Brecha 3: Montaje NTFS sin `noperm`

| Atributo | Valor |
|----------|-------|
| **Plan** | `rw,noatime,uid=1000,gid=1000,iocharset=utf8,prealloc` |
| **Realidad** | Se agregó `acl` al mount pero no `noperm` |
| **Impacto** | Potenciales conflictos de permisos entre ntfs3 ACLs y Samba |
| **Cobertura DR** | ✅ `/etc/fstab` se respalda en `backup.sh --full` (backup_etc) |
| **Solución** | Agregar `noperm` a las opciones de montaje en `/etc/fstab` (requiere sudo) |
| **Prioridad** | 🟡 Media — recomendado para estabilidad de Samba a largo plazo |

### 🟢 Brecha 4: `packages/flatpak.txt` no existe

| Atributo | Valor |
|----------|-------|
| **Plan** | Mencionado en estructura de directorios |
| **Realidad** | No hay flatpaks instalados, el archivo no se genera |
| **Impacto** | Ninguno — `backup.sh` lo maneja con `|| true` |
| **Prioridad** | 🟢 Baja — documentar como opcional |

### 🟢 Brecha 5: `.gitignore` mínimo

| Atributo | Valor |
|----------|-------|
| **Plan** | No especificado |
| **Realidad** | Solo excluye `.DS_Store`, `Thumbs.db`, `*.swp`, `*.swo`, `*~`, `scripts/*.tmp` |
| **Impacto** | Bajo — funcional pero podría excluir más (`.env`, `*.log`) |
| **Prioridad** | 🟢 Baja |

### 🟢 Brecha 6: Configs de aplicaciones no versionadas

| Configuración | Ruta | ¿En backup? |
|--------------|------|-------------|
| Hyprland monitors.conf (GDK_SCALE) | `~/.config/hypr/monitors.conf` | ❌ No (Omarchy domain) |
| Audacity desktop override (Wayland) | `~/.local/share/applications/audacity.desktop` | ❌ No |
| Brave flags (Wayland) | `~/.config/brave-flags.conf` | ❌ No |
| Chromium flags (Wayland) | `~/.config/chromium-flags.conf` | ❌ No |

**Nota:** Estos configs son específicos del usuario local y no críticos para la recuperación del servidor (son ajustes de UI). En caso de desastre, se pueden re-aplicar manualmente en minutos. Si se desea automatizar, se pueden agregar a `bootstrap.sh` o como hooks de Omarchy.

---

## 4. Cambios Realizados en esta Sesión

### 4.1 Samba — Corrección de Acceso y Escritura desde Windows

| # | Cambio | Archivo | Estado |
|---|--------|---------|--------|
| 1 | Abrir puertos 139/tcp y 445/tcp en UFW | `sudo ufw allow` | ✅ Aplicado |
| 2 | Iniciar y habilitar `nmb.service` | `sudo systemctl enable --now nmb` | ✅ Aplicado |
| 3 | `server signing = mandatory` → `auto` | `/etc/samba/smb.conf` | ✅ Aplicado |
| 4 | Crear `scripts/samba-setup.sh` | `~/.dotfiles/scripts/samba-setup.sh` | ✅ Versionado |
| 5 | Crear `packages/samba/smb.conf` (template) | `~/.dotfiles/packages/samba/smb.conf` | ✅ Versionado |
| 6 | Eliminar password hardcodeado `Dominito@2020` | `~/.dotfiles/scripts/samba-setup.sh` | ✅ Usa `SAMBA_PASSWORD` env var |
| 7 | Agregar guard para `SAMBA_PASSWORD` vacío | `~/.dotfiles/scripts/samba-setup.sh` | ✅ Warn + fallback manual |
| 8 | Agregar nota de password Samba en restore | `~/.dotfiles/scripts/restore.sh` | ✅ Paso en checklist final |
| 9 | Doc: regla MANDATORIA sobre password | `AGENTS.md` §1.6 regla #4 | ✅ Versionado |
| 10 | Doc: Samba flags `--restart`, puertos UFW, nmb | `AGENTS.md` §2.12 | ✅ Versionado |

**Backup coverage:** ✅ Todo versionado en Git + `/etc/samba/smb.conf` respaldado en `backup.sh --full`

### 4.2 Escalado HiDPI — Audacity + Brave/Chromium

| # | Cambio | Archivo | Estado |
|---|--------|---------|--------|
| 1 | `GDK_SCALE=2` → `GDK_SCALE=1` global | `~/.config/hypr/monitors.conf` | ✅ Aplicado (requiere logout) |
| 2 | Audacity: `GDK_BACKEND=x11` → `wayland` | `~/.local/share/applications/audacity.desktop` | ✅ Aplicado |
| 3 | Brave: flags Wayland nativo | `~/.config/brave-flags.conf` | ✅ Creado |
| 4 | Chromium: flags Wayland nativo | `~/.config/chromium-flags.conf` | ✅ Creado |

**Backup coverage:** ❌ Ninguno de estos archivos está versionado en Git ni respaldado por `backup.sh`. Son configs de UI específicos del usuario.

### 4.3 Documentación

| # | Cambio | Archivo | Estado |
|---|--------|---------|--------|
| 1 | AGENTS.md actualizado | `~/.dotfiles/AGENTS.md` | ✅ Commit `705d0a3` |
| 2 | Spec de brechas y DR (este archivo) | `DISASTER_RECOVERY_SPEC.md` | ✅ Creado |

---

## 5. Plan para Cerrar Brechas

### Fase 1 — Inmediata (próxima sesión)

- [ ] **🔴 Brecha 1**: Mover `starship.toml` a Stow
  ```bash
  mkdir -p ~/.dotfiles/stow_packages/starship/.config
  mv ~/.config/starship.toml ~/.dotfiles/stow_packages/starship/.config/starship.toml
  cd ~/.dotfiles/stow_packages && stow --restow --target=$HOME starship
  cd ~/.dotfiles && git add -A && git commit -m "fix: starship.toml ahora es symlink de Stow" && git push
  ```

### Fase 2 — Mantenimiento

- [ ] **🟡 Brecha 2**: Actualizar README.md o redirigir a AGENTS.md
- [ ] **🟡 Brecha 3**: Agregar `noperm` al mount NTFS
  ```bash
  # Requiere sudo y editar /etc/fstab
  # Cambiar: UUID=... /mnt/disc-a00 ntfs3 rw,noatime,uid=1000,gid=1000,acl,iocharset=utf8,prealloc 0 0
  # A:        UUID=... /mnt/disc-a00 ntfs3 rw,noatime,uid=1000,gid=1000,noperm,iocharset=utf8,prealloc 0 0
  sudo sed -i 's/,acl,/,noperm,/' /etc/fstab
  sudo mount -o remount /mnt/disc-a00
  ```

### Fase 3 — Automatización (deseable)

- [ ] Agregar los configs de UI a `bootstrap.sh` o hooks de Omarchy:
  - `~/.config/brave-flags.conf`
  - `~/.config/chromium-flags.conf`
  - `~/.local/share/applications/audacity.desktop`
- [ ] **🟢 Brecha 5**: Mejorar `.gitignore` (agregar `.env`, `*.log`, `node_modules/`)

---

## 6. Checklist de Recuperación ante Desastres

### Escenario: Instalación limpia de Omarchy (o cualquier Arch Linux)

```bash
# ═══════════════════════════════════════════════════════════════
# PASO 1 — Prerequisitos
# ═══════════════════════════════════════════════════════════════
sudo pacman -S git stow

# ═══════════════════════════════════════════════════════════════
# PASO 2 — Clonar dotfiles
# ═══════════════════════════════════════════════════════════════
git clone git@github.com:RaymundoYcaza/dotfiles.git ~/.dotfiles

# ═══════════════════════════════════════════════════════════════
# PASO 3 — Restauración completa (automática)
# ═══════════════════════════════════════════════════════════════
cd ~/.dotfiles && ./scripts/restore.sh --auto
```

### Post-restauración manual (verificar cada uno):

- [ ] **Red**: `ip addr show` → IP debe ser `192.168.100.81/24`
- [ ] **Samba**: Probar `smbclient -L localhost -N` → debe listar `disc-a00`
- [ ] **Samba password**: `sudo smbpasswd inorizonti` (configurar contraseña)
- [ ] **Samba desde Windows**: Acceder a `\\192.168.100.81\disc-a00`
- [ ] **Samba UFW**: `sudo ufw status` → puertos 139, 445 deben estar abiertos
- [ ] **Disco externo**: `ls /mnt/disc-a00/Z01_BACKUPS/` → debe montarse automáticamente
- [ ] **Ollama**: `sudo ~/.dotfiles/scripts/ollama-setup.sh` (si aplica)
- [ ] **Dokploy**: Verificar contenedores con `docker ps`
- [ ] **Claves SSH/GPG**: Restaurar desde backup
- [ ] **Audacity** → Si se ve mal: `GDK_BACKEND=wayland audacity` (probar)
- [ ] **Brave/Chromium** → Si páginas se ven mal: verificar `brave://gpu` (Ozone: wayland)
- [ ] **Starship** → Si no hay prompt bonito: instalar con `restore.sh` o Stow manual

### Si se necesita recovery desde backup físico:

```bash
# Backup de /etc/ (incluye smb.conf, fstab, network, etc.)
ls /mnt/disc-a00/Z01_BACKUPS/omarchy-backups/etc/
sudo tar -xzf /mnt/disc-a00/Z01_BACKUPS/omarchy-backups/etc/etcbak-*.tar.gz -C /

# Modelos de IA (Ollama blobs)
ls /mnt/disc-a00/Z01_BACKUPS/omarchy-backups/ollama-state/
rsync -av /mnt/disc-a00/Z01_BACKUPS/omarchy-backups/ollama-state/ /mnt/disc-a00/Z01-DEVOPS/state/ollama/
```

---

## 7. Diagrama de Cobertura

```
                      ┌─────────────────────────────────────┐
                      │         SISTEMA OMARCHY              │
                      └─────────────────────────────────────┘
                                     │
            ┌────────────────────────┼────────────────────────┐
            │                        │                        │
            ▼                        ▼                        ▼
   ┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐
   │  GIT (GitHub)    │    │  BACKUP FÍSICO   │    │  NO CUBIERTO     │
   │  ~/.dotfiles/    │    │  /mnt/disc-a00/  │    │  (manual)        │
   ├─────────────────┤    ├──────────────────┤    ├──────────────────┤
   │ scripts/        │    │ /etc/*.tar.gz    │    │ ~/.config/hypr/  │
   │ stow_packages/  │    │  (smb.conf,      │    │  (monitors.conf) │
   │ packages/       │    │   fstab, network) │    │ ~/.config/*-     │
   │ AGENTS.md       │    │ dotfiles/        │    │  flags.conf      │
   │ DISASTER_SPEC   │    │  (rsync)         │    │ ~/.local/share/  │
   │                 │    │ ollama-state/    │    │  applications/   │
   │ ✅ Commit 705d0a3│    │ gentleman-dots/  │    │  (audacity.desktop)│
   └─────────────────┘    └──────────────────┘    └──────────────────┘
          ▲                        ▲                        ▲
          │                        │                        │
   restore.sh --auto      backup.sh --full          Re-aplicar
                                                     manualmente
```

---

## Apéndice A: Comandos de Verificación Rápida

```bash
# Verificar estado del sistema post-restauración
echo "=== IP ===" && ip addr show enp3s0 | grep 'inet '
echo "=== Samba ===" && smbclient -L localhost -N 2>/dev/null | grep -E 'disc|Sharename'
echo "=== Samba services ===" && systemctl is-active smb nmb
echo "=== Samba users ===" && sudo pdbedit -L 2>/dev/null || echo "No users"
echo "=== UFW ===" && sudo ufw status | grep -E '(139|445)'
echo "=== Docker ===" && docker ps --format '{{.Names}}'
echo "=== Discos ===" && mount | grep -E 'disc|blackpearl'
echo "=== Ollama ===" && curl -s http://192.168.100.81:11434/api/tags | head -c 200
```

## Apéndice B: Último Commit de Referencia

```
705d0a3 fix: Samba - server signing auto, password via env var, firewall rules + docs
```

---

*Documento generado el 2026-06-28 como parte de la auditoría de brechas del proyecto configuracion-omarchy.*

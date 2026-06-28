# Ollama — Gestión de Modelos

Este directorio contiene los **Modelfiles** para importar modelos GGUF
existentes (desde `/mnt/blackpearl/lmstudio_models/`) a Ollama.

---

## 📋 Workflow Completo

### 1. Ver modelos GGUF disponibles

```bash
ls /mnt/blackpearl/lmstudio_models/*/*.gguf
```

### 2. Crear un Modelfile

Cada archivo define un modelo. El contenido es una sola línea:

```dockerfile
FROM /models/<directorio>/<archivo>.gguf
```

Ejemplo — crear `Modelfiles/qwen3.5-0.8b`:

```bash
echo 'FROM /models/diodel/Qwen3.5-0.8B-Q4_K_M-GGUF/qwen3.5-0.8b-Q4_K_M.gguf' \
  > Modelfiles/qwen3.5-0.8b
```

### 3. Importar a Ollama

```bash
cd /mnt/disc-a00/Z01-DEVOPS/containers/ollama
docker compose exec ollama ollama create <nombre> -f /Modelfiles/<archivo>
```

Ejemplo:

```bash
docker compose exec ollama ollama create qwen3.5-0.8b -f /Modelfiles/qwen3.5-0.8b
```

### 4. Verificar

```bash
docker compose exec ollama ollama list
```

### 5. Probar

```bash
curl http://192.168.100.81:11434/api/generate -d '{
  "model": "<nombre>",
  "prompt": "Hola, ¿cómo estás?",
  "stream": false
}'
```

### 6. Versionar el Modelfile en Git

```bash
cp Modelfiles/<nombre> ~/.dotfiles/packages/ollama/Modelfiles/
cd ~/.dotfiles && git add -A && git commit -m "feat: add Modelfile for <nombre>"
git push
```

Así, en una futura restauración se puede reimportar automáticamente.

---

## 📊 Modelos disponibles actualmente

| Ruta en /models | Modelo | Tamaño | VRAM estimada |
|-----------------|--------|--------|--------------|
| `diodel/Qwen3.5-0.8B-Q4_K_M-GGUF/qwen3.5-0.8b-Q4_K_M.gguf` | Qwen3.5-0.8B | 0.8B params | ~600 MB ✅ |
| `jc-builds/Qwen3.5-9B-Q4_K_M-GGUF/Qwen3.5-9B-Q4_K_M.gguf` | Qwen3.5-9B | 9B params | ~5.5 GB 🚫 |
| `llmfan46/gemma-4-12B-it-qat-q4_0-uncensored-heretic-GGUF/gemma-4-12B-it-qat-q4_0-uncensored-heretic-Q4_0.gguf` | Gemma-4-12B | 12B params | ~7 GB 🚫 |
| `mradermacher/Leyes-Ecuador-20250825-200051-GGUF/Leyes-Ecuador-20250825-200051.Q4_K_S.gguf` | Leyes-Ecuador | ~7B params | ~4.5 GB 🚫 |
| `Offensivesec/ubuntu-support-llm/ubuntu-support-Q4_K_M.gguf` | ubuntu-support | ~3B params | ~2 GB ✅ |

✅ = Cabe en GTX 1050 Ti (4GB VRAM)
🚫 = Requiere CPU offloading o más VRAM

Ya importado: **Qwen3.5-0.8b** ✅

---

## 🔄 Restauración automática de modelos

Si se pierde el state/ollama (blobs), los modelos se pueden reimportar
desde los Modelfiles versionados:

```bash
cd /mnt/disc-a00/Z01-DEVOPS/containers/ollama
for mf in ~/.dotfiles/packages/ollama/Modelfiles/*; do
  name=$(basename "$mf")
  docker compose exec ollama ollama create "$name" -f "/Modelfiles/$name"
done
```

---

## ☁️ Modelos Cloud (ollama.com)

Además de modelos GGUF locales, Ollama puede usar **modelos cloud** que se
ejecutan en los servidores de ollama.com (ej: `gemma4:31b-cloud`,
`llama4:70b-cloud`). Útiles cuando un modelo no cabe en tu VRAM o querés
probar modelos grandes sin descargarlos.

### Autenticación

```bash
# 1. Iniciar sesión (interactivo, una sola vez)
docker exec -it ollama ollama signin
# → Abrir https://ollama.com/device en el navegador
# → Ingresar el código de verificación

# 2. Verificar que está autenticado
docker exec ollama ollama list

# 3. Probar un modelo cloud
docker exec ollama ollama run gemma4:31b-cloud "Hola"

# 4. Cerrar sesión (para cambiar de usuario)
docker exec ollama ollama signout
```

La sesión persiste aunque el contenedor se reinicie (se guarda en
`state/ollama/`).

### API Key (alternativa programática)

```bash
# Generar key en https://ollama.com/settings
curl https://ollama.com/api/chat \
  -H "Authorization: Bearer <api-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma4:31b-cloud",
    "messages": [{"role": "user", "content": "Hola"}],
    "stream": false
  }'
```

---

## 🦆 Goose — Configuración con Ollama

**Goose** es un agente AI de código abierto que puede usar Ollama como
provider, tanto para modelos locales GGUF como para modelos cloud.

### Configurar Goose para Ollama local (ya autenticado)

```bash
# Configuración interactiva
goose configure
# → Seleccionar Ollama como provider
# → Host: http://192.168.100.81:11434
# → Model: gemma4:31b-cloud (o cualquier modelo local/cloud)

# O editar ~/.config/goose/config.yaml directamente:
# GOOSE_PROVIDER: ollama
# OLLAMA_HOST: http://192.168.100.81:11434
# GOOSE_MODEL: gemma4:31b-cloud
```

### Configurar Goose para Ollama Cloud directo

Si preferís que Goose hable directo con ollama.com (sin pasar por tu
servidor local), usá la API key:

```yaml
# ~/.config/goose/config.yaml
GOOSE_PROVIDER: ollama
OLLAMA_HOST: https://ollama.com
OLLAMA_CLOUD_API_KEY: "tu-api-key"
GOOSE_MODEL: gemma4:31b-cloud
```

### Uso diario

```bash
# CLI interactivo
goose

# Comando directo
goose run "Genera una función que invierta una lista enlazada en Python"

# Desktop (GUI)
goose-desktop
```

Goose consulta a Ollama via API OpenAI-compatible (`/v1/chat/completions`).
Ollama decide si el modelo corre local (GGUF en GPU) o en cloud
(modelos `*-cloud` autenticados).

---

## 🧪 API OpenAI compatible

Endpoint: `http://192.168.100.81:11434/v1`

```bash
# Chat completion
curl http://192.168.100.81:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3.5-0.8b",
    "messages": [{"role": "user", "content": "Hola"}],
    "stream": false
  }'

# Embeddings
curl http://192.168.100.81:11434/api/embed \
  -d '{
    "model": "qwen3.5-0.8b",
    "input": "Texto a vectorizar"
  }'
```

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

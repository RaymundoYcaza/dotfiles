# Modelfiles para Ollama

Los Modelfiles permiten importar modelos GGUF existentes (desde
`/mnt/blackpearl/lmstudio_models/`) a Ollama sin descargarlos de nuevo.

## Uso

Cada archivo en este directorio define un modelo. El contenido típico es:

```dockerfile
FROM /models/<directorio>/<archivo>.gguf
```

Para importar un modelo a Ollama:

```bash
cd /mnt/disc-a00/Z01-DEVOPS/containers/ollama
docker compose exec ollama ollama create <nombre> -f /Modelfiles/<archivo>
```

## Modelos disponibles

| Directorio en /models | Modelo | Tamaño |
|-----------------------|--------|--------|
| `diodel/Qwen3.5-0.8B-Q4_K_M-GGUF/` | Qwen3.5-0.8B | 0.8B params ✅ |
| `jc-builds/Qwen3.5-9B-Q4_K_M-GGUF/` | Qwen3.5-9B | 9B params 🚫 (no cabe) |
| `llmfan46/gemma-4-12B-it-qat-q4_0-...-GGUF/` | Gemma-4-12B | 12B params 🚫 |
| `mradermacher/Leyes-Ecuador-...-GGUF/` | Leyes-Ecuador | ~7B params 🚫 |
| `Offensivesec/ubuntu-support-llm/` | ubuntu-support | ~3B params ✅ |

✅ = Cabe en GTX 1050 Ti (4GB VRAM)
🚫 = Requiere CPU offloading o más VRAM

## Ejemplo: importar Qwen3.5-0.8B

Crea `Modelfiles/qwen3.5-0.8b` con:

```dockerfile
FROM /models/diodel/Qwen3.5-0.8B-Q4_K_M-GGUF/qwen3.5-0.8b-Q4_K_M.gguf
```

Luego ejecuta:

```bash
cd /mnt/disc-a00/Z01-DEVOPS/containers/ollama
docker compose exec ollama ollama create qwen3.5-0.8b -f /Modelfiles/qwen3.5-0.8b
```

Para probar:

```bash
curl http://192.168.100.81:11434/api/generate -d '{
  "model": "qwen3.5-0.8b",
  "prompt": "Hola, ¿cómo estás?"
}'
```

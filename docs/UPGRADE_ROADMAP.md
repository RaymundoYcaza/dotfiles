# Upgrade Roadmap: Hacia una AMD Radeon RX 7900 XTX (24GB)

> **Propósito:** Documentar el estado actual del hardware, los componentes necesarios para
> soportar una RX 7900 XTX, y el orden progresivo de compras para optimizar el flujo de caja.
>
> **Meta final:** Ejecutar modelos de IA localmente con 24GB de VRAM en Omarchy + Arch Linux,
> usando ROCm (Ollama, vLLM, PyTorch, etc.)
>
> **Fecha:** 2026-06-28

---

## 📊 Estado Actual del Hardware

| Componente | Modelo | Especificación | ¿Válido para 7900 XTX? |
|-----------|--------|---------------|----------------------|
| **CPU** | Intel Core i5-7400 | 4C/4T @ 3.0GHz (Kaby Lake, LGA1151) | ❌ Bottleneck severo |
| **Motherboard** | ASUS PRIME B250M-A | LGA1151, DDR4, PCIe 3.0 x16, mATX | ❌ Socket obsoleto |
| **RAM** | 23GB DDR4 | Velocidad por confirmar (prob. 2133/2400 MT/s) | ⚠️ DDR4 aceptable pero lenta |
| **GPU actual** | NVIDIA GTX 1050 Ti | 4GB VRAM, PCIe 3.0 | ❌ Reemplazar |
| **GPU objetivo** | AMD Radeon RX 7900 XTX | 24GB VRAM, PCIe 4.0 x16, ~350W TBP | 🎯 Meta |
| **PSU** | 500W (genérico OEM) | Sin datos de certificación | ❌ Insuficiente |
| **Storage OS** | 447GB SSD (SATA) | sdb, lectura secuencial ~500 MB/s | ⚠️ Funciona, NVMe ideal |
| **Storage datos** | 931GB HDD | sda, 7200rpm | ✅ Para datos/almacenamiento |
| **Storage externo** | 3.6TB HDD NTFS | sdc - /mnt/disc-a00 | ✅ Externo |
| **Case** | Por confirmar | mATX (por motherboard actual) | ⚠️ Puede no caber GPU de >340mm |
| **OS** | Arch Linux (Omarchy) | Rolling release | ✅ ROCm tiene buen soporte Linux |

---

## 🧮 Análisis de Compatibilidad

### Cuello de botella CPU-GPU
El i5-7400 tiene **4 núcleos sin Hyper-Threading** y es de 2017. Incluso para inferencia
de modelos (donde la GPU hace el trabajo pesado), el CPU se encarga de:
- Tokenización/preprocesamiento de texto
- Carga de modelos a VRAM
- Comunicación PCIe
- Sistema operativo + Docker + servicios

Con una 7900 XTX, el i5-7400 **limitará severamente** el rendimiento general del sistema
y la velocidad de carga de modelos.

### PCIe 3.0 vs 4.0
La 7900 XTX es PCIe 4.0 x16, pero es compatible con PCIe 3.0 x16. En workloads de
inferencia de modelos, la diferencia entre PCIe 3.0 y 4.0 es **marginal (<5%)** porque
los pesos se cargan una vez y permanecen en VRAM. Sin embargo, el B250M-A solo tiene
**PCIe 3.0**, y el slot x16 comparte ancho de banda con otros dispositivos.

### Fuente de poder
500W es **insuficiente**. La 7900 XTX tiene un TBP de ~355W y picos transitorios de
hasta **450W**. Solo la GPU necesita 355W, dejando solo 145W para CPU, RAM, discos,
ventiladores, USB — insuficiente para un i5-7400 (65W TDP) y el resto del sistema.
Recomendación: **850W+ 80+ Gold como mínimo, 1000W ideal**.

### Espacio físico
La motherboard actual es **mATX** (24.4 x 22.6 cm). Muchas 7900 XTX de gama alta
(ASUS TUF, Sapphire Nitro+) miden ~350mm de largo y ocupan 3 slots. Se debe verificar
que el case actual tenga espacio para una GPU de ese tamaño.

---

## 🛒 Orden de Compra Recomendado (Optimizado por Flujo de Caja)

### Fase 1 — Fuente de Poder (~$100-150)
**Inversión inicial que ya se beneficia hoy**

| Componente | Recomendación | Precio estimado |
|-----------|--------------|----------------|
| **PSU** | Corsair RM850x (850W, 80+ Gold, modular) | ~$130 |
| Alternativa | EVGA SuperNOVA 850 G7, Be Quiet! Pure Power 12M 850W | ~$110-140 |

**¿Por qué primero?**
- Se puede instalar AHORA y funciona con el sistema actual
- La PSU actual (500W) es el riesgo más inmediato
- Una buena PSU dura 10+ años y sirve para cualquier build futuro
- La 7900 XTX necesita mínimo 800W

**Checklist:**
- [ ] Adquirir PSU de 850W+ (modular recomendado)
- [ ] Verificar que tenga 3 conectores PCIe 8-pin (para AIBs de gama alta)
- [ ] Instalar y cable management
- [ ] ⚡ Beneficio inmediato: sistema más estable desde hoy

---

### Fase 2 — Plataforma: CPU + Motherboard + RAM (~$400-700)
**El upgrade más grande, necesario para que la 7900 XTX vuele**

#### Opción A: AMD AM5 (Recomendado para IA/Rendimiento)
| Componente | Recomendación | Precio |
|-----------|--------------|--------|
| **CPU** | AMD Ryzen 7 7700X (8C/16T) o Ryzen 7 9700X | ~$250-350 |
| **Motherboard** | ASUS TUF GAMING B650-PLUS (ATX, PCIe 4.0/5.0) | ~$180 |
| **RAM** | 32GB (2x16GB) DDR5-6000 CL30 (Ej: G.Skill Flare X5) | ~$100 |
| **Total** | | ~$530-630 |

#### Opción B: Intel LGA1700 (Buena relación costo/beneficio)
| Componente | Recomendación | Precio |
|-----------|--------------|--------|
| **CPU** | Intel Core i5-14600K (14C/20T) o i7-14700K | ~$220-350 |
| **Motherboard** | ASUS PRIME Z790-P o B760 (DDR5) | ~$160-200 |
| **RAM** | 32GB (2x16GB) DDR5-6000 CL30 | ~$100 |
| **Total** | | ~$480-650 |

#### Opción C: Usado / Socket LGA1700 low-cost
| Componente | Recomendación | Precio |
|-----------|--------------|--------|
| **CPU** | Intel Core i5-12600K (10C/16T) usado | ~$100-120 |
| **Motherboard** | B660/B760 DDR4 usada | ~$60-80 |
| **RAM** | 32GB (2x16GB) DDR4-3200 (reutilizar o comprar) | ~$40-50 |
| **Total** | | ~$200-250 |

**¿Por qué segunda?**
- Sin plataforma moderna, la 7900 XTX no puede rendir
- DDR5 y PCIe 4.0/5.0 son necesarios para máximo ancho de banda
- Se puede diferir comprando usado (Opción C)

**Checklist:**
- [ ] Decidir entre AM5 (recomendado), LGA1700, o usado
- [ ] Verificar que el case sea ATX (no solo mATX) — si no, comprar case en esta fase
- [ ] Adquirir CPU + Motherboard + RAM
- [ ] Instalar — implica desmontar todo, instalar nueva placa, CPU, RAM
- [ ] Transferir SSD/HDD existentes a la nueva placa
- [ ] Probar que el sistema bootea y funciona
- [ ] Reinstalar Arch/Omarchy o reparar bootloader

---

### Fase 2.5 — Case (si aplica, ~$60-100)
Si el case actual no tiene espacio para una GPU de 340mm+:

| Componente | Recomendación | Precio |
|-----------|--------------|--------|
| **Case** | Fractal Design Pop Air, Corsair 4000D, NZXT H5 Flow | ~$70-100 |

Se puede comprar junto con la plataforma (Fase 2) o antes si se necesita espacio.

---

### Fase 3 — SSD NVMe (Opcional, ~$60-100)
Para mejorar velocidad de carga de modelos y sistema:

| Componente | Recomendación | Precio |
|-----------|--------------|--------|
| **NVMe** | Samsung 990 Pro 1TB, WD Black SN850X 1TB | ~$80-100 |
| Alternativa | TeamGroup MP44 1TB, Crucial T500 1TB | ~$60-80 |

Los modelos de IA ocupan espacio. Qwen3.5-9B = 5.5GB, Gemma-4-12B = 7GB, modelos
de 70B pueden ocupar 40-50GB. Un NVMe de 1TB da espacio cómodo.

**Checklist:**
- [ ] Adquirir NVMe de 1TB+
- [ ] Instalar en slot M.2 de la nueva motherboard
- [ ] Mover modelos de IA a NVMe para carga más rápida

---

### Fase 4 — AMD Radeon RX 7900 XTX (~$800-1000)
**La pieza final — el motivo de todo el upgrade**

| Componente | Recomendación | Precio |
|-----------|--------------|--------|
| **GPU** | Sapphire Pulse RX 7900 XTX 24GB | ~$850 |
| Alternativa | ASUS TUF RX 7900 XTX, PowerColor Red Devil | ~$900-1000 |

**¿Por qué última?**
- Es la inversión más grande (~$800-1000)
- Sin PSU y plataforma adecuadas, no funcionaría (o funcionaría mal)
- Instalarla al final permite verificar que todo el sistema está listo

**Checklist:**
- [ ] Verificar que la PSU de 850W+ tiene los conectores necesarios
- [ ] Verificar que el case tiene espacio físico (largo + slots)
- [ ] Adquirir RX 7900 XTX
- [ ] Retirar GTX 1050 Ti
- [ ] Instalar RX 7900 XTX
- [ ] Conectar cables PCIe de la PSU
- [ ] Instalar drivers AMD / ROCm
- [ ] Configurar Ollama para usar ROCm
- [ ] Probar modelos grandes (Qwen3.5-9B, Gemma-4-12B, Leyes-Ecuador-7B)
- [ ] Verificar que los modelos que antes no cabían ahora funcionan

---

## 📋 Resumen de Costos

| Fase | Componentes | Costo mínimo | Costo recomendado |
|------|------------|-------------|------------------|
| 1 | PSU 850W+ | ~$100 | ~$130 |
| 2 | CPU + Mobo + RAM | ~$200 (usado) | ~$550 (AM5) |
| 2.5 | Case (si aplica) | ~$60 | ~$80 |
| 3 | NVMe 1TB (opcional) | ~$60 | ~$80 |
| 4 | RX 7900 XTX | ~$800 | ~$900 |
| **Total** | | **~$1,220** | **~$1,740** |

---

## 🎯 Modelos que correrán con la 7900 XTX (24GB VRAM)

| Modelo | Tamaño | Cuantización | VRAM estimada | Antes (4GB) | Después (24GB) |
|--------|--------|-------------|--------------|------------|---------------|
| Qwen3.5-0.8B | 0.8B | Q4_K_M | ~600 MB | ✅ Corría | ✅ |
| ubuntu-support | ~3B | Q4_K_M | ~2 GB | ✅ Corría | ✅ |
| Qwen3.5-9B | 9B | Q4_K_M | ~5.5 GB | 🚫 No cabía | ✅ |
| Leyes-Ecuador | ~7B | Q4_K_S | ~4.5 GB | 🚫 No cabía | ✅ |
| Gemma-4-12B | 12B | Q4_0 | ~7 GB | 🚫 No cabía | ✅ |
| **DeepSeek-R1** (ejemplo) | ~67B | IQ2_XS | ~20 GB | 🚫 | ✅ Justo |
| **Llama 3.1** (ejemplo) | ~70B | Q2_K | ~22 GB | 🚫 | ✅ Justo |
| **Qwen3.5-32B** (ejemplo) | 32B | Q4_K_M | ~18 GB | 🚫 | ✅ |
| **Gemma-4-27B** (ejemplo) | 27B | Q4_K_M | ~16 GB | 🚫 | ✅ |

---

## 📝 Notas Técnicas

### ROCm en Arch Linux (Omarchy)
Ollama soporta ROCm de forma nativa. Con la 7900 XTX:
```bash
# Verificar que ROCm detecta la GPU
rocm-smi

# Ollama usará ROCm automáticamente
ollama serve

# Verificar
ollama run qwen3.5-9b
```

### Alternativa: LM Studio
LM Studio también soporta ROCm y es más amigable para probar modelos.

### Consideraciones de Puertos
La 7900 XTX tiene DisplayPort 2.1 y HDMI 2.1. Para monitor 4K @ 120Hz+ se necesita
DisplayPort 2.1 o HDMI 2.1. Verificar que el monitor sea compatible.

---

## 📐 Espacio Físico — Verificación

Antes de comprar la GPU, medir el case:

```bash
# Ancho máximo de GPU (largo desde el bracket hasta el extremo)
# Medir desde la parte trasera del case hasta el frente
echo "Medir con cinta métrica el espacio disponible para GPU"

# Slots PCIe disponibles
lspci | grep -c 'PCI bridge'
# La 7900 XTX ocupa 2.5-3 slots
```

---

*Documento generado el 2026-06-28 para planificar el upgrade progresivo del servidor MaxiMax.*

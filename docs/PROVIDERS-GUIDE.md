# ARNES ARGOS — Guía de Conexiones y Proveedores

> **Mini-guía de proveedores**: cómo se conecta ARGOS a cada suscripción/API.
> Verificado: 2026-08-05 · Todo esto vive en tu máquina, listo para usar.

---

## 🌐 Resumen: ARGOS usa OpenCode como motor

```
TÚ → "atlas" en CMD → ARNES ARGOS Shell
        ├─ [1] Chat → opencode --agent atlas-player  (el motor de agentes)
        ├─ [2] Wizard modelos → opencode models (catálogo vivo)
        └─ Configuración → .arnes/config.json + ~/.config/opencode/opencode.json
```

**No necesitas abrir Codex ni Claude por separado.** ARGOS orquesta; OpenCode ejecuta;
los proveedores (Go/OpenAI/NVIDIA/B.AI) dan los modelos.

---

## 🔑 Proveedores conectados (verificado con `opencode auth list`)

| Proveedor | Auth | Base URL | Cómo conecta |
|---|---|---|---|
| **OpenCode Go** | api | catálogo: `https://opencode.ai/zen/go/v1/models` | Suscripción $10/mes — IDs tipo `opencode-go/qwen3.8-max` |
| **OpenAI** | **oauth** (cuenta GPT) | `https://api.openai.com/v1` | Login por CUENTA (no API key) — 13 modelos GPT-5.x |
| **NVIDIA NIM** | api | `https://integrate.api.nvidia.com/v1` | API key gratis (1000-5000 credits, 40 req/min) |
| **B.AI** | api key | `https://api.b.ai/v1` | Da acceso a Claude Opus 4.8/5, Fable 5, GPT-5.6, Qwen3.8 |
| **Z.AI** | api | `https://open.bigmodel.cn/api/paas/v4` | GLM (Zhipu) |
| **SiliconFlow** | api | `https://api.siliconflow.cn/v1` | Modelos open-source |
| **TokenRouter** | api | `https://api.tokenrouter.com/v1` | Kimi K3 free, ruteo |
| **MiniMax** | token plan | — | Plan de tokens MiniMax |

---

## 🧠 Cómo se conecta cada tipo

### OpenCode Go (suscripción)
```bash
opencode auth login      # → selecciona "OpenCode Go"
# Ya autenticado: opencode auth list muestra "OpenCode Go (api)"
# Catálogo: https://opencode.ai/zen/go/v1/models
# Modelos: opencode-go/deepseek-v4-flash, opencode-go/gpt-5.6-luna, opencode-go/qwen3.8-max
```

### OpenAI (cuenta GPT — OAuth, NO API key)
```bash
argos connect            # → elige "openai" → verifica la sesion y la marca conectada
                         #   (si aun no hay sesion, lanza el flujo real de autorizacion)
# Manual (equivalente):
opencode auth login      # → selecciona "OpenAI"
                         # → elige "ChatGPT Plus/Pro (Codex Subscription)"
                         # → se abre el navegador → te logueas con tu cuenta
                         # → OpenCode detecta tu plan automáticamente
# Ya autenticado: "OpenAI (oauth)"
# Sesion guardada en ~/.local/share/opencode/auth.json (persiste entre sesiones)
# Modelos: openai/gpt-5.6-sol, openai/gpt-5.6-terra, openai/gpt-5.6-luna...
```

### NVIDIA (API gratis)
```bash
# 1. Obtén tu key en https://build.nvidia.com (gratis, 1000-5000 credits)
# 2. Configura la variable de entorno:
setx NVIDIA_API_KEY "nvapi-XXXX..."    # PowerShell (persistente)

# Ya configurado en opencode.json:
# "nvidia": { "baseURL": "https://integrate.api.nvidia.com/v1", "apiKey": "env:NVIDIA_API_KEY" }
# Modelos: nvidia/deepseek-ai/deepseek-v4-flash, nvidia/deepseek-ai/deepseek-v4-pro (GRATIS)
```

### B.AI (Claude sin cuenta de Anthropic)
```bash
# Ya configurado con API key en opencode.json
# Modelos: bai/claude-opus-5, bai/claude-fable-5, bai/gpt-5.6-sol, bai/qwen3.8-max...
```

---

## 🎯 Asignación actual de modelos por agente (config.json)

| Agente | Modelo | Proveedor | Costo |
|---|---|---|---|
| Atlas | qwen3.8-max | OpenCode Go / B.AI | plan |
| Vivi | gpt-5.6-luna | OpenAI (OAuth) | plan GPT |
| Ansem | deepseek-v4-flash | NVIDIA | GRATIS |
| Kuja | deepseek-v4-flash | NVIDIA | GRATIS |
| Eiko | deepseek-v4-flash | OpenCode Go | plan |
| Amarant | gpt-5.6-luna | OpenAI | plan GPT |
| Eremez | deepseek-v4-flash | NVIDIA | GRATIS |
| Auron | deepseek-v4-pro | NVIDIA | GRATIS |
| Bran | gpt-5.6-luna | OpenAI | plan GPT |
| Quina | deepseek-v4-flash | OpenCode Go | plan |
| Tidus | deepseek-v4-flash | OpenCode Go | plan |
| Bard | gpt-5.6-luna | OpenAI | plan GPT |
| Ragnarok | gpt-5.6-luna | OpenAI / B.AI | plan |
| Varys | gpt-5.6-luna | OpenAI | plan GPT |
| Tywin | deepseek-v4-flash | NVIDIA | GRATIS |
| Sam | gpt-5.6-luna | OpenAI | plan GPT |

**Cambiar**: `atlas` → opción 2 (wizard con flechas) → actualiza `.arnes/config.json`.

---

## 🛠️ Comandos útiles

```bash
opencode auth list        # ver proveedores conectados
opencode models           # catálogo vivo de modelos
opencode models nvidia    # solo modelos NVIDIA
atlas                     # abrir ARGOS Shell
atlas -Setup              # reconfigurar modelos (wizard)
```

---

## ⚠️ Nota: hay un placeholder en opencode.json

El provider `opencode-go-2` tiene `"apiKey": "TU_API_KEY_CUENTA_2"` (placeholder de una 2ª cuenta Go que aún no configuras). Si no lo usas, puedes ignorarlo; si tienes una 2ª cuenta Go, pon tu key ahí.

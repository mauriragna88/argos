# ADR-004 - Modelos por agente: deepseek como caballo de batalla

> **Fecha**: 2026-08-07
> **Autor**: Usuario + Atlas + Quina
> **Estado**: `accepted`

---

## Contexto

La configuracion de modelos tenia 3 fuentes contradictorias (opencode.json, oh-my-opencode.jsonc,
agent-models.json) y usaba nvidia/deepseek-ai/deepseek-v4-pro que llego a EOL el 2026-08-07.
El usuario paga suscripcion GPT Plus (cuota semanal limitada) y opencode-go (cuota propia), y
nvidia se agota a veces. Queria dividir el consumo para no agotar la cuota GPT.

## Decision

- **Fuente unica de verdad**: `~/.config/arnes/agent-models.json` (29 agentes = 16 ARNES + 13 OMO).
- **Despliegue a 3 destinos**: `agents/*.md` (frontmatter), `oh-my-opencode.jsonc` (agente OMO),
  `opencode.json` — via `argos-models-apply.ps1` con regex que preserva comentarios y `variant`.
- **Estrategia de gasto** (mucho volumen = barato, poca frecuencia = mejor modelo):
  - Deepseek flash (opencode-go, version 3107): 15 agentes de trabajo pesado (vivi, ansem,
    kuja, eiko, explore, deep_worker, hephaestus, metis, plan...). ES EL CABALLO DE BATALLA.
  - gpt-5.6-luna (opencode-go): solo 3 de decision (atlas, tywin, sam) — uso minimo, no agota GPT.
  - glm-5.2: 5 de estrategia media (amarant, bran, auron, varys, momus).
  - minimax-m3: 3 de research/arquitectura (eremez, maestro, sisyphus).
  - deepseek-v4-pro: 2 consultores (oracle, kimi).
  - mimo-v2.5-pro: 1 diseno (prometheus).
- **Atlas es `mode: primary`** (orquestador que abre OpenCode); los demas `subagent`.
- **Comando `/model`** en OpenCode: wizard amigable (elige agente -> elige modelo) + CLI `argos model`.
- **Capa global OSMA**: `~/.config/arnes/osma-global.db` para patrones reutilizables entre proyectos
  (memoria local sigue aislada por proyecto en cada `.arnes/arnes.db`).

## Alternativas consideradas

| Alternativa | Pros | Contras |
|---|---|---|
| Todos en gpt-5.6-luna | Maxima calidad | Agota la cuota GPT semanal |
| nvidia para premium | Modelos buenos (glm-5.2, minimax-m3) | Cuota nvidia se agota a veces |
| Deepseek flash para el trabajo pesado + top tier solo en decision | Barato + calidad donde importa | 3 agentes dependen de opencode-go/gpt |

## Consecuencias

**Positivas**:
- La cuota GPT solo la tocan 3 agentes con uso minimo (no se agota sola)
- El trabajo pesado (la mayoria de llamadas) cae en deepseek flash = costo minimo
- Una sola fuente de verdad, configurable con /model sin tocar JSON a mano
- Cero dependencia de nvidia (inestable) y cero modelos EOL

**Negativas / Riesgos**:
- Los 3 de decision dependen de opencode-go/gpt-5.6-luna (si opencode-go cambia precios/limites, ajustar)
- Si deepseek flash no da calidad en un quest dificil, Atlas debe escalar a glm/minimax (manual por ahora)
- La capa global OSMA es nueva: hay que usarla con disciplina (solo patrones reutilizables)

## Razon (por que esta)

"Mientras mas pesado el trabajo, mas barato el modelo; el top tier solo donde se decide."
El harness es tuyo: la config de modelos tambien. Deepseek flash hace el 80% del trabajo a costo
minimo, los 3 de decision gastan casi nada, y todo se cambia con un `/model`.

---
*Memoria: guardado en arnes.db `amarant/arch-decisions`*
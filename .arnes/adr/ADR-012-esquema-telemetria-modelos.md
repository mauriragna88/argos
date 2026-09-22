# ADR-012 — Esquema de telemetría de modelos

> **Fecha**: 2026-09-22
> **Autor**: Amarant (arquitectura) + Quina (ledger)
> **Estado**: `accepted`
> **Relacionado**: ADR-011 (scoring), ADR-004 (modelos por token), Fase 1

---

## Contexto

El plan de Fase 1 pedía una tabla `model_runs` en el brain OSMA. El brain real vive en
`~/.config/arnes/osma/osma_brain.py` — **repo global separado que este repo no modifica**
(misma decisión que ADR-014/015/016). Además, el brain ya tiene `skill_executions` con
`model/provider/tokens/verdict/success`, pero **por ejecución de skill**, sin quest_type,
route, party ni reward.

## Decisión

La telemetría canónica de este repo es **`.arnes/model-runs.jsonl`**, append-only, escrita
por `cli/model-telemetry.ps1` (acciones `record`/`stats`) y alimentada automáticamente por
`loop-engine.ps1` en quest-done. Esquema de cada línea:

```json
{"event":"model_run","ts":"ISO-8601","agent":"vivi","model":"opencode-go/deepseek-v4-flash",
 "provider":"opencode-go","quest_id":"Q-001","quest_type":"frontend","difficulty":3,
 "route":"pro","party":"vivi,eiko","tokens_used":4500,"verdict":"PASS","reward":0.9}
```

Reglas:

- **Aditivo**: los campos futuros (`latency_ms`, `cached_tokens`, `cost_estimate`, `loops`,
  `first_pass_success`) se agregan sin romper lectores (líneas viejas siguen válidas).
- **No es memoria paralela**: es telemetría operativa; OSMA sigue siendo el cerebro y no se
  importa a `observations` (prohibición del plan).
- **Lectura tolerante**: una línea corrupta se ignora, nunca rompe `stats`.
- **Relación con `skill_executions`**: no se duplican campos ni la tabla; `skill_executions`
  mide skills (brain), `model-runs` mide corridas de modelo por quest (este repo). Si el
  brain adopta `model_runs` en el futuro, este JSONL es la fuente a migrar.
- **Derivaciones**: `provider` sale del prefijo del modelo; `route` de la dificultad
  (1-2 flash, 3 pro, 4-5 highest) y `reward` del verdict (+0.9 / +0.3 / -0.8) cuando no se
  pasan explícitos — el contrato vive en `model-telemetry.ps1` y se verifica en tests.

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Tabla `model_runs` en SQLite del repo | Rechazada: duplica el cerebro y añade acoplamiento a OSMA |
| B. Extender `skill_executions` en el brain | Rechazada en F1: repo externo, sin permiso de cambio; queda como extensión futura |
| C. **JSONL append-only en `.arnes/`** (ELEGIDA) | Cero acoplamiento, reconstruible, tolerante a fallos, medible desde el día 1 |

## Consecuencias

- `model-telemetry stats` responde `success_pct`/`avg_tokens` por model×route×quest_type.
- Tests herméticos: `tests/model-telemetry.tests.ps1` (campos, derivaciones, reward,
  append-only, filtro, tolerancia a corrupción, vacío).
- F3 consume `verdict`+`quest_type` para la clasificación de causa; F5 usa `quest_id`.

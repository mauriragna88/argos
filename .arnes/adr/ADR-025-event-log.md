# ADR-025 — Event log (JSONL, dueño Varys, separado de OSMA)

> **Fecha**: 2026-09-22
> **Autor**: Amarant (arquitectura) + Varys (documentalista)
> **Estado**: `accepted`
> **Relacionado**: ADR-012 (telemetría), ADR-006 (contract gate), Fase 1

---

## Contexto

El plan de Fase 1 pedía hooks PI (`tool_call`, `before_agent_start`, `agent_settled`) que
escribieran un `.arnes/event-log.jsonl` append-only, con Varys como dueño, para que **cada
quest deje un rastro reconstruible**. En el repo, el motor nativo (`cli/loop-engine.ps1`,
`cli/argos-cycle.ps1`) ya cierra cada quest escribiendo ledger, evidence packs y telemetría;
los hooks PI viven en `pi/extensions` (otro runner).

## Decisión

**El event log del arnes es la unión de tres artefactos append-only, con Varys como dueño**:

| Artefacto | Escribe | Contenido |
|---|---|---|
| `.arnes/model-runs.jsonl` | `model-telemetry.ps1` (loop-engine en quest-done) | `model_run` por quest (ADR-012) |
| `.arnes/quest-ledger.json` | `loop-engine.ps1` | quest, agent, verdict, tokens, timestamps |
| `.arnes/memory/export/varys/*` (evidence packs) | Varys | bitácora de secuencia ordenada del quest |

Reglas:

- **Granularidad**: mínimo un evento por quest cerrado (quest-done); eventos adicionales
  solo cuando aportan reconstrucción (FAIL→remediation→PASS).
- **Orden**: append-only; la reconstrucción es por orden de inserción + `ts`.
- **Separación de OSMA**: el event log **no se importa** a observaciones/experiencias —
  es telemetría operativa, no memoria (prohibición de memoria paralela del plan).
- **Retención**: sin límite hoy (gitignored); rotación/compresión futura por tamaño si el
  archivo supera ~50 MB, decidida con datos.
- **Fallos**: la escritura de telemetría nunca rompe el hook (try/catch en loop-engine);
  un event log incompleto se reporta como hueco, no se inventa.

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Importar eventos a OSMA como observaciones | Rechazada: memoria paralela y ruido en recall |
| B. Hooks PI dedicados en `pi/extensions` como único camino | Diferida: el motor nativo ya emite; PI se suma cuando ese runner lo necesite |
| C. **Unión de artefactos existentes con dueño Varys** (ELEGIDA) | Cero componentes nuevos, rastro ya reconstruible hoy |

## Consecuencias

- F4 (quest graph) reconstruye nodos desde estos artefactos sin crear otro log.
- Los tests de F1 (telemetría) y de F3 (intentos) cubren el contrato de escritura.
- Varys audita que cada quest cerrado tenga al menos un `model_run` y su bitácora.

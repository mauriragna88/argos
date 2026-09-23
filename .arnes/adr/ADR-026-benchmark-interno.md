# ADR-026 — Benchmark interno del harness

> **Fecha**: 2026-09-22
> **Autor**: Amarant (arquitectura) + Quina (economía)
> **Estado**: `accepted`
> **Relacionado**: ADR-011 (scoring), ADR-012 (telemetría), ADR-024 (code mode), Fase 6

---

## Contexto

Sin medición, "el harness mejora al modelo" es una opinión. El plan exige un benchmark
**reproducible** que compare el MISMO modelo con y sin ARGOS, con métricas canónicas y un
criterio de éxito explícito — y prohíbe auto-escalar modelos con él (eso requiere revisar
ADR-011/013 con datos).

## Decisión

**Runner reproducible** (`benchmark`, expuesto como `argos bench`):

- `record`: una corrida por (modelo, config `baseline|argos`, quest) con las 9 métricas:
  verdict/PASS, `first_pass`, `tokens`, `cost_usd`, `latency_ms`, `loops`, `regressions`,
  `security_findings`, `human_interventions`. Persistencia: `.arnes/benchmarks.jsonl`.
- `report`: por modelo, stats agregadas de baseline y argos (pass_rate, first-pass avg,
  tokens/costo/latencia/loops promedio, totales de regresiones/seguridad/intervenciones),
  deltas y **veredicto del criterio central**:
  `modelo medio + ARGOS ≥ mismo modelo sin ARGOS en PASS rate`.
- `list`: corridas registradas.

Reglas:

- El runner NO cambia routing ni escala modelos (ADR-011 sigue siendo advisory).
- Los datos de F1 (`model_runs.jsonl`) son la fuente natural para llenar el benchmark; el
  `record` explícito existe para pares controlados.
- Un veredicto `argos<baseline` es señal de revisión, no de acción automática.

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Benchmark "a mano" | Rechazada por el plan: no reproducible |
| B. **Runner con JSONL + report comparativo** (ELEGIDA) | Reproducible, sin dependencias, comparable |
| C. Auto-tuning con los datos | Rechazada: requiere revisar ADR-011/013 con datos reales primero |

## Consecuencias

- El criterio central queda computado y visible (`argos bench`).
- F1 (telemetría) + F5 (regresiones) + F3 (loops/causa) alimentan las métricas del reporte.
- Tests: `tests/benchmark.tests.ps1` (record, validaciones, report con ambos veredictos,
  list y sin datos).

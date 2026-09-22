# ADR-011 — Scoring dinámico de modelos

> **Fecha**: 2026-09-22
> **Autor**: Amarant (arquitectura) + Bran (allocación) + Quina (ledger)
> **Estado**: `accepted` (fórmula fijada; implementación diferida a F3+)
> **Relacionado**: ADR-012 (telemetría), ADR-013 (perfiles AGENT≠MODEL), Fase 1

---

## Contexto

El routing actual es **estático**: `~/.config/arnes/agent-models.json` ata un modelo a un
agente y `.arnes/model-routing-policy.json` declara preferencias/fallback. No existe ninguna
señal de desempeño real (success rate, loops, costo por pass). GAP_ANALYSIS P1 exige
`capability_fit × historical_success × availability × trust × cost_efficiency × latency_fit`.

Fase 1 no decide modelos: **solo mide**. Este ADR fija la fórmula y sus fuentes para que
F3 (loop contract + causa de fallo) la implemente con evidencia y no la reinvente.

## Decisión

**El score es advisory, nunca auto-aplicado.** Se calcula offline a partir de:

| Factor | Fuente |
|---|---|
| `historical_success` | `success_pct` por model×route×quest_type en `.arnes/model-runs.jsonl` (ADR-012) |
| `cost_efficiency` | `avg_tokens` × pricing por modelo (`cli/pricing.ps1`) |
| `capability_fit` | perfil de capacidades por agente (ADR-013) contra `route` (flash/pro/highest) |
| `availability` | conexiones activas (`connections.json` verificadas) |
| `trust` | trust_score del agente en OSMA |
| `latency_fit` | `latency_ms` (campo futuro aditivo de la telemetría) |

Fórmula (pesos iniciales, calibrables con datos reales de F1):

```
score = 0.30·historical_success
      + 0.20·capability_fit
      + 0.20·cost_efficiency
      + 0.15·trust
      + 0.10·latency_fit
      + 0.05·availability
```

Consumidores: Bran (`bran-vision`) propone, Quina (`quina-ledger`) presupuesta, el usuario
aprueba. Ningún componente cambia el modelo de un agente por score sin causa clasificada
(ADR-018) y sin registro en el ledger.

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Mantener routing estático | Rechazada: sin señal de desempeño no hay decisión model-agnostic con evidencia |
| B. Score en runtime auto-aplicado | Rechazada por ahora: cambiaría modelos sin causa clasificada ni revisión |
| C. Score **advisory** calculado desde telemetría (ELEGIDA) | El humano/Bran decide; el score ordena candidatos con datos |

## Consecuencias

- F1 solo captura datos; ningún cambio de routing en F1 (regla del plan).
- Las métricas objetivo quedan definidas: `model_success_rate`, `avg_tokens`,
  `cost_per_pass`, `fallback_trigger_rate` (F3), `false_escalation_rate` (F3).
- La fórmula se revisa con ≥30 runs reales antes de que Bran la use para recomendar.

# ADR-018 — Clasificación de causa de fallo y estrategia de retry

> **Fecha**: 2026-09-22
> **Autor**: Amarant (arquitectura) + Sam (counsel) + Eiko (remediación)
> **Estado**: `accepted`
> **Relacionado**: ADR-017 (contratos), ADR-011 (scoring), ADR-012 (telemetría), Fase 3

---

## Contexto

Hasta hoy cada FAIL quedaba registrado con `cause = "failed_verification"` — un placeholder
que no distinguía si el problema era el modelo, el contexto, una herramienta, el spec o el
entorno. Sin causa no hay retry inteligente: se reintentaba igual y se repetía el fallo.

## Decisión

**Clasificador determinista por señales observables** (`loop-contract.ps1`, acciones
`classify`/`attempt`), con precedencia fija:

```
tool > entorno > spec > contexto > implementacion > modelo
```

| Señal | Causa | strategy_delta sugerido |
|---|---|---|
| `tool_error` | tool | `tool` (arreglar comando/herramienta) |
| `env_issue` | entorno | `env` (red/auth/permisos) |
| `spec_gap` | spec | `spec` (afinar acceptance criteria) |
| `context_missing` | contexto | `context` (recompilar con más presupuesto) |
| `code_defect` | implementacion | `implementation` (fix del código) |
| (sin señales) | modelo | `model` (re-rutear) |

Reglas duras:

- **Retry cambia UNA variable**: `strategy_delta` ∈ {model, context, tool, spec, env,
  implementation, party}; más de una ⇒ el registro se rechaza (exit 1).
- **FAIL sin remediation es inválido** (regla Tywin preservada): la acción `attempt` lo
  rechaza; el registro queda en `.arnes/loop-attempts.jsonl`.
- Señales desconocidas ⇒ rechazo explícito (contrato cerrado, no adivinanza).
- El clasificador **no decide el retry**: alimenta a Sam (`causes`) y a Eiko (tipo de Mend);
  Atlas decide. `strategy_delta_source` distingue `explicit` (lo declaró alguien) de
  `classifier` (sugerido).

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Dejar `failed_verification` genérico | Rechazada: sin causa no hay anti-repetición |
| B. Clasificar con LLM | Rechazada: no determinista ni reproducible entre corridas |
| C. **Clasificador por señales con precedencia fija** (ELEGIDA) | Testeable con casos sintéticos, explicable, sin costo |

## Consecuencias

- `loop-engine` cierra cada intento con causa clasificada (`code_defect` para FAILs con
  remediation brief; `context_missing` cuando se excede presupuesto — señales explícitas).
- `causes` agrega causas y firmas repetidas ⇒ candidatas a guard (F5) y consejo de Sam.
- Tests: casos sintéticos por señal, rechazo de delta múltiple, rechazo de FAIL sin
  remediation (`tests/loop-contract.tests.ps1`).

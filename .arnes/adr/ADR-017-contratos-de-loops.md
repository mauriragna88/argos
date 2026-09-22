# ADR-017 — Contratos de loops

> **Fecha**: 2026-09-22
> **Autor**: Amarant (arquitectura) + Atlas (orquestación)
> **Estado**: `accepted`
> **Relacionado**: ADR-018 (causa y retry), ADR-006 (contract gate), Fase 3

---

## Contexto

El loop nativo (`cli/loop-engine.ps1`) iteraba con un `max_iterations` suelto en
`loop-state.json` y sin criterios de aceptación por quest: el party no sabía **cuándo
parar** ni qué se estaba verificando, y un quest podía consumir tokens sin techo.

## Decisión

Cada quest lleva un **LOOP CONTRACT** persistido en `.arnes/loop-contracts/Q-XXX.json`,
creado por `loop-engine` al iniciar el quest (`loop-contract.ps1 -Action create`) con:

| Campo | Contenido |
|---|---|
| `goal` / `prompt` | el quest original |
| `acceptance_criteria` | criterios verificables por tipo (heurística + Atlas los enriquece) |
| `verification` | comandos/gates esperados (typecheck, tests, RLS check...) |
| `max_iterations` | techo de reintentos |
| `token_budget` | techo de tokens del quest |
| `retry_policy` | `max_retries` + `change_one_variable: true` (ADR-018) |
| `stop_conditions` | PASS, límites excedidos, decisión de Atlas (pause/escalate) |

`-Action check` valida en runtime que el quest siga dentro del contrato (intentos y
tokens); fuera de límites ⇒ `within_limits: false` con issues explícitos ⇒ Atlas pausa
con razón documentada (`abort_conditions`).

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Seguir con max_iterations suelto | Rechazada: sin acceptance ni presupuesto el loop no es auditable |
| B. Tabla de contratos en el brain OSMA | Rechazada: repo externo (misma regla que ADR-012/014) |
| C. **JSON por quest en `.arnes/loop-contracts/`** (ELEGIDA) | Versionable, inspeccionable, consumible por el party y por Tywin |

## Consecuencias

- El party conoce el contrato al arrancar (Atlas lo inyecta) y Tywin verifica contra sus
  `acceptance_criteria` (L4 de la ladder, ADR-020).
- Compatibilidad: contratos ausentes no rompen (`check` reporta `contrato no existe`).
- Tests herméticos en `tests/loop-contract.tests.ps1` (create/check/límites).

# ADR-019 — Regression Factory

> **Fecha**: 2026-09-22
> **Autor**: Amarant (arquitectura) + Kuja (guards) + Tywin (sugerencia)
> **Estado**: `accepted`
> **Relacionado**: ADR-018 (causa y retry), ADR-020 (ladder L6), ADR-006 (contract audit), Fase 5

---

## Contexto

Un FAIL corregido sin guard vuelve. Con F3 ya existen la **causa clasificada** y la
**failure_signature** en `.arnes/loop-attempts.jsonl`, pero no había un registro del guard
que protege ese fallo: ni trazabilidad (quest → firma → guard), ni estado (archivo existe o
no), ni forma de ejecutarlo como verificación en quests del mismo dominio.

## Decisión

Registro append-only **`.arnes/regressions.jsonl`** con dos eventos:

| Evento | Quién | Contenido |
|---|---|---|
| `regression_suggestion` | loop-engine (PASS tras FAIL) | quest, verdict, guard_type inferido (security/contract/unit), failure_signature, status `suggested`, dedup por quest+firma |
| `regression_guard` | Kuja (`-Action create`) | quest, guard_type, guard_path, guard_exists, status `active`/`missing_file`, failure_signature, created_by, verified_at |

CLI: `cli/regression.ps1` (`suggest`/`create`/`list`/`check`) expuesto como
`argos regression ...`. `list` muestra **guards** (las candidatas se cuentan aparte).

Reglas:

- **Gate de determinismo**: solo fallos reproducibles se convierten en guard.
- **Proof rojo→verde**: el guard debe fallar al reintroducir el bug y pasar con el fix.
- **No duplicación**: misma firma + tipo + quest no crea guards duplicados (ni sugerencias).
- **Dueños**: Tywin sugiere, Kuja implementa, Auron valida los guards de seguridad.
- Los gates de `arnes-contract-audit` se **registran** como regressions; no se reimplementan.

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Tabla `regressions` en el brain OSMA | Rechazada: repo externo (misma regla que ADR-012/017) |
| B. Escribir tests sin registro | Rechazada: sin trazabilidad no hay L6 ni medición de regresiones |
| C. **JSONL + CLI por quest** (ELEGIDA) | Cero acoplamiento, inspeccionable, deduplicable |

## Consecuencias

- L6 de la ladder (ADR-020) ejecuta los guards del dominio; el benchmark (F6) mide
  `regressions` detectadas.
- `regression.ps1` ahora **persiste** la candidata (antes solo la imprimía: sin rastro) y
  `list` filtra guards reales.
- Tests herméticos: `tests/regression.tests.ps1` (suggest + dedup + tipo inferido, create
  active/missing_file/duplicado, list solo guards, check existe/no existe).

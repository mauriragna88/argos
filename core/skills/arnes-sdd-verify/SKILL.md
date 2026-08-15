---
name: arnes-sdd-verify
description: >
  ARNES SDD Fase 6 - Verificacion. Comprueba que la implementacion cumple el spec.
  Rol principal: Tywin (Verifier). Revisa cada criterio de aceptacion del spec.md contra
  el codigo implementado. Emite verdict PASS/FAIL con evidencia.
  Trigger: Cuando apply termino las tareas y antes de archivar el change.
---

## Purpose

La fase **verify** es la auditoria final: la implementacion debe cumplir los criterios
del spec. NO se confia en el ejecutor — se verifica con evidencia real.

## Flujo

1. Leer `.arnes/sdd/<change-id>/spec.md` (criterios de aceptacion)
2. Leer `tasks.md` (todas las tareas marcadas done?)
3. Verificar con lectura directa (solo read — sin comandos):
   - `read` los archivos del change (tipos, estructura, contrato)
   - `read` los tests del change si existen
   - contrastar CADA criterio de aceptacion contra lo leido
4. Contrastar CADA criterio de aceptacion contra el codigo
5. **Contract Audit gate (MANDATORY si el change toca DB/API/frontend)**:
   - El harness ejecuta el gate determinístico del contrato (skill arnes-contract-audit, ADR-006) y el agente consume el reporte con `read`
   - El reporte (L1-L6, checks C1-C34) entra como evidence pre-verdict
   - FAIL del gate = FAIL del verdict (aunque el spec este cumplido)
   - Aplica SIEMPRE si el change toca: migraciones, `database.types.ts`, Zod schemas, queries supabase-js, response shapes de API
6. Consultar memoria/grafo: las relaciones registradas son correctas?
7. Emitir verdict:

```
VERDICT: PASS | FAIL_PARTIAL | FAIL_TOTAL
Evidencia:
  - archivos leidos: <lista>
  - tipos/imports/tests: PASS
  - tests: 12/12 PASS (leidos)
  - Criterio R1.S1.1: PASS (test cubre email invalido)
  - Criterio R2: FAIL (no hay test para el escenario de expiracion)
Remediation (si FAIL): <que falta exactamente>
```

7. Guardar verdict: `write` una linea en `.arnes/memory/export/tywin-memory.jsonl` (topic `tywin/verdicts`, type `verdict`)

> **Contract audit**: si el change toca la superficie DB/API/frontend, el paso 5 es obligatorio
> (skill `arnes-contract-audit`, ADR-006). Sin el reporte no hay verdict.

## Reglas

1. **Evidencia, no opinion** — cada PASS/FAIL con archivo leido (read) y criterio contrastado
2. **Todos los criterios** — no saltes ninguno del spec
3. **FAIL = remediation** — si falla, di exactamente que falta (remediation brief)
4. **FAIL_PARTIAL** — criterios cumplidos + pendientes listados
5. **NO aprobar sin tests** — si el spec pedia tests y no hay, es FAIL

## Referencia de archivos

```
# Ver criterios
read .arnes/sdd/<change-id>/spec.md
# Ver estado de tasks
read .arnes/sdd/<change-id>/tasks.md
```

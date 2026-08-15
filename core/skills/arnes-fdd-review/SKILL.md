---
name: arnes-fdd-review
description: >
  ARNES FDD Fase 3 - Review. Revisa la feature implementada contra su plan: verifica
  criterios de done, calidad y que cumple el valor prometido. Rol: Kuja (QA) + Tywin (verdict).
  Trigger: Cuando implement termino la feature y antes de archivarla.
---

## Purpose

Verificar que la feature entrega el valor prometido y pasa los gates de calidad.
El review es por FEATURE (rápido y enfocado), no un mega-audit de todo el set.

## Flujo

1. Leer feature-plan: `.arnes/fdd/<FL>/F<N>-plan.md` (criterios de done)
2. Verificar con lectura directa (solo read — sin comandos):
   - `read` los archivos de la feature (tipos, estructura, imports, contrato)
   - `read` los tests de la feature si existen
   - contrastar cada criterio del plan contra lo leido
3. Contrastar cada criterio del plan contra el código
4. **Contract Audit gate (MANDATORY si la feature toca DB/API/frontend)**:
   - El harness ejecuta el gate determinístico del contrato (skill arnes-contract-audit, ADR-006) y el agente consume el reporte con `read`
   - El reporte (L1-L6, checks C1-C34) entra como evidence pre-verdict
   - FAIL del gate = FAIL del verdict (aunque los criterios de done estén cumplidos)
   - Aplica SIEMPRE si la feature toca: migraciones, `database.types.ts`, Zod schemas, queries supabase-js, response shapes de API
5. Kuja: tests de la feature (proporcional — trivial = poco, complejo = completo)
6. Tywin: verdict PASS / FAIL_PARTIAL / FAIL_TOTAL con evidencia
7. Guardar verdict: `write` una linea en `.arnes/memory/export/tywin-memory.jsonl` (topic `tywin/verdicts`, type `verdict`)

## Output esperado

```
FEATURE F<N> REVIEW:
  - Criterios: 5/5 cumplidos
  - Archivos leidos: <lista> / tipos-imports-tests: PASS
  - Verdict: PASS
  - Evidencia: <archivos leidos + criterios contrastados>
```

## Reglas

1. **Evidencia, no opinión** — cada check con archivo leido (read) y criterio contrastado
2. **FAIL = remediation** — qué falta exactamente para el siguiente intento
3. **Proporcionalidad** — una feature S no necesita el mismo review que una L
4. **Guardar verdict** — la memoria sabe si la feature pasó o no
5. **Contract audit no skipable** (arnes-contract-audit, ADR-006) — si la feature toca DB/API/frontend, el paso 4 es obligatorio; sin reporte no hay verdict

## Referencia de archivos

```
read .arnes/fdd/<FL>/F<N>-plan.md
```

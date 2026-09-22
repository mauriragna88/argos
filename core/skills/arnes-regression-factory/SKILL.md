---
name: arnes-regression-factory
description: >
  ARNES REGRESSION FACTORY - cuando un quest pasa de FAIL a PASS, el fallo se convierte en
  un guard permanente (test unitario, contract, security rule, integration, static) con
  trazabilidad completa. El proof es el test rojo al reintroducir el bug.
  Trigger: quest-done con PASS tras FAIL (Tywin sugiere), o "convierte este bug en guard".
---

## Purpose

Un bug arreglado sin guard vuelve. La fábrica toma el ciclo FAIL → remediation → PASS
(clasificado en F3 con causa y firma) y lo convierte en una defensa ejecutable que corre
como L6 de la ladder de Tywin (ADR-020) en cada quest del mismo dominio.

## Flujo

1. **Candidata (automática)**: el harness la emite en quest-done con PASS tras FAIL
   (acción `suggest` de `argos regression`, disparada por el loop) → persiste una
   `regression_suggestion` en el registro `.arnes/regressions.jsonl` (dedup por quest+firma)
   e infiere el `guard_type`: security (rls/policy/auth) · contract (api/schema/endpoint) ·
   unit (bug/fix/error).
2. **Guard (Kuja)**: implementa el guard real y lo registra con la acción `create`:
   `argos regression create <QuestId> <GuardType> <GuardPath> <FailureSignature>`
   → status `active` si el archivo existe; `missing_file` si falta (queda pendiente, no se ignora).
3. **Firma desde F3**: la `failure_signature` sale de `loop-attempts.jsonl`
   (`argos contract causes`) — mismo lenguaje que la clasificación de causa (ADR-018).
4. **Proof obligatorio**: el guard debe **fallar al reintroducir el bug** y **pasar con el
   fix** (rojo → verde). Un guard que nunca falla no protege nada.
5. **Gate de determinismo**: solo fallos reproducibles se convierten en guard; un fallo
   intermitente se documenta como riesgo, no como guard.
6. **Consulta**: `argos regression list [Q-XXX]` (muestra guards; las candidatas se cuentan
   aparte) y `argos regression check <ruta>`.
7. **L6 (ADR-020)**: los guards del dominio corren como nivel de verificación de los quests
   del mismo dominio; un guard roto es FAIL de la ladder.

## Reglas

1. No duplicar `arnes-contract-audit`: los gates de contract se **registran** como regression,
   no se reimplementan
2. No duplicar `osma-pattern-detect`: los patrones (V5) son conocimiento; las regressions son
   guards ejecutables
3. Sin guard para fallos no reproducibles (gate de determinismo)
4. Todo guard tiene dueño (Kuja por defecto; Auron valida los de seguridad) y trazabilidad
   quest → firma → guard
5. El guard vive en el código del proyecto (git); `.arnes/` solo guarda el registro

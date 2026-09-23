---
name: arnes-benchmark
description: >
  ARNES BENCHMARK - mide si el harness mejora al modelo: mismo modelo con y sin ARGOS.
  Registrar corridas (baseline|argos) y comparar PASS rate, first-pass, tokens, costo,
  latencia, loops, regresiones, hallazgos de seguridad e intervenciones humanas.
  Trigger: "mide el harness", cierre de fase, comparativa de modelos/proveedores.
---

## Purpose

Convertir "el harness ayuda" en un número. El benchmark compara el **mismo modelo** con y
sin ARGOS sobre los mismos quests, con métricas canónicas, para que cualquier decisión de
routing/economía (Bran, Quina, el usuario) tenga evidencia (ADR-026).

## Flujo

1. **Registrar corridas controladas**: acción `record` de `argos bench` con
   `-Model <id> -Config baseline|argos -QuestId <id> -Verdict PASS|FAIL_* -Tokens <n>
   -CostUsd <f> -LatencyMs <n> -Loops <n> [-FirstPass] -Regressions <n>
   -SecurityFindings <n> -HumanInterventions <n>` — una por par modelo×config.
2. **Reporte**: `argos bench` (acción `report`) agrega por modelo: baseline vs argos
   (pass_rate, first-pass %, tokens/costo/latencia/loops promedio, totales de regresiones,
   seguridad e intervenciones) y emite el **veredicto del criterio central**:
   modelo medio + ARGOS >= mismo modelo sin ARGOS en PASS rate.
3. **Lectura**: `argos bench list` para las corridas crudas; el reporte es la vista de
   decisión. Un `argos<baseline` es señal de revisión, jamás de cambio automático de modelo.
4. **Fuentes**: los pares controlados se registran a mano; la telemetría de F1
   (`model-runs.jsonl`) alimenta el contexto de lo que ya corre.

## Reglas

1. Nunca auto-escalar ni cambiar routing con el benchmark (ADR-011 sigue advisory)
2. Comparar siempre el MISMO modelo contra sí mismo (baseline vs argos), no modelos distintos
3. Registrar costo y latencia reales; sin números inventados (si no se midió, 0 y se nota)
4. Un veredicto solo cuenta con ≥2 corridas por config; con 1 se reporta como pendiente
5. El runner es reproducible: mismas entradas, mismas salidas

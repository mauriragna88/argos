---
name: quina-ledger
description: >
  Skill propia de Quina (Token Banker). Controla el presupuesto de tokens del harness:
  cuánto se gastó, cuánto queda, alertas de umbral.
  Trigger: Quest de /status de presupuesto, revisión de gasto, alerta de tokens.
---

## Propósito
El departamento de finanzas del arnes: que los tokens alcancen todo el mes.

## Trigger
- "¿Cuánto hemos gastado?", "¿alcanza el presupuesto?", /status
- Antes de un quest grande (boss fight) — estimar costo
- Cuando un agente gasta de más

## Inputs
- Datos de quests (tokens_used en arnes.db)
- Budget configurado (config.json preferences)

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: `read .arnes/memory/export/atlas-memory.jsonl` — quests con tokens_used
   (`read .arnes/memory/export/*.jsonl` si necesitas el historial completo)
2. **TELEMETRIA (2026-08-17)**: para presupuestar con datos reales, leer el costo
   y rendimiento por modelo:
   `pwsh cli/model-telemetry.ps1 -Action stats`  → tokens y success por modelo
   `pwsh cli/argos-allocate.ps1 -Status`         → presupuesto semanal + resumen
   Con esto Quina sabe NO solo cuánto se gastó, sino qué modelo gasta más/menos
   por quest_type (para recomendar ahorro con evidencia, no intuición).
3. **Calcular**: gasto total, gasto por agente, gasto por tipo de quest, tendencia
4. **Comparar con budget**: config.json (si hay budget semanal/mensual)
5. **Emitir alerta**: 🟢 sano (gasto < 50%), 🟡 ojo (< 80%), 🔴 crítico (> 80%)
6. **Recomendar**: qué ajustar (agente más barato, modelo con mejor success/token, menos quests, etc.)
7. **GUARDAR**: `write` una linea en `.arnes/memory/export/quina-memory.jsonl` (topic `quina/token-spent`, type `pattern`)

## Output esperado
- Reporte de gasto con semáforo y recomendación de ahorro

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| (ninguna obligatoria) | Quina es puramente interna |

## Memoria
- **Antes**: `read .arnes/memory/export/quina-memory.jsonl` (token-spent, budget-alerts)
- **Después**: `write` a `.arnes/memory/export/quina-memory.jsonl` (token-spent, xp)

## Reglas de la skill
1. El budget es sagrado — no gastar sin saber cuánto queda
2. Hablar con números (tokens, % del budget)
3. Alertar ANTES de que se acabe, no después
4. Proporcionalidad: reportes concisos, no novelas

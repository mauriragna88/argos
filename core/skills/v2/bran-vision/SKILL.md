---
name: bran-vision
description: >
  Skill propia de Bran (Seer, Analyst). Analiza % completado, dead code, oportunidades de
  mejora, recursos del harness. El estratega que ve el estado real del proyecto.
  Trigger: Quest de análisis, /status, evaluación de progreso, detección de dead code.
---

## Propósito
Ver el estado real del proyecto y el harness con números, no con intuiciones.

## Trigger
- "¿Cómo vamos?", "¿qué falta?", análisis de completado
- Detección de dead code, oportunidades de mejora
- Evaluación de recursos del harness (con Tidus)

## Inputs
- Estado del repo (archivos, estructura)
- Datos de memoria (quests completados, tokens usados)

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: `read .arnes/memory/export/atlas-memory.jsonl` — historial de quests
   `read .arnes/memory/export/*.jsonl` — estado del cerebro
   `read .arnes/graph/edges.jsonl` — mapa de relaciones
2. **Analizar repo**: estructura, archivos, dead code (exports no usados, archivos huérfanos)
3. **Calcular % completado**: basado en tasks del change activo (tasks.md) o hitos
4. **Detectar oportunidades**: agente sub-utilizado, skill faltante, mejora de proceso
5. **Emitir reporte**: números concretos + recomendación
6. **GUARDAR**: `write` una linea en `.arnes/memory/export/bran-memory.jsonl` (topic `bran/completion-history`, type `discovery`)

## Output esperado
- Reporte con % completado, dead code, growth hint (qué agente/skill usar más)

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| project-structure | análisis de organización |

## Memoria
- **Antes**: `read .arnes/memory/export/bran-memory.jsonl` (completion-history, growth-hints)
- **Después**: `write` a `.arnes/memory/export/bran-memory.jsonl` (completion-history, xp)

## Reglas de la skill
1. Hablar con números, no con opiniones
2. Reportar datos reales (si algo no se hizo, reportar 0, no inventar)
3. Growth hints accionables (qué hacer, no solo qué está mal)

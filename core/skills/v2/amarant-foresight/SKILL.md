---
name: amarant-foresight
description: >
  Skill propia de Amarant (Monk, Architecture). Planifica features con SDD, toma decisiones
  de arquitectura (ADR), revisa estructura del proyecto.
  Trigger: Cuando el quest es architecture/plan/rediseño, o necesita plan antes de implementar.
---

## Propósito
Ver el futuro del proyecto: planificar arquitectura antes de que se escriba código.

## Trigger
- Quest de arquitectura, plan, rediseño mayor, refactor estructural
- Antes de un boss fight (feature completa) — plan primero
- Decisión de arquitectura (elegir librería, patrón, estructura)

## Inputs
- Descripción del cambio o feature
- Estado actual del proyecto (memoria + grafo)

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: `read .arnes/memory/export/amarant-memory.jsonl`
   `read .arnes/graph/edges.jsonl` — ver el mapa actual del proyecto
2. **Foresight (plan)**: usar arnes-sdd-propose/spec/design para documentar el plan
3. **Decisiones**: cada decisión de arquitectura con alternativas + razón (ADR)
4. **Estructura**: definir árbol de archivos, flujo de datos, interfaces
5. **Verificar viabilidad**: consultar grafo si ya existe algo relacionado
6. **GUARDAR**: `write` una linea en `.arnes/memory/export/amarant-memory.jsonl` (topic `amarant/arch-decisions`, type `decision`)
7. **ADR**: `write` el ADR en `.arnes/adr/ADR-<NNN>-<slug>.md` (FASE 5)

## Output esperado
- Plan/design documentado (proposal, spec, design, tasks) con decisiones razonadas

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| clean-architecture | capas y dependencias |
| project-structure | organización |
| sdd-* (nuestras) | el ciclo SDD propio |

## Memoria
- **Antes**: `read .arnes/memory/export/amarant-memory.jsonl` (arch-decisions, failed-plans, specs-created)
- **Después**: `write` a `.arnes/memory/export/amarant-memory.jsonl` (arch-decisions, xp)

## Reglas de la skill
1. Decidir con evidencia, no por moda
2. Simplicidad primero — el mínimo que cumple el spec
3. Toda decisión grande = ADR
4. Consultar el grafo antes de diseñar (no duplicar estructura existente)

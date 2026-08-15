---
name: arnes-fdd-plan
description: >
  ARNES FDD Fase 1 - Plan. Crea la feature-list (conjunto de features) y el feature-plan
  (plan individual por feature). FDD = entregar valor incremental feature a feature.
  Trigger: Cuando el usuario pide una feature completa o un conjunto de funcionalidades
  que se pueden dividir en features pequeñas entregables.
---

## Purpose

Feature-Driven Development del ARNES: dividir el trabajo en **features independientemente
entregables** — cada una da valor visible al terminar. A diferencia del SDD (spec profunda
para un cambio grande), el FDD planifica y ejecuta incrementalmente.

## Flujo

1. **Feature List** (el mapa):
   - Copiar template: `.arnes/fdd/templates/feature-list.md` → `.arnes/fdd/FL-<fecha>-<nn>/`
   - Listar features: cada una con prioridad, tamaño (S/M/L), dependencias
   - Ordenar por valor: primero las que desbloquean a las demás
2. **Feature Plan** (por feature):
   - Copiar template: `feature-plan.md` → `.arnes/fdd/<FL>/F<N>-plan.md`
   - Descripción de valor, alcance, enfoque, tareas, verificación, estimación

## Reglas

1. **Feature = valor entregable** — si no se ve el valor al terminar, no es una feature
2. **Independencia** — cada feature se puede hacer sin esperar a todo el set
3. **Tamaños** — S (<1 quest), M (1-2), L (3+ → subdividir en M)
4. **Memoria**: lee `read .arnes/graph/edges.jsonl` y `read .arnes/memory/export/*.jsonl` — no duplicar features ya hechas
5. **Guardar**: `write` una linea en `.arnes/memory/export/atlas-memory.jsonl` (topic `atlas/quest-history`, type `action`)
6. **Conectar a SDD**: si una feature es compleja, usar arnes-sdd para su spec/design

## Referencia de archivos

```
read .arnes/fdd/templates/feature-list.md
read .arnes/fdd/templates/feature-plan.md
```

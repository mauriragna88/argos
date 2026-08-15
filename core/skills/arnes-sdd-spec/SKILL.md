---
name: arnes-sdd-spec
description: >
  ARNES SDD Fase 2 - Especificacion. Crea el spec.md con requirements y escenarios verificables.
  Transforma la propuesta en especificaciones claras que guian el diseno y la implementacion.
  Trigger: Cuando el proposal esta aprobado y necesitas definir exactamente QUE debe cumplir el sistema.
---

## Purpose

La fase **spec** convierte la intencion en requirements precisos. Cada requerimiento tiene
escenarios verificables (entrada → comportamiento esperado). Esto es lo que Tywin verifica despues.

## Flujo

1. Copiar template: `.arnes/sdd/templates/spec.md` → `.arnes/sdd/<change-id>/spec.md`
2. Llenar:
   - **Requirements**: R1, R2... (funcionales)
   - **Scenarios**: S1.1, S1.2... (entrada → salida esperada)
   - **No-funcionales**: performance, seguridad, accesibilidad
   - **Restricciones**: stack, convenciones del repo
   - **Dependencias**: verificar con arnes-graph
   - **Criterios de aceptacion**: para Tywin verify

## Reglas

1. **Escenarios concretos** — "si email es invalido → muestra error" no "valida email"
2. **Verificable** — cada criterio debe poder comprobarse con un test o inspeccion
3. **Stack obligatorio** — TypeScript strict, Zod, Tailwind, convenciones del repo
4. **Consulta el grafo** — `read .arnes/graph/edges.jsonl` para ver si ya existe algo relacionado
5. **Guardar en memoria**: `write` una linea en `.arnes/memory/export/amarant-memory.jsonl` (topic `amarant/specs-created`, type `discovery`)

## Referencia de archivos

```
read .arnes/sdd/templates/spec.md
```

---
name: arnes-sdd-propose
description: >
  ARNES SDD Fase 1 - Propuesta. Crea el proposal.md de un cambio (feature/fix/refactor).
  Documenta intencion, alcance, enfoque, impacto y criterios de exito ANTES de escribir codigo.
  Trigger: Cuando Atlas o el usuario piden planificar un cambio, feature nueva, o cualquier
  trabajo que merezca spec antes de codigo.
---

## Purpose

El SDD (Spec-Driven Development) del ARNES garantiza que planificamos ANTES de codificar.
La fase **propose** define QUÉ queremos lograr y si vale la pena.

## Flujo

1. Crear carpeta del change: `.arnes/sdd/<change-id>/`
2. Copiar template: `.arnes/sdd/templates/proposal.md` → `.arnes/sdd/<change-id>/proposal.md`
3. Llenar con datos reales:
   - **Intención**: qué problema resuelve
   - **Alcance**: qué entra, qué NO entra
   - **Enfoque**: cómo se abordaría
   - **Impacto**: archivos, tokens, riesgo, L0?
   - **Criterios de éxito**: verificables

## Reglas

1. **Antes de codificar**: SIEMPRE proposal primero para cambios > 1 archivo
2. **L0**: si el cambio es L0, marcar `L0: sí` — Auron hará el L0 Gate
3. **Buscar en memoria**: consulta arnes-graph y arnes-memory si algo similar ya existe
4. **Criterios verificables**: nada de "funciona bien" — "test X pasa" o "lint limpio"
5. **Guardar decisión**: al aprobar/rechazar → `write` una linea en `.arnes/memory/export/atlas-memory.jsonl` (topic `atlas/decisions`, type `decision`)

## Referencia de archivos

```
# Ver template
read .arnes/sdd/templates/proposal.md
```

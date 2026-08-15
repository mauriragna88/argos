---
name: arnes-sdd-apply
description: >
  ARNES SDD Fase 5 - Implementacion. Ejecuta las tareas del tasks.md escribiendo codigo real.
  Cada tarea: leer spec/design para contexto, implementar, verificar localmente, marcar done.
  Trigger: Cuando las tasks estan definidas y aprobadas, Atlas delega la implementacion.
---

## Purpose

La fase **apply** implementa las tareas. El ejecutor NO es el orquestador: hace el trabajo
de codigo de las tareas asignadas, siguiendo el spec y el design.

## Flujo (por cada tarea asignada)

1. Leer `.arnes/sdd/<change-id>/spec.md` y `design.md` (contexto obligatorio)
2. Leer la tarea especifica del `tasks.md`
3. Consultar memoria y grafo ANTES de crear (anti-alucinacion) — solo read:
   ```
   read .arnes/memory/export/<tu>-memory.jsonl   # tu memoria
   read .arnes/graph/edges.jsonl                  # mapa de relaciones
   ```
4. Implementar (TDD: test primero si aplica — regla de Kuja/Proportional Verification)
5. Verificar localmente: lint + types + tests del archivo tocado
6. Guardar aprendizaje: `write` una linea en `.arnes/memory/export/<tu>-memory.jsonl` (topic `<tu>/<topic>`)
7. Registrar relacion: `write` la relacion en `.arnes/graph/edges.jsonl` (si creaste un nodo)
8. Marcar tarea done en tasks.md

## Reglas

1. **Contexto primero** — nunca implementes sin leer spec + design
2. **TDD cuando aplica** — tests primero para logica; proporcional a la complejidad (4+4=8)
3. **Verificacion local** — no marques done sin lint/types/tests pasando
4. **Memoria** — guarda patrones, bugs, decisiones al terminar
5. **No cambies el spec** — si descubres que el spec esta mal, avisa a Atlas (no improvises)

## Anti-alucinacion

Antes de crear algo, verifica si ya existe:
```
read .arnes/memory/export/<tu>-memory.jsonl
read .arnes/graph/edges.jsonl
```
Si existe, REUTILIZA. No re-implementes.

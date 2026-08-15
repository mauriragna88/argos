# Tasks — <Nombre del Cambio>

> **Change ID**: `C-<YYYYMMDD>-<NN>`
> **Basado en**: design <ID>
> **Fecha**: <YYYY-MM-DD>
> **Estado**: `pending` | `in_progress` | `done`

---

## Desglose de tareas (cada una ~5-15 min de trabajo)

### T1 — <Título de la tarea>
- [ ] **Archivo**: <ruta exacta>
- [ ] **Qué hacer**: <descripción precisa>
- [ ] **Dependencias**: <T0, T2...>
- [ ] **Agente asignado**: <vivi, ansem, kuja...>
- [ ] **Verificación**: <cómo se sabe que está lista>
- [ ] **Tokens estimados**: <N>K

### T2 — <Título>
...

## Orden de ejecución

1. T1 → 2. T2 → 3. T3 (o paralelo si no hay dependencias)

## Criterios de "done" del change

- [ ] Todas las tareas completadas
- [ ] Lint + types + tests + build pasan
- [ ] Grafo actualizado (arnes-graph add edges)
- [ ] Memoria guardada (arnes-memory save)

---
*Al completar, pasar a verify (Tywin) y archive*

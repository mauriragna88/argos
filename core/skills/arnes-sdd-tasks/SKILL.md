---
name: arnes-sdd-tasks
description: >
  ARNES SDD Fase 4 - Desglose de tareas. Crea el tasks.md con tareas pequenas (5-15 min),
  archivos exactos, dependencias, agente asignado y verificacion. El mapa de ejecucion.
  Trigger: Cuando el design esta aprobado y necesitas dividir la implementacion en tareas.
---

## Purpose

La fase **tasks** convierte el design en tareas accionables. Cada tarea es pequena,
con archivo exacto, agente asignado y criterio de "done". Asi Atlas delega con precision
y los agentes saben exactamente que hacer.

## Flujo

1. Copiar template: `.arnes/sdd/templates/tasks.md` → `.arnes/sdd/<change-id>/tasks.md`
2. Desglosar en tareas:
   - **T1, T2, T3...**: cada una con archivo exacto, que hacer, dependencias, agente, verificacion, tokens
3. Definir orden de ejecucion (secuencial o paralelo si no hay dependencias)
4. Criterios de "done" del change completo

## Reglas

1. **Tareas pequenas** — 5-15 min cada una, no megatareas
2. **Archivo exacto** — "reescribir (write) src/components/Login.tsx" no "el login"
3. **Verificacion concreta** — "lint pasa", "test LoginForm pasa", no "revisar"
4. **Asignacion por skill** — frontend→vivi, backend→ansem, tests→kuja (regla de proporcionalidad)
5. **Tokens estimados** — para que Quina controle el presupuesto
6. **Dependencias explicitas** — que tarea debe terminar antes

## Referencia de archivos

```
read .arnes/sdd/templates/tasks.md
```

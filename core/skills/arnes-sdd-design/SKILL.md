---
name: arnes-sdd-design
description: >
  ARNES SDD Fase 3 - Diseno tecnico. Crea el design.md con decisiones de arquitectura,
  estructura, flujo de datos, interfaces y contratos. Rol principal: Amarant (Monk).
  Trigger: Cuando el spec esta aprobado y necesitas definir COMO se implementa.
---

## Purpose

La fase **design** define la arquitectura: que archivos, que interfaces, como fluyen los datos.
Aqui se toman las decisiones (ADR) que se registraran en la FASE 5.

## Flujo

1. Copiar template: `.arnes/sdd/templates/design.md` → `.arnes/sdd/<change-id>/design.md`
2. Llenar:
   - **Decisiones (AD)**: tabla con alternativa elegida + razon
   - **Estructura**: arbol de archivos
   - **Flujo de datos**: como viaja la informacion
   - **Interfaces**: API, props, schemas, RLS
   - **Consideraciones**: escalabilidad, mantenibilidad, deuda aceptada

## Reglas

1. **Decide con evidencia** — cada AD con alternativa y razon (no "porque si")
2. **Estructura clara** — el arbol de archivos debe ser suficiente para tasks
3. **Anti-alucinacion** — `read .arnes/graph/edges.jsonl`: que ya existe, que librerias usa el repo
4. **Simplicidad primero** — no sobre-disenar; el minimo que cumple el spec
5. **ADR para decisiones grandes** — se registrara en .arnes/adr/ (FASE 5)

## Referencia de archivos

```
read .arnes/sdd/templates/design.md
```

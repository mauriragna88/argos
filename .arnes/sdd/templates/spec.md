# Spec — <Nombre del Cambio>

> **Change ID**: `C-<YYYYMMDD>-<NN>`
> **Basado en**: proposal <ID>
> **Fecha**: <YYYY-MM-DD>
> **Autor**: <agente>
> **Estado**: `draft` | `reviewed` | `approved`

---

## 1. Requirements (funcionales y no funcionales)

### R1 — <Requerimiento>
<Descripción del requerimiento. Qué debe poder hacer el sistema.>

**Scenarios**:
- **S1.1** — <Entrada/condición> → <Comportamiento esperado>
- **S1.2** — <Entrada/condición> → <Comportamiento esperado>

### R2 — <Requerimiento>
...

## 2. No-funcionales

- **Performance**: <latencia, throughput>
- **Seguridad**: <auth, RLS, validación>
- **Accesibilidad**: <WCAG nivel>
- **Compatibilidad**: <navegadores, dispositivos>

## 3. Restricciones / Constraints

- <stack obligatorio: TypeScript strict, Zod, Tailwind...>
- <convenciones del repo>
- <limitaciones conocidas>

## 4. Dependencias

- <librerías, servicios, otros cambios>
- <verificar en arnes-graph si ya existen>

## 5. Criterios de aceptación (para Tywin verify)

- [ ] <escenario verificable 1>
- [ ] <escenario verificable 2>
- [ ] Tests: <qué se prueba y cómo>

---
*Memoria: al aprobar, guardar en arnes.db `amarant/specs-created`*

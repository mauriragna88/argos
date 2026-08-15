# Design — <Nombre del Cambio>

> **Change ID**: `C-<YYYYMMDD>-<NN>`
> **Basado en**: spec <ID>
> **Fecha**: <YYYY-MM-DD>
> **Autor**: <Amarant o arquitecto>
> **Estado**: `draft` | `approved`

---

## 1. Decisiones de arquitectura

| # | Decisión | Alternativas | Por qué esta |
|---|---|---|---|
| AD-1 | <decisión> | <alt 1, alt 2> | <razón> |

## 2. Diagrama / Estructura

```
<estructura de archivos o flujo>
src/
  components/
    Login.tsx
  lib/
    validation.ts
```

## 3. Flujo de datos

<describir cómo fluye la información>

## 4. Interfaces / Contratos

- **API**: <endpoint, método, request/response>
- **Componente**: <props, eventos>
- **Schema**: <tabla, columnas, RLS>

## 5. Consideraciones

- **Escalabilidad**: <cómo crece>
- **Mantenibilidad**: <qué tan fácil de cambiar>
- **Deuda técnica aceptada**: <qué se pospone y por qué>

## 6. Plan de implementación (referencia a tasks)

- Ver `tasks.md` para el desglose

---
*Memoria: al aprobar, registrar ADR en .arnes/adr/ (FASE 5)*

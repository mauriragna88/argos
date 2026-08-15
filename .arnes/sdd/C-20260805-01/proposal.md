# Proposal — Login Form con Zod

> **Change ID**: `C-20260805-01`
> **Fecha**: 2026-08-05
> **Autor**: Usuario + Atlas
> **Estado**: `approved`
> **Tipo**: `feature`

---

## 1. Intención (¿Qué queremos lograr?)

Crear un formulario de login en el proyecto con validación Zod, TypeScript strict,
dark mode (preferencia de Vivi en memoria), y tests con Vitest. Reutilizar
Sidebar.tsx (ya existe en memoria de Vivi).

## 2. Alcance (¿Qué entra y qué NO entra?)

**Incluye**:
- Componente LoginForm.tsx (React, Server Component default, use client solo para interactivos)
- Validación Zod: email válido, password no vacío, mensajes de error accesibles
- Dark mode + rojo atlas (preferencia guardada: vivi/ui-patterns)
- Tests unitarios (Vitest): validación y render
- ARIA roles para accesibilidad

**NO incluye** (fuera de alcance):
- Backend de autenticación real (supabase auth) — otro change
- RLS policies — otro change
- Tests E2E completos — solo unit en este change

## 3. Enfoque propuesto

Componente Server por defecto con validación cliente (Zod schema compartido).
Se usa `use client` solo para el manejo de submit. Reutilizar el patrón de Sidebar.tsx.

## 4. Impacto estimado

- **Archivos afectados**: src/components/LoginForm.tsx, src/lib/validation.ts, tests
- **Tokens estimados**: 4.2K
- **Tiempo estimado**: 1 quest
- **Riesgo**: `bajo`
- **L0**: `no`

## 5. Criterios de éxito (verificables)

- [x] LoginForm.tsx creado con TypeScript strict (sin any)
- [x] Zod valida email inválido → muestra error accesible
- [x] Zod valida password vacío → muestra error
- [x] Tests Vitest pasan (12/12)
- [x] Dark mode aplicado (memoria vivi/ui-patterns)

## 6. Decisión

- [x] Aprobado por Atlas

---
*Memoria: al aprobar/rechazar, guardar en arnes.db `atlas/decisions`*


# Feature Plan — Login Form con Zod

> **Feature ID**: `F1` (referencia a FL-20260805-01)
> **Fecha**: 2026-08-05
> **Autor**: Vivi + Ansem
> **Estado**: `archived`

---

## 1. Descripción (una frase de valor)

Formulario de login con validación Zod, dark mode y tests — el usuario puede autenticarse de forma segura.

## 2. Alcance

**Incluye**:
- LoginForm.tsx (React, Server Component, zod validation)
- Mensajes de error accesibles (ARIA)
- Dark mode + rojo atlas (memoria vivi/ui-patterns)
- Tests Vitest unitarios

**NO incluye**:
- Backend de auth real (Supabase) — feature futura
- RLS policies — feature futura

## 3. Enfoque de implementación

Server Component por defecto, `use client` para submit. Zod schema compartido.
Reutilizar patrón de Sidebar.tsx (existe en memoria de Vivi).

## 4. Tareas de la feature

- [x] T1: src/components/LoginForm.tsx — crear componente (agente: vivi)
- [x] T2: src/lib/validation.ts — schema Zod (agente: ansem)
- [x] T3: src/components/LoginForm.test.tsx — tests (agente: kuja)

## 5. Verificación (criterios de done de la feature)

- [x] Lint + types + tests + build pasan
- [x] Zod valida email inválido → error accesible
- [x] Zod valida password vacío → error
- [x] Memoria guardada (vivi/components-built)
- [x] Grafo actualizado (Login.tsx → zod)

## 6. Estimación

- **Tokens estimados**: 4.2K
- **Quests estimados**: 1
- **Agentes**: vivi, ansem, kuja

---
*Memoria: al completar, registrar quest + feature done en arnes.db*

# Feature List — Sistema de Login

> **FDD List ID**: `FL-20260805-01`
> **Fecha**: 2026-08-05
> **Autor**: Usuario + Atlas
> **Estado**: `paused`

---

## Objetivo del Feature Set

Sistema de autenticación completo para el proyecto: login, password reset y dashboard
post-login. Cada feature es entregable independiente.

> **Nota de alcance:** esta lista pertenece a un proyecto de aplicación externo. Este
> repositorio contiene el harness ARNES y no tiene los archivos `src/components/LoginForm.tsx`
> ni `src/lib/validation.ts` referenciados por los planes. Se conserva como historial FDD y no se
> ejecutan F3/F4 aquí.

## Features (ordenadas por prioridad/valor)

| # | Feature | Prioridad | Tamaño | Depende de | Estado |
|---|---|---|---|---|---|
| F1 | Login Form con Zod | Alta | M | — | done |
| F2 | Password Reset | Media | S | F1 | done |
| F3 | Dashboard post-login | Media | M | F1 | blocked-external-project |
| F4 | Session timeout + refresh | Alta | S | F1 | blocked-external-project |

## Reglas de la lista

1. Cada feature es independientemente entregable
2. Tamaños: S = <1 quest, M = 1-2 quests, L = 3+ (subdividir)
3. Orden: F1 desbloquea a las demás
4. Al completarse: `done` → se archiva su plan individual

## Progreso

- [x] F1 — Login Form con Zod (done)
- [x] F2 — Password Reset (done)
- [ ] F3 — Dashboard post-login (bloqueada: proyecto externo)
- [ ] F4 — Session timeout + refresh (bloqueada: proyecto externo)

---
*Memoria: al crear/actualizar, guardar en arnes.db `atlas/quest-history`*

# Feature List — Harness ARNES (Quality of Life)

> **FDD List ID**: `FL-20260810-01`
> **Fecha**: 2026-08-10
> **Autor**: Atlas + Sisyphus
> **Estado**: `active`

---

## Objetivo del Feature Set

Mejorar la experiencia del harness ARNES ARGOS: progresión (XP), personalización visual,
visibilidad de uso de tokens y publicación en marketplaces. Cada feature es entregable
independiente y verificable con `argos doctor` + parseo PowerShell.

## Features (ordenadas por prioridad/valor)

| # | Feature | Prioridad | Tamaño | Depende de | Estado |
|---|---|---|---|---|---|
| F1 | Sistema XP en CLI (nivel por agente en /party y /status) | Media | S | — | done |
| F2 | Temas personalizables (Atlas rojo-negro, Vivi violeta, Amarant bronce) | Baja | S | — | done |
| F3 | Stats dashboard (tokens por sesión/día/semana, costo aprox, racha) | Media | M | F1 | done |
| F4 | Publicación en marketplaces (Smithery + skills.sh) | Baja | M | — | blocked-requires-release |
| F5 | Selector de entorno (target opencode/codex/claude) | Media | M | — | done |
| F6 | Modo autónomo por objetivo (argos goal / autowork) | Media | M | F1 | done |

## Reglas de la lista

1. Cada feature debe ser **independientemente entregable** (valor visible al terminar)
2. Tamaños: S = <1 quest, M = 1-2 quests, L = 3+ quests (L se subdivide en features M)
3. Orden: F1 desbloquea datos que F3 reutiliza
4. Al completarse: `done` → se archiva su plan individual

## Progreso

- [x] F1 — Sistema XP en CLI (done)
- [x] F2 — Temas personalizables (done)
- [x] F3 — Stats dashboard (done)
- [ ] F4 — Publicación en marketplaces (blocked-requires-release)
- [x] F5 — Selector de entorno opencode/codex/claude (done)
- [x] F6 — Modo autónomo por objetivo (done)

---
*Memoria: al crear/actualizar, guardar en arnes.db `atlas/quest-history`*

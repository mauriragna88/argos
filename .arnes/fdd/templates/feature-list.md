# Feature List — <Proyecto/Área>

> **FDD List ID**: `FL-<YYYYMMDD>-<NN>`
> **Fecha**: <YYYY-MM-DD>
> **Autor**: <usuario o Atlas>
> **Estado**: `active` | `completed` | `paused`

---

## Objetivo del Feature Set

<Qué se quiere lograr con este conjunto de features.>

## Features (ordenadas por prioridad/valor)

| # | Feature | Prioridad | Tamaño | Depende de | Estado |
|---|---|---|---|---|---|
| F1 | <nombre feature> | Alta/Media/Baja | S/M/L | — | pending |
| F2 | <nombre feature> | Alta | M | F1 | pending |
| F3 | <nombre feature> | Media | S | — | pending |
| ... | ... | ... | ... | ... | ... |

## Reglas de la lista

1. Cada feature debe ser **independientemente entregable** (valor visible al terminar)
2. Tamaños: S = <1 quest, M = 1-2 quests, L = 3+ quests (L se subdivide en features M)
3. Orden: primero features que desbloquean valor para las demás
4. Cada feature al completarse: `done` → se archiva su plan individual

## Progreso

- [ ] F1 — <estado>
- [ ] F2 — <estado>
- [ ] F3 — <estado>

---
*Memoria: al crear/actualizar, guardar en arnes.db `atlas/quest-history`*

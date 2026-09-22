# ADR-027 — Tool discovery con metadata (decisión tomada, implementación diferida al runner PI)

> **Fecha**: 2026-09-22
> **Autor**: Amarant (arquitectura)
> **Estado**: `accepted` (implementación diferida)
> **Relacionado**: ADR-022 (quest graph), ADR-012 (no crear fuentes paralelas), Fase 4

---

## Contexto

El plan de Fase 4 pedía tool discovery (`argos_tool_search`) para exponer **metadata** de
tools (nombre + descripción + cuándo + schema diferido hasta la selección) y así reducir el
contexto ocupado por catálogos completos. El catálogo real de tools vive en el runner PI /
opencode (decenas de tools), **fuera de este repo**; el runner nativo (`argos code/party`)
expone 6 tools fijas.

## Decisión

La decisión de diseño queda tomada: **metadata-first** (nombre + descripción + trigger) con
schema cargado solo al seleccionar, y búsqueda por query en el runner que tenga catálogo
grande. **La implementación se difiere al repo del runner PI** (`pi/extensions`), porque:

- En este repo no hay catálogo que descubrir (6 tools fijas): un "search" sobre ellas sería
  un índice de 6 entradas — dato muerto (anti-patrón ADR-004/012).
- Crear un catálogo paralelo de tools del harness violaría "no crear fuentes paralelas".

El benchmark (F6) medirá `tokens de catálogo` antes/después cuando el runner PI lo
implemente; en este repo no se simula.

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Catálogo en-repo sobre las 6 tools nativas | Rechazada: no hay nada que descubrir, sería ceremonia |
| B. **Metadata-first implementado en el runner PI** (ELEGIDA, diferida) | Donde vive el catálogo grande y el problema real de contexto |
| C. No hacerlo nunca | Rechazada: el objetivo (↓tokens de catálogo) es válido, solo cambia el repo |

## Consecuencias

- F4 en este repo cierra **quest graph + gate + invalidación** (ADRs 022/023); tool
  discovery queda como pendiente explícito del runner PI, sin bloquear F5/F6.
- Si el runner PI no se toca, el único costo es seguir cargando catálogos completos allí
  (medible con F6).

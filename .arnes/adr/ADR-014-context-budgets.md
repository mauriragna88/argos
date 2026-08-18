# ADR-014 — Context budgets por fuente

> **Fecha**: 2026-08-17
> **Autor**: Atlas (orquestación) + Amarant (arquitectura)
> **Estado**: `accepted`
> **Relacionado**: ADR-015 (utility score), ADR-016 (progressive disclosure), Fase 2

---

## Contexto

El contexto del turno se armaba como concatenación manual (argos-cognition.ts) con un
`max_tokens` global de `osma_context()`. Con 5+ fuentes distintas (memoria, experiencias,
principios, skills, evidencia), un tope global hace que una fuente dominante (ej. memoria)
consuma el presupuesto y deje fuera fuentes de mayor confianza (ej. principios/evidencia).

## Decisión

Cada fuente tiene su **propio presupuesto de tokens** (`memory=600, experience=400,
principles=500, skills=250, evidence=200`; total ~1950). El Context Compiler
(`cli/argos-context.ps1`) respeta el budget por fuente: selecciona filas por utility
descendente hasta agotar el presupuesto de ESA fuente, nunca el de otra.

- El presupuesto es configurable por quest vía `-Budgets` (JSON).
- Si una fuente falla, las demás siguen (degradación parcial — ver ADR-015).
- La telemetría (Fase 1) informa la calibración futura de los números.

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Un solo max_tokens global | Rechazada: fuente dominante ahoga a las demás |
| B. Presupuestos por fuente (ELEGIDA) | Cada fuente con tope propio; ninguna se come el contexto completo |
| C. Extender `osma_context()` con budgets | Rechazada: no se modifica el brain OSMA (repo global separado) |

## Consecuencias

- El turno inyecta ~2K tokens máx (vs. 6K del max_tokens global anterior) sin perder fuentes.
- `tokens_injected` se reporta en cada compile → medible contra la meta ≥20% de reducción.
- La relación `.arnes/principles/` es configuración versionada, no memoria (no viola OSMA).

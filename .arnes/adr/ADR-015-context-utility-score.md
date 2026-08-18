# ADR-015 — Context utility score

> **Fecha**: 2026-08-17
> **Autor**: Atlas (orquestación) + Amarant (arquitectura)
> **Estado**: `accepted`
> **Relacionado**: ADR-014 (budgets), ADR-016 (disclosure), Fase 2

---

## Contexto

Con presupuesto por fuente, hay que decidir QUÉ filas entran al contexto. Sin scoring,
entran las primeras (orden de retorno de cada fuente), que no son necesariamente las más
útiles (un recuerdo ruidoso puede ser más reciente que uno relevante).

## Decisión

Cada fila del contexto lleva un **context_utility_score** calculado por el Context
Compiler (no por el brain):

```
utility = (0.4*relevance + 0.3*validation + 0.3*salience) * trust / (1 + tokens/100)
```

- **relevance**: overlap de keywords entre el prompt y el texto (0-1).
- **validation**: confianza/reward de la fuente (experiencias validadas > observaciones).
- **salience**: proximidad/posición (recencia como proxy).
- **trust por fuente**: principles=1.0, evidence=1.0, experience=0.9, memory=0.7, skills=0.6.
- **token_cost**: penaliza filas largas (mismo contenido en menos tokens gana).

Las filas se ordenan por utility desc y se seleccionan hasta agotar el budget de la fuente.

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Orden de llegada | Rechazada: premia recencia, no utilidad |
| B. Utility score compuesto (ELEGIDA) | Reuse de cue_quality/salience/confidence de OSMA V6/V7, calculado en ARGOS |
| C. LLM-ranking | Rechazada: costo en tokens por fila, no determinista |

## Consecuencias

- El contexto inyectado es rankeado por utilidad real, no por orden.
- El score es transparente (cada fila lo lleva) → auditable por Tywin/Bran.
- Fase 3 puede usar el score para routing de modelos (score alto + quest difícil → pro).

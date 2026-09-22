# ADR-023 — Invalidación de nodos downstream

> **Fecha**: 2026-09-22
> **Autor**: Amarant (arquitectura) + Atlas (orquestación)
> **Estado**: `accepted`
> **Relacionado**: ADR-022 (quest graph), Fase 4

---

## Contexto

GAP_ANALYSIS P6.2: si un nodo cambia una **interfaz pública**, no existía propagación de
invalidación hacia los nodos dependientes — el trabajo downstream quedaba "pass" con una
base ya inválida (falso verde).

## Decisión

`quest-graph invalidate <nodo>` marca el nodo **y todos sus dependientes directos e
indirectos** (recursivo, con guard anti-ciclo) como `pending`, con
`evidence: "invalidado por cambio en '<nodo>'"` y `updated_at` nuevo. Los nodos
independientes **no se tocan**. La operación devuelve la lista de invalidados (JSON) para
auditoría y para que Atlas sepa qué rama reabrir.

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Invalidación manual nodo por nodo | Rechazada: se olvida un dependiente y el falso verde vuelve |
| B. **Propagación recursiva automática** (ELEGIDA) | Un cambio de interfaz reabre exactamente la rama afectada |
| C. Invalidar el grafo completo | Rechazada: tira trabajo independiente ya verificado |

## Consecuencias

- Cambiar un contrato (schema/API) reabre solo la rama dependiente.
- Test: cadena `n1→n2→n3` + nodo aislado `n9` intacto (`tests/quest-graph.tests.ps1`).
- La lista de invalidados queda disponible para que Atlas re-planifique con Sam.

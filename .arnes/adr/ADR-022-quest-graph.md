# ADR-022 — Quest graph (gate de Bran, estados, operaciones)

> **Fecha**: 2026-09-22
> **Autor**: Amarant (arquitectura) + Bran (gate) + Atlas (orquestación)
> **Estado**: `accepted`
> **Relacionado**: ADR-017 (contratos), ADR-018 (causa), ADR-023 (invalidación), Fase 4
> **Nota de numeración**: el plan listaba este ADR como "ADR-021", número ya ocupado por
> `ADR-021-cache-prefix.md`; se renumera a 022.

---

## Contexto

El plan pide activar quest graph **solo cuando Bran lo justifique**, evolucionando
`autonomous_tasks` (que vive en el brain OSMA, repo externo) — está prohibido crear un
motor paralelo. En este repo el patrón establecido es persistencia JSON/JSONL por quest
(ADR-012/017/019).

## Decisión

- **Gate obligatorio**: `quest-graph justify` evalúa señales explícitas y persiste
  `graph_justification` (quest, señales, `verdict: graph|linear`, razones). Sin señales ⇒
  **lineal** — no convertir todo en graph.
- El grafo vive por quest en `.arnes/quest-graph/<quest>.json`: nodos
  `{id,title,deps,status,evidence,updated_at}` + `paused` del grafo.
- **Estados**: `pending | ready | running | verifying | pass | fail | blocked | paused`.
  `next` = nodos pending/ready cuyos deps están en `pass` (con el grafo no pausado).
- **Operaciones**: `create` (desde TasksFile JSON), `set` (+evidence por nodo), `next`,
  `status`, `pause` (nodo o `-All`), `fork` (variante sin colisión), `invalidate` (ADR-023).
- Expuesto como `argos graph ...`.

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Quest graph como motor nuevo | Prohibida por el plan (y duplicaría `autonomous_tasks`) |
| B. Extender la tabla del brain OSMA | Rechazada: repo externo (misma regla que ADR-012/017/019) |
| C. **JSON por quest + gate de Bran** (ELEGIDA) | Cero acoplamiento, inspeccionable, testable en-repo |

## Consecuencias

- Los quests lineales no pagan overhead de graph (el gate es la puerta).
- Estados + evidence por nodo habilitan `next` (resume tras pausa) y alimentan L4 de la
  ladder (ADR-020) y la telemetría por nodo cuando el runner lo use.
- Tests herméticos: `tests/quest-graph.tests.ps1` (9 checks: gate lineal/graph, create,
  next por deps, set + evidence, invalidación, fork, pause por nodo y de grafo).

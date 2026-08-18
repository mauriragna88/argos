# IMPLEMENTATION_PLAN.md — Plan por Fases: ARNES ARGOS Model-Agnostic

> **Autor**: Amarant (Monk, Architecture) · **Fecha**: 2026-08-13 · **Fase**: 0 (plan, sin tocar código)
> **Reglas globales**: no reescribir ARGOS · no reemplazar OSMA · no crear memoria paralela · no crear otro loop engine · no framework externo central · no agregar agentes RPG (16 son suficientes) · reutilizar antes de crear · medir antes de optimizar · ningún cambio es exitoso sin evidencia verificable · ADRs se redactan al inicio de cada fase tras aprobación del usuario.
> **Referencias**: `GAP_ANALYSIS.md` (veredictos por prioridad) · `CURRENT_ARCHITECTURE.md` (estado real).

---

## FASE 1 — Telemetría de Modelos + Event Log (fundacional)

### Objetivo concreto
Que el harness registre **qué modelo hizo qué, con qué resultado y a qué costo** — la base de datos sin la cual ninguna decisión model-agnostic posterior (routing, self-optimization, benchmark) tiene evidencia. Además formalizar el event log append-only.

### Componentes a tocar
| Ruta | Cambio |
|---|---|
| `cli/arnes_brain.py` | Nueva tabla `model_runs` (o extensión de `skill_executions`) en `_migrate()` (aditivo, idempotente, patrón V4-V7); comandos `osma-model-run` (record) y `osma-model-stats` (agregados) |

> **NOTA DE IMPLEMENTACIÓN (2026-08-17)**: el brain real vive en el repo OSMA global
> (`~/.config/arnes/osma/osma_brain.py`, fuera de este repo). La telemetría de Fase 1
> se implementó **dentro de este repo** sin tocar el brain compartido:
> `cli/model-telemetry.ps1` (record/stats sobre `.arnes/model-runs.jsonl`, event log
> append-only) con hook automático en `loop-engine.ps1` (quest-done). El contrato de
> la tabla `model_runs` del brain queda como extensión futura del repo OSMA; el
> evento log cumple el criterio de done (stats con datos reales) desde ya.
| `pi/extensions/argos-learning.ts` | En `agent_settled`, registrar run: agent/model/provider/quest_type/difficulty/route/party/tokens_in/out/cached/cost/latency/loops/verdict/first_pass_success/reward_signal |
| `pi/extensions/argos-cognition.ts` | Pasar `path` (FAST/RECALL/SKILL/DELIBERATE/DEEP) elegido al registro |
| `cli/argos-engine.ps1` | Devolver `latency_ms`, `cached_tokens`, `cost_estimate` en la respuesta (ya devuelve usage) |
| `pi/extensions/argos-*.ts` (nuevo `argos-event-log.ts`) | Hook `tool_call` + `before_agent_start` + `agent_settled` que escriben eventos JSONL append-only |
| `.arnes/event-log.jsonl` | Nuevo archivo (append-only, no memoria — OSMA sigue siendo el cerebro) |
| `core/auditors/varys.agent.md` | Varys como **dueño del event log**: garantizar que cada quest deje rastro reconstruible |

### Comandos/herramientas OSMA nuevos a crear
- `osma-model-run` (registrar run de modelo con todos los campos de telemetría)
- `osma-model-stats` (agregados: success_rate, avg_loops, tokens_per_pass, cost_per_pass por model×quest_type)
- `argos_event_log` (tool PI: append evento) — o hook directo, sin tool expuesta
- `argos_model_stats` (tool PI: consultar stats de modelos)

### Hooks PI a extender
- `before_agent_start`: capturar ruta cognitiva decidida + contexto inyectado (para medir `tokens_injected_per_turn` en F2)
- `agent_settled`: escribir `model_runs` + evento `quest_settled` con verdict

### Skills a crear o evolucionar
- **Evolucionar** `core/skills/v2/quina-ledger/SKILL.md`: Quina lee `osma-model-stats` para presupuestar (no solo ledger manual)
- **Evolucionar** `core/skills/v2/bran-vision/SKILL.md`: Bran lee `osma-model-stats` para Allocate (primer paso de self-optimization)

### Pruebas obligatorias (9 tests, nivel V6/V7)
1. `osma-model-run` registra todos los campos (agent/model/provider/quest_type/route/tokens/latency/verdict/reward)
2. Migración idempotente: correr `_migrate()` dos veces no duplica tabla ni rompe schema_version '7'
3. `osma-model-stats` calcula success_rate y tokens_per_pass correctos con datos sintéticos
4. `agent_settled` escribe model_runs sin romper el flujo existente (save→link→reinforce→experience)
5. Fallo de escritura de telemetría nunca rompe el hook (try/except, patrón V7 reactivation)
6. Event log append-only: los eventos de un quest se reconstruyen en orden
7. Event log no interfiere con OSMA (no se importa a observaciones — memoria paralela prohibida)
8. `quest-ledger.json` sigue escribiéndose (compatibilidad con el sistema actual)
9. Benchmark mínimo: mismo quest con 2 modelos distintos produce 2 rows comparables en model_runs

### Criterio de done verificable
- `osma-model-stats` responde agregados reales desde un quest ejecutado (evidencia: filas en model_runs con model/provider/tokens/verdict)
- `.arnes/event-log.jsonl` contiene el ciclo completo de ≥1 quest (evidence_pack → verdict → decision)
- `npm test` verde (suite existente + 9 nuevos)
- **NO** se cambió ninguna decisión de routing todavía (esto es solo medir)

### Dependencias
- Ninguna (fase fundacional).

### Qué NO hacer en esta fase
- No tocar `model-routing-policy.json` (ni scoring, ni fallback) — solo instrumentar
- No crear tabla duplicada de `skill_executions` si se puede extender; si se crea `model_runs`, documentar relación (no duplicar campos que ya viven en skill_executions)
- No rediseñar `osma_context()`
- No agregar agentes

### ADRs que inicia Amarant en esta fase
- **ADR-011** — Scoring dinámico de modelos (se redacta la fórmula y fuentes; la implementación del scoring es F2/F3, pero la decisión de schema se toma aquí)
- **ADR-012** — Esquema telemetría de modelos (model_runs vs extensión de skill_executions; campos; relación con quests/experiences)
- **ADR-013** — Perfiles de capacidades AGENT≠MODEL (formato, jerarquía con model-routing-policy.json)
- **ADR-025** — Event log (formato JSONL, granularidad, dueño Varys, retención, separación de OSMA)

---

## FASE 2 — Context Compiler + Golden Principles

### Objetivo concreto
Construir el contexto óptimo del turno con presupuesto por fuente y scoring de utilidad, y estructurar los golden principles como fuente más del contexto.

> **NOTA DE IMPLEMENTACIÓN (2026-08-17)**: implementado dentro de este repo sin tocar
> el brain OSMA (extender `osma_context()` con budgets queda como extensión futura del
> repo OSMA): `cli/argos-context.ps1` (compile con presupuesto por fuente + utility
> score + degradación parcial, consumiendo `osma-memory recall`/`experience search`),
> `.arnes/principles/` (6 archivos: general/architecture/frontend/backend/security/
> testing), progressive disclosure de skills (`argos skills meta` + `readSkillFrontmatter`
> en PI, `loadSkillContent` al activar), skill `bard-drift` (auditoría contra principios),
> Step 1.7 en el orquestador y comandos `argos context` / `/context`. ADR-014/015/016.

### Componentes a tocar
| Ruta | Cambio |
|---|---|
| `cli/arnes_brain.py` | **Extender** `osma_context()` → aceptar presupuesto por fuente (`system/quest/memory/files/skills/evidence`) en vez de un `max_tokens` global; exponer `context_utility_score` por fila (relevance × trust × validation × salience × task_fit ÷ token_cost, reusando cue_quality/salience/confidence de V6/V7) |
| `pi/extensions/argos-cognition.ts` | Nuevo módulo `argos-context.ts` (o refactor de cognition) que orquesta fuentes: memoria OSMA + working memory + ADRs + errores/soluciones + contradicciones + skills + archivos repo + quest actual + acceptance criteria + evidence_pack + principios |
| `.arnes/principles/` | Crear `general.md`, `architecture.md`, `frontend.md`, `backend.md`, `security.md`, `testing.md` (contenido corto, no prompts gigantes) |
| `core/auditors/tywin.agent.md` | Proveer `acceptance criteria` estructuradas al Context Compiler |
| `pi/extensions/argos-skills.ts` | **Progressive disclosure**: `discoverSkills()` expone metadata (name/description/trigger) y solo se carga el SKILL.md completo al activarse |

### Comandos/herramientas OSMA nuevos
- `osma-context` extendido (param `budgets` JSON: por fuente)
- `argos_context_compile` (tool PI: compilar contexto del turno según ruta cognitiva)
- `argos_skill_meta` (tool PI: metadata de skills para disclosure)

### Hooks PI a extender
- `before_agent_start`: usar `argos_context_compile` en lugar de la concatenación manual actual (argos-cognition.ts) — **misma inyección, mejor selección**
- `agent_settled`: registrar qué recuerdos del contexto fueron usados (proxy de relevance)

### Skills a crear o evolucionar
- **Crear** `core/skills/v2/bard-drift/SKILL.md` (o evolucionar bard.agent.md): Bard audita código contra `.arnes/principles/` (drift detection)
- **Evolucionar** `core/skills/v2/amarant-foresight/SKILL.md`: usar context compiler para su RECALL

### Pruebas obligatorias (9 tests)
1. `osma-context` con budgets por fuente respeta el presupuesto de cada fuente (system ≤ X, memory ≤ Y, …)
2. `context_utility_score` rankea un recuerdo relevante (cue match alto + salience alta + confianza alta) por encima de uno ruidoso
3. Selección de 5-15 recuerdos: con 300 observaciones, el contexto inyecta ≤ 15
4. Progressive disclosure: `skill_meta` lista 14+ skills sin cargar sus SKILL.md; el SKILL.md solo se lee al activar
5. Los principios de `.arnes/principles/` se inyectan solo los relevantes al quest type
6. Context compile con quest frontend ≠ quest backend (diferentes fuentes ponderadas)
7. Sin regresión: el contexto compilado contiene al menos lo que el pipeline actual inyecta (osma-context + experiencia previa)
8. Fallo de una fuente (ej. skills) no bloquea el contexto (degradación parcial)
9. `tokens_injected_per_turn` se reduce ≥20% vs Fase 1 para quest trivial (evidencia de presupuesto)

### Criterio de done verificable
- `argos_context_compile` produce contexto con presupuestos por fuente verificables (JSON de budgets) y utility scores
- 9 tests nuevos verdes + suite existente verde
- Un quest trivial del benchmark muestra reducción de tokens inyectados sin pérdida de PASS rate

### Dependencias
- Fase 1 (usa model_runs para calibrar presupuestos; usa event log para medir)

### Qué NO hacer en esta fase
- No crear un "motor de contexto" separado de `osma_context()` — es extensión de la misma función
- No meter 300 recuerdos al prompt
- No tocar el routing de modelos (el scoring se implementa en F3)
- No convertir `.arnes/principles/` en otro CONVENTIONS.md duplicado — decidir relación en ADR-016 (progressive disclosure) y en una nota de diseño

### ADRs que inicia Amarant en esta fase
- **ADR-014** — Context budgets por fuente
- **ADR-015** — Context utility score
- **ADR-016** — Progressive disclosure de skills

---

## FASE 3 — Loop Contract Engine + Tywin Verification Ladder

### Objetivo concreto
Convertir el loop actual en un sistema de contratos por quest (FAIL→causa→remediation→variable cambiada→retry) y dar a Tywin una ladder de verificación explícita con preferencia determinista.

### Componentes a tocar
| Ruta | Cambio |
|---|---|
| `cli/loop-engine.ps1` | Aceptar/crear LOOP CONTRACT por quest: goal/acceptance/verification/max_iterations/token_budget/cost_budget/progress_signal/retry_policy/escalation_policy/stop_conditions/abort_conditions (JSON en `.arnes/loop-contracts/Q-XXX.json`) |
| `cli/arnes_brain.py` | Nueva tabla `loop_attempts` (quest_id, attempt, failure_signature, root_cause, remediation, strategy_delta, result) — o extensión de `quests`/`autonomous_tasks` |
| `core/auditors/tywin.agent.md` | Ladder 6 niveles: L1 STATIC/L2 MECHANICAL/L3 BEHAVIORAL/L4 QUEST/L5 ADVERSARIAL/L6 REGRESSION; `verification_level` en verdict; regla "si existe forma determinista, no opinión" |
| `core/skills/arnes-contract-audit/SKILL.md` | Integrar como parte de L1/L3 de la ladder (ya existe ADR-006) |
| `core/auditors/sam.agent.md` | Sam conseja con `loop_attempts` (causas repetidas) — ya tiene sam-digest |
| `.arnes/loop-state.json` | Schema extendido: contract_id, current_cause, strategy_delta |

### Comandos/herramientas OSMA nuevos
- `osma-loop-contract` (crear/consultar contrato)
- `osma-loop-attempt` (registrar intento con causa)
- `argos_loop_state` (tool PI: estado del loop con causa actual)
- (Tywin): `argos_verdict` extendido con `verification_level`

### Hooks PI a extender
- `before_agent_start`: inyectar el LOOP CONTRACT del quest actual (goal, acceptance, stop_conditions)
- `agent_settled`: registrar `loop_attempt` con la causa clasificada (modelo vs contexto vs tool vs spec vs entorno vs implementación)

### Skills a crear o evolucionar
- **Evolucionar** `core/skills/v2/tywin-judgment/SKILL.md`: ladder 6 niveles + verification_level en verdict
- **Evolucionar** `core/skills/v2/sam-counsel/SKILL.md`: usa loop_attempts para consejo anti-repetición
- **Evolucionar** `core/skills/v2/eiko-mend/SKILL.md`: Eiko elige remediación según causa clasificada (no "Mend" genérico)

### Pruebas obligatorias (9 tests)
1. LOOP CONTRACT se crea y persiste por quest con todos los campos
2. `loop_attempt` registra failure_signature/root_cause/remediation/strategy_delta
3. Clasificador de causa distingue modelo vs spec vs contexto (casos sintéticos)
4. Retry con strategy_delta cambia UNA variable (modelo O contexto O party — nunca todo)
5. FAIL sin remediation sigue inválido (regla Tywin preservada)
6. Verdict incluye verification_level (L1-L6) y evidence_command cuando es determinista
7. Ladder: un quest con test ejecutable no puede ser PASS por inspección LLM (regla enforce)
8. Contract violado (max_iterations excedido) → abort_conditions activa → pausa documentada
9. Compatibilidad: loop-state.json legacy sigue leyéndose (migración de campos)

### Criterio de done verificable
- `.arnes/loop-contracts/Q-XXX.json` existe para un quest real con contrato completo
- `loop_attempts` muestra al menos 1 FAIL con causa clasificada y strategy_delta
- Verdict JSON de Tywin incluye `verification_level` y evidence de comando ejecutado
- 9 tests verdes + suite existente

### Dependencias
- Fase 1 (telemetría alimenta la clasificación de causa: si el modelo falla igual en spec buena → causa modelo; si falla distinto → otra causa)
- Fase 2 (context compiler: "problema de contexto" como causa necesita presupuestos medidos)

### Qué NO hacer en esta fase
- No crear un loop engine nuevo — extender `cli/loop-engine.ps1`
- No reemplazar a Tywin — la ladder es su marco de trabajo
- No auto-escalar modelo sin evidencia (la escalación de modelo sigue siendo del router de F3+ y siempre con causa)

### ADRs que inicia Amarant en esta fase
- **ADR-017** — Contratos de loops
- **ADR-018** — Clasificación de causa de fallo y estrategia de retry
- **ADR-020** — Verification Ladder

---

## FASE 4 — Quest Graph (evolución de autonomous_tasks) + Tool Discovery

### Objetivo concreto
Activar quest graph solo cuando Bran lo justifique, evolucionando `autonomous_tasks` (no motor nuevo), e implementar tool discovery con metadata.

### Componentes a tocar
| Ruta | Cambio |
|---|---|
| `cli/arnes_brain.py` | **Extender** `autonomous_tasks`: agregar estado `VERIFYING`, columna `evidence` por nodo (ya existe), operaciones `task-resume/retry/fork/pause`, propagación de invalidación downstream |
| `core/auditors/bran.agent.md` | Gate de graph: Bran decide cuándo usar quest graph (múltiples features, dependencias, frontend/backend paralelos, migraciones, integraciones, proyectos nuevos, fan-out/fan-in, tareas largas) — escribe `graph_justification` |
| `core/repo-sizer.agent.md` | Input para la decisión de Bran |
| `pi/extensions/argos-orchestrator.ts` | Cuando Bran justifica graph: crear quest con tasks del graph (vía `aquest`/`atask`) |
| `pi/extensions/argos-memory.ts` | **Tool discovery**: `argos_tool_search(query)` + metadata de tools; cargar schema completo solo tras seleccionar |

### Comandos/herramientas OSMA nuevos
- `osma-task-invalidate` (invalidar nodos downstream cuando una interfaz pública cambia)
- `osma-task-resume` / `osma-task-fork` / `osma-task-pause` (por nodo)
- `argos_tool_search` (tool PI)
- `osma-graph-justify` (registrar justificación de Bran y medir si el graph valió la pena)

### Hooks PI a extender
- `before_agent_start`: si quest es graph, inyectar estado del nodo (BLOCKED/READY/RUNNING/VERIFYING/PASS/FAIL/PAUSED + dependencies)
- `agent_settled`: marcar nodo VERIFYING/PASS/FAIL con evidence

### Skills a crear o evolucionar
- **Evolucionar** `core/skills/v2/bran-vision/SKILL.md`: gate de graph (justificación + costo/beneficio)
- **Evolucionar** `core/skills/v2/atlas-orchestrate/SKILL.md`: orquestación de quest graph

### Pruebas obligatorias (9 tests)
1. Gate de Bran: quest simple NO genera graph; quest multi-dependencia SÍ
2. `osma-task-invalidate`: nodo que cambia interfaz pública invalida dependientes directos e indirectos
3. Retry por nodo: fallo en un nodo → retry solo ese nodo, sin tocar PASS anteriores
4. Fork: un nodo se duplica en 2 variantes sin colisión
5. Pause por nodo: pausar un nodo no bloquea nodos independientes
6. Estado VERIFYING se asigna antes de verificación y pasa a PASS/FAIL con evidence
7. `argos_tool_search("supabase migration")` devuelve las tools correctas (schema/diff/migrate)
8. Tools legacy (argos_memory_search etc.) siguen registradas siempre (compatibilidad)
9. Quest graph no aumenta tokens en quests simples (medir graph_overhead)

### Criterio de done verificable
- Un quest tipo boss con dependencies se ejecuta con graph: nodos con estados, invalidación funcionando, resume desde nodo FAIL
- `argos_tool_search` funciona y la carga de schemas de tools disminuye en el contexto (medible)
- 9 tests verdes + suite existente

### Dependencias
- Fase 1 (event log para reconstruir nodos), Fase 3 (contratos de loop por nodo)

### Qué NO hacer en esta fase
- No convertir todo en graph — el gate de Bran es obligatorio
- No crear un quest graph paralelo a `autonomous_tasks`
- No confundir con `edges` (grafo de relaciones)

### ADRs que inicia Amarant en esta fase
- **ADR-021** — Quest graph (gate de Bran, estados, operaciones)
- **ADR-022** — Invalidación de nodos downstream
- **ADR-023** — Tool discovery (metadata de tools)

---

## FASE 5 — Regression Factory

### Objetivo concreto
Cuando FAIL → remediation → PASS, analizar si el fallo puede volverse guard (unit/integration/browser/schema assertion/security rule/lint/static check/contract test/golden principle) y crearlo con trazabilidad.

### Componentes a tocar
| Ruta | Cambio |
|---|---|
| `cli/arnes_brain.py` | Nueva tabla `regressions` (id, memory_id, quest_id, failure_signature, guard_type, guard_path, status, created_by, created_at) + relación memory_id→regression_id |
| `core/auditors/tywin.agent.md` | En PASS post-FAIL, Tywin emite sugerencia de regression (con el remediation_brief cerrado como input) |
| `core/classes/rogue.agent.md` (Kuja) | Kuja implementa el guard (unit/integration/browser/contract) |
| `core/auditors/auron.agent.md` | Auron valida guards de seguridad (security rule) |
| `core/skills/arnes-contract-audit/SKILL.md` | Los guards de contract se registran en la tabla regressions |
| `core/skills/v2/kuja-backstab/SKILL.md` | Kuja crea guards como parte de su flujo |

### Comandos/herramientas OSMA nuevos
- `osma-regression-create` (registrar guard con memoria_id/quest_id/failure_signature)
- `osma-regressions` (listar guards por quest/failure)
- `osma-regression-check` (correr guards de un quest — conecta con L6 de la ladder en F3)
- `argos_regression_create` (tool PI)

### Hooks PI a extender
- `agent_settled`: cuando verdict es PASS tras FAIL, auto-sugerir regression candidate (con failure_signature de loop_attempts)

### Skills a crear o evolucionar
- **Crear** `core/skills/arnes-regression-factory/SKILL.md` (procedimiento: analizar FAIL→PASS, decidir tipo de guard, crear, registrar)

### Pruebas obligatorias (9 tests)
1. FAIL→remediation→PASS produce una regression candidate con failure_signature
2. `osma-regression-create` persiste memory_id→quest_id→failure_signature
3. Guard unit: un fix que era una assertion se convierte en test unit que captura el bug original
4. Guard contract: un drift DB↔API capturado por contract-audit se registra como regression
5. Guard security: una regla de RLS faltante se convierte en security rule guard
6. Regression guard falla cuando el bug se reintroduce (el test rojo es el proof)
7. Regression guard pasa cuando el fix está (verde)
8. No-duplicación: el mismo failure_signature no crea guards duplicados
9. L6 de la ladder (F3) ejecuta la suite de regressions en cada quest del mismo dominio

### Criterio de done verificable
- Al menos 2 guards reales creados desde quests con FAIL previo, con test que falla al reintroducir el bug
- `osma-regressions` lista guards con trazabilidad completa
- 9 tests verdes + suite existente

### Dependencias
- Fase 3 (clasificación de causa y ladder: la regression nace de un FAIL clasificado y se valida en L6)
- Fase 4 (si el quest usó graph, las regresiones se asocian a nodos)

### Qué NO hacer en esta fase
- No duplicar `arnes-contract-audit` (los guards de contract se registran en regressions, no se reimplementan)
- No duplicar `osma-pattern-detect` (los patrones V5 siguen siendo conocimiento; regressions son guards ejecutables)
- No crear guards para fallos no reproducibles (gate: solo deterministas/reproducibles)

### ADRs que inicia Amarant en esta fase
- **ADR-019** — Regression Factory (relación memory→regression→quest, tipos de guard, dueños)

---

## FASE 6 — Code Mode (reducido) + Benchmark formal

### Objetivo concreto
Implementar el router de modo de ejecución (DIRECT_TOOL/CODE_MODE/AGENT/SUBAGENT) con CODE_MODE reducido (script local sin sandbox, con Auron Gate reforzado; sandbox real diferido) y formalizar el benchmark del harness: Modelo X sin ARGOS vs Modelo X + ARGOS.

### Componentes a tocar
| Ruta | Cambio |
|---|---|
| `pi/extensions/argos-orchestrator.ts` | Router de modo: decidir DIRECT_TOOL vs CODE_MODE vs AGENT vs SUBAGENT según la secuencia de tools necesaria |
| `pi/extensions/argos-permissions.ts` + `argos-permissions-core.ts` | Auron Gate reforzado para code mode: bloquear scripts que toquen rutas protegidas/comandos destructivos incluso dentro de un script |
| `cli/argos-engine.ps1` | Soporte para ejecutar script generado (TS/Python) con resultado compacto |
| `pi/extensions/argos-brain.ts` | Canal de resultado grande fuera de contexto (procesar output grande → resumen compacto) |
| `cli/smoke-test.ps1` / `tests/` | Benchmark: runner que ejecuta el mismo quest con y sin ARGOS, comparando métricas |

### Comandos/herramientas OSMA nuevos
- `argos_mode_route` (tool PI: decidir modo de ejecución)
- `osma-benchmark-run` (registrar benchmark: modelo, con/sin ARGOS, PASS rate, tokens, cost, latency, loops, regressions, security findings, human intervention)

### Hooks PI a extender
- `tool_call`: interceptar intentos de CODE_MODE y aplicar Auron Gate antes de ejecutar
- `agent_settled`: registrar resultado del modo elegido en model_runs (F1) para comparar

### Skills a crear o evolucionar
- **Evolucionar** `core/skills/v2/auron-bulwark/SKILL.md`: L0 Gate para code mode (scripts generados)
- **Crear** `core/skills/arnes-benchmark/SKILL.md`: procedimiento del benchmark interno

### Pruebas obligatorias (9 tests)
1. Router de modo elige DIRECT_TOOL para 1-2 tools y CODE_MODE para secuencias >N
2. Script CODE_MODE con `rm -rf`/ruta protegida es bloqueado por Auron Gate
3. CODE_MODE devuelve resultado compacto (output grande → resumen < umbral)
4. Resultado de code mode se registra en model_runs (mismo formato que DIRECT_TOOL)
5. Benchmark runner ejecuta mismo quest con/sin ARGOS y produce comparativa
6. Métricas del benchmark: PASS rate, first_pass, tokens, cost, latency, loops, regressions, security findings, human intervention
7. Modelo medio + ARGOS ≥ mismo modelo sin ARGOS en PASS rate (el objetivo central)
8. Sin regresión: DIRECT_TOOL sigue funcionando como antes (code mode es opt-in)
9. Auron Gate: script peligroso con intento de bypass es bloqueado (incluso si el LLM lo escribe "inocente")

### Criterio de done verificable
- Benchmark reporta al menos 1 par (mismo modelo con/sin ARGOS) con las 9 métricas
- CODE_MODE activo en un quest real con ahorro de tokens medido
- Auron Gate bloquea un script destructivo en test
- 9 tests verdes + suite existente

### Dependencias
- Fase 1 (telemetría), Fase 2 (context), Fase 3 (loop+verificación), Fase 4 (graph), Fase 5 (regresiones) — el benchmark compara el harness completo

### Qué NO hacer en esta fase
- No implementar sandbox real (diferido: requiere decisión de runtime aislado, fuera de alcance)
- No ejecutar código destructivo sin Auron Gate — nunca
- No hacer el benchmark "a mano" — el runner debe ser reproducible
- No usar el benchmark para auto-escalar modelos todavía (eso requiere revisión de ADR-011/013 con datos reales)

### ADRs que inicia Amarant en esta fase
- **ADR-024** — Code Mode (política de modos, Auron Gate para scripts, sandbox diferido)
- **ADR-026** — Benchmark interno del harness (métricas canónicas, runner, criterio de éxito: modelo medio + ARGOS ≥ modelo sin ARGOS)

---

## Tabla de dependencias entre fases

```
F1 Telemetría + Event Log ──► F2 Context Compiler ──► F3 Loop Contract + Ladder ──► F4 Quest Graph + Tool Discovery ──► F5 Regression Factory ──► F6 Code Mode + Benchmark
        │                       │                         │                            │
        └──► alimenta ──────────┘                         └──► alimenta ──────────────┘
```

- **F2** necesita F1 (calibrar presupuestos con datos reales).
- **F3** necesita F1 (causa de fallo con telemetría) + F2 (causa "contexto" medible).
- **F4** necesita F1 (event log para reconstruir nodos) + F3 (contratos por nodo).
- **F5** necesita F3 (causa clasificada + ladder L6).
- **F6** necesita F1-F5 (benchmark del harness completo).

## Reglas de ejecución por fase (transversales)

1. **Cada fase termina con evidencia**: criterio de done verificable + 9 tests + suite existente verde. "Compila" no es done.
2. **ADRs al inicio de cada fase**: Amarant redacta los ADRs listados tras aprobación del usuario. NO redactar antes.
3. **Reutilizar antes de crear**: cada fase comienza con una verificación de que no existe la base (las rutas de "evolución" en este plan son explícitas).
4. **Medir antes de optimizar**: OSMA V8 solo se propone si las métricas de F1-F2 (memory_precision, memory_hit_rate, contradiction_rate, tokens_per_useful_memory, reward_after_retrieval) muestran una propiedad cognitiva faltante.
5. **Auron conserva L0 Gate** en todas las fases: migraciones, RLS, auth, secretos, deploy, cambios destructivos, shell peligroso, eliminación masiva, permisos, infra sensible.
6. **No agregar agentes RPG**: toda capacidad nueva se mapea a servicio/extensión/skill/estructura OSMA/componente existente (los 16 agentes son suficientes).
7. **Idioma es-MX en todo documento**; nombres técnicos en inglés cuando son estándar.

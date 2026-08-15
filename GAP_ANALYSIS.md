# GAP_ANALYSIS.md — Análisis de Brechas: 10 Prioridades para ARNES ARGOS Model-Agnostic

> **Autor**: Amarant (Monk, Architecture) · **Fecha**: 2026-08-13 · **Fase**: 0 (análisis, sin tocar código)
> **Método**: para cada prioridad — qué existe (ruta/evidencia), qué falta (gap concreto), riesgo, ADRs pendientes, métricas a instrumentar, y veredicto contra el principio de diseño (↑success/↓tokens/↓cost/↓retries/↓latency/↑seguridad/↑observabilidad/↑recuperación).

**Criterio de aprobación global** (del prompt): toda capacidad nueva debe justificar al menos una métrica. Si no la justifica → `NO ENTRA`.

---

## P1 — MODEL CAPABILITY ROUTER 2.0

### YA EXISTE
- Catálogo estático de modelos × plataforma × suscripción: `core/model-router.agent.md`, `.arnes/model-recommendations.json`.
- Política declarativa de preferencia/fallback: `.arnes/model-routing-policy.json` (v2.0.0, `resolution_mode: catalog_backed_aliases`, `preference_order` por agente, `stuck_agent_rule`, `on_error_429_401_410`).
- Resolución de modelos en PI: `pi/extensions/argos-model-router.ts` (`loadAgentModels` lee `~/.config/arnes/agent-models.json` + `.arnes/model-assignments.json`).
- Motor de completions directo: `cli/argos-engine.ps1` (bai/nvidia/opencode-go/openai, retry 429, MaxTokens).
- Fallback chain por agente: `model-routing-policy.json` `agents[*].preference_order`; `model-chain.json` (legacy, read_only).
- Tabla `skill_executions` en `cli/arnes_brain.py:188-209` **ya captura** `model`, `provider`, `tokens_in`, `tokens_out`, `tool_calls`, `verdict`, `success` — la semilla de telemetría (hoy nadie la lee para routing).
- Comando `route` en `arnes_brain.py:3372` (clasificación por query+risk).

### FALTA (gap concreto)
1. **Separación AGENT ≠ MODEL formal**: hoy `config.json` y `agent-models.json` atan un modelo a un agente. Falta el perfil de capacidades requeridas por agente (YAML `requires/prefers/fallback`) independiente del modelo concreto.
2. **Perfil de modelos** (coding/reasoning/tool_use/speed/cost/context): no existe; `model-recommendations.json` solo tiene "best_for" textual.
3. **Telemetría histórica estructurada**: no existe tabla `model_runs` ni extensión de `experiences` para `agent/model/provider/quest_type/difficulty/route/party/tokens/cost/latency/loops/verdict/first_pass_success/reward_signal`. `quest-ledger.json` solo guarda agent/verdict/tokens; `skill_executions` guarda parcial pero sin `difficulty`, `route`, `party`, `latency`, `loops`, `reward_signal`.
4. **Score dinámico**: no existe `capability_fit × historical_success × availability × trust × cost_efficiency × latency_fit`.
5. **Políticas explícitas**: cheap-first/balanced/quality-first/emergency/offline-fallback no están como conjunto seleccionable (solo hay tiers por suscripción).
6. **Clasificación de causa de fallo** (modelo vs contexto vs tool vs spec vs entorno vs implementación): no existe; hoy `stuck_agent_rule` solo cuenta 3 fails y cambia de modelo.

### RIESGO
- **Duplicar fuentes de verdad**: ya hubo fragmentación (5 archivos) que ADR-004 resolvió. Cualquier "nuevo router" debe **extender** `model-routing-policy.json` (fuente declarada) o consolidarla, nunca crear otra.
- Duplicar `skill_executions` con una tabla nueva sin migrar — riesgo de dato muerto doble.
- Escalar modelo sin distinguir causa (el anti-patrón que el prompt explícitamente prohíbe).

### ADRs pendientes (NO redactar ahora)
- **ADR-011** — Scoring dinámico de modelos (fórmula, pesos, fuentes de telemetría, qué tabla).
- **ADR-012** — Esquema OSMA de telemetría de modelos (`model_runs` o extensión de `skill_executions`/`experiences`).
- **ADR-013** — Perfiles de capacidades por agente (formato YAML, separación AGENT≠MODEL, jerarquía con model-routing-policy.json).

### MÉTRICAS A INSTRUMENTAR (antes de implementar)
- `model_success_rate` por (model, quest_type, difficulty)
- `model_avg_loops` / `model_first_pass_rate`
- `tokens_per_pass` por modelo vs agente
- `cost_per_pass` (entran Quina + ledger)
- `fallback_trigger_rate` (cuántas veces el stuck_agent_rule cambia modelo)
- `false_escalation_rate` (veces que se escaló modelo cuando la causa era spec/contexto/tool)

### VEREDICTO: **ENTRA** (↑success, ↓cost, ↓retries, ↓latency, ↑observabilidad)
La telemetría de modelos es el requisito fundacional del harness model-agnostic: sin datos de desempeño, ninguna decisión de routing puede ser evidence-based. Es además la prioridad con más partes ya existentes (policy V2 + skill_executions) — el trabajo es principalmente **cablear y medir**, no construir de cero.

---

## P2 — CONTEXT COMPILER

### YA EXISTE
- `osma_context()` en `cli/arnes_brain.py:1683`: paquete de recall contextual con **presupuesto de tokens** (`max_tokens`, default 6000) y trim ordenado por prioridad (`associations`→`errors_solutions`→`agents`→`contradictions`→`decisions`→`direct`).
- Inyección en `before_agent_start`: `pi/extensions/argos-cognition.ts:53-99` (osma-context 600 tokens) y `:104-141` (experiencia previa top 3).
- `osma-cue-search` (V6) ya rankea por relevance (cue_quality, convergencia, salience, competencia).
- Fuentes ya disponibles en OSMA: memoria (observations), experiencias, ADRs, errores+soluciones (bugfix/discovery), contradicciones, working memory, cognitive_checkpoints (estado del turno).

### FALTA (gap concreto)
1. **Presupuesto explícito por fuente** (system/quest/memory/files/skills/evidence con pesos dinámicos según context window, modelo, quest type, ruta cognitiva, complejidad): hoy es un solo `max_tokens` global.
2. **Context utility score** = relevance × trust × validation × salience × task_fit ÷ token_cost: no existe como función; el trim es por orden fijo, no por score.
3. **Selección de 5-15 recuerdos útiles** en vez de caps fijos (5 decisiones/5 errores/5 agentes/3 contradicciones): hoy `argos-cognition.ts` usa caps hardcodeados.
4. **Progressive disclosure de skills/Superpowers**: hoy `discoverSkills()` lista todo; el agente debe leer el SKILL.md completo para saber qué contiene. Falta metadata-first (nombre + descripción + cuándo) y contenido profundo solo al activarse.

### RIESGO
- **Duplicar osma-context**: hay que **extender** `osma_context()` (misma función, más granular) o crear un orquestador nuevo que la llame — no un motor de contexto paralelo.
- Meter demasiada memoria al prompt (el anti-patrón "300 recuerdos") — mitigado por presupuesto por fuente.
- Progressive disclosure puede romper el flujo actual de skills si no se respeta el registro en `skill_mastery`.

### ADRs pendientes
- **ADR-014** — Context budgets por fuente (fórmula de pesos, dónde vive la config).
- **ADR-015** — Context utility score (qué dimensiones, cómo se calcula, dónde se guarda el score por recuerdo).
- **ADR-016** — Progressive disclosure de skills (metadata schema, activación).

### MÉTRICAS A INSTRUMENTAR
- `tokens_injected_per_turn` por fuente (para presupuesto real)
- `context_relevance` (post-hoc: cuántos recuerdos inyectados fueron usados — proxy: tool calls a memoria en el turno)
- `usefulness_rate` por fuente (memoria vs files vs skills vs evidence)
- `prompt_size_vs_success` (correlación)

### VEREDICTO: **ENTRA** (↓tokens, ↓cost, ↑success)
El harness hoy inyecta contexto con caps fijos y sin scoring — el Context Compiler es exactamente la pieza que convierte "más contexto" en "mejor contexto". Se apoya 100% en capacidades V4-V7 ya existentes (salience, cues, reactivación). Riesgo bajo si se extiende `osma_context()` en lugar de duplicarlo.

---

## P3 — LOOP CONTRACT ENGINE

### YA EXISTE
- Loop engine: `core/loop-engine.agent.md` (state machine IDLE→QUESTING→EVALUATING→AUTO_NEXT/PAUSE_USER/CIRCUIT_BREAKER) + `cli/loop-engine.ps1` (implementación con `quest-done`, `attempt_count`, `audit_artifacts`, `artifact-integrity.ps1`).
- Anti-loop rules: max retries 3, max quests en cadena 5, max tokens 100K, max turns 10, stall detection.
- `.arnes/loop-state.json`: state, current_quest_id, chain, attempt_count, audit_artifacts (evidence/verdict/remediation/sam_counsel/atlas_decision).
- Remediation flow: `core/auditors/tywin.agent.md` — FAIL produce `remediation_brief`; `README.md` documenta "FAIL/RETOQUE → la remediation de Tywin se convierte en el siguiente prompt".
- Circuit breaker: `cli/circuit-breaker.ps1`, `.arnes/circuit-breaker.json`, config en `config.json` `combat.circuit_breaker`.

### FALTA (gap concreto)
1. **Contrato formal por quest**: `goal, acceptance, verification, max_iterations, token_budget, cost_budget, progress_signal, retry_policy, escalation_policy, stop_conditions, abort_conditions` no se declara como estructura por quest (hoy hay defaults globales).
2. **FAIL → clasificar causa → remediation → cambiar variable relevante → nuevo intento**: hoy el retry es "misma party, mismo modelo, otro intento" (attempt_count) salvo que Tywin emita brief manual. No hay registro estructurado de `failure_signature`, `root_cause`, `strategy_delta`.
3. **Persistencia en OSMA del ciclo de loop**: no hay tabla de loop contracts ni de attempts con causa.

### RIESGO
- **Crear un loop engine paralelo**: el prompt dice explícitamente "evolucionar loop-engine existente (no crear paralelo)". Todo debe vivir en `loop-engine.ps1` + `loop-state.json` + OSMA.
- Romper `artifact-integrity.ps1` (gate que verifica que evidence/verdict/remediation existan antes de pasar de quest) — es la base del contrato ya.

### ADRs pendientes
- **ADR-017** — Contratos de loops (schema del contrato por quest, dónde se persiste, quién lo firma).
- **ADR-018** — Clasificación de causa de fallo y estrategia de retry (taxonomía de causas, cuándo cambiar variable).

### MÉTRICAS A INSTRUMENTAR
- `retries_per_quest` por causa (ya hay attempt_count)
- `same_cause_retry_rate` (cuántas veces el retry repite la misma causa → loop inútil)
- `remediation_apply_rate` (cuántos remediation_brief se aplican)
- `loop_contract_violations` (quests que exceden max_iterations/token_budget)

### VEREDICTO: **ENTRA** (↓retries, ↓cost, ↑recuperación, ↑observabilidad)
Es la corrección del anti-patrón `while fail: try again`. La infraestructura (loop-state, audit_artifacts, remediation) ya existe — el gap es estructurar el contrato y el registro de causa.

---

## P4 — REGRESSION FACTORY

### YA EXISTE
- **NO EXISTE como capacidad**. Lo más cercano: `arnes-contract-audit` (ADR-006, gate determinístico C1-C34) — pero es auditoría estática por proyecto, no fábrica de regresiones desde FAIL→remediation→PASS.
- Test suite del harness (`tests/unit/osma-*.test.ts`, `tests/*.ps1`) valida el motor, no las regresiones de quests.
- OSMA V5 `osma-pattern-detect` clusteriza experiencias exitosas en patrones — relacionado pero no regression guard.

### FALTA (gap concreto)
1. **Pipeline FAIL → remediation → PASS → analizar si el fallo puede volverse guard** (unit/integration/browser/schema assertion/security rule/lint/static check/contract test/golden principle).
2. **Relación persistente** `memory_id → regression_id → quest_id → failure_signature`: no existe tabla ni enlaces.
3. **Trigger de creación**: quién y cuándo decide crear el guard (sugerencia: Tywin post-PASS con el remediation_brief cerrado + Kuja implementa).

### RIESGO
- Duplicar `arnes-contract-audit` (ya hace validaciones determinísticas) o duplicar `osma-pattern-detect` (ya abstrae patrones de éxito). La Regression Factory debe **consumir** ambos, no recrearlos.
- Complejidad alta: distinguir qué fallos son "regresionables" (deterministas, reproducibles) de cuáles no.

### ADRs pendientes
- **ADR-019** — Regression Factory (relación memory→regression→quest, tipos de guard, quién la ejecuta).

### MÉTRICAS A INSTRUMENTAR
- `regression_guard_created_rate` (cuántos FAIL→PASS producen guard)
- `regression_catch_rate` (cuántos guards capturan fallos nuevos antes de verificación)
- `regression_false_positive_rate`

### VEREDICTO: **ENTRA** (↑success, ↓retries, ↑seguridad)
Es la prioridad con mayor impacto en "no volver a pisar la misma piedra". El harness ya tiene la materia prima (remediation_brief + contract-audit + pattern-detect); falta la conexión. Fase tardía (después de P3 y P5 porque depende de la clasificación de causa y de la ladder de verificación).

---

## P5 — TYWIN VERIFICATION LADDER

### YA EXISTE
- Tywin: `core/auditors/tywin.agent.md` — verdict PASS/FAIL_PARTIAL/FAIL_TOTAL, checks por tipo de quest (frontend/backend/fix/architecture/L0), **remediation_brief obligatorio en FAIL**, contrato JSON de verdict.
- `arnes-contract-audit` (ADR-006): gate determinístico DB↔API↔Frontend — el germen de "si existe forma determinista de demostrarlo, no usar LLM".
- Evidencia: `core/protocols/atlas-advisory-handoff.md` — evidence_pack de Varys → verdict de Tywin → consejo de Sam → decisión de Atlas.
- `cli/artifact-integrity.ps1`: valida que los artefactos existan (verdict.json, evidence.json) antes de proseguir.

### FALTA (gap concreto)
1. **Ladder explícita de 6 niveles**: L1 STATIC (lint/typecheck/schemas/format), L2 MECHANICAL (unit/build/integration), L3 BEHAVIORAL (browser/API/database/flows), L4 QUEST (acceptance criteria), L5 ADVERSARIAL (Kuja + Auron), L6 REGRESSION (suite histórica). Hoy Tywin evalúa checks por categoría sin niveles ni verificación_level.
2. **Preferencia formal determinista sobre opinión**: no hay regla escrita "si existe test ejecutable, el LLM no puede marcar PASS por inspección". `arnes-contract-audit` lo hace para DB, pero no para el resto.
3. **`verification_level` en el verdict**: el contrato JSON de verdict no incluye `verification_level` ni `evidence_command` (comando que se ejecutó, exit code, assertions).

### RIESGO
- **Reemplazar Tywin en vez de evolucionarlo**: el prompt dice "evolucionar, no reemplazar". La ladder debe ser el **marco de trabajo** de Tywin, no un auditor nuevo.
- Romper el contrato de verdict (tests `orchestration-contract.tests.ps1`, `tests/unit/capsule.test.ts` etc.) si se cambia el JSON — migración compatible.

### ADRs pendientes
- **ADR-020** — Verification Ladder (6 niveles, qué es determinista, verification_level en el verdict).
- (Relacionado pero separado: ADR-018 para clasificación de causa de fallo — la ladder alimenta la causa.)

### MÉTRICAS A INSTRUMENTAR
- `verification_level_distribution` (qué % de verdicts son L1 vs L5)
- `llm_opinion_pass_rate` (verdicts PASS sin evidencia ejecutada — debe tender a 0)
- `deterministic_catch_rate` (fallos que el gate determinista atrapó y el LLM no)

### VEREDICTO: **ENTRA** (↑success, ↑seguridad, ↑observabilidad, ↓retries)
Alineado con la filosofía ADR-006 ("gate determinístico antes que otro LLM") y con la regla del prompt "no LLM que marque PASS sin pruebas". Costo bajo: es sobre todo una estructura formal sobre lo que Tywin + contract-audit ya hacen.

---

## P6 — QUEST GRAPH

### YA EXISTE
- `autonomous_quests` + `autonomous_tasks` en `cli/arnes_brain.py:274-305`: task graph con `dependencies` (JSON), `status` (pending/ready/running/pass/fail/blocked), `attempts`, `model`, `escalated_model`, `tokens_used`. Es un **DAG de tareas** funcional.
- `cli/argos-goal.ps1` (modo autónomo por objetivo) + `.arnes/goal-state.json` (historial, resume con `-Resume`).
- Grafo general de relaciones (`edges`, `arnes-graph.ps1`) — no es quest graph pero es el grafo del harness.

### FALTA (gap concreto)
1. **Graph solo cuando Bran lo justifique**: hoy no hay gate que decida cuándo usar graph vs quest simple.
2. **Invalidación downstream**: si un nodo cambia una interfaz pública, no hay análisis automático de nodos dependientes a invalidar (los `autonomous_tasks` tienen dependencies pero no propagación de invalidación).
3. **Operaciones de persistencia**: resume, retry node, fork, pause por nodo (existe pause global, no por nodo).
4. **Estados formales BLOCKED/READY/RUNNING/VERIFYING/PASS/FAIL/PAUSED con evidence por nodo**: `autonomous_tasks` tiene casi todos, falta `VERIFYING` y `evidence` por nodo ya existe como columna.

### RIESGO
- **Convertir todo en graph** (anti-patrón del prompt): el gate de Bran es obligatorio. El quest graph debe ser **la misma tabla** `autonomous_tasks` evolucionada, no un sistema paralelo.
- Confundir quest graph con `edges` (grafo de relaciones del harness) — son cosas distintas; no mezclar.

### ADRs pendientes
- **ADR-021** — Quest graph (cuándo Bran lo justifica, estados formales, operaciones de persistencia).
- **ADR-022** — Invalidación de nodos downstream (cuándo un cambio de interfaz pública invalida dependientes).

### MÉTRICAS A INSTRUMENTAR
- `graph_quests_ratio` (quests con graph vs total — para validar el gate)
- `downstream_invalidation_hits` (cuántas invalidaciones evitaron bugs)
- `graph_overhead_tokens` (costo del graph vs beneficio)

### VEREDICTO: **ENTRA con restricción** (↑success, ↑recuperación en quests grandes)
Pero **solo si se implementa como evolución de `autonomous_tasks` + gate de Bran**, no como motor nuevo. El prompt lo prohíbe explícitamente como "convertir todo en graph".

---

## P7 — TOOL DISCOVERY

### YA EXISTE
- **NO EXISTE `argos_tool_search`**. Las 13 tools de `argos-memory.ts` + `argos_working_memory` se registran siempre en PI.
- `discoverSkills()` (argos-skills.ts) lista skills — análogo pero no para tools.
- El motor `argos-engine.ps1` ya soporta `-Tools` (definiciones OpenAI function-calling) — la base para cargar tools bajo demanda.

### FALTA (gap concreto)
1. **`argos_tool_search(query)`** que devuelva tools relevantes por query (ej. "supabase migration" → db.inspect_schema/diff/migrate/rollback).
2. **Filosofía discover→select→load→execute**: hoy todo está cargado siempre; falta la selección dinámica.
3. Carga de schemas completos solo después de seleccionar (hoy PI inyecta todas las tools).

### RIESGO
- Bajo si se implementa como tool nueva + metadata de tools existentes; alto si se rompe el registro actual (los agentes esperan `argos_memory_search` etc. disponibles).
- Puede no justificar métrica si el número de tools es pequeño (14 tools hoy no saturan contexto). **El beneficio real aparece al crecer el arsenal** (contract-audit, supabase, playwright, etc.).

### ADRs pendientes
- **ADR-023** — Tool discovery (metadata de tools, contrato de `argos_tool_search`, cuándo cargar schema completo). ADR menor — puede fusionarse con otro si se implementa junto a P2/context.

### MÉTRICAS A INSTRUMENTAR
- `tools_in_context_count` (hoy fijo; objetivo: variable)
- `tool_schema_tokens` (tokens de schemas de tools inyectados por turno)
- `tool_search_precision` (de los tools cargados por búsqueda, cuántos se usaron)

### VEREDICTO: **ENTRA condicionado** (↓tokens, ↓context, ↓cost)
Se aprueba **como mejora del arsenal futuro**, no como prioridad urgente: con 14 tools el ahorro de tokens es marginal hoy. Si se implementa, debe hacerse con metadata y sin romper el registro actual.

---

## P8 — CODE MODE

### YA EXISTE
- **Base parcial**: `cli/argos-engine.ps1` (ejecuta completions directos), `cli/arnes_brain.py` (Python para memoria), Node/TS runtime en PI, PowerShell para CLI. El harness ya "ejecuta código local" (Python brain, scripts PS).
- `argos-permissions.ts` ya bloquea comandos destructivos (L0 Gate parcial).

### FALTA (gap concreto)
1. **Política formal DIRECT_TOOL/CODE_MODE/AGENT/SUBAGENT**: no existe un router que decida cuándo un multi-step de tools se resuelve mejor por un script local.
2. **Sandbox/runtime**: no hay un runtime aislado para scripts generados por LLM (ejecuta en el shell del proyecto — riesgo).
3. **Resultado compacto fuera de contexto**: no hay canal para procesar resultados grandes (logs, greps masivos) fuera del prompt.

### RIESGO
- **Seguridad**: ejecutar scripts LLM-generados sin sandbox es peligroso. Auron L0 Gate debe extenderse a code mode (el prompt lo exige: "nunca ejecutar destructivos sin gate").
- Complejidad: es la prioridad con mayor superficie nueva (runtime, sandbox, router de modo).

### ADRs pendientes
- **ADR-024** — Code Mode (política DIRECT_TOOL/CODE_MODE/AGENT/SUBAGENT, sandbox, cuándo activar).

### MÉTRICAS A INSTRUMENTAR
- `tokens_saved_by_code_mode` (turnos multi-tool que pasan a script)
- `code_mode_error_rate` (scripts fallidos)
- `security_incidents_code_mode`

### VEREDICTO: **ENTRA en fase tardía, reducido** (↓tokens, ↓latency)
Es legítima pero **la más costosa y arriesgada de las 10** (sandbox + seguridad). No debe entrar en Fase 1. Propuesta: implementar primero el router de modo con DIRECT_TOOL vs CODE_MODE simple (script TS/Python sin sandbox, con Auron Gate reforzado), y diferir sandbox real.

---

## P9 — GOLDEN PRINCIPLES

### YA EXISTE
- `CONVENTIONS.md` en raíz (reglas universales del harness).
- Skills de agente con "Reglas" por dominio (`core/skills/v2/*/SKILL.md`).
- ADRs (decisiones que codifican principios: ADR-001 independencia, ADR-006 determinismo, ADR-005 encoding).

### FALTA (gap concreto)
1. **`.arnes/principles/`** (general/architecture/frontend/backend/security/testing.md) — no existe el directorio.
2. **Selección por Context Compiler**: los principios deben inyectarse solo los relevantes (no prompts gigantes).
3. **Drift detection de Bard**: Bard (Continuous Improvement) no tiene hoy una fuente estructurada de principios contra la que auditar.

### RIESGO
- Muy bajo: es contenido + convención, no motor. Riesgo único: duplicar `CONVENTIONS.md` — hay que decidir si `CONVENTIONS.md` se convierte en la fuente y `.arnes/principles/` la desglosa, o viceversa.

### ADRs pendientes
- Ninguno mayor. Si acaso una nota dentro de ADR-014 (context) o ADR-016 (skills) — los principios son contenido, no arquitectura.

### MÉTRICAS A INSTRUMENTAR
- `principle_violation_rate` (drift detectado por Bard por categoría)
- `principle_context_tokens` (tokens de principios inyectados — objetivo bajo)

### VEREDICTO: **ENTRA, costo bajo** (↑success, ↑seguridad, ↑observabilidad)
Es barata y da estructura a lo que hoy está disperso. Se implementa junto con Context Compiler (los principios son una fuente más del contexto).

---

## P10 — EVENT LOG VS CONTEXT

### YA EXISTE
- `loop-state.json` `audit_artifacts`: rutas a evidence_pack/verdict/remediation/sam_counsel/atlas_decision por quest.
- `quest-ledger.json`: quests con agent/verdict/tokens/timestamp.
- `varys.agent.md`: evidence_pack estructurado (quest_id, acceptance criteria, agents_and_outputs, changed_files, diff_ref, unavailable_evidence) + write-back a blackboard/memoria.
- `.arnes/shared-blackboard.json`: patterns, failed_attempts, party_config_history, trust_scores.
- `.arnes/runs/Q-XXX/` (referenciado en loop-state): artefactos por quest.

### FALTA (gap concreto)
1. **Event log append-only formal**: no existe un `event-log.jsonl` (append-only de todo lo ocurrido). Hoy la trazabilidad está fragmentada en ledger + loop-state + blackboard + runs/.
2. **Reconstrucción completa**: no se puede reconstruir quest/route/party/model assignment/memory injection/tool calls/outputs/verdict/loops/cost desde una sola fuente.
3. **Separación conceptual EVENT LOG (todo) vs OSMA (conocimiento aprendido) vs CONTEXT (subconjunto)**: no está formalizada; el harness tiende a usar historial de chat como memoria.

### RIESGO
- **Crear memoria paralela** (anti-patrón): el event log NO es memoria — es un registro append-only plano (JSONL). OSMA sigue siendo el cerebro. Si se diseña como "otra base de memoria", duplica OSMA.
- Confundir event log con `sessions` (tabla OSMA) — sesiones es metadata, event log es el flujo completo.
- Costo de escritura: cada tool call/output puede ser pesado. Hay que definir granularidad (eventos de alto nivel por turno, no cada tool output).

### ADRs pendientes
- **ADR-025** — Event log (formato, granularidad, quién escribe — Varys dueño, dónde vive, retención).

### MÉTRICAS A INSTRUMENTAR
- `event_log_reconstruction_success` (¿se puede reconstruir un quest del pasado completo?)
- `event_log_overhead` (tokens/bytes por quest del log)
- `context_rebuild_time` (tiempo para reconstruir contexto desde event log)

### VEREDICTO: **ENTRA** (↑observabilidad, ↑recuperación)
Es el habilitador de "reconstruir qué pasó" — necesario para self-optimization (Bran/Sam/Quina) y para el benchmark del harness. Se implementa como JSONL append-only simple, con Varys como dueño (ya es el dueño natural de la trazabilidad).

---

## Resumen de veredictos

| # | Prioridad | Veredicto | Fase sugerida |
|---|---|---|---|
| 1 | Model Capability Router 2.0 | ✅ ENTRA | Fase 1 (fundacional) |
| 2 | Context Compiler | ✅ ENTRA | Fase 2 |
| 3 | Loop Contract Engine | ✅ ENTRA | Fase 3 |
| 4 | Regression Factory | ✅ ENTRA (depende de P3+P5) | Fase 5 |
| 5 | Tywin Verification Ladder | ✅ ENTRA | Fase 3 |
| 6 | Quest Graph | ✅ ENTRA con restricción (evolucionar autonomous_tasks + gate Bran) | Fase 4 |
| 7 | Tool Discovery | ✅ ENTRA condicionado (arsenal futuro) | Fase 4 |
| 8 | Code Mode | ⚠️ ENTRA reducido en fase tardía (sandbox diferido) | Fase 6 |
| 9 | Golden Principles | ✅ ENTRA, costo bajo | Fase 2 (con context) |
| 10 | Event Log vs Context | ✅ ENTRA | Fase 1 (con telemetría) |

**Ninguna prioridad se marca "NO ENTRA" completa**: las 10 justifican al menos una métrica. Las restricciones están en P6 (no todo en graph), P7 (no urgente hoy), P8 (reducida, seguridad primero).

## ADRs pendientes consolidados (ADR-011+)

| ADR | Decisión que registrará | Fase que lo inicia |
|---|---|---|
| ADR-011 | Scoring dinámico de modelos | F1 |
| ADR-012 | Esquema telemetría de modelos (model_runs) | F1 |
| ADR-013 | Perfiles de capacidades AGENT≠MODEL | F1 |
| ADR-014 | Context budgets por fuente | F2 |
| ADR-015 | Context utility score | F2 |
| ADR-016 | Progressive disclosure de skills | F2 |
| ADR-017 | Contratos de loops | F3 |
| ADR-018 | Clasificación de causa de fallo y retry | F3 |
| ADR-019 | Regression Factory | F5 |
| ADR-020 | Verification Ladder | F3 |
| ADR-021 | Quest graph + gate de Bran | F4 |
| ADR-022 | Invalidación de nodos downstream | F4 |
| ADR-023 | Tool discovery | F4 |
| ADR-024 | Code Mode | F6 |
| ADR-025 | Event log | F1 |

## Regla OSMA (no V8 por moda)

Antes de proponer OSMA V8 en cualquier fase, instrumentar y medir: `memory_precision`, `memory_usefulness`, `memory_hit_rate`, `memory_false_activation`, `contradiction_rate`, `tokens_per_useful_memory`, `reward_after_retrieval`. **Solo si los datos muestran una propiedad cognitiva faltante se propone V8** — y siempre como capa aditiva sobre V7 (patrón V4→V7 ya establecido en ADR-007/008/009/010). Esta Fase 0 no ve evidencia suficiente para justificar V8 hoy.

# CURRENT_ARCHITECTURE.md — ARNES ARGOS: Estado Actual del Harness

> **Autor**: Amarant (Monk, Architecture) · **Fecha**: 2026-08-13 · **Fase**: 0 (análisis, sin tocar código)
> **Objetivo**: describir la arquitectura real de ARNES ARGOS tal como existe hoy, con rutas exactas, ADRs que la documentan, capacidades y límites. Todo lo aquí afirmado fue verificado contra el repo.

---

## 0. Resumen ejecutivo

ARNES ARGOS es un harness RPG de 16 agentes con memoria propia (SQLite+FTS5), metodologías propias (SDD/FDD/ADR), configuración global por máquina y tres capas de integración runtime (PI hooks, CLI PowerShell, motor Python). El principio rector declarado en ADR-001: **"como mejor tengamos nuestro arnes, el modelo es indistinto"** — la semilla del objetivo model-agnostic que esta Fase 0 analiza.

Las 4 capas del prompt se confirman y localizan:

| Capa | Ubicación real | Rol |
|---|---|---|
| **PI** (sistema nervioso) | `pi/extensions/argos-*.ts` (14 archivos) | Hooks runtime `before_agent_start`, `agent_settled`, `session_compact`, `tool_call` + 14 tools `argos_*` |
| **OSMA** (cerebro) | `cli/arnes_brain.py` (3,673 líneas) + `.arnes/arnes.db` | Memoria asociativa SQLite+FTS5, V1→V7 |
| **Metodologías** | `core/skills/` (SDD, FDD, ADR, contract-audit) + `core/skills/v2/` (16 skills propias) + superpowers externos | Procesos de ingeniería |
| **Party** | `core/classes/*.agent.md` (10) + `core/auditors/*.agent.md` (8) + `core/atlas-player.agent.md` | 16 agentes RPG |

**Hallazgo clave de esta Fase 0**: el harness ya tiene implementada una parte significativa de las 10 prioridades del prompt, pero **sin telemetría de desempeño por modelo** (el gap estructural para ser model-agnostic). El detalle está en `GAP_ANALYSIS.md`.

---

## 1. Capa PI — Sistema nervioso (hooks runtime)

**Ubicación**: `pi/extensions/` · **Documentado por**: ADR-007 §3 (integración ARGOS), ADR-008 §8, ADR-009 §9, ADR-010 §5.

### 1.1 Hooks registrados

| Hook | Archivo | Qué hace |
|---|---|---|
| `session_start` | `argos-core.ts`, `argos-skills.ts`, `argos-ui.ts` | Boot: status UI, registro de skills (`skill register`), widget header |
| `before_agent_start` | `argos-cognition.ts`, `argos-orchestrator.ts` | **Inyección de contexto**: Cognitive Router + working memory + `osma-context` (paquete asociativo, 600 tokens) + `osma-experience-search` (experiencias previas, top 3 apply/caution). Clasificación de quest + party recomendado |
| `agent_settled` | `argos-learning.ts` | **Aprendizaje**: `save` observación → `osma-link` (co-activación con recuerdos recuperados) → `osma-reinforce` (éxito/fallo) → `osma-experience-record` (experiencia con reward +0.5/−1.0, V5/V6) → `skill exec` |
| `session_before_compact` | `argos-compaction.ts` | Checkpoint de working memory (`checkpoint create`) |
| `session_compact` | `argos-compaction.ts` | `osma-sleep 24` (el sueño: decay, consolidación, contradicciones) + rehidratar working memory desde checkpoint |
| `tool_call` | `argos-permissions.ts` | L0 Gate parcial: bloquea `write`/`edit` en rutas protegidas (`arnes.db`, `.env`, `connections.json`, `.git`, `config.json`) y comandos destructivos (`rm -rf`, `format`) |

### 1.2 Tools registradas (14)

| Tool | Archivo | Comando OSMA detrás |
|---|---|---|
| `argos_memory_search` | `argos-memory.ts` | `osma-recall` (RAG asociativo con propagación de activación) |
| `argos_memory_get` | `argos-memory.ts` | `get` |
| `argos_memory_save` | `argos-memory.ts` | `save` |
| `argos_memory_update` | `argos-memory.ts` | `update` |
| `argos_memory_verify` | `argos-memory.ts` | `verify` |
| `argos_memory_stats` | `argos-memory.ts` | `stats` |
| `argos_memory_context` | `argos-memory.ts` | `context` |
| `argos_memory_context_assoc` | `argos-memory.ts` | `osma-context` (paquete asociativo completo) |
| `argos_memory_timeline` | `argos-memory.ts` | `revisions` |
| `argos_memory_relations` | `argos-memory.ts` | `edges` |
| `argos_experience_search` | `argos-memory.ts` | `osma-experience-search` (experiencias validadas V5) |
| `argos_cue_search` | `argos-memory.ts` | `osma-cue-search` (recuperación multidimensional V6 + reactivación V7) |
| `argos_episode` | `argos-memory.ts` | `osma-episode` (reconstrucción episodio completo V7) |
| `argos_working_memory` | `argos-working-memory.ts` | — (lee estado local) |

**Puente a OSMA**: `argos-brain.ts` `runBrain()` hace `spawn("python", [brain, db, ...args])` con stdin JSON. `resolveBrainPath()` resuelve `cli/arnes_brain.py`.

### 1.3 Working Memory (estado local del turno)

`argos-working-memory.ts` mantiene: `quest`, `questType`, `agent`, `goal`, `nextAction`, `files`, `errors`, `facts` (máx 10), `activeSkill`, `procedureStage`, `recalledMemoryIds` (máx 20 — para co-activación). Se inyecta al prompt como bloque `## ARGOS WORKING MEMORY (actual)`.

### 1.4 Límites de PI hoy

- **Todo el contexto se inyecta como texto plano concatenado** en `before_agent_start` — no hay presupuesto fino por fuente, ni scoring de utilidad (prioridad 2 del prompt).
- **Todas las tools se registran siempre** — no hay tool discovery selectivo (prioridad 7).
- La inyección de memoria usa `slice(0, 200)`/`slice(0, 160)` por fila y caps fijos (5 decisiones, 5 errores, 5 agentes, 3 contradicciones, 3 experiencias) — heurística fija, no `context utility score`.
- El Cognitive Router vive solo como **prompt** (texto en `getCognitionBlock`), no como decisión programática: el agente "elige" FAST/RECALL/SKILL/DELIBERATE/DEEP leyendo instrucciones.
- `argos-orchestrator.ts` clasifica quest y recomienda party, pero el resultado **no se persiste** en OSMA (`void party`).

---

## 2. Capa OSMA — Cerebro asociativo (memoria)

**Ubicación**: `cli/arnes_brain.py` (motor, 3,673 líneas) · `.arnes/arnes.db` (SQLite+FTS5) · `cli/arnes-memory.ps1` (CLI) · `cli/arnes-graph.ps1` (grafo) · `.arnes/memory/export/*.jsonl` (snapshots git).

### 2.1 Versiones y ADRs

| Versión | ADR | Qué aporta |
|---|---|---|
| V1 | **ADR-001** (`memoria-sqlite`) | Memoria propia SQLite+FTS5, cero dependencias externas, export JSONL. El principio: "nadie más controla nuestro cerebro" |
| V2/V3 | (en ADR-001/002) | Columnas cognitivas: `confidence`, `storage_strength`, `retrieval_strength`, `volatility`, `state`, `memory_kind`, `evidence`; `skill_mastery`, `skill_executions`, `memory_reviews`, `cognitive_checkpoints`, `autonomous_quests/tasks` |
| V4 | **ADR-007** (`osma-asociativa-v4`) | Memoria **asociativa**: `observation_links` (sinapsis), `contradictions`, `consolidations`; propagación de activación BFS, refuerzo por utilidad (`osma-reinforce`), el sueño (`osma-sleep`), `osma-context` con presupuesto de tokens |
| V5 | **ADR-008** (`osma-experiencias-validadas-v5`) | **Experiencias validadas**: tablas `experiences` (situation→reasoning→conclusion→action→outcome + `reward_signal` −1..1), `patterns` (con provenance `source_experience_ids`), `experience_links`, `experience_observation_links`; taxonomía 6 estados; `osma-pattern-detect` |
| V6 | **ADR-009** (`osma-memoria-multidimensional-v6`) | **Cues multidimensionales**: `experience_cues` con 17 tipos de componente, `cue_quality` (IDF), convergencia no lineal (`episode_activation_score`), salience funcional, dimensiones independientes, retrieval anchors |
| V7 | **ADR-010** (`osma-episode-pattern-completion-v7`) | **Pattern completion + reactivación**: `episode_id` (`EPISODE_XXXX`), `osma-episode` (reconstrucción completa), `_reactivate()` (recordar modifica la memoria), competencia con señales completas (`_competition_score`), fallback FTS5 |

### 2.2 Schema real (verificado en `cli/arnes_brain.py` líneas 93-569)

Tablas base (V1-V3): `agents`, `observations` (+FTS5 `observations_fts` con triggers), `quests`, `sessions`, `edges`, `skill_mastery`, `skill_executions`, `skill_memory_links`, `memory_reviews`, `meta` (`schema_version` = `'7'`), `cognitive_checkpoints`, `autonomous_quests`, `autonomous_tasks`.

Tablas asociativas (V4-V7): `observation_links`, `contradictions`, `consolidations`, `experiences`, `patterns`, `experience_links`, `experience_observation_links`, `experience_cues`.

**El prompt pedía verificar que `observations_fts`, `experience_cues`, `experiences`, `experience_links`, `observation_links`, `contradictions`, `consolidations`, `patterns`, `experience_observation_links`, `meta` existen — confirmado, todas existen** (líneas 94-569).

### 2.3 Comandos OSMA (dispatch `main()`, ~50 comandos)

- **Memoria base**: `init`, `save` (con `_link_on_write`), `recall`, `reinforce`, `verify`, `reconsolidate`, `reviews`, `get`, `update`, `revisions`, `compact`, `search`, `context`, `agent`, `export`, `import`, `stats`
- **Grafo**: `edge`, `edges`, `neighbors`, `path`, `graph-stats`
- **Checkpoints/continuidad**: `checkpoint create/get/list`, `capsule`, `consolidate-recent`, `continuity`
- **Autónomos**: `aquest`, `atask`
- **V4 asociativo**: `osma-migrate`, `osma-link`, `osma-recall`, `osma-reinforce`, `osma-context`, `osma-contradictions`, `osma-contradiction-resolve`, `osma-sleep`, `osma-consolidations`, `osma-consolidation-finalize`, `osma-stats`
- **V5 experiencias**: `osma-experience-record`, `osma-experience-validate`, `osma-experience-search`, `osma-pattern-detect`, `osma-patterns`, `osma-experience-reuse`, `osma-experience-stats`, `osma-experience-analyze`
- **V6/V7 multidimensional**: `osma-cues`, `osma-cue-search`, `osma-anchor-add`, `osma-routes`, `osma-episode`
- **Skills**: `skill register/exec/link/status/executions` (tabla `skill_executions` **ya registra model/provider/tokens_in/tokens_out/tool_calls** — base para telemetría)
- **Routing**: `route` (clasificación por query+risk)

### 2.4 Capacidades cognitivas ya presentes (V4-V7)

`osma-recall` (recall BM25 + propagación BFS `act_child = act_parent × 0.8 × weight`, umbral 0.25), `osma-context` (paquete con presupuesto de tokens, trim ordenado), `osma-sleep` (decay persistido desde `decay_base`, transiciones ACTIVE→WARM→COLD→ARCHIVED, dedup, detección de contradicciones, debilitamiento de links ×0.995), `osma-link` (4 señales: coactivation/success/correction/same_quest), `osma-reinforce` (éxito→score+, fallo→confidence−/contested), `osma-experience-record` (descompone en 17 cues + salience), `osma-cue-search` (convergencia no lineal `Σqᵢ + 0.1·k²·avg(q)`, competencia `_competition_score` con 4 pesos), `_reactivate` (frequency+1, retrieval_strength+0.03, cues coactivation+1, links weight+0.05), `osma-episode` (reconstrucción completa).

### 2.5 Límites de OSMA hoy

- **Cero telemetría de desempeño de modelos**: no existe tabla `model_runs`; la única fuente es `skill_executions` (parcial, no scoring). El router no aprende de resultados.
- `osma-context` recibe un solo `max_tokens` global (6000 default) — no presupuesto por fuente.
- Sin `contradiction_rate`/`memory_precision`/`memory_hit_rate` como métricas instrumentadas (solo `osma-stats` cuenta elementos).
- Los 17 tipos de cues y los pesos de competencia (`_W_RECENCY=0.05`, etc.) son **constantes hardcodeadas en el módulo** — no configurables por proyecto.

---

## 3. Capa Metodologías — Skills

**Ubicación**: `core/skills/` · **Documentado por**: ADR-002 (proceso propio), ADR-003 (skills propias).

### 3.1 Skills propias del harness (`core/skills/`)

| Skill | Fase | Rol principal |
|---|---|---|
| `arnes-sdd-propose/spec/design/tasks/apply/verify/archive` | SDD completo (7 fases) | Amarant (design), Tywin (verify), implementación delegada |
| `arnes-fdd-plan/implement/review/archive` | FDD (4 fases) | Features incrementales |
| `arnes-adr` | ADR | Decisiones de arquitectura |
| `arnes-memory` | Memoria | Lectura/escritura JSONL + arnes.db |
| `arnes-graph` | Grafo | Relaciones entre componentes |
| `arnes-contract-audit` | Gate determinístico (ADR-006) | 34 validaciones en 6 capas (C1-C34), DB↔API↔Frontend |
| `arnes-agent-memory` | Memoria por agente | Instrucciones de namespace |
| `arnes-context-digest` | Consolidación | El "sueño" del agente |

### 3.2 Skills v2 propias por agente (`core/skills/v2/`)

16 skills: `amarant-foresight`, `ansem-smite`, `atlas-orchestrate`, `auron-bulwark`, `bran-vision`, `eiko-mend`, `eremez-mark`, `kuja-backstab`, `quina-ledger`, `ragnarok-scout`, `sam-counsel`, `tidus-tide-check`, `tywin-judgment`, `varys-whisper`, `vivi-fireball`, + `template`. Estructura canónica: `--- name/description ---` + Purpose + Trigger + Inputs + Pasos + Output + Complementos web + Memoria + Reglas.

### 3.3 Superpowers externos

`discoverSkills()` en `argos-skills.ts` escanea: `~/.pi/agent/git/github.com/obra/superpowers/skills` (14 skills: brainstorming, test-driven-development, systematic-debugging, writing-plans, subagent-driven-development, verification-before-completion, using-git-worktrees, executing-plans, dispatching-parallel-agents, receiving/requesting-code-review, finishing-a-development-branch, using-superpowers, writing-skills), `core/skills`, `pi/skills`. Se registran en `skill_mastery` al `session_start`.

### 3.4 Límites de skills hoy

- **Sin progressive disclosure**: los SKILL.md se cargan completos al agente (el agente los "lee" vía skill tool), no metadata-primero/contenido-profundo-al-activar (prioridad 2).
- `skill_executions` existe y registra model/provider/tokens/verdict — pero **no alimenta ninguna decisión de routing** (dato muerto hoy).

---

## 4. Capa Party — 16 agentes RPG

**Ubicación**: `core/classes/*.agent.md` (10) + `core/auditors/*.agent.md` (8) + `core/atlas-player.agent.md` (1) + `core/repo-sizer.agent.md`, `core/quest-detector.agent.md`, `core/model-router.agent.md`, `core/loop-engine.agent.md` (subagentes de Atlas).

### 4.1 Clases (`core/classes/`)

| Archivo | Agente | Rol |
|---|---|---|
| `mage.agent.md` | Vivi | Frontend DPS |
| `paladin.agent.md` | Ansem | Backend Tank |
| `rogue.agent.md` | Kuja | QA/Security DPS |
| `cleric.agent.md` (en config: eiko) | Eiko | Healer/DevOps |
| `monk.agent.md` | Amarant | Architecture/Strategist |
| `ranger.agent.md` | Eremez | Research/Librarian |
| `bard.agent.md` | Bard | Continuous Improvement |
| `tidus.agent.md` | Tidus | Infrastructure Warden |
| `ragnarok.agent.md` | Ragnarok | Procurement Warden |
| (auron/bran/quina/varys/tywin/sam en auditors) | | |

### 4.2 Auditors (`core/auditors/`)

| Archivo | Agente | Rol | Estado actual relevante |
|---|---|---|---|
| `varys.agent.md` | Varys | Tracker/Shadow | Hand-off + **evidence_pack** estructurado + write-back a blackboard y memoria por-agente |
| `varys-documentalist.agent.md` | Varys Doc | Document Auditor | Drift docs↔código, secrets scan |
| `tywin.agent.md` | Tywin | Verifier | Verdict PASS/FAIL_PARTIAL/FAIL_TOTAL + **remediation_brief** (FAIL sin remediation = auditoría incompleta) + checks por tipo de quest |
| `bran.agent.md` | Bran | Seer/Strategist (#2) | Repo Sizer + Allocate + Streak reports |
| `sam.agent.md` | Sam | Elder Counselor (#1.5) | Pre-quest brief (3 líneas) + **sam-digest.json** + trust scores |
| `quina.agent.md` | Quina | Token Banker | Budget, thresholds 80/95/100% |
| `auron.agent.md` | Auron | Security Warden (L0 Gate) | OWASP + RLS + **Permiso de Trabajo en Altura** (L0 Gate) |

### 4.3 Subagentes de Atlas (`core/`)

- `atlas-player.agent.md` — orquestador principal (TURN 0-8)
- `quest-detector.agent.md` — clasificación por keywords + complexity (HP/MP estimados)
- `model-router.agent.md` — catálogo estático de modelos × plataforma × suscripción + fallback chain (prioridad 1 base)
- `loop-engine.agent.md` — state machine IDLE→QUESTING→EVALUATING→AUTO_NEXT/PAUSE/CIRCUIT_BREAKER + reglas anti-loop (prioridad 3 base)
- `repo-sizer.agent.md` — clasifica repo en lean/medium/standard/boss

### 4.4 Configuración de agentes/modelos

| Archivo | Contenido |
|---|---|
| `~/.config/arnes/agent-models.json` | Fuente única de verdad de modelos por agente (29 agentes = 16 ARNES + 13 OMO) — ADR-004 |
| `~/.config/arnes/connections.json` | Proveedores con API keys |
| `.arnes/config.json` | Plataforma/suscripción/preferencias/characters con `model_opencode/codex/claude` |
| `.arnes/model-recommendations.json` | Catálogo estático 2026.07 (platforms × plans × recommended_party × overrides × fallback_chain) |
| `.arnes/model-assignments.json` | Asignación concreta por quest (`quest_type`, `platform`, `assignments`, `tier`) |
| `.arnes/model-routing-policy.json` | **Política V2 (2026-08-08)**: `resolution_mode: catalog_backed_aliases`, provider tiers (nvidia free → opencode-go fallback, luna 60/40), `preference_order` por agente, `stuck_agent_rule` (5 min / 3 fails / switch), `on_error_429_401_410` |
| `.arnes/model-chain.json` | Cadena NVIDIA legacy (referencia histórica; policy dice "read_only") |
| `cli/argos-engine.ps1` | Motor nativo que habla directo con APIs (bai/nvidia/opencode-go/openai), retry 429, MaxTokens |
| `cli/model-router.ps1`, `model-catalog.ps1`, `model-health.ps1`, `model-route-status.ps1` | Implementaciones PowerShell del routing |

### 4.5 Protocolos (`core/protocols/`)

- `atlas-advisory-handoff.md` — contrato evidencia→verdict→consejo→decisión
- `sam-digest.schema.json`, `shared-blackboard.schema.json`, `atlas-context-handoff.schema.json`, `atlas-handoff-state.schema.json`
- `cli/loop-engine.ps1` — implementación con `audit_artifacts` (evidence_pack/verdict/remediation/sam_counsel/atlas_decision), `attempt_count`, `artifact-integrity.ps1`

### 4.6 Estado de datos (`/arnes/.arnes/`)

`shared-blackboard.json` (patterns, agent_learnings, failed_attempts, party_config_history, trust_scores, circuit_breaker_state), `quest-ledger.json` (quests con agent/verdict/tokens), `sam-digest.json` (recomendaciones cruzadas entre quests), `loop-state.json` (state=QUESTING, audit_artifacts con rutas), `repo-profile.json`, `circuit-breaker.json`, `preferences.json`, `model-assignments.json`.

---

## 5. Mapeo: qué de las 10 prioridades YA EXISTE parcialmente

| Prioridad del prompt | Estado en el repo | Evidencia |
|---|---|---|
| 1. Model Capability Router 2.0 | **PARCIAL (base estática, sin aprendizaje)** | `core/model-router.agent.md`, `.arnes/model-recommendations.json` (catálogo), `.arnes/model-routing-policy.json` (fallback declarativo), `pi/extensions/argos-model-router.ts` (loadAgentModels), `cli/argos-engine.ps1`. **Falta**: perfiles de capacidades por agente, scoring dinámico, telemetría, separación AGENT≠MODEL formal |
| 2. Context Compiler | **PARCIAL (osma-context con presupuesto simple)** | `osma_context()` en `arnes_brain.py:1683` (max_tokens + trim), inyección en `argos-cognition.ts:53-99`. **Falta**: presupuesto por fuente, context utility score, progressive disclosure |
| 3. Loop Contract Engine | **PARCIAL (loop engine + audit_artifacts)** | `core/loop-engine.agent.md`, `cli/loop-engine.ps1`, `.arnes/loop-state.json` (attempt_count, audit_artifacts), `core/tactics/turn-economy.md`. **Falta**: contrato formal por quest, FAIL→clasificar causa→remediation→cambiar variable→retry, registro en OSMA |
| 4. Regression Factory | **NO EXISTE** | Nada en el repo. `arnes-contract-audit` (ADR-006) es gate determinístico, no fábrica de regresiones |
| 5. Tywin Verification Ladder | **PARCIAL (Tywin + contract-audit)** | `core/auditors/tywin.agent.md` (verdict + remediation_brief), `core/skills/arnes-contract-audit/SKILL.md` (L1-L6, C1-C34). **Falta**: 6 niveles explícitos con verification_level en el verdict, preferencia determinista formal |
| 6. Quest Graph | **PARCIAL (autonomous_tasks como task graph)** | `autonomous_quests` + `autonomous_tasks` en `arnes_brain.py:274-305` (dependencies, status pending/ready/running/pass/fail/blocked, escalated_model). **Falta**: invalidación downstream, fork, persistencia de nodos por quest |
| 7. Tool Discovery | **NO EXISTE** | `argos-memory.ts` registra 13 tools siempre; no hay `argos_tool_search` |
| 8. Code Mode | **NO EXISTE (base en argos-engine.ps1)** | `cli/argos-engine.ps1` ejecuta completions directos pero no hay política DIRECT_TOOL/CODE_MODE/AGENT/SUBAGENT |
| 9. Golden Principles | **NO EXISTE (base en CONVENTIONS.md)** | No hay `.arnes/principles/`. `CONVENTIONS.md` existe como reglas universales |
| 10. Event Log vs Context | **PARCIAL (audit_artifacts + ledger)** | `loop-state.json` (audit_artifacts con rutas de evidencia), `quest-ledger.json`, `varys.agent.md` (evidence_pack). **Falta**: event log append-only formal |

---

## 6. Riesgos estructurales detectados (pre-análisis)

1. **Fragmentación del model router**: 5+ fuentes de verdad coexistieron (`model-recommendations.json`, `model-assignments.json`, `model-routing-policy.json`, `model-chain.json`, `config.json` characters). La policy V2 declara ser "fuente de verdad" y marca las otras "read_only" — **cualquier evolución del router 2.0 debe respetar esa jerarquía o se reintroduce la fragmentación que ADR-004 eliminó**.
2. **OSMA sin métricas de calidad**: no se puede justificar OSMA V8 sin `memory_precision`, `memory_hit_rate`, `contradiction_rate`, etc. El prompt exige medir antes de optimizar — hay que instrumentar en Fase 1 sin tocar el motor.
3. **`skill_executions` como dato muerto**: ya captura model/provider/tokens/verdict por ejecución de skill, pero nada lo lee para routing. Es la semilla natural de la telemetría de modelos sin crear duplicados.
4. **Cognitive Router como prompt, no como motor**: no hay decisión programática de ruta cognitiva — el harness depende de que el LLM "obedezca" instrucciones. Para ser model-agnostic esto debe volverse una decisión del harness, no del modelo.

---

## 7. Conclusión de la capa actual

ARNES ARGOS ya es un harness con memoria asociativa real (V7), metodologías propias completas, y un ciclo de quest orquestado con evidencia verificable. El salto a **model-agnostic** no requiere reescritura: requiere (a) telemetría de desempeño por modelo (model_runs), (b) convertir decisiones que hoy son "prompt al LLM" en decisiones del harness (routing, contexto, verificación), y (c) cerrar los gaps de las prioridades 4, 7, 8, 9. El detalle está en `GAP_ANALYSIS.md`.

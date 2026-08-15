# ARGOS AUTONOMOUS PARTY — Diseño de orquestación multiagente autónoma

> **Fecha**: 2026-08-07
> **Estado**: propuesto (pendiente revisión del usuario)
> **Autor**: Usuario + asistente
> **Requiere aprobación antes de implementar**
> **Base**: ARGOS SUPERPOWERS (fusión Pi + ARNES ARGOS + Superpowers) — spec `2026-08-06-argos-superpowers-fusion-design.md`, plan implementado (commits `b929fc6`..`26952d8`).

---

## 1. Contexto

La fusión ARGOS SUPERPOWERS está implementada (paquete pi `argos-superpowers`, 9 tools `argos_memory_*`, 17 role-skills, cognitive router, working memory, permisos, compaction, UI `/argos*`, launcher `argos pi`, fusion-check 7/7 PASS). Los 16 agentes existen como role-skills pero **se ejecutan con el modelo de sesión** (Opción A v1).

Esta spec evoluciona el harness para que los agentes **trabajen de forma autónoma en tareas largas**, cada uno ejecutándose **realmente con SU modelo configurado**, sin que el usuario elija agentes manualmente. El usuario expresa "WHAT I WANT"; Atlas (orquestador) transforma eso en WHO + WHAT TASK + WHICH MODEL + WHICH SKILL + HOW MUCH EFFORT + WHEN + HOW TO VERIFY.

### Auditorías de esta fase (evidencia)

- **`pi-subagents` instalado** en `~/.pi/agent/npm/` (v0.42.1, `pi install npm:pi-subagents`): añade la tool `subagent` a pi y expone APIs programáticas (`src/api/delegation.ts`, `background-work.ts`, `control-channel.ts`, `external-runs.ts`) + agentes predefinidos (reviewer, oracle, scout...). Es el mecanismo real de delegación.
- **Catálogo de modelos de pi contiene los IDs de `~/.config/arnes/agent-models.json`** (verificado con `pi --list-models`): `opencode-go/gpt-5.6-luna` ✓, `opencode-go/deepseek-v4-flash` ✓, `opencode-go/deepseek-v4-pro` ✓, `nvidia/z-ai/glm-5.2` ✓, `nvidia/minimaxai/minimax-m3` ✓, `openai-codex/gpt-5.6-luna` ✓. **El model router mapea directo; sin modelos faltantes.**
- La fuente de verdad de modelos sigue siendo `~/.config/arnes/agent-models.json` (NO hardcodear; leer siempre).
- La fundación reutilizable de la fusión: `argos-brain.ts` (runBrain), `argos-party.ts` (catálogo), `argos-model-router.ts`, `argos-orchestrator.ts` (classifyQuest/recommendParty), `argos-working-memory.ts`, `argos-permissions.ts`, `argos-compaction.ts`, `argos-ui.ts`, `argos-skills.ts`, `argos-learning.ts`.

## 2. Objetivo y no-objetivos

**Objetivo**: una quest larga (ej. "crea una plataforma web para una escuela") se ejecuta autónomamente: Atlas clasifica → Amarant/SDD si DEEP → task graph → party selection con señales estructuradas → delegación vía tool `subagent` con modelos reales por agente → resultados estructurados → verificación por niveles → escalación controlada → aprendizaje → continuidad tras compaction/restart. El usuario no elige agentes.

**No-objetivos (v1)**:
- No reemplazar SDD/FDD/ADR/TDD ARGOS (siguen siendo la metodología).
- No copiar/forkear pi-subagents (se consume como paquete instalado).
- No cambiar permanentemente la configuración de modelos de un agente (el escalation es por ejecución).
- No conversación libre entre agentes (comunicación por contratos/resultados/memoria/task graph).
- No otro orchestrator externo, otra memoria, otro framework de skills.
- No tocar OpenCode ni los comandos argos legacy.

## 3. Arquitectura

```
                        USER
                          │
                          ▼
                    ARGOS ATLAS         (sesión pi, modelo top-tier, uso reducido)
                          │
                 high-level thinking (clasifica, decide party, delega, verifica, autoriza)
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
          AMARANT       MEMORY      TASK GRAPH        (arnes.db: tasks/deps/runs)
          (SDD/ADR)     (V3)            │
                          │             ▼
                          ▼        ARGOS SCHEDULER    (argos-scheduler.ts)
                         SDD     party scoring + contracts + budgets + stop conditions
                                      │
                  pi-subagents tool `subagent` (Atlas delega — decisión aprobada A)
                    ┌───────────┬──────┴─────────┬───────────┐
                    ▼           ▼                ▼           ▼
                  VIVI        ANSEM            AURON       EIKO
               (modelo real)(modelo real)  (modelo real) (modelo real)
                    └───────────┴───────┬────────┴───────────┘
                                        ▼
                                     KUJA (L2)
                                        ▼
                                    TYWIN (L3)
                                        ▼
                                     BARD (aprendizaje)
                                        ▼
                                   MEMORY V3 (consolidación)
                                        ▼
                                     ATLAS → FINALIZAR / next phase
```

- Atlas = cerebro ejecutivo (modelo top-tier, pocas llamadas, decisiones importantes).
- Especialistas = agentes hijos de pi-subagents, cada uno con SU modelo (mapeo directo ARNES→pi).
- Task Graph = estado durable del trabajo en `arnes.db` (sobrevive compaction y restart).
- Comunicación = TASK_CONTRACT → TASK_RESULT estructurado; nunca transcripts.

## 4. Task Graph en arnes.db (aditivo)

Nuevas tablas (comandos aditivos en `arnes_brain.py`, sin tocar lo existente):

```sql
CREATE TABLE IF NOT EXISTS tasks (
    id          TEXT PRIMARY KEY,        -- T1, T2...
    quest_id    TEXT NOT NULL,
    description TEXT NOT NULL,
    domain      TEXT,                    -- architecture|frontend|backend|auth|db|security|testing|deployment...
    assigned_agent TEXT,
    status      TEXT DEFAULT 'ready',    -- ready|running|pass|fail|blocked|skipped
    dependencies TEXT DEFAULT '[]',      -- JSON: [task ids]
    input       TEXT DEFAULT '',
    output      TEXT DEFAULT '',
    acceptance  TEXT DEFAULT '[]',       -- JSON: criterios
    evidence    TEXT DEFAULT '',
    attempts    INTEGER DEFAULT 0,
    model       TEXT,
    provider    TEXT,
    created_at  TEXT DEFAULT (datetime('now')),
    updated_at  TEXT DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS task_dependencies (
    task_id TEXT NOT NULL, depends_on TEXT NOT NULL, PRIMARY KEY (task_id, depends_on)
);
CREATE TABLE IF NOT EXISTS task_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL, agent TEXT, model TEXT, provider TEXT,
    result TEXT,               -- PASS | FAIL | REVIEW
    summary TEXT, evidence TEXT, blockers TEXT,
    tokens_in INTEGER DEFAULT 0, tokens_out INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now'))
);
```

Comandos CLI nuevos en `arnes_brain.py` (backward compatible):
- `task add <json>` — crea/actualiza task (upsert por id).
- `task update <json>` — status/assign/model/attempts/evidence.
- `task graph <quest_id>` — tareas + dependencias + status (para el scheduler).
- `task ready <quest_id>` — tasks `ready` cuyas dependencias están `pass`.
- `task result <json>` — registra un task_run + actualiza task.
- `quest-tasks <quest_id>` — lista tasks de la quest.

El scheduler y la UI consumen esto vía `runBrain`.

## 5. Capability registry + party selection

- `agent_capabilities` derivado de los `.agent.md` + metadata estructurada (SIN duplicar fuentes): se construye en `argos-party.ts` extendiendo `AgentCard` con `{ capabilities[], triggers[], anti_triggers[], risk_level, cost_tier, preferred_skills, historical_success }`.
- `classifyQuest` (ya existe) → descomposición en dominios (`architecture, frontend, backend, authentication, database, security, testing, deployment`).
- Mapeo dominio→agente (tabla de scoring): cada dominio aporta candidatos con peso (trigger match, histórico de éxito, cost tier, riesgo). Atlas decide con el ranking; nunca se llama a los 16 por defecto.
- `recommendParty` (ya existe) se extiende al scoring.

## 6. TASK_CONTRACT y TASK_RESULT

**TASK_CONTRACT** (inyectado al subagente vía la tool `subagent`, contexto aislado):

```text
[ARGOS TASK CONTRACT]
Agent: argos-ansem
Quest: school-platform-001
Task: AUTH-03
Objective: Implement student login backend.
Acceptance: email/password · Supabase Auth · errors handled · no service-role client-side · tests passing
Relevant decisions: #184 #202
Files likely: src/lib/auth.ts, src/api/auth/*
Allowed scope: backend/auth
Do not modify: frontend
Skills recommended: TDD, systematic-debugging si tests fallan
Return: RESULT, FILES_CHANGED, TESTS, EVIDENCE, BLOCKERS, MEMORIES_TO_SAVE
```

**TASK_RESULT** (persistido en `task_runs` + memoria):

```text
TASK_RESULT: task_id, agent, status (PASS/FAIL), summary, files_changed[],
tests, evidence, blockers[], decisions[], new_memory_candidates[], suggested_next_tasks[]
```

Atlas recibe solo el resumen (`Ansem: PASS · 2 files · 12 tests · no blockers`). No lee el transcript del subagente.

## 7. Model routing (real)

- Fuente de verdad: `~/.config/arnes/agent-models.json` (leer siempre, NO hardcodear).
- Mapeo directo ARNES→pi confirmado (Sección 1). `argos-model-router.ts` resuelve `provider/model` y lo pasa a la definición del subagente.
- Fallback: si el modelo asignado no está disponible → fallback configurado por ARGOS (`.arnes/config.json` → `model_fallback`); si no existe, informar. Registrar `{requested, actual, reason}` en el task_run (nunca cambiar silenciosamente).
- Escalación por ejecución (no permanente): intentos 1-2 modelo base → intento 3 modelo superior (ej. flash→pro) → intento 4 intervención Atlas/usuario. Registrar `{base_model, escalated_model, reason}`.

## 8. Scheduler autónomo

`argos-scheduler.ts` (extensión):

- Comandos: `/argos-run` (inicia/continúa), `/argos-pause`, `/argos-resume`, `/argos-stop`.
- Loop (en `turn_end`/`agent_settled` cuando el scheduler está activo y el loop no está pausado):

```text
while quest not complete:
    ready = task ready (<quest_id>)          # dependencias satisfechas
    if no ready and no running: escalate/stop
    for each ready task (respecto a presupuesto y colisión de archivos):
        contract = buildContract(task)
        Atlas delega vía tool `subagent` (decisión A) con el contract
    collect TASK_RESULT → task result (<json>)
    update task graph → re-evaluar dependencias
    resolve blockers → crear remediation tasks si aplica
    stop conditions → break
```

- **Stop conditions**: QUEST PASS (todos los tasks PASS + gates) / USER DECISION REQUIRED / PERMISSION REQUIRED / EXTERNAL BLOCKER / BUDGET LIMIT / REPEATED FAILURE LIMIT (configurable, default 3 escalaciones).
- **Guardas anti-loop infinito**: límite de intentos por task, límite de tasks creadas por quest, límite de iteraciones sin progreso (no-op guard).
- **Presupuestos por task**: `token_budget`, `tool_budget`, `turn_budget` (Quina decide según path: routine→cheap, complex→strong, architecture→strong, security→strong, verification→cheap).
- **Paralelismo con colisión**: tasks independientes pueden delegarse en paralelo (fanout de pi-subagents); antes de lanzar, detectar solapamiento de archivos (`files likely`) → si colisionan, serializar (o worktree con `using-git-worktrees` cuando aporte).
- **Autonomy levels**: `SAFE` (más confirmaciones) / `BALANCED` (autónomo en repo, confirma riesgosos) / `AUTONOMOUS` (continúa ampliamente, gates críticos nunca se omiten). Default `BALANCED` (config en `.arnes/config.json` → `autonomy_level`).

## 9. Roles en el loop

- **Atlas**: clasifica, construye party, delega, monitoriza, resuelve blockers, verifica, autoriza FINALIZAR. Nunca hace trabajo delegable. Solo profundiza en subagente FAIL / Tywin FAIL / security critical / conflicto / dependency blocked / ambigüedad / fallo repetido.
- **Amarant**: DEEP/DELIBERATE → SDD/ADR primero (requirements, spec, architecture, tasks, acceptance). Autoridad de arquitectura.
- **Tywin**: verifica milestones (L3) y actúa como Memory Conflict Judge. Verdict PASS/FAIL/REVIEW con evidencia. Niveles: L0 trivial self-check / L1 tests agente / L2 Kuja / L3 Tywin milestone / L4 Auron+Tywin high-risk gate.
- **Varys**: evidencia/provenance (puede auditar recuerdos sin evidence).
- **Sam**: consolidación, promoción semántica/procedural, digests, dedupe, forgetting.
- **Bard**: aprendizaje (qué aprendimos, qué falló, qué automatizar) con clasificación required/recommended/future; nunca expande scope (las ideas fuera de scope van a `future_candidate`).
- **Quina**: token/memory/skill/tool-call/agent budgets según path.
- **Kuja**: L2 verification (tests).
- **Auron**: L4 high-risk gates + auditoría.

## 10. Compaction + continuidad

- El scheduler persiste su estado en el checkpoint: `{quest, task graph, ready, running, blocked, agent assignments, next scheduler action}`.
- `session_before_compact` → consolidación + checkpoint con scheduler state.
- Recovery Capsule incluye: quest, progreso, ready tasks, blocked tasks, agente activo, next scheduler action.
- Después de compactar → el loop continúa (NO rediseñar el proyecto).
- `argos pi` al arrancar: detecta quest sin terminar (`quest-tasks` con status != pass) → "Resume school-platform-001?" → rehidrata working memory + task graph + checkpoint y continúa.

## 11. Anti-hallucination

- Cada subagente recibe memory cards estructuradas ([PROJECT FACT #184] state/confidence/fact/source), no texto ambiguo.
- Jerarquía de evidencia (fusion spec §7) se mantiene.
- Los hechos del proyecto no cambian sin evidencia (Atlas no cambia facts sin evidence).

## 12. UI

- Footer: `ARGOS • Quest school-platform-001 • 12/27 tasks` + RUNNING/READY/BLOCKED compacto.
- `/argos-party`: ATLAS (modelo, ORCHESTRATOR, ACTIVE) + cada agente (modelo, rol, RUNNING task).
- `/argos-quest`: barra de progreso, PASS/RUNNING/READY/BLOCKED/FAILED counts, next milestone.
- `/argos-tasks`: tabla del task graph (id, agente, status, dependencias).

## 13. Testing y criterios de terminación (del spec del usuario, adoptados)

1. Feature grande con un solo prompt → party seleccionada automáticamente.
2. Atlas NO ejecuta trabajo especializado rutinario.
3. Cada agente ejecuta con SU modelo configurado (verificable en task_runs: model/provider).
4. Pi reutiliza providers autenticados; sin duplicar API keys.
5. Tasks independientes en paralelo; dependencias respetadas; colisiones controladas.
6. Contexto aislado por subagente (contract, no transcript).
7. Atlas recibe resultados resumidos.
8. Superpowers seleccionable automáticamente (vía skill routing + mastery).
9. SDD/TDD/ADR funcionan (Amarant + party).
10. Tywin verifica milestones (L0-L4).
11. Retry/escalación controlada; sin loops infinitos.
12. Cognitive Compaction conserva el scheduler; restart recupera la quest.
13. Token usage por modelo medible (task_runs tokens_in/out).
14. El modelo top-tier consume proporcionalmente menos que los workers.

**Tests automatizables**: unit (task graph CRUD vía brain, party scoring, classifier, escalation policy, capsule con scheduler state) + integración (quest de prueba con 2-3 agentes en fixture, `/argos-run` con BALANCED, TASK_RESULT persistido, resume tras restart simulado). Extender `tests/integration/fusion-check.ps1`.

## 14. Fases de implementación

| Fase | Entregable | Verificación |
|---|---|---|
| 1 | Tablas + comandos `task*`/`quest-tasks` en `arnes_brain.py` (aditivo) | unit: CRUD + graph + ready; smoke brain real |
| 2 | Capability registry + party scoring (extender `argos-party.ts`) | unit: scoring/triggers/anti_triggers |
| 3 | TASK_CONTRACT builder + TASK_RESULT parser + wiring `subagent` con modelos | unit: contract/result round-trip; integración: 1 agente real |
| 4 | Scheduler loop + stop conditions + presupuestos + autonomy levels | integración: quest 2-3 tasks BALANCED |
| 5 | Escalación (modelo por ejecución) + verificación L0-L4 (Tywin) | integración: FAIL→escalar→L3 |
| 6 | Paralelismo con control de colisión de archivos | integración: 2 tasks independientes en paralelo; colisión→serial |
| 7 | UI `/argos-run/pause/resume/stop/tasks/quest` + compaction con scheduler state | smoke manual + unit capsule |
| 8 | Resume/restart (`argos pi` detecta quest) + extender fusion-check | integración: restart simulado |

Cada fase: implementar → testear → verificar → continuar (patrón del plan de fusión: red→green→commit por task).

## 15. Riesgos

- **Cuotas de provider**: los subagentes consumen modelos; límites (429/usage) pueden pausar el loop → stop condition EXTERNAL BLOCKER + reintento con backoff.
- **pi-subagents API**: verificar la versión instalada antes de cada integración (regla "no inventar APIs"); si la API de delegación programática no expone lo necesario, usar la tool `subagent` (decisión A ya contempla esto).
- **Colisiones en paralelo**: mitigadas con detección de archivos; si persisten, worktrees.
- **Coste del loop**: presupuestos por task + stop conditions + no-op guard.
- **El escalation de modelo por ejecución** requiere que el modelo superior exista en pi (deepseek-v4-pro confirmado ✓).

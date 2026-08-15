# ARGOS SUPERPOWERS — Diseño de fusión nativa (Pi + ARNES ARGOS + Superpowers)

> **Fecha**: 2026-08-06
> **Estado**: propuesto (pendiente revisión del usuario)
> **Autores**: Usuario + asistente
> **Requiere aprobación antes de implementar**

---

## 1. Contexto

El usuario tiene un harness RPG propio (**ARNES ARGOS**, 16 agentes, memoria SQLite+FTS5, SDD/FDD/ADR/TDD, grafo, quests, verificación) que hoy orquesta agentes vía **OpenCode**. Quiere una **fusión nativa** con **Pi Coding Agent** (runtime/TUI/ejecución de modelos) y **Superpowers** (biblioteca procedural de skills) en un único harness llamado **ARGOS SUPERPOWERS**, sin productos en cadena: una sola experiencia.

Este documento valida el master spec del usuario contra la realidad auditada (repo ARNES, API de Pi instalada, skills de Superpowers instaladas) y fija el diseño de implementación.

### Auditorías realizadas (evidencia)

**1. ARNES ARGOS — auditado, Memory V3 ES REAL:**
- `cli/arnes_brain.py` (SQLite+FTS5): tablas `agents`, `observations` (memory_kind working|episodic|semantic|procedural, confidence, storage_strength, retrieval_strength, volatility immutable|stable|slow|dynamic|ephemeral, state active|dormant|archived|contested|superseded, evidence, source, supersedes), `quests`, `sessions`, `edges` (weight, success/failure/coactivation), `skill_mastery` (state new|learning|reliable|mastered|needs_review|stale|quarantined), `skill_executions`, `skill_memory_links`, `memory_reviews`, `cognitive_checkpoints` (agent, skill_state, test_state, build_state, git_state), `meta`.
- `cli/arnes-memory.ps1` verbs reales: init, save, search, recall, context, agent, get, update, reinforce, verify, reconsolidate, suggest-topic, revisions, compact, consolidate, consolidate-recent, checkpoint, capsule, continuity, cognitive-compact, backup, export, import, stats, quest, quests, edge, edges, skill (register|exec|link|status|executions), route, reviews.
- 16 prompts de agente: `core/classes/*.agent.md` (9) + `core/auditors/*.agent.md` (7) — incluye tidus y ragnarok (opencode solo registra 15).
- Skills v2 propias: `core/skills/**` y `core/skills/v2/**` (24 SKILL.md).
- Config global por máquina: `~/.config/arnes/agent-models.json` (modelo por agente), `~/.config/arnes/connections.json`.
- Proyecto: `.arnes/arnes.db`, `.arnes/memory/*.jsonl`, `.arnes/sam-digest.json`, `.arnes/shared-blackboard.json`, `.arnes/sdd/`, `.arnes/fdd/`, `.arnes/adr/`, `.atl/skill-registry.md` (mapeo tipo→skill/agente).

**2. Pi (versión instalada) — API real mapea 1:1 con el spec:**
- Eventos de extensión: `session_start`, `session_shutdown`, `resources_discover`, `before_agent_start` (inyección de mensaje + system prompt), `agent_start/end/settled`, `turn_start/end`, `tool_call` (bloqueable, input mutable), `tool_result` (modificable), `context` (mensajes mutables), `model_select`, `session_before_compact`/`session_compact`, `input`, `user_bash`, `project_trust`.
- API: `pi.registerTool`, `pi.registerCommand`, `pi.registerShortcut`, `pi.registerFlag`, `pi.registerProvider`, `pi.setActiveTools`, `pi.getAllTools`, `pi.appendEntry`.
- `ctx`: `ui` (notify/setStatus/setWidget/confirm/select/input), `sessionManager`, `modelRegistry`, `model`, `compact()`, `getContextUsage()`, `getSystemPrompt()`, `signal`.
- CLI: `pi --no-session` (modo efímero → single brain), `pi -e`, paquetes vía `settings.json`/`pi install`.
- Paquetes: manifiesto `pi` en `package.json` (`extensions`, `skills`, `prompts`, `themes`); convención de directorios `extensions/`, `skills/`, `prompts/`.
- Ejemplos oficiales útiles: custom-footer, custom-header, confirm-destructive, custom-compaction, commands.
- **Restricción verificada**: pi NO tiene API pública `setModel` (solo `setThinkingLevel`, `setActiveTools`) y NO tiene tool nativa de subagentes/delegación.

**3. Superpowers (instalado, `git:github.com/obra/superpowers`):**
- 14 skills en `~/.pi/agent/git/github.com/obra/superpowers/skills/`: brainstorming, dispatching-parallel-agents, executing-plans, finishing-a-development-branch, receiving-code-review, requesting-code-review, subagent-driven-development, systematic-debugging, test-driven-development, using-git-worktrees, using-superpowers, verification-before-completion, writing-plans, writing-skills.

## 2. Objetivo y no-objetivos

**Objetivo**: un solo harness percibido como ARGOS SUPERPOWERS: Pi = runtime/cuerpo, ARGOS = cerebro/memoria/orquestación, Superpowers = habilidades procedurales. `argos pi` arranca la experiencia completa; la memoria durable es únicamente `arnes.db`.

**No-objetivos (v1)**:
- No reinventar memoria (Memory V3 ya existe) ni metodologías (SDD/FDD/ADR/TDD ya existen).
- No copiar/forkear Superpowers ni duplicar su contenido.
- No introducir vector DB, Redis, otro orchestrator, otra memoria, otro framework de skills (§86).
- No tocar OpenCode ni los comandos argos existentes (backward compat, §54-55).
- No implementar la ejecución de agentes por modelo real (Opción B) en v1 (ver §5b).

## 3. Arquitectura

```
                      USER
                       │
                       ▼
            ARGOS SUPERPOWERS (una experiencia)
                       │
              ┌────────▼────────┐
              │   PI RUNTIME    │  pi --no-session + extensiones ARGOS
              └────────┬────────┘
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
  ARGOS COGNITION  ARGOS PARTY    PROCEDURAL SYSTEM
  Memory V3 (db)   16 role-skills  ARNES skills v2
  Working Memory   selección       + Superpowers
  Cognitive Router  Atlas          (solo registro/mastery)
  Compaction        Quina/Bran/Sam
  Learning          Tywin/Varys
        │              │              │
        └──────────────┼──────────────┘
                       ▼
              PI TOOLING (read/write/edit/bash
              + tools argos_memory_*)
                       ▼
                   CODEBASE
```

- **Pi** es la única capa que ejecuta modelo y tools.
- **ARGOS** es la única memoria persistente (`<proyecto>/.arnes/arnes.db`).
- **Superpowers** vive como paquete pi instalado; ARGOS solo registra identidad/mastery de sus skills (procedural memory), sin copiar contenido.
- Fuera de un proyecto con `.arnes`: pi funciona normal, la extensión es no-op (§53, §80).

## 4. Paquete pi `argos-superpowers`

Ruta en el repo: `pi/` (raíz del paquete), instalable con `pi install ./pi` (path local → `~/.pi/agent/settings.json`) o vía git/npm más adelante.

```
pi/
├── package.json          # name: argos-superpowers · keywords: [pi-package]
│                         # pi: { extensions: ["./extensions"], skills: ["./skills"], prompts: ["./prompts"] }
├── extensions/
│   ├── argos-core.ts          # bootstrap: session_start → detecta .arnes, DB, schema, migraciones, config, UI
│   ├── argos-memory.ts        # tools argos_memory_* → bridge a arnes_brain.py (subprocess, JSON)
│   ├── argos-working-memory.ts# working memory (hechos frescos de sesión, evitar RAG repetido)
│   ├── argos-cognition.ts     # marco cognitivo FAST/RECALL/SKILL/DELIBERATE/DEEP (contexto + gates)
│   ├── argos-skills.ts        # discovery de skills (ARGOS + Superpowers) + mastery en arnes.db
│   ├── argos-party.ts         # catálogo de 16 agentes desde fuentes canónicas + aislamiento de contexto
│   ├── argos-orchestrator.ts  # Atlas: quest, party select, cognitive path
│   ├── argos-model-router.ts  # mapeo agent-models.json → footer/status (declarativo en v1)
│   ├── argos-permissions.ts   # tool_call: bloquea arnes.db, .env, credenciales, .git, rutas fuera, destructivos
│   ├── argos-compaction.ts    # session_before_compact → consolidate+checkpoint; session_compact → Recovery Capsule
│   ├── argos-learning.ts      # agent_settled → episodio + skill_executions
│   └── argos-ui.ts            # footer/widgets + comandos /argos*
├── skills/
│   ├── argos-atlas/ … argos-ragnarok/   # 16 role-skills (derivadas de core/*.agent.md + v2 skills)
│   └── arnes-memory/ arnes-graph/ (skills ARNES re-exportadas como pi skills)
└── prompts/               # plantillas opcionales de cognitive paths / recovery capsule
```

Reglas:
- No modificar pi core; solo API pública documentada.
- Antes de cada integración importante, re-verificar la API de la versión instalada.
- Dependencias runtime en `dependencies`; paquetes core de pi (`@earendil-works/pi-*`, `typebox`) en `peerDependencies`.

## 5. Launcher `argos pi`

Nuevo subcomando en el CLI ARGOS existente (`argos pi`), PowerShell SOLO para arrancar:
1. Detectar project root y `.arnes` (si no existe `.arnes`, avisar y seguir = pi normal o inicializar según comportamiento actual).
2. Health-check ARNES: integridad de `arnes.db` (schema + stats), migraciones pendientes (vía `arnes-memory.ps1` / `arnes_brain.py`).
3. Verificar pi instalado, superpowers en `pi list`, `~/.config/arnes/agent-models.json` presente.
4. Banner ARGOS SUPERPOWERS (runtime/brain/memory/graph/party/cognition/superpowers/compaction).
5. Lanzar **`pi --no-session`** desde la raíz del proyecto (single brain) con la extensión ARGOS cargada.
6. Ceder el control completamente a pi.

`argos chat`, `argos code`, `argos opencode` y demás comandos se conservan (admin/maintenance/fallback durante validación).

## 6. Single brain

- `pi --no-session` ⇒ sesión efímera: pi no crea segundo archivo de memoria persistente.
- ARGOS (`arnes.db`) es la única memoria durable. El historial de sesión de pi es runtime.
- La continuidad entre sesiones la proveen los checkpoints/cápsulas ARGOS (no el historial de pi).
- Verificar en implementación que `--no-session` es compatible con la extensión y con `argos pi` (si un caso de uso requiriera sesión pi, documentar la excepción; el default es efímero).

## 7. Memory V3 — consumo y bridges

- No duplicar lógica en TypeScript: las tools ARGOS hacen **bridge** a `arnes_brain.py` (subprocess `python`, entrada/salida JSON) y a `arnes-memory.ps1 -Quiet` cuando aplique.
- Tools registradas (pi `registerTool`), escondiendo SQLite/Python/PowerShell al LLM:
  - `argos_memory_search`, `argos_memory_get`, `argos_memory_save`, `argos_memory_update`, `argos_memory_context`, `argos_memory_timeline`, `argos_memory_relations`, `argos_memory_verify`, `argos_memory_stats`
  - `argos_working_memory`
  - `argos_graph_neighbors`, `argos_graph_path`
  - `argos_quest_status`, `argos_project_status`
- Respuestas estructuradas al modelo (ej. tarjeta MEMORY con kind/topic/state/epistemic/confidence/trust/importance/source/summary).
- Anti-alucinación: jerarquía de evidencia estricta (repo verificado > tests/tools > hecho del usuario > memoria verificada > memoria observada > inferencia > hipótesis); si repo contradice memoria ⇒ repo gana, observación nueva, memoria previa `superseded`/`contested`.

## 8. Working memory

- Antes de RAG completo, consultar working memory (quest activo, agente activo, objetivo, archivos, errores, hechos verificados recientes, skill activa, next action).
- Si una pregunta se responde correctamente desde working memory ⇒ FAST, sin búsquedas repetidas.
- Implementación: bloque inyectado en `before_agent_start` + tool `argos_working_memory`; la sesión pi es el cache vivo.

## 9. Cognitive Router (honesto: prompt + gates, no control-flow)

- Pi no puede forzar el camino del modelo. El router se implementa como:
  - **Contexto** (`before_agent_start`): quest, agente actual, working memory, next action y marco de decisión FAST/RECALL/SKILL/DELIBERATE/DEEP con el principio "mínimo esfuerzo suficiente".
  - **Presupuestos Quina** por path (FAST: 0 agentes, 0-1 lookup de memoria; SKILL: 1 agente, 1 procedimiento, contexto ligero; DEEP: especialistas múltiples, contexto mayor, verificación fuerte).
  - **Gates de verificación** (Tywin) según riesgo del path.
- El modelo declara el path (visible en footer) y la extensión ajusta contexto/tools en consecuencia.
- FAST: responder con working/semantic memory, sin agentes ni skills ni tools extra.
- RECALL: memory search → resultado verificado → respuesta.
- SKILL: patrón reconocido → procedural memory → skill router → ejecutar → verificar (ej. runtime error + tests fallando ⇒ systematic-debugging si mastery/contexto lo justifica).
- DELIBERATE: feature normal, contexto incompleto, confianza media ⇒ memoria+tools+agente+skill+verificación.
- DEEP: arquitectura/seguridad/migración/riesgo ⇒ SDD/FDD/Amarant/party/Auron/Tywin.

## 10. Agentes — ingesta y selección

**Ingesta automática (sin JSON nuevo duplicado)** — `argos-party.ts` en `session_start`:
- Lee fuentes canónicas: `core/classes/*.agent.md` + `core/auditors/*.agent.md` (16), `core/skills/v2/*/SKILL.md`, `~/.config/arnes/agent-models.json`, `.atl/skill-registry.md`.
- Construye catálogo en memoria (índice ligero, cache opcional en `.arnes/argos-party.json`): `{ id, displayName, role, promptSource, skillV2, model, memoryNamespace }`.
- Los 16 agentes existen en pi (incluye tidus y ragnarok). Editar `core/classes/mage.agent.md` se refleja en el siguiente arranque/`/reload`. Una sola fuente de verdad.

**Selección inteligente** — Atlas (sesión pi) decide por quest con contexto inyectado:
1. Quest type detectado (frontend/backend/fix/research/architecture/devops/boss).
2. Mapeo automático tipo→skill/agente (`.atl/skill-registry.md`: `.tsx`→vivi-fireball, API→ansem-smite, tests→kuja-backstab, Docker→eiko-mend...).
3. Memoria histórica: qué party funcionó en quests similares (Sam/Bran desde arnes.db).
4. Budget Quina (tokens).
El catálogo JSON no decide; decide el modelo (Atlas) guiado por ese contexto.

**Ejecución (Opción A aprobada)**: los agentes son **role-skills** con aislamiento de contexto: `before_agent_start` inyecta solo `{role, task, quest, SDD/ADR relevantes, memory cards relevantes, procedimiento seleccionado, archivos/contexto, restricciones}` — nunca todo el chat principal.

**Model routing (v1, honesto)**: pi ya está autenticado y conoce los providers/modelos (login/API conectados al inicio, como el usuario recuerda) — ARGOS **reutiliza esa autenticación**: NO copia API keys ni crea configuración manual nueva. `argos-model-router.ts` solo mapea `~/.config/arnes/agent-models.json` → catálogo real de pi (`ctx.modelRegistry`), validando disponibilidad. Ejemplo: asignación ARNES `opencode-go/gpt-5.6-luna` → provider `opencode-go`, modelo `gpt-5.6-luna` del registry de pi. Si el modelo asignado no está disponible: NO cambiar silenciosamente — aplicar fallback configurado por ARGOS (o informar) y registrar `{requested, actual, reason}` en la ejecución (§21 del master spec). Como pi no expone `setModel`, el footer muestra el modelo configurado del agente y la role-skill opera con el modelo de sesión (el de Atlas). El usuario puede cambiar el modelo de sesión con `/model`. **Opción B (multi-model real**: spawn `pi -p --model <provider/model> --no-session` por agente) queda como fase posterior condicional a benchmark (§84). El modelo no es el cerebro: memoria/skills/quests/grafo viven en ARNES y sobreviven cualquier cambio de modelo (§63, §93).

## 11. Superpowers — fusión procedural

- No copiar/forkear/modificar el paquete Superpowers.
- `argos-skills.ts` descubre las skills cargadas vía API real (`systemPromptOptions.skills` en `before_agent_start`, y/o rutas del paquete).
- ARGOS registra en `arnes.db` (tabla `skill_mastery`/`skill_executions` vía comando `skill`) solo: `{ skill, source, version/hash, mastery, success, failure, contexts, associations, history }`.
- Skill routing considera: relevancia, patrón, mastery, confianza, success rate, failure patterns, compatibilidad de agente, riesgo, costo tokens/tools, precondiciones, anti-triggers. Puede elegir 0, 1 o pocas skills. No activar Superpowers por defecto.
- Skills prioritarias reconocidas (existen en la versión instalada): systematic-debugging, verification-before-completion, requesting-code-review, receiving-code-review, using-git-worktrees, finishing-a-development-branch (y las demás reales).
- Mastery: new→learning→reliable→mastered (y needs_review/stale/quarantined) con success_count/failure_count/confidence/last_used/hash. Cambio de hash de skill ⇒ mastered→needs_review (mantener historial).
- Aprendizaje: tras skill→ejecución→tests→Tywin, guardar resultado distinguiendo skill failure / model failure / environment failure / permission failure / external dependency failure (no castigar la skill equivocada).
- NO duplicar SDD/FDD/ADR/TDD: ARGOS sigue siendo la fuente de specs/plans/tasks/decisiones; Superpowers complementa ejecución. Precedencia fijada (§30 del master spec).

## 12. Compaction

- Pipeline: contexto crece → consolidación ARGOS (`consolidate`/`consolidate-recent`) → Cognitive Checkpoint → Memory V3 → compactación nativa de pi → Recovery Capsule → rebuild working memory → continuar.
- Hooks reales: `session_before_compact` (consolidar + checkpoint; puede proveer summary custom) y `session_compact` (reinyectar cápsula).
- Checkpoint preserva: quest, goal, phase, agente activo, completed, pending, decisions, blockers, active files, modified files, tests, build, git state, skill activa, procedure state, memory IDs críticos, **NEXT ACTION exacta**.
- Recovery Capsule inyecta SOLO contexto mínimo: identity, project, quest, agent, goal, completed, pending, blocker, decisions, skill, next action, critical memory refs. No reinyectar la DB completa.
- Superpowers + compaction: preservar solo `{active procedure, procedure stage, skill execution ID}`; dejar que Superpowers/pi restaure la skill normalmente.
- Checkpoints naturales (≠ compaction): antes de handoff, tras fase de quest, tras verdict Tywin, tras decisión importante, antes de operación riesgosa, feature complete, shutdown.

## 13. Permisos

- `tool_call` intercepta y bloquea: `write/edit/bash` sobre `.arnes/arnes.db`, `connections.json`, `.env`, credenciales, `.git`, rutas fuera del proyecto, comandos destructivos, cambios de producción.
- Toda modificación de memoria pasa por `argos_memory_*` (nadie edita arnes.db directo).
- Confirmación UI (`ctx.ui.confirm`) solo para operaciones riesgosas; lecturas normales sin preguntar.
- UX: `[ARGOS PERMISSION] Agent: Ansem · Action: edit · File: src/api/auth.ts · Allow?`

## 14. UI y comandos

- Footer `ctx.ui.setStatus`: `ARGOS • Ansem • DeepSeek Flash • SKILL • systematic-debugging`; FAST: `ARGOS • FAST • Memory ✓`; DEEP: `ARGOS • DEEP • Atlas → Amarant + Ansem + Auron`.
- Widget header (`ctx.ui.setWidget`): estado compacto (proyecto/quest/agente/path/memoria).
- Comandos registrados: `/argos`, `/argos-status`, `/argos-memory`, `/argos-memory-doctor`, `/argos-agents`, `/argos-agent`, `/argos-party`, `/argos-quest`, `/argos-skills`, `/argos-checkpoint`, `/argos-compact`, `/argos-continuity`, `/argos-doctor`.
- `/argos`: proyecto, quest, agente activo, path cognitivo, Memory V3, RAG, grafo, pi runtime, superpowers, modelo actual, uso de contexto.
- `/argos-skills`: fuente, estado mastery, %, ejecuciones verificadas (PASS/FAIL), mejores contextos, last used.
- `/argos-memory-doctor`: observaciones por kind, estados, conflictos, memorias sin evidencia, duplicados, FTS, grafo, backup.
- `/argos-continuity`: Quest/Agent/Goal/Plan/Blockers/Skill/Next Action + Continuity Score.

## 15. Precedencia

1. Instrucción explícita actual del usuario
2. Realidad verificada del repo
3. Hechos verificados de proyecto ARGOS
4. Quest/SDD/ADR aprobado ARGOS
5. Rol de agente activo ARGOS
6. Memory V3 ARGOS
7. Skill routing procedural ARGOS
8. Procedimiento Superpowers
9. Defaults de pi

## 16. Plan de implementación por fases (mapea al master spec §87)

Cada fase: implementar → testear → verificar → continuar. Tests en `tests/` (patrón: `verify-read-write-only.ps1`).

| Fase | Entregable | Verificación |
|---|---|---|
| 1 | Auditar ARGOS actual (Memory V3, Compaction) | Documento de auditoría (este spec) ✅ hecho |
| 2 | Auditar APIs reales de pi instalada | ✅ hecho (Sección 1) |
| 3 | Auditar Superpowers instalado | ✅ hecho (Sección 1) |
| 4 | Crear paquete pi `pi/` (package.json + esqueleto de extensiones) | `pi list` muestra argos-superpowers; extensión carga sin errores |
| 5 | Boot + detección de proyecto + UI base (`argos-core.ts` + banner + footer) | Fuera de `.arnes`: pi normal. Dentro: footer ARGOS. Test §65 (BOOT) |
| 6 | Memory tools bridge (`argos-memory.ts`) | Test §66 (MEMORY): pregunta un hecho verificado y responde desde Memory V3 |
| 7 | Working memory (`argos-working-memory.ts`) | Test §67 (WORKING MEMORY): follow-up inmediato sin RAG repetido |
| 8 | Cognitive Router (`argos-cognition.ts`) | Tests §68 (FAST: pregunta fácil sin activar agentes/skills) |
| 9 | ARGOS Party (`argos-party.ts` + 16 role-skills) | Test §71 (PARTY): Atlas delega con contextos aislados |
| 10 | Model Router (`argos-model-router.ts`, declarativo v1, **reusando la autenticación de pi**: login/API ya conectados, sin copiar keys) | Test §72 (MODEL ROUTING): footer muestra modelo configurado por agente, resuelto contra el catálogo real de pi |
| 11 | Skill discovery/router (`argos-skills.ts`) | Test §69 (SKILL): bug reproducible selecciona procedimiento adecuado |
| 12 | Fusión Superpowers ↔ Procedural Memory | Test §70 (MASTERY) + §77 (SKILL LEARNING) |
| 13 | Integración SDD/FDD/ADR/TDD | Tests §73 (SDD), §74 (TDD) |
| 14 | Permisos (`argos-permissions.ts`) | Bloqueo real de escritura a arnes.db/.env desde el LLM |
| 15 | Cognitive Compaction (`argos-compaction.ts`) | Tests §78 (COMPACTION) + §79 (SESSION RESTART) |
| 16 | Learning loop (`argos-learning.ts`) | Test §77 + §76 (SUPERSESSION fuera de RAG normal) |
| 17 | Comandos/UI completos | `/argos-*` operativos; Tests §75 (CONFLICT) |
| 18 | `argos pi` launcher + benchmark | Tests §65/§79/§80/§81/§82/§83; benchmark §84 |

## 17. Criterios de terminación (del master spec §94, adoptados)

1. `argos pi` abre la experiencia. 2. Pi es el runtime. 3. ARGOS es el cerebro. 4. Memory V3 funciona cada turno. 5. Working Memory evita búsquedas repetidas. 6. Cognitive Router funciona. 7. Los 16 agentes funcionan. 8. Model routing funciona (declarativo v1). 9. Superpowers descubierto. 10. Superpowers en Procedural Memory. 11. Skill Mastery se actualiza. 12-15. SDD/FDD/ADR/TDD funcionan. 16. Tywin verifica. 17. Bard aprende. 18. Sam consolida. 19. Varys mantiene provenance. 20. Quina controla presupuesto. 21. Compaction conserva continuidad. 22. Session restart conserva continuidad. 23. No existe segunda memoria. 24. OpenCode no se rompió. 25. Pi normal funciona fuera de ARGOS. 26. Un modelo barato obtiene beneficio demostrable. 27. El usuario percibe un solo harness.

## 18. Riesgos y decisiones diferidas

- **Multi-model real (Opción B)**: diferido a fase 10 posterior, condicional a benchmark (§84). El spec del usuario lo permite explícitamente (§86).
- **`--no-session` y extensión**: validar compatibilidad durante fase 5; si algún flujo requiere sesión pi, documentar excepción (default efímero).
- **Cognitive Router**: es prompt + gates + budgets, no control-flow forzado sobre el LLM (limitación real de pi; el modelo decide el esfuerzo, guiado por contexto).
- **Tidus/Ragnarok**: en pi entran los 16 aunque opencode solo registró 15; verificar que sus prompts y skills v2 están completos antes de fase 9.
- **No romper ARGOS actual**: los comandos existentes y OpenCode se conservan; la fusión se valida en paralelo (backward compat).

# PLAN ARNES ARGOS — Roadmap Maestro del Harness

> **Documento de continuidad entre sesiones.**
> **ARNES ARGOS**: el gigante de los 100 ojos — todo lo ve, todo lo vigila.
> **ARGOS = el ENTORNO** (comando `argos` desde cualquier carpeta). **Atlas = el orquestador** dentro.
> Creado: 2026-08-05 · Última actualización: 2026-08-05 (cierre de sesión)
> **Estado actual: ARNES ARGOS v2 completo + comando argos operativo + 3 modos + recommend.**

---

## ✨ PALABRA MÁGICA DE CONTINUIDAD: "CIEN OJOS"

> Para retomar la sesión: escribe **"CIEN OJOS"** y ARGOS sabrá que vienes a continuar.
> Es el gatillo: abre este plan, verifica git/memoria y sigue con los pendientes de abajo.

## 🎯 MAÑANA RETOMAMOS AQUÍ (sesión del 2026-08-06)

**Siguiente paso pendiente**: continuar con la visión de configuración del usuario:
1. ✅ Conexiones GLOBALES (una vez por computadora) — `~/.config/arnes/connections.json`
2. ✅ argos-recommend (mini-guía inteligente con prioridad ahorro/equilibrio/calidad)
3. ✅ **RAGNAROK PRIMERA BÚSQUEDA** (2026-08-06): cuando no hay proveedores conectados, `argos recommend` y el flujo de proyecto nuevo muestran la guía de Ragnarok (qué conectar: nvidia gratis, opencode-go workhorse, openai razonamiento, bai elite)
4. ✅ **FLUJO DE PROYECTO NUEVO PROBADO** (2026-08-06, carpeta real `argos-test-proyecto`) — ver abajo
5. ✅ **`argos configure` USA LA RECOMENDACIÓN COMO DEFAULT** (2026-08-06): si el modelo previo del agente no está disponible entre los proveedores conectados, el picker abre con la recomendación (equilibrio) ya preseleccionada

**Para retomar**: `argos` → [4] Recomendación inteligente → luego [3] Configurar modelos

---

### ✅ Prueba de flujo de proyecto nuevo (2026-08-06) — 2 bugs encontrados y corregidos

**Prueba**: carpeta real `C:\Users\LapOne Mx\Documents\GitHub\argos-test-proyecto`, secuencia `argos init` → `connect` → `configure` → `recommend` → `status`.

**Resultados**:
- ✅ `argos init` crea `.arnes/` + `agent-models.json` (16 agentes con defaults)
- ✅ `argos-connect status` lista conexiones GLOBALES (bai, nvidia, opencode-go conectados)
- ✅ `argos recommend` lista 14 modelos de proveedores conectados (leía global correctamente)
- ✅ `argos configure` configura los 16 agentes desde proveedores conectados (después del fix)
- ✅ Detección `has_connections` en menú usa proveedores globales conectados (después del fix)

**Bug 1 (CRÍTICO — corregido en `cli/argos.ps1`)**: `argos.ps1` leía conexiones de la ruta LOCAL `.arnes/connections.json`, pero `argos-connect.ps1`/wizard escriben en la GLOBAL `~/.config/arnes/connections.json`. Síntoma: conectabas proveedores → "conectado" → al configurar agentes decía "No hay proveedores conectados". Fix: `$GlobalConnPath` usada en `Get-ProjectState` (≥1 proveedor `connected`) y `Show-ConfigureModels`.

**Bug 2 (corregido en `cli/argos-connect.ps1` + `cli/argos-connect-wizard.ps1`)**: el wizard OAuth abría la URL base de la API (`https://api.openai.com/v1`) en vez del login real de la cuenta. Fix: campo `login_url` por proveedor (`openai` → `https://chatgpt.com/auth/login`, `claude` → `https://claude.ai/login`), con migración idempotente en `init` (agrega `login_url` a proveedores conocidos en el JSON global existente) y fallback a `base_url` si no existe.

**Gotchas nuevos**:
- `Read-Host` crashea en modo NO interactivo (`PSInvalidOperationException`) → CORREGIDO 2026-08-06: helper `Read-Input` en argos.ps1, argos-recommend, argos-connect-wizard y argos-interaction (devuelve vacío en vez de crashear). El flujo completo de proyecto nuevo ya corre headless sin colgarse.
- El picker (`argos-picker.ps1`) tiene fallback no interactivo: devuelve la opción default automáticamente (útil para tests headless).
- `argos-chat.ps1` usa `$Root` del repo (no del proyecto) para `$ArnesDir` — inofensivo hoy, inconsistente con el resto (usa `Get-Location`).
- La carpeta de test `argos-test-proyecto` puede borrarse cuando quieras.

### ✅ Mejoras de configuración (2026-08-06, 2ª ronda)

- **Recomendación rol-consciente**: `argos-recommend.ps1` ahora tiene `$ROLE_PREF` por agente (alineado a la estrategia 75% DeepSeek + Luna razonamiento + Qwen Atlas). Antes "equilibrio" asignaba `claude-fable-5` a TODOS los agentes (incluido Atlas) — un bug de calidad. Ahora: Atlas→qwen3.8-max, razonamiento→gpt-5.6-luna, volumen→deepseek-v4-flash NVIDIA, Auron→deepseek-v4-pro gratis.
- **`-Priority` param**: `argos recommend -Priority ahorro|equilibrio|calidad` funciona sin interacción (para automatización). El motor se reutiliza por dot-source desde argos.ps1 (guarda de main con `$MyInvocation.InvocationName`).
- **Guía Ragnarok**: cuando no hay proveedores conectados, se muestra qué conectar primero (nvidia/opencode-go/openai/bai) en lugar de un callejón sin salida.

### ✅ ESLABÓN CRÍTICO: modelos por agente APLICADOS (2026-08-06)

**Problema encontrado**: `argos configure` escribía `.arnes/agent-models.json`, pero NADA lo aplicaba a los agentes reales. Los 16 agentes del party son SUBAGENTES de OpenCode definidos en `~/.config/opencode/agents/<name>.md` SIN frontmatter de modelo. Según las docs de OpenCode, un subagente sin `model` usa el modelo del agente primario que lo invoca → TODO el trabajo caía en qwen3.8-max (modelo de Atlas) → sin uso por modelo en los dashboards.

**Fix**: nuevo `cli/argos-models-apply.ps1` — inyecta frontmatter `model: <x>` + `mode: subagent` en cada `agents/<name>.md` instalado. Se ejecuta automáticamente después de `argos configure` y `argos recommend -Apply`, y tras `atlas sync` (SyncAgents re-aplica para no perder el frontmatter). En el chat: comando `/connectagent` reconfigura modelos sin salir.

**Cadena completa**: `argos configure` → `.arnes/agent-models.json` → `argos-models-apply` → `~/.config/opencode/agents/*.md` (frontmatter model) → Atlas delega vivi/ansem/auron → CADA UNO usa SU modelo → uso de tokens por modelo real. Reiniciar la sesión de argos/opencode para que tome los modelos.

**Gotcha**: los agentes `.md` instalados tenían mojibake cp1252→UTF-8 pre-existente (em-dash "â€""). El script repara por línea (round-trip seguro) y preserva BOM UTF-8.

### ✅ MOTOR NATIVO + CICLO COMPLETO (2026-08-06) — sin opencode

- **`cli/argos-engine.ps1`**: motor nativo que habla DIRECTO con las APIs (bai, nvidia, opencode-go, openai) — OpenAI-compatible, con reintentos (429/500/503), uso de tokens por respuesta, y **body UTF-8 explícito** (bug crítico: PS 5.1 mandaba ISO-8859-1 → HTTP 500 con unicode en todo opencode-go).
- **`cli/argos-cycle.ps1`**: ciclo orquestador completo: ATLAS orquesta (PARTY + plan) → AMARANT plan técnico → BARD mejora continua (FALTA/NO SE MENCIONÓ/AGREGAR) → PARTY ejecuta con SUS modelos → TYWIN verifica (PASS/FAIL + remediation) → ATLAS autoriza (FINALIZAR/RETOQUE). Reporte en `.arnes/quests/` + mejoras/verdict en memoria.
- **`cli/argos-chat.ps1`**: chat NATIVO (sin opencode), multi-turno, persona RPG completa, uso de tokens por mensaje.
- **`argos test-model`**: prueba "hola" por modelo con el motor nativo. **`argos quest "<quest>"`**: lanza el ciclo completo.
- **Economía de tokens (por diseño)**: Atlas (tier, persona completa ~6K tkns) SOLO 2 llamadas/quest (orquesta + autoriza) — estratega caro pero preciso; Amarant planea con NVIDIA gratis; el party ejecuta con DeepSeek Flash/Pro; Tywin verifica gratis.
- **Endpoints corregidos**: opencode-go → `https://opencode.ai/zen/go/v1` (el `api.opencode.ai/v1` daba 404); bai → `api.b.ai/v1` (catálogo 37 modelos, chat da 403 con la key actual — pendiente validar con el proveedor).

**Pendiente siguiente**: modo CODING nativo (leer/editar/crear archivos en vivo, como Claude Code/Codex pero ARNES) + delegación del party con herramientas reales.

### ✅ DECISIÓN: OpenCode como entorno de trabajo (2026-08-06)

El usuario decidió usar **OpenCode como el entorno interactivo de trabajo** (su TUI es superior para trabajar en vivo) y **ARNES como la capa de configuración, memoria y agentes**:
- ARNES = conexiones y modelos (una vez por máquina), memoria por proyecto (arnes.db), los 16 agentes RPG con sus modelos asignados, doctor/verify, perfiles de proyecto.
- OpenCode = el entorno donde trabajas (chat, delegación de agentes, edición de archivos) usando NUESTROS 16 agentes y SUS modelos.
- **Puente**: `argos opencode` (o menú [9]) → sincroniza agentes+modelos (`atlas --sync`) → abre opencode en la carpeta. Los agentes viven en `~/.config/opencode/agents/*.md` con frontmatter de modelo.
- El chat nativo de ARNES queda disponible para consultas rápidas, pero NO compite con opencode para trabajo real.

### ✅ Distribución y portabilidad (2026-08-06)

- **Modelos GLOBALES de máquina**: `~/.config/arnes/agent-models.json` — se configuran UNA vez (`argos configure` / `argos recommend`) y se despliegan al frontmatter de los agentes instalados en cualquier proyecto. Migración automática desde proyectos con config local. `~/.config/arnes/agent-models.json` — se configuran UNA vez (`argos configure` / `argos recommend`) y se despliegan al frontmatter de los agentes instalados en cualquier proyecto. Migración automática desde proyectos con config local.
- **Instalador npm**: `package.json` + `bin/argos.js` (multiplataforma) + `bin/postinstall.js` (sync de agentes + conexiones + despliegue de modelos). `npm install -g .` deja el comando `argos` global.
- **Instalador directo**: `install.ps1` / `install.sh` actualizados (param `-RepoUrl`, wrappers `argos`+`atlas`, `atlas --sync` headless).
- **Docker**: `Dockerfile` (pwsh + node + opencode CLI) + `docker-compose.yml` con volúmenes de `~/.config/arnes`, `~/.config/opencode` y la carpeta de trabajo → corre en cualquier PC.
- **README**: manual de instalación en la página principal (3 opciones: instalador directo, npm, Docker) + quickstart + docs.
- `atlas.ps1 --sync`: modo headless para instaladores (sync agentes + skills + memoria + despliegue de modelos).

**Pendiente usuario**: subir repo a GitHub (URL definida con usuario `mauriragna88`, placeholder reemplazado en README; pendiente en installers) y decidir si se remueve el plugin de memoria de terceros del `opencode.json` global (solo agentes SDD legacy).

### ✅ Independencia total — LIMPIEZA COMPLETADA (2026-08-06)

- ✅ **El party ARNES (16 agentes) es 100% independiente**: memoria propia en arnes.db (FASE 1 BRAIN), SDD/FDD/ADR propios, flujo argos propio.
- ✅ **Limpieza total del repo completada 2026-08-06**: eliminados los scripts legacy de memoria de terceros; rewired loop-engine/circuit-breaker a `arnes-memory.ps1`; bloque legacy de carga de memoria reemplazado por `Load-ArnesMemory` en atlas/activate; todos los agentes, skills y docs actualizados a memoria propia (arnes.db). CERO menciones restantes.
- ✅ Config global `~/.config/opencode/opencode.json` aún conserva el plugin de memoria de terceros para los agentes sdd-*/maestro legacy (fuera del flujo del party) — decisión pendiente del usuario si se remueve.

---

## 🎯 MISIÓN DEL ARNES

Construir el **ARNES v2** — un ecosistema de desarrollo 100% propio e independiente:
- **CERO dependencia** de herramientas externas: memoria, metodos y skills propios
- Memoria cerebral propia (SQLite + FTS5), Knowledge Graph, SDD, FDD, ADR propios
- El harness hace el trabajo pesado → el modelo de IA es intercambiable (DeepSeek/Qwen/GPT)
- Anti-alucinación por diseño: memoria + verificación, no confianza ciega en el LLM

**Principio rector**: "Como mejor tengamos nuestro arnes, el modelo de IA es indistinto porque tiende a alucinar más." → El sistema verifica, el modelo ejecuta.

---

## 📦 DEPENDENCIAS PERMITIDAS (verificadas 2026-08-05 en la máquina)

| Recurso | Versión | Uso |
|---|---|---|
| SQLite + FTS5 | 3.50.4 (probado en vivo) | arnes.db — memoria cerebral |
| Python | 3.14.4 | Motor de memoria (sqlite3 nativo) |
| Node | v24.12.0 | OpenCode + scripts |
| PowerShell | 5.1 | Atlas Shell + CLI |
| Git | 2.52.0 | Repo + versionado |
| winsqlite3.dll | Nativo Windows | Backup SQLite |

**PROHIBIDO depender de**: herramientas externas de memoria/orquestacion · Neo4j · bases externas · SDKs ajenos. Todo corre con Python + SQLite + PowerShell.

---

## 🧠 ARQUITECTURA CEREBRAL (ARNES BRAIN)

### Analogía: SQLite = hipocampo, Knowledge Graph = neocortex

```
ARNES BRAIN (arnes.db - SQLite + FTS5)
│
├── agents          → quién eres (id, clase, modelo, trust_score)
├── observations    → recuerdos (agente, topic_key, tipo, contenido, timestamp)
├── quests          → misiones (qué se hizo, party, resultado, tokens)
├── sessions        → sesiones (inicio, fin, resumen)
├── edges           → RELACIONES (node_a, node_b, relation, agent, ts) [FASE 2]
└── FTS5 index      → índice de recuerdos (búsqueda instantánea)
```

### Conceptos cerebrales implementados

| Concepto | Implementación | Beneficio |
|---|---|---|
| Memoria episódica | observations con quest_id | "¿qué hicimos la última vez?" |
| Memoria semántica | patterns/learnings | Hechos inyectados, no suposiciones |
| Memoria procedural | skills + XP | El agente sabe qué le funcionó |
| Recall selectivo | FTS5 query de lo relevante | No satura la ventana del LLM |
| Consolidación (sueño) | digest periódico por agente | Recuerdos compactos y duraderos |
| Plasticidad sináptica | trust_score sube/baja | Lo que falla se debilita |
| Anti-alucinación (RAG) | El agente busca HECHOS antes de actuar | No inventa, verifica |

### Patrón Atlas-consulta-agente

```
ATLAS necesita saber → task() al agente → agente busca en SU memoria (arnes.db)
→ agente responde → Atlas usa la respuesta. (Ahorra tokens, cada uno vive su rol.)
```

### Formato híbrido memoria

- `arnes.db` = memoria activa (SQLite, rápida, consultable)
- `.arnes/memory/export/*.jsonl` = snapshot para git/backup (auto-export al cerrar sesión)
- Auto-recuperación: si no hay db → crear desde JSONL; si no hay JSONL → exportar desde db

---

## 🏗️ METODOLOGÍAS (ARNES METHOD)

| Metodología | Para qué | Estado |
|---|---|---|
| **SDD** (Spec-Driven) | Features grandes: spec → design → tasks → apply → verify | FASE 3 |
| **FDD** (Feature-Driven) | Listas de features: feature list → plan → implement → review | FASE 4 |
| **TDD** (Test-Driven) | Test primero, red→green→refactor | ✅ Ya existe (vitest) |
| **Proportional Verification** (regla de Kuja, 2026-08-05) | El esfuerzo del test ES proporcional a la complejidad. Trivial = 1-2 tests o ninguno (regla 4+4=8). NO sobre-verificar con "verificación teatral" | ✅ Aplicada en rogue.agent.md |
| **ADR** (Architecture Decision Records) | Toda decisión de arquitectura queda registrada | FASE 5 |
| **DDD** (Domain-Driven) | Glosario de dominio si el proyecto lo pide | Opcional |
| **Knowledge Graph** | Relaciones entre todo (quién tocó qué) | FASE 2 |
| **Skills PROPIAS v2** | Skills de los 13 agentes 100% propias (las de internet solo como referencia) | FASE 3.5 |

---

## 🔒 REGLA INALTERABLE (DECISIÓN DEL USUARIO 2026-08-05)

**El arnes NO depende de herramientas externas EN NADA: ni skills, ni SDD, ni memoria, ni nada.**
- Las skills de internet (superpowers, ui-ux-pro-max, taste-skill) **SÍ SE MANTIENEN CARGADAS** como
  **complemento de poder** para que los agentes sean top — pero NUNCA son una dependencia obligatoria.
- Los agentes cargan skills **100% propias del arnes** (v2) como identidad y proceso.
- Las skills web son el ARSENAL extra: cuando una skill propia lo necesite, puede apoyarse en las web
  para ejecutar mejor (ej: vivi-fireball usa react + tailwind instalados, pero el PROCEDIMIENTO es nuestro).
- Cero referencias a origenes externos en el skill-registry.
- FASE 3.5 es dedicada a crear estas skills propias + mapear las web como complemento.

---

## 📋 FASES DE IMPLEMENTACIÓN

### FASE 1 — ARNES BRAIN (memoria propia) ✅ COMPLETADA 2026-08-05
- [x] Crear `arnes.db` (SQLite + FTS5): schema agents, observations, quests, sessions, edges
- [x] `arnes-memory.ps1` CLI: save, search, context, export-jsonl, import-jsonl
- [x] Skill `arnes-memory` (el cerebro)
- [x] Skill `arnes-agent-memory` (instrucción para que cada agente guarde/consulte SU memoria)
- [x] Skill `arnes-context-digest` (consolidación / "sueño")
- [x] Integrar en los agent.md: "después de actuar, guarda a memoria" (7 party members)
- [x] Test de humo: save → search → context → export → quest → edge ✅
- [x] Sync skills a OpenCode: ~/.config/opencode/skills/atlas/arnes-*

**Detalles técnicos**:
- `cli/arnes_brain.py` — motor Python (SQLite nativo, FTS5, triggers auto-sync)
- `cli/arnes-memory.ps1` — CLI PowerShell (usa archivo temporal para evitar encoding cp1252)
- `arnes.db` ubicado en `.arnes/arnes.db` (53KB inicial)
- 15 agentes registrados (atlas + party + auditores + tidus + ragnarok)
- 4 observaciones de prueba, 1 quest (Q-001), 1 edge (Login.tsx → zod)
- **Gotcha**: en PowerShell 5.1, pasar JSON por pipe corrompe acentos → usar archivo temporal + `Get-Content -Raw`

### FASE 2 — ARNES GRAPH (relaciones) ✅ COMPLETADA 2026-08-05
- [x] Tabla `edges` sobre arnes.db (ya existia del schema FASE 1)
- [x] `arnes-graph.ps1` CLI: add, query, neighbors, path, stats
- [x] Motor extendido: add_edge, query_edges, neighbors (BFS), path (BFS), graph_stats
- [x] Skill `arnes-graph`
- [x] Mapa de código: componentes ↔ librerías ↔ agentes (Login.tsx → zod, Sidebar → tailwind, users → rls-policy)
- [x] Test de humo: query, neighbors depth=2, path-finding Login→tailwind ✅

**Detalles técnicos**:
- `cli/arnes-graph.ps1` — CLI PowerShell del grafo
- Motor: `arnes_brain.py` con BFS para neighbors y path-finding
- Estado actual: 6 nodos, 5 edges (uses: 3, imports: 1, protected_by: 1)
- Anti-alucinación por relaciones: "si el grafo dice que existe, existe"

### FASE 3 — ARNES SDD (metodos propios) ✅ COMPLETADA 2026-08-05
- [x] Skills propias file-based: `arnes-sdd-propose/spec/design/tasks/apply/verify/archive`
- [x] Carpeta `.arnes/sdd/` con templates (proposal, spec, design, tasks)
- [x] Change de ejemplo: `.arnes/sdd/C-20260805-01/` (Login Form con Zod)
- [x] 7 skills sincronizadas a OpenCode
- [x] Ciclo SDD probado: proposal aprobado → quest Q-002 registrado

**Detalles técnicos**:
- Templates en `.arnes/sdd/templates/` (proposal.md, spec.md, design.md, tasks.md)
- Cada change vive en `.arnes/sdd/C-YYYYMMDD-NN/`
- Skills: arnes-sdd-propose → spec → design → tasks → apply → verify → archive
- Flujo conectado a memoria: cada fase guarda en arnes.db (specs-created, quest-history)
- La fase verify la ejecuta Tywin (PASS/FAIL con evidencia)

### FASE 3.5 — ARNES SKILLS PROPIAS (DECISIÓN 2026-08-05) ✅ COMPLETADA
> **El usuario decidió: skills 100% propias, sin dependencias externas obligatorias.**
> Las skills de internet instaladas (superpowers, ui-ux-pro-max, taste-skill, etc.) **SE MANTIENEN**
> como **complemento de poder / arsenal** para que los agentes sean top — nunca como dependencia obligatoria.
> El PROCEDIMIENTO es nuestro; las skills web potencian la ejecución.

- [x] Crear skills propias renovadas en `core/skills/v2/` (16 skills) — sin origenes externos
- [x] Actualizar `.atl/skill-registry.md` — mapeo RPG → skills PROPIAS v2
- [x] Cada skill propia define: trigger, inputs, pasos, output esperado, conexión a memoria (arnes.db)
- [x] Skills del arnes (15 agentes): vivi-fireball, ansem-smite, kuja-backstab, eiko-mend, amarant-foresight, eremez-mark, auron-bulwark, bran-vision, quina-ledger, varys-whisper, tywin-judgment, sam-counsel, atlas-orchestrate, tidus-tide-check, ragnarok-scout
- [x] La capa RPG (niveles/XP/damage) se mantiene pero apunta a las skills propias v2
- [x] Mapear skills web como COMPLEMENTO (no dependencia): cada skill propia lista qué skills web potencian su ejecución
- [x] Template `arnes-skill-v2` para crear futuras skills

**Detalles técnicos**:
- Ubicación: `core/skills/v2/<agente>-<skill>/SKILL.md`
- Sincronizadas a OpenCode: `~/.config/opencode/skills/atlas/v2/` (16 skills)
- Skill-registry renovado con compact rules v2 (archivo → skill propia)

### FASE 4 — ARNES FDD ✅ COMPLETADA 2026-08-05
- [x] Skills `arnes-fdd-plan/implement/review/archive`
- [x] Carpeta `.arnes/fdd/` con templates (feature-list, feature-plan)
- [x] Feature set de ejemplo: `.arnes/fdd/FL-20260805-01/` (Sistema de Login, 4 features)
- [x] Features conectadas a memoria (cada feature registra quest en arnes.db)
- [x] 4 skills sincronizadas a OpenCode

**Detalles técnicos**:
- FDD = features independientemente entregables (valor visible al terminar cada una)
- Diferencia con SDD: SDD = spec profunda para un change; FDD = lista de features incrementales
- Templates: feature-list.md (el mapa) + feature-plan.md (plan por feature)
- Feature set de ejemplo: F1 Login done, F2 Password Reset done, F3/F4 pending

### FASE 5 — ARNES ADR ✅ COMPLETADA 2026-08-05
- [x] Skill `arnes-adr`
- [x] Carpeta `.arnes/adr/` con template.md
- [x] 3 ADRs registrados: ADR-001 (SQLite+FTS5), ADR-002 (proceso propio), ADR-003 (skills propias)
- [x] Amarant registra decisiones (contexto, decisión, alternativas, consecuencias)

**Detalles técnicos**:
- Formato: contexto → decisión → alternativas → consecuencias → razón
- Ubicación: `.arnes/adr/ADR-NNN-slug.md`
- Conexión a memoria: `amarant/arch-decisions` en arnes.db

### FASE 6 — ATLAS SHELL + GIT ✅ COMPLETADA 2026-08-05
- [x] `atlas-shell.ps1` — banner ARNES + menú (chat/wizard/memoria/health/novedades)
- [x] `argos-picker.ps1` — selector con flechas (estilo /models)
- [x] `atlas.cmd` — wrapper para ejecutar desde CMD/PowerShell
- [x] Detección de proveedores (Go/OpenAI/NVIDIA) en el shell
- [x] Wizard de configuración con flechas (modelos por agente)
- [x] Reconfiguración parcial: `atlas-shell.ps1 -Setup`
- [x] Chat directo: opción 1 → opencode --agent atlas-player
- [x] Git re-init (el .git estaba vacío/roto) ✅ commit inicial 76635d4
- [x] `.gitignore` (protege secretos, arnes.db, basura)
- [x] Limpieza: imagen10.jpg + Sin título.jpg eliminados
- [x] README.md actualizado (instalación, empresa ARNES, memoria, metodologías)

**Detalles técnicos**:
- Shell: `cli/atlas-shell.ps1` (banner + menú + wizard + chat) — con BOM UTF-8
- Picker: `cli/argos-picker.ps1` (flechas ↑/↓, Enter, Q, Esc) — con BOM UTF-8
- `atlas.cmd` apunta a atlas-shell.ps1
- Git: 1 commit inicial con todo el ecosistema
- **Gotcha**: los emojis rompen PS 5.1 sin BOM — usar texto plano + BOM UTF-8 obligatorio

### FASE 7 — TIDUS (Infrastructure & Growth Warden) ✅ COMPLETADA 2026-08-05
> **Departamento de Sistemas del harness.** Vigila que el entorno y cada agente tengan recursos suficientes.

- [x] `core/classes/tidus.agent.md` creado ✅ (health-check, cuotas, growth)
- [x] Integrar en `cli/atlas.ps1` SyncAgents (mapeo tidus → core/classes/tidus.agent.md)
- [x] Skill `tidus-tide-check` (health-check de recursos: disco, RAM, CPU) — en core/skills/v2/
- [x] Skill `tidus-cuota-check` (revisar cuotas Go/OpenAI/NVIDIA) — parte de tidus-tide-check
- [x] Integrar health-check al inicio de sesión (test realizado: semáforo GREEN)
- [x] Conectar a arnes.db: `tidus://health-history` ✅ (health-check guardado)
- [x] Registrado en config.json (modelo deepseek-v4-flash)

**Test realizado**: disco 156GB libres, RAM 20GB, CPU 30%, OpenCode conectado → GREEN

### FASE 8 — RAGNAROK (Procurement & Research Warden) ✅ COMPLETADA 2026-08-05
> **Departamento de Compras del harness.** Investiga la web (repos, Reddit, X), busca skills/metodologías
> nuevas, compara contra lo que tenemos y propone la "compra". El arnes nunca se estanca.

- [x] `core/classes/ragnarok.agent.md` creado ✅ (scout, tendencias, comparativas, adopción)
- [x] Integrar en `cli/atlas.ps1` SyncAgents (mapeo ragnarok → core/classes/ragnarok.agent.md)
- [x] Skill `ragnarok-scout` (scan web: repos git, Reddit, X, awesome-lists) — en core/skills/v2/
- [x] Skill `ragnarok-compare` (War Cry: lo nuevo vs lo actual, ROI) — en core/skills/v2/
- [x] Scan de novedades al inicio de sesión (ciclo Scout → War Cry probado)
- [x] Conectar a arnes.db: `ragnarok://adopciones`, `ragnarok://rechazos` ✅ (scout-results guardado)
- [x] Documentación: lo adoptado se agrega a docs/ del repo
- [x] Registrado en config.json (modelo gpt-5.6-luna)

**Test realizado**: ciclo Scout → War Cry → Recomendación (mantener dual capa ADR-003)

### FASE 9 — AURON L0 GATE (Permiso de Trabajo en Altura) ✅ COMPLETADA 2026-08-05
> **Auron = supervisor de seguridad industrial.** Antes de todo quest L0 verifica que el agente
> tenga "equipo": skill requerida, docs revisadas, plan de rollback, entorno correcto, impacto, backup.

- [x] `core/auditors/auron.agent.md` actualizado ✅ (checklist L0 Gate de 6 checks)
- [x] Conectar a arnes.db: `auron://l0-permits/<quest_id>` ✅ (test guardado)
- [x] Test: quest L0 sin plan de rollback → Auron bloquea (FAIL) ✅ PASÓ
- [x] Test: quest L0 completo → Auron permite (PASS) ✅ PASÓ
- [x] Test: quest L0 sin skill requerida → Auron bloquea (FAIL) ✅ PASÓ

**Test realizado**: 3/3 tests correctos — L0 Gate operativo

---

## 🛠️ SKILLS A CREAR (total)

| Skill | Fase |
|---|---|
| `arnes-memory` | 1 |
| `arnes-agent-memory` | 1 |
| `arnes-context-digest` | 1 |
| `arnes-graph` | 2 |
| `arnes-sdd-propose` | 3 |
| `arnes-sdd-spec` | 3 |
| `arnes-sdd-design` | 3 |
| `arnes-sdd-tasks` | 3 |
| `arnes-sdd-apply` | 3 |
| `arnes-sdd-verify` | 3 |
| `arnes-sdd-archive` | 3 |
| `arnes-fdd-plan` | 4 |
| `arnes-fdd-implement` | 4 |
| `arnes-fdd-review` | 4 |
| `arnes-fdd-archive` | 4 |
| `arnes-adr` | 5 |
| `arnes-skill-v2` (template de skill propia) | 3.5 |
| `tidus-tide-check` (health-check recursos) | 7 |
| `tidus-cuota-check` (cuotas proveedores) | 7 |
| `ragnarok-scout` (scan web novedades) | 8 |
| `ragnarok-compare` (comparativa War Cry) | 8 |
| Skills v2 de los 13 agentes (vivi-fireball, ansem-smite, kuja-backstab, eiko-mend, amarant-foresight, eremez-mark, auron-bulwark, bran-vision, quina-ledger, varys-whisper, tywin-judgment, sam-counsel, atlas-orchestrate) | 3.5 |

---

## 🎯 CONFIGURACIÓN DE MODELOS (2026-08-05 — ya aplicada)

### Proveedores conectados (verificados con `opencode auth list`)
- ✅ **OpenCode Go** (api) — suscripción $10/mes
- ✅ **OpenAI** (oauth) — cuenta GPT con plan (13 modelos GPT-5.x disponibles)
- ✅ **NVIDIA NIM API** (api) — GRATIS (1000-5000 credits, 40 req/min)
- ✅ MiniMax, Z.AI, bai, tokenrouter, Alibaba...

### Asignación actual en `.arnes/config.json`

| Agente | Modelo | Proveedor | Costo |
|---|---|---|---|
| Atlas | `qwen3.8-max` | Go | plan |
| Vivi | `gpt-5.6-luna` | OpenAI | plan GPT |
| Ansem | `deepseek-v4-flash` | NVIDIA | GRATIS |
| Kuja | `deepseek-v4-flash` | NVIDIA | GRATIS |
| Eiko | `deepseek-v4-flash` | Go | plan |
| Amarant | `gpt-5.6-luna` | OpenAI | plan GPT |
| Eremez | `deepseek-v4-flash` | NVIDIA | GRATIS |
| Auron | `deepseek-v4-pro` | NVIDIA | GRATIS |
| Bran | `gpt-5.6-luna` | OpenAI | plan GPT |
| Quina | `deepseek-v4-flash` | Go | plan |
| Varys | `gpt-5.6-luna` | OpenAI | plan GPT |
| Tywin | `deepseek-v4-flash` | NVIDIA | GRATIS |
| Sam | `gpt-5.6-luna` | OpenAI | plan GPT |

**Nota**: el usuario quiere PODER cambiar esto con un wizard interactivo de flechas (FASE 6). El proveedor NVIDIA permite DeepSeek V4 Pro GRATIS.

---

## 🔴 PENDIENTES IMPORTANTES / GOTCHAS

1. **Git roto**: `.git/` existe pero vacío (0 archivos, sin HEAD). `git init` de nuevo en FASE 6.
2. **BOM UTF-8 obligatorio** en `atlas-init.ps1` — si un editor guarda sin BOM, el banner se corrompe (PS 5.1 lee sin BOM como ANSI).
3. **atlas-player en opencode.json** apunta a `nvidia/deepseek-ai/deepseek-v4-pro` — debe actualizarse a qwen3.8-max en FASE 6 (o antes).
4. **skills sdd-* legacy instaladas** en `~/.config/opencode/skills/` — reemplazadas por las nuestras en FASE 3.
5. **skill-registry.md referencias a origenes externos** — actualizado a skills propias v2 en FASE 3.5.
5. **Plugin de memoria de terceros** MCP en opencode.json — solo para agentes SDD legacy, fuera del flujo del party.
6. **Basura en repo**: `imagen10.jpg` y `Sin título.jpg` — limpiar en FASE 6.
7. **PowerShell 5.1** — el `$_` en comandos bash se come por interpolación; usar scripts temporales o escaping.
8. **Consola cp1252** — no imprimir emojis Unicode desde python directo en consola; usar archivos temporales o ASCII.

---

## 📁 ARCHIVOS CLAVE DEL REPO

| Ruta | Función |
|---|---|
| `cli/argos.ps1` | **NUEVO** El ENTORNO: `argos` desde cualquier carpeta — detecta proyecto, /connect, /configuremodel, chat |
| `cli/argos-connect.ps1` | **NUEVO** Gestor de conexiones (connections.json propio, secrets protegidos) |
| `cli/argos-connect-wizard.ps1` | **NUEVO** Wizard interactivo de conexiones (flechas, estilo /connect propio) |
| `cli/argos-chat.ps1` | **NUEVO** Chat nativo con Atlas (prompt [ARGOS], sin TUI ajena) |
| `cli/argos.cmd` | **NUEVO** Wrapper `argos` en PATH (ASCII, sin BOM) |
| `cli/atlas-init.ps1` | Inicializador con banner ARNES mamalón (tiene BOM UTF-8) |
| `cli/atlas.ps1` | Launcher principal (onboarding, sync, lanza OpenCode/Codex/Claude) |
| `cli/atlas-ff.ps1` | Command center (models, routes, doctor, configure) |
| `cli/atlas-model-config.ps1` | Configurador de cadena de modelos |
| `cli/model-catalog.ps1` | Catálogo vivo de modelos (opencode models) |
| `cli/agent-model-resolver.ps1` | Resuelve modelo por agente contra catálogo |
| `docs/PROVIDERS-GUIDE.md` | **NUEVO** Mini-guía de conexiones: OAuth OpenAI, API NVIDIA, catálogo Go, URLs |
| `core/memory-system.md` | Diseño de memoria propia (arnes.db SQLite+FTS5) |
| `core/protocols/` | Schemas de blackboard, sam-digest, handoff |
| `.arnes/config.json` | Config principal (modelos por agente) |
| `.arnes/model-recommendations.json` | Party recomendada por plan |
| `.arnes/model-routing-policy.json` | Preferencias y fallbacks por agente |
| `.arnes/shared-blackboard.json` | Conocimiento cross-agent |
| `.arnes/sam-digest.json` | Puente de memoria inter-quest |
| `.openspec/` | SDD actual (file-based, reusable como base de arnes-sdd) |
| `core/classes/tidus.agent.md` | **NUEVO** Tidus — Infrastructure & Growth Warden (FASE 7) |
| `core/classes/ragnarok.agent.md` | **NUEVO** Ragnarok — Procurement & Research Warden (FASE 8) |
| `core/auditors/auron.agent.md` | **AMPLIADO** Auron — checklist L0 Gate (permiso trabajo en altura, FASE 9) |

---

## 🏢 LA EMPRESA ARNES (organización completa 2026-08-05)

```
ARNES = EMPRESA
├── Dirección General      → ATLAS (orquestador)
├── Sistemas/Infra         → TIDUS (nuevo) + Eiko (builds)
├── Programación           → Vivi (frontend) + Ansem (backend)
├── Compras               → RAGNAROK (nuevo) — web, repos, proveedores, skills nuevas
├── Controlling/Finanzas   → Quina (tokens)
├── Mejora Continua        → BARD — código, deuda técnica, DX
├── Seguridad              → AURON — permiso de trabajo en altura (L0 gate)
├── QA                     → Kuja — TDD + verificación proporcional
├── Arquitectura           → Amarant — SDD/ADR
├── Investigación          → Eremez — docs, librerías
├── Auditoría              → Varys + Tywin + Sam
└── Marketing/Ventas       → ⚠️ futuro (README/docs = "ventas")
```

**Flujo entre departamentos**:
- Tidus detecta skill faltante → Ragnarok investiga la mejor en la web → Atlas decide → Quina valida costo → Auron verifica seguridad → se adopta y se documenta
- Ragnarok propone cambio de metodología (SDD/FDD/grafos) → Amarant evalúa arquitectura → Atlas decide → se documenta
- Auron bloquea quest L0 sin plan de rollback → el agente corrige → Auron permite → sigue el quest

---

## 🚀 CÓMO RETOMAR EN LA PRÓXIMA SESIÓN

1. Leer este documento (`docs/PLAN-ARNES.md`)
2. Leer `docs/WHAT-IS-LEFT.md` y `.arnes/next-steps.json` si existen
3. Verificar estado: `git status`, `.arnes/config.json`, `opencode auth list`
4. Continuar con la FASE que quede pendiente (actualmente: FASE 1)
5. Comenzar FASE 1: crear arnes.db + arnes-memory CLI + skills de memoria
6. Nota: Fases 7-9 (Tidus/Ragnarok/Auron) tienen sus agent.md YA creados — solo falta integrarlos (sync + skills + tests)

**Convención**: al terminar cada sesión, actualizar este documento (fases completadas, gotchas nuevos, estado del harness).

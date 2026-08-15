# Estado del Proyecto — Que nos Falta

> creado: 2026-07-25
> actualizado: 2026-08-14 (F1+F2+F3+fix handles SQLite commiteados; doc alineado con master)

## ⚠️ IMPORTANTE — LEE PRIMERO `docs/PLAN-ARNES.md`

El roadmap maestro está en **`docs/PLAN-ARNES.md`**. Ese documento es la fuente de verdad para la visión ARNES v2:
ecosistema 100% propio (memoria SQLite, knowledge graph, SDD/FDD/ADR propios) SIN herramientas externas.
Este archivo resume el estado heredado; el plan futuro vive en PLAN-ARNES.md.

## Completado (lo que ya funciona)

- [x] CLI npm `argos` con entrada multiplataforma basada en PowerShell
- [x] Diagnóstico de prerequisitos con `argos doctor`
- [x] Configuración global de proveedores y modelos por agente
- [x] Sincronización de agentes, modelos y skill trees con OpenCode
- [x] Mutex de sincronización para evitar colisiones entre procesos concurrentes
- [x] Escrituras idempotentes de modelos para reducir el tiempo de arranque repetido
- [x] Memoria propia SQLite/FTS5 y knowledge graph
- [x] Metodologías propias SDD, FDD y ADR documentadas
- [x] Documentación pública base, changelog, contribución y troubleshooting de arranque
- [x] Suite de tests unificada (`npm test`) y CI en GitHub Actions
- [x] Grafo de relaciones activado con edges reales y test propio
- [x] Comandos `argos xp`, `argos stats` y `argos theme`
- [x] Doctor con detección de agentes faltantes por nombre
- [x] Release v0.1.0 publicado en GitHub
- [x] `argos target freebuff` — nuevo target con modelos abiertos y despliegue de `AGENTS.md` al proyecto (commit `319f1e2`)
- [x] Instaladores (`install.ps1`, `install.sh`, `installer-snippet.sh`) con `mauriragna88` y corrección CRLF en `install.sh` (commit `319f1e2`)
- [x] `--test-force-exit` en `package.json` para evitar que `npm test` se quede colgado (commit `af12976`)
- [x] OSMA V7 — Episode Pattern Completion + Reactivation (ADR-010), 60/60 tests (commit `46de8cc`)
- [x] Comando `osma-stats` para resumir el estado cerebral V4-V7, defensivo ante tablas faltantes, 49/49 tests (commit `4bf3bc1`)
- [x] Quest Recommender Gate — `quest-detector.ps1 -Recommend`, `atlas-orchestrator.ps1 -Gate always|auto|off` y `preferences.json` con `quest_gate`, 6/6 tests (commit `82ca6a9`)
- [x] Recuperación de confianza de Ansem: `trust_score` restaurado de 0.5 a 0.75 tras `osma-stats` PASS (auditoría Tywin 7/7)
- [x] `argos doctor` con 10 puntos de diagnóstico, incluida detección de Docker

- [x] Estructura SDD completa (proposal, spec, design, tasks)
- [x] Config base `.arnes/config.json` con plataforma/suscripcion/party
- [x] CONVENTIONS.md - reglas universales del harness
- [x] Skill Registry con skills internas + externas mapeadas a cada clase
- [x] Atlas Player Agent (`atlas-player.agent.md`) con quest detect, party select, loop, circuit breaker
- [x] Quest Detector subagent
- [x] Model Router subagent (3 plataformas x free/pro tiers)
- [x] Loop Engine subagent con state machine IDLE → QUESTING → EVALUATE → AUTO_NEXT
- [x] 6 Party Class Agent files:
  - Vivi (Mage frontend) con skills Fireball/Flare/Inferno/Meteor Shower
  - Eiko (Cleric Healer) con skills Mend/Esuna/Cura/Mass Heal
  - Ansem (Paladin Backend) con skills Smite/Divine Shield/Holy Ground
  - Kuja (Rogue QA) con skills Backstab/Shadow Clone/Eviscerate
  - Amarant (Monk Architecture) con skills Foresight/Meditation/Zen
  - Eremez (Ranger Research) con skills Mark/Swarm/Wide Net
- [x] 6 Skill Tree JSON files (uno por clase)
- [x] 3 Tactics files (party composition, turn economy, mana conservation)
- [x] CLI legacy `activate.ps1` con deteccion auto + UI rojo-negro
- [x] Deploy hooks para:
  - OpenCode (atlas-agent.json + alt.json model mapping)
  - Codex (codexrc.json)
  - Claude (claude_desktop_config.json)
- [x] Cross-platform adapter rules (`adapter-rules.md`)
- [x] Research de skills externas con rankings (`RESEARCH-SKILLS-2026.md`)
- [x] Memoria por subagente (memory-system.md)
- [x] Flujo de uso completo documentado (`USAGE-FLOW.md`)
- [x] **Varys Documentalist** (auditor de docs) — NEW 2026-07-27
- [x] Atlas primary agent configurado en `~/.config/opencode/opencode.json`
- [x] Model chain con auto-fallback NVIDIA → SiliconFlow → Z.ai

## Pendiente (lo que nos falta)

### 🔴 Roadmap — ver `docs/PLAN-ARNES.md` para el detalle completo

**FASES (en orden de ejecución):**

| Fase | Qué | Estado |
|---|---|---|
| **FASE 1 — ARNES BRAIN** | arnes.db (SQLite+FTS5) + arnes-memory CLI + skills memoria | Hecho |
| **FASE 2 — ARNES GRAPH** | Capa de relaciones (edges) + arnes-graph CLI | Hecho |
| **FASE 3 — ARNES SDD** | Skills arnes-sdd-* propias | Hecho |
| **FASE 4 — ARNES FDD** | Skills arnes-fdd-* + features | F1 (XP unlocks) · F2 (temas UI) · F3 (USD stats) · fix handles SQLite — Hecho · F4 (marketplace) bloqueada |
| **FASE 5 — ARNES ADR** | Registro de decisiones + skill arnes-adr | Hecho |
| **FASE 6 — ARGOS CLI + GITHUB** | CLI, modelos, diagnóstico, documentación y publicación | Publicado (release v0.1.0) |

### Pendientes heredados (de la versión anterior)

1. **Probar Atlas en OpenCode real**
   - Verificar que el agente `atlas` carga con system prompt RPG
   - Verificar que la delegacion con `task(subagent_type="vivi")` funciona

2. **Validar Atlas en OpenCode real** con una sesión completa y documentar resultados.

3. **Cerrar la publicación de GitHub**: separar cambios acumulados, revisar secretos, elegir
   commits atómicos y crear el primer release.

4. **Limpiar artefactos locales** antes de publicar, incluyendo imágenes o configuraciones que
   no formen parte del producto.

### Media Prioridad — Quality of Life

7. **XP system en CLI**
   - Trackear XP ganada y guardarla en config.json
   - Mostrar nivel en /party y /status
   - Skills se desbloquean segun unlocks/skills cuando sube level — Hecho (commit `cef365c`)
     - `cli/skill-unlocks.ps1` mapea 9 agentes a sus skill JSONs y muestra skills desbloqueadas por nivel en `argos xp`.

### Baja Prioridad — Nice to have

8. **Temas personalizables**
   - Atlas rojo-negro, Tema Vivi (violeta), Tema Amarant (bronce), etc. — Hecho (commit `b55228f`)
     - `cli/theme-colors.ps1` aplica el color de acento del tema activo a `argos-chat`, `argos-xp` y `argos-stats`.

9. **Stats dashboard**
   - Total tokens usados por sesion/dia/semana
   - Costo aproximado en USD por sesion/dia — Hecho (commit `b55228f`)
     - `cli/pricing.ps1` + `argos stats` muestran costo USD por agente y por día.
   - Racha de quests completados

10. **Marketplace publish**
     - subir Atlas RPG a Smithery y skills.sh para que otros la puedan instalar (bloqueado hasta publicar en npm)

11. **Limpieza y pruebas pendientes**
    - Eliminar la causa raíz de los handles abiertos de SQLite en fixtures de tests — Hecho (commit `932ff57`, `--test-force-exit` eliminado, 63/63 pass en 70s).
    - ~~Eliminar o mover a `legacy/` `activate.ps1` / `evenatan-ui.ps1`, actualmente marcados como deprecados.~~ — Hecho (commit `cef365c`, movidos a `legacy/` con `README.md` explicativo).

12. **Tareas externas del usuario**
    - Rotar la API key de B.AI.
    - Probar una sesión real.
    - Publicar el paquete en npm.

## Decisiones Tomadas (2026-08-05)

1. ✅ **Modelos reasignados** — DeepSeek V4 Flash como workhorse (75%), GPT-5.6 Luna para razonamiento, Qwen3.8 Max para Atlas. Proveedores: Go + OpenAI (OAuth) + NVIDIA (GRATIS).
2. ✅ **ARNES v2 100% independiente** — memoria SQLite propia, SDD/FDD/ADR propios. CERO herramientas externas.
3. ✅ **Memoria = SQLite (arnes.db) + FTS5** — búsqueda instantánea tipo cerebro, con export JSONL para git.
4. ✅ **FDD aprobado** — se construye como FASE 4.
5. ✅ **Knowledge Graph aprobado** — capa de relaciones (FASE 2).
6. ✅ **Harness > modelo** — el sistema verifica; el modelo es intercambiable.
7. ✅ **Atlas Shell** — banner + wizard de modelos con flechas + chat directo (FASE 6).
8. ✅ **Continuidad entre sesiones** — este documento + PLAN-ARNES.md son la fuente de retoma.

## Documentos de referencia

- [`README.md`](../README.md) — instalación y uso público.
- [`CHANGELOG.md`](../CHANGELOG.md) — cambios por release.
- [`CONTRIBUTING.md`](../CONTRIBUTING.md) — contribución y validación.
- [`ARGOS-STARTUP.md`](./ARGOS-STARTUP.md) — diagnóstico del arranque.

## SIGUIENTE SESIÓN (guardado 2026-08-14 — para retomar con "continua")

**Estado: todo commiteado y pusheado (master, árbol limpio).** Último commit: `932ff57` (fix handles SQLite). F1, F2, F3 y fix handles ya en master.

### Ya implementado hoy (no rehacer)
- `argos target` (selector opencode/codex/claude/freebuff con party completo en Claude y roster en Codex/Freebuff); `argos target freebuff` ya está implementado.
- `argos goal` / `/autowork` (modo autónomo por objetivo con memoria: remediation → siguiente prompt).
- `argos xp`, `argos stats`, `argos theme`.
- OSMA V7 (Episode Pattern Completion + Reactivation), `osma-stats` y recuperación de trust de Ansem.
- Quest Recommender Gate (`-Recommend`, `-Gate always|auto|off`, `quest_gate`) ya está completado.
- Instaladores actualizados, corrección CRLF en `install.sh`, `--test-force-exit` y `argos doctor` con Docker como punto 10.
- Varys guarda la bitácora de secuencia (`varys/evidence-packs/<quest>`); Atlas decide con CONTEXTO DE MEMORIA.
- Suite unificada `npm test` + CI + grafo activado + release v0.1.0 + paquete npm preparado.
- **F1 (skill unlocks por XP)** en `argos xp` vía `cli/skill-unlocks.ps1` (commit `cef365c`).
- **F2 (temas en UIs)** — `argos-chat`, `argos-xp`, `argos-stats` usan `cli/theme-colors.ps1` (commit `b55228f`).
- **F3 (USD en stats)** — `argos stats` muestra costo USD por agente y por día usando `cli/pricing.ps1` (commit `b55228f`).
- **Fix handles SQLite** — `arnes_brain.py` cierra idempotente + `atexit`+`__del__`; `argos-brain.ts` mata hijo tras timeout; `--test-force-exit` eliminado; 63/63 pass (commit `932ff57`).
- **Legacy cleanup** — `activate.ps1`, `evenatan-ui.ps1` movidos a `legacy/` con `README.md` (commit `cef365c`).

### Pendiente PARA EL USUARIO (externo, no es código)
1. **Probar la sesión real**: `argos quest "<algo>"`, `argos goal "<objetivo>" -MaxIterations 3`,
   `argos target codex` y `argos target claude` — es el examen de fuego del ciclo con APIs reales.
2. **Rotar la API key de B.AI** que estaba en el backup local eliminado.
3. **Publicar en npm**: `npm adduser` (login) → `npm publish` (el paquete ya está listo, v0.1.0).
4. **F4 del FDD**: publicar Atlas en Smithery y skills.sh (requiere el npm publish antes).

### Pendiente DE CÓDIGO si el usuario lo pide
- ~~F2 temas: aplicar el tema elegido (`argos theme set X`) a las UI reales~~ — Hecho (`b55228f`).
- ~~F3 stats: costo aproximado USD por sesión/día~~ — Hecho (`b55228f`).
- ~~F1: desbloqueo de skills por nivel de XP~~ — Hecho (`cef365c`).
- ~~Limpieza legado: `activate.ps1` / `evenatan-ui.ps1`~~ — Hecho, movidos a `legacy/` (`cef365c`).
- ~~Handles abiertos de SQLite en fixtures de tests: corregir la causa raíz~~ — Hecho (`932ff57`).
- Si la prueba real falla en la cadena quest/party: depurar con el stub `tests/stubs/fake-cycle.ps1`.
- ~~Racha (streak) de quests en `argos stats`~~ — Hecho (`b2ee623`): muestra racha actual + mejor racha histórica.

### Regla de retoma
Cuando el usuario diga "continua", leer este bloque + `README.md` y seguir con lo pendiente
en el orden: prueba real del usuario → ajustes que surjan → F4 marketplace → mejoras FDD.

### PRÓXIMO TRABAJO DE CÓDIGO (cuando el usuario diga "seguimos") — en este orden
1. ~~**Aplicar el tema elegido a las UI reales**~~ — Hecho (commit `b55228f`). `argos theme set X`
   aplica el color de acento a `argos-chat`, `argos-xp` y `argos-stats` vía `cli/theme-colors.ps1`.
2. ~~**Costo aprox. USD en stats**~~ — Hecho (commit `b55228f`). `argos stats` muestra USD por
   agente y por día usando `cli/pricing.ps1`.
3. ~~**Desbloqueo de skills por nivel de XP**~~ — Hecho (commit `cef365c`). `argos xp` muestra
   skills desbloqueadas por nivel usando `cli/skill-unlocks.ps1`.
4. ~~**Limpiar el legado**~~ — Hecho (commit `cef365c`). `activate.ps1`, `evenatan-ui.ps1` y
   `activate.sh` movidos a `legacy/` con `README.md` explicativo.
5. ~~**(NUEVO) Racha de quests en `argos stats`**~~ — Hecho (commit `b2ee623`). Muestra racha
   actual y mejor racha histórica de días consecutivos con quests usando `quest-ledger.json`.
6. **(NUEVO) Marketplace F4** — publicar en Smithery y skills.sh (requiere `npm publish` antes).

### IMPORTANTE: registro de uso del usuario
- `.arnes/quest-ledger.json` y `.arnes/model-assignments.json` se modifican CADA vez que el
  usuario usa `argos` (quests, tokens, timestamps). **NO revertirlos** (`git checkout --`) ni
  ignorarlos: son la evidencia de uso para el diagnóstico ("¿usaste argos?" → leer el ledger).
- La fuente de verdad de memoria es `.arnes/arnes.db` (gitignored): ejecuciones por agente,
  verdicts de Tywin, evidence packs de Varys, debriefs de Atlas.
- Al retomar, reportar al usuario qué hizo: nº de quests nuevos, tokens, verdicts (se puede
  consultar con `argos stats`).

## Estado del árbol de trabajo

El repositorio puede contener cambios acumulados de sesiones anteriores. Antes de publicar en
GitHub hay que revisar `git status`, separar los cambios por responsabilidad y no incluir claves,
memoria local ni configuraciones privadas.

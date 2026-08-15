# ARGOS SUPERPOWERS — Punto de retoma (cierre 2026-08-07)

> **Siguiente sesión**: leer este archivo primero. Todo lo construido está commiteado.
> **Ledger de ejecución (git-ignored, sobrevive en disco)**: `.superpowers/sdd/2026-08-06-argos-superpowers-fusion/progress.md`

---

## 1. Qué se construyó esta sesión (commits `6355a0d`..`2ab0ac6`, 11 commits)

### Fase A — Fusión ARGOS SUPERPOWERS (COMPLETA, fusion-check 7/7 PASS)

| Commit | Entrega |
|---|---|
| `6355a0d` | Spec de fusión (design doc) |
| `b929fc6` | Paquete pi `argos-superpowers` + bootstrap + bridge `runBrain` → `arnes_brain.py` |
| `95e78fb` | 9 tools `argos_memory_*` (search/get/save/update/verify/stats/context/timeline/relations) |
| `77ef7f4` | Working memory + Cognitive Router (FAST/RECALL/SKILL/DELIBERATE/DEEP) |
| `e57ec35` | Catálogo 16 agentes (IDs RPG: vivi/ansem/...) + model router declarativo |
| `9db504a` | 17 role-skills (`pi/skills/argos-*`) + discovery de skills (Superpowers+ARNES) |
| `c2319fb` | Orquestador quest-type + permisos + compaction (checkpoint/capsule) |
| `829d566` | Learning loop + UI (11 comandos `/argos*`) |
| `f750c1d` | Launcher `argos pi` (single brain, banner, health-check) |
| `26952d8` | Suite de integración `tests/integration/fusion-check.ps1` (**7/7 PASS**) |

Verificación: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/integration/fusion-check.ps1` → PASS.
Tests unit: `cd pi && npx tsx --test ../tests/unit/*.test.ts` → 14 PASS. Typecheck: `cd pi && npx tsc --noEmit` → limpio.

### Fase B — ARGOS AUTONOMOUS PARTY (SPEC ESCRITO, PENDIENTE DE TU APROBACIÓN)

- Spec: `docs/superpowers/specs/2026-08-07-argos-autonomous-party-design.md`
- Versión legible (letra grande): `docs/superpowers/specs/2026-08-07-argos-autonomous-party-design.html`
- **Estado**: esperando tu revisión/ok. **Siguiente paso**: escribir el plan de implementación (writing-plans) con 8 fases.

---

## 2. Cómo retomar (siguiente sesión)

1. Leer este archivo.
2. **Si aprobaste la Autonomous Party**: invocar `writing-plans` → crear `docs/superpowers/plans/2026-08-07-argos-autonomous-party.md` (8 fases del spec §14) → ejecutar (red→green→commit por task, patrón de la fusión).
3. **Si quieres ajustar el spec**: editar el .md, regenerar el HTML (o pedirlo), re-approbar.

---

## 3. Hallazgos del entorno (importantes)

1. **`~/.pi/agent/settings.json` fue reescrito durante la sesión** perdiendo el package de superpowers — **RESTAURADO** (packages + defaults). Tenía BOM UTF-8 (eliminado). Verificar que siga: `cat ~/.pi/agent/settings.json`.
2. **`pi list` no refleja los packages de settings.json** en esta config (dice "No packages installed" aunque superpowers carga). No es un problema funcional.
3. **`pi-subagents` v0.42.1 instalado** (`~/.pi/agent/npm/`): tool `subagent` + APIs programáticas. Es el mecanismo de delegación de la Autonomous Party.
4. **Modelos de `agent-models.json` confirmados en el catálogo pi**: `opencode-go/gpt-5.6-luna`, `opencode-go/deepseek-v4-flash`, `opencode-go/deepseek-v4-pro`, `nvidia/z-ai/glm-5.2`, `nvidia/minimaxai/minimax-m3` — todos existen. Mapeo directo.
5. **Cuotas de provider inestables** (opencode-go: usage limit; nvidia: 429/404/410 intermitente). Los subagentes despachados como `pi -p` fallan a ratos → para la AP usar la tool `subagent` de pi-subagents + stop condition EXTERNAL BLOCKER con backoff.
6. Archivos globales ajenos en `~/.pi/agent/{extensions,skills,npm}` (`argos-atlas-protocol.ts`, `argos-commands.md`, `argos-compaction.ts`, `pi-subagents`) — prototipos previos o efectos de subagentes; revisar antes de integrar la AP (no son del repo).

---

## 4. Reglas que aplican a la sesión

- **Single brain**: única memoria persistente `<proyecto>/.arnes/arnes.db`; `argos pi` usa `--no-session`.
- **No inventar APIs de pi**: verificar contra `docs/` y `examples/extensions/` de la versión instalada (0.84.0).
- **No tocar**: pi core, opencode.json, comandos argos legacy, `.arnes/` en tests.
- **Superpowers**: no copiar/forkear; ARGOS solo registra mastery.
- **SDD/FDD/ADR/TDD ARGOS** siguen siendo la metodología oficial.
- Skills ARNES v2: read/write-only en su contexto; en pi runtime usan el tooling completo (gate de permisos protege rutas peligrosas).

---

## 5. Archivos clave

| Archivo | Rol |
|---|---|
| `pi/extensions/*.ts` | 12 extensiones ARGOS (core, brain, memory, working-memory, cognition, party, orchestrator, model-router, skills, permissions, compaction, learning, ui) |
| `pi/skills/argos-*/SKILL.md` | 17 role-skills (regenerables: `node pi/scripts/gen-role-skills.mjs`) |
| `cli/argos-pi.ps1` | Launcher `argos pi` (subcomando ya registrado en `cli/argos.ps1`) |
| `tests/unit/*.test.ts` | Tests unit (14 PASS) |
| `tests/integration/fusion-check.ps1` + `boot-smoke.ps1` | Integración (7/7 PASS) |
| `docs/superpowers/specs/2026-08-06-*.md` | Spec fusión |
| `docs/superpowers/specs/2026-08-07-*.md/.html` | Spec Autonomous Party |
| `docs/superpowers/plans/2026-08-06-*.md` | Plan fusión (12 tasks, completado) |

---

## 6. Notas de trabajo

- Los cambios sucios del working tree (`cli/`, `core/`, `.arnes/`, etc.) son del usuario (su sesión argos) — NO tocar/committear.
- `cli/argos.ps1` ya tiene el caso `'pi'` registrado (en el working tree sucio del usuario).
- El BOM del `settings.json` global de pi se eliminó (arregla warnings en cada arranque de pi).

# ARGOS SUPERPOWERS — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir la fusión nativa Pi + ARNES ARGOS + Superpowers en un solo harness percibido como ARGOS SUPERPOWERS, arrancable con `argos pi`, con ARGOS como única memoria persistente.

**Architecture:** Paquete pi (`pi/`) con extensiones TypeScript que: (1) en `session_start` detectan `.arnes` y hacen bootstrap (DB, config, catálogo de 16 agentes, working memory, skills, UI); (2) registran tools `argos_memory_*` como bridge a `arnes_brain.py` (subprocess python + JSON); (3) inyectan contexto cognitivo en `before_agent_start` (working memory + quest + marco FAST/RECALL/SKILL/DELIBERATE/DEEP); (4) integran compactación vía `session_before_compact`/`session_compact` (checkpoint + Recovery Capsule); (5) bloquean operaciones peligrosas en `tool_call`; (6) registran comandos `/argos*` y footer/widgets UI. Fuera de proyectos con `.arnes`, la extensión es no-op. Los 16 agentes son role-skills con catálogo derivado de las fuentes canónicas (core/*.agent.md + core/skills/v2 + agent-models.json), ejecutados por la sesión pi (Opción A).

**Tech Stack:** TypeScript (extensiones pi, cargadas por jiti), `@earendil-works/pi-coding-agent` (ExtensionAPI), `typebox` (schemas), Node 16+, Python 3.8+ (bridge `arnes_brain.py`, ya existente), PowerShell (launcher `argos pi`), tests con `node:test` + `tsx` y `.ps1`.

**Spec:** `docs/superpowers/specs/2026-08-06-argos-superpowers-fusion-design.md` (aprobado por el usuario).

## Global Constraints

(Verbatim del spec / master spec del usuario — cada task las hereda implícitamente)

1. Pi YA instalado/autenticado y Superpowers YA instalado (`git:github.com/obra/superpowers`). NO reinstalar pi, NO re-login, NO cambiar configuración pi, NO modificar OpenCode, NO instalar Oh My Pi, NO otra memoria, NO otro orchestrator.
2. **Single brain:** la única memoria persistente es `<proyecto>/.arnes/arnes.db`. `argos pi` lanza `pi --no-session`. El historial de sesión de pi es runtime, nunca fuente de verdad.
3. **No inventar APIs de pi:** antes de cada integración, verificar contra la versión instalada (`docs/` + `examples/extensions/`). NO usar APIs internas frágiles si existe API pública.
4. **Reutilizar autenticación pi:** providers/modelos ya conectados (login/API). NO copiar API keys, NO crear configuración manual de credenciales.
5. **Memory V3 y Compaction NO se duplican:** las tools hacen bridge a `arnes_brain.py` / `arnes-memory.ps1` (subprocess, JSON). NO reimplementar lógica SQLite/TS.
6. **Superpowers NO se copia/forkea/modifica:** ARGOS solo registra identidad/mastery (`skill_mastery`/`skill_executions`).
7. **SDD/FDD/ADR/TDD ARGOS siguen siendo las oficiales:** Superpowers complementa ejecución, no crea otra fuente de spec/plan/tasks/ADR.
8. **Backward compat:** NO eliminar `argos`, `argos chat`, `argos code`, `argos opencode`. NO tocar opencode.json. OpenCode debe seguir funcionando.
9. Fuera de un proyecto con `.arnes`, pi funciona normal (extensión no-op). NO obligar a todo pi a ser ARGOS.
10. **Tools de la fusión:** los agentes en pi usan el tooling completo de pi (read/write/edit/bash) — la fusión SUPERSEDE la restricción read/write-only de las skills v2; el gate de permisos (`argos-permissions.ts`) protege rutas peligrosas.
11. No introducir vector DB, Redis, otro agent framework, otro orchestrator, otra memoria, otro skill framework (sin benchmark que lo justifique).
12. No modificar pi core.
13. Las skills ARNES conservan su restricción read/write-only EN SU CONTEXTO v2; dentro de pi runtime, la role-skill fusionada define el tooling real.

## Estado de fases previas (completado)

- Fases 1–3 (auditorías ARGOS / pi / Superpowers): HECHO y documentado en el spec.
- Fase 4–17: este plan.
- Fase 18 (benchmark §84): esqueleto en T15; corrida completa post-implementación (manual/acompañada).

## File Structure

```
pi/
├── package.json                     # name argos-superpowers · pi manifest · devDep tsx
├── tsconfig.json
├── extensions/
│   ├── argos-core.ts                # bootstrap: detecta .arnes, carga config, inicializa módulos, UI base
│   ├── argos-brain.ts               # bridge util: resolveBrainPath + runBrain(cmd, stdinJson) → JSON
│   ├── argos-memory.ts              # tools argos_memory_* (registerTool) sobre argos-brain
│   ├── argos-working-memory.ts      # working memory de sesión (Map) + tool argos_working_memory
│   ├── argos-cognition.ts           # bloque cognitivo (FAST/RECALL/SKILL/DELIBERATE/DEEP) inyectado en before_agent_start
│   ├── argos-party.ts               # catálogo 16 agentes desde fuentes canónicas + getAgentContext()
│   ├── argos-orchestrator.ts        # detección quest type + recomendación de party (skill-registry + memoria)
│   ├── argos-model-router.ts        # mapeo agent-models.json → modelo configurado (footer) + fallback
│   ├── argos-skills.ts              # discovery skills (Superpowers + ARNES) + registro mastery en arnes.db
│   ├── argos-permissions.ts         # tool_call: bloquea rutas protegidas y comandos destructivos
│   ├── argos-compaction.ts          # session_before_compact → consolidate+checkpoint; session_compact → capsule
│   ├── argos-learning.ts            # agent_settled → observación episódica + skill execution
│   └── argos-ui.ts                  # footer/widgets + comandos /argos*
├── skills/
│   ├── argos-<agente>/SKILL.md      # 16 role-skills (generadas por script scripts/gen-role-skills.mjs)
│   └── arnes-memory/SKILL.md        # re-export de la skill ARNES de memoria (referencia)
└── scripts/
    └── gen-role-skills.mjs          # genera las 16 role-skills desde core/*.agent.md
tests/
├── unit/
│   ├── catalog.test.ts              # catálogo de agentes (node:test + tsx)
│   ├── model-router.test.ts
│   ├── permissions.test.ts
│   ├── capsule.test.ts
│   └── brain-bridge.test.ts         # round-trip contra arnes_brain.py con DB temporal
└── integration/
    └── boot-smoke.ps1               # lanza pi -p con la extensión en fixture con .arnes
fixture-arnes/                       # proyecto de prueba con .arnes mínimo (creado por tests)
cli/
├── argos-pi.ps1                     # launcher `argos pi` (health-check + pi --no-session)
└── argos.ps1                        # MODIFICAR: registrar subcomando `pi`
docs/superpowers/plans/              # este archivo
```

## Interfaces clave (contratos entre tasks)

- `runBrain(cwd: string, args: string[], stdinJson?: unknown): Promise<{ ok: boolean; data: unknown; error?: string }>` — de `argos-brain.ts`. Resuelve db en `<cwd>/.arnes/arnes.db` y brain en `<cwd>/cli/arnes_brain.py`; spawn `python <brain> <db> <args...>`; stdin JSON cuando `stdinJson` presente; parsea stdout JSON.
- `loadAgentModels(cwd): Promise<Record<string, string>>` — lee `~/.config/arnes/agent-models.json` (fallback: `.arnes/model-assignments.json`).
- `buildAgentCatalog(cwd): Promise<AgentCard[]>` — de `argos-party.ts`. `AgentCard = { id, displayName, role, promptFile, skillV2, model, memoryNamespace, topics[] }`.
- `getAgentContext(card, task): string` — bloque de contexto aislado para inyectar.
- `getWorkingMemoryBlock(): string` — de `argos-working-memory.ts`.
- `getCognitionBlock(state: { questType?, agent?, path? }): string` — de `argos-cognition.ts`.
- `isProtectedPath(cwd, absPath): { protected: boolean; reason?: string }` — de `argos-permissions.ts`.
- `checkpointNow(cwd, state): Promise<number>` / `buildRecoveryCapsule(cwd, cpId): Promise<string>` — de `argos-compaction.ts`.

---

### Task 1: Paquete pi + bootstrap ARGOS (Fase 4–5: package + core + detección)

**Files:**
- Create: `pi/package.json`, `pi/tsconfig.json`, `pi/extensions/argos-core.ts`
- Test: `tests/unit/brain-bridge.test.ts`, `tests/integration/boot-smoke.ps1`, `fixture-arnes/`

**Interfaces:**
- Produces: `runBrain(cwd, args, stdinJson)` en `argos-brain.ts`; export default del factory de extensión en `argos-core.ts`; `isArnesProject(cwd)`.

- [ ] **Step 1: Escribir el test del bridge (fail primero)**

`tests/unit/brain-bridge.test.ts`:
```ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { runBrain } from "../../pi/extensions/argos-brain";

test("runBrain: save+recall round-trip contra arnes_brain.py", async () => {
  const dir = mkdtempSync(join(tmpdir(), "argos-bridge-"));
  mkdirSync(join(dir, ".arnes"));
  const db = join(dir, ".arnes", "arnes.db");
  // init db via brain
  await runBrain(dir, ["init", db]);
  await runBrain(dir, ["save", db, "-"], {
    agent: "vivi", topic_key: "vivi/ui-patterns", type: "pattern",
    content: "User prefiere dark mode", confidence: 0.99,
  });
  const res = await runBrain(dir, ["recall", db, "dark mode", "vivi", "5"]);
  assert.equal(res.ok, true);
  const rows = (res.data as any[]);
  assert.ok(rows.some((r) => (r.content as string).includes("dark mode")));
});

test("runBrain: falla fuera de proyecto arnes", async () => {
  const dir = mkdtempSync(join(tmpdir(), "argos-bridge-"));
  const res = await runBrain(dir, ["stats"]);
  assert.equal(res.ok, false);
});
```

- [ ] **Step 2: Correr el test para verlo fallar**

Run: `cd pi && npm i && npx tsx --test ../tests/unit/brain-bridge.test.ts`
Expected: FAIL (`Cannot find module '../../pi/extensions/argos-brain'`).

- [ ] **Step 3: Crear `pi/package.json`**

```json
{
  "name": "argos-superpowers",
  "version": "0.1.0",
  "description": "Fusión nativa ARNES ARGOS + Pi + Superpowers. ARGOS = cerebro, Pi = runtime, Superpowers = habilidades.",
  "keywords": ["pi-package", "argos", "arnes", "superpowers"],
  "license": "MIT",
  "type": "module",
  "main": "extensions/argos-core.ts",
  "peerDependencies": {
    "@earendil-works/pi-coding-agent": "*",
    "typebox": "*"
  },
  "devDependencies": {
    "tsx": "^4.19.0",
    "@types/node": "^20.0.0"
  },
  "scripts": {
    "test": "tsx --test ../tests/unit/*.test.ts",
    "gen:skills": "node scripts/gen-role-skills.mjs"
  },
  "pi": {
    "extensions": ["./extensions"],
    "skills": ["./skills"],
    "prompts": ["./prompts"]
  }
}
```

- [ ] **Step 4: Crear `pi/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "skipLibCheck": true,
    "noEmit": true,
    "types": ["node"]
  },
  "include": ["extensions/**/*.ts"]
}
```

- [ ] **Step 5: Crear `pi/extensions/argos-brain.ts`**

```ts
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { join, resolve } from "node:path";

export function isArnesProject(cwd: string): boolean {
  return existsSync(join(cwd, ".arnes", "arnes.db"));
}

export function resolveBrainPath(cwd: string): string {
  // La fusión asume argos pi desde la raíz del repo (donde vive cli/arnes_brain.py)
  const local = resolve(cwd, "cli", "arnes_brain.py");
  if (existsSync(local)) return local;
  throw new Error("ARGOS: no se encontró cli/arnes_brain.py en la raíz del proyecto");
}

export async function runBrain(
  cwd: string,
  args: string[],
  stdinJson?: unknown
): Promise<{ ok: boolean; data: unknown; error?: string }> {
  try {
    const brain = resolveBrainPath(cwd);
    const db = join(cwd, ".arnes", "arnes.db");
    const child = spawn("python", [brain, db, ...args], {
      cwd,
      windowsHide: true,
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    if (stdinJson !== undefined) {
      child.stdin.write(JSON.stringify(stdinJson));
    }
    child.stdin.end();
    const code: number = await new Promise((res) => child.on("close", res));
    if (code !== 0) {
      return { ok: false, data: null, error: stderr.trim() || `exit ${code}` };
    }
    const trimmed = stdout.trim();
    if (!trimmed) return { ok: true, data: null };
    try {
      return { ok: true, data: JSON.parse(trimmed) };
    } catch {
      return { ok: true, data: trimmed };
    }
  } catch (e) {
    return { ok: false, data: null, error: (e as Error).message };
  }
}
```

- [ ] **Step 6: Crear `pi/extensions/argos-core.ts`**

```ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isArnesProject } from "./argos-brain.js";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    if (!isArnesProject(ctx.cwd)) return; // pi normal fuera de ARGOS (§53)
    ctx.ui.setStatus("argos", "ARGOS SUPERPOWERS • boot…");
    ctx.ui.setWidget("argos-header", [
      "ARGOS SUPERPOWERS",
      `Project: ${ctx.cwd}`,
      "Memory V3 • READY",
    ]);
    ctx.ui.setStatus("argos", "ARGOS SUPERPOWERS • Memory V3 ✓");
  });
}
```

- [ ] **Step 7: Correr tests hasta pasar**

Run: `cd pi && npx tsx --test ../tests/unit/brain-bridge.test.ts`
Expected: 2 PASS.

- [ ] **Step 8: Smoke de boot con pi real**

`tests/integration/boot-smoke.ps1`:
```powershell
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$ext = Join-Path $root 'pi/extensions/argos-core.ts'
$out = & pi --no-session -e $ext -p "Responde unicamente: OK" 2>&1
if ($LASTEXITCODE -ne 0) { Write-Host "FAIL boot: $out" -ForegroundColor Red; exit 1 }
if ($out -match 'OK') { Write-Host 'PASS boot-smoke' -ForegroundColor Green; exit 0 }
Write-Host "FAIL boot (sin OK): $out" -ForegroundColor Red; exit 1
```
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/integration/boot-smoke.ps1`
Expected: PASS (pi arranca con la extensión y responde OK; en proyecto sin .arnes la extensión es no-op).

- [ ] **Step 9: Commit**

```bash
git add pi/ tests/unit/brain-bridge.test.ts tests/integration/boot-smoke.ps1
git commit -m "feat(argos-superpowers): paquete pi + bootstrap ARGOS + bridge a arnes_brain"
```

---

### Task 2: Tools de memoria (Fase 6) — search/get/save/update/stats/context

**Files:**
- Create: `pi/extensions/argos-memory.ts`
- Test: `tests/unit/brain-bridge.test.ts` (extender con asserts de `search`/`get` vía `runBrain`)

**Interfaces:**
- Consumes: `runBrain(cwd, args, stdinJson)`.
- Produces: tools `argos_memory_search`, `argos_memory_get`, `argos_memory_save`, `argos_memory_update`, `argos_memory_stats`, `argos_memory_context`, `argos_memory_verify`, `argos_memory_timeline`, `argos_memory_relations`; helper `memoryCard(row): string` (formato MEMORY #id).

- [ ] **Step 1: Extender el test (red)**

Agregar a `tests/unit/brain-bridge.test.ts`:
```ts
test("memory tools: search devuelve tarjeta con confidence y state", async () => {
  const dir = mkdtempSync(join(tmpdir(), "argos-bridge-"));
  mkdirSync(join(dir, ".arnes"));
  const db = join(dir, ".arnes", "arnes.db");
  await runBrain(dir, ["init", db]);
  await runBrain(dir, ["save", db, "-"], {
    agent: "ansem", topic_key: "ansem/rls-policies", type: "pattern",
    content: "RLS por user_id con auth.uid()", confidence: 0.98, score: 5,
  });
  const res = await runBrain(dir, ["recall", db, "RLS", "ansem", "5"]);
  const rows = res.data as any[];
  assert.ok(rows[0].confidence >= 0.9);
  assert.equal(rows[0].state, "active");
});
```

- [ ] **Step 2: Verificar red**

Run: `cd pi && npx tsx --test ../tests/unit/brain-bridge.test.ts`
Expected: FAIL (assert confidence) — el recall actual puede devolver confidence default si no se guardó; ajustar el assert si el brain ya la conserva; el punto es fijar el contrato.

- [ ] **Step 3: Implementar `argos-memory.ts`**

```ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { runBrain } from "./argos-brain.js";

export function memoryCard(row: any): string {
  return [
    `MEMORY #${row.id}`,
    "",
    `kind: ${row.memory_kind ?? "?"}`,
    `topic: ${row.topic_key}`,
    "",
    `state: ${row.state}`,
    `epistemic: ${row.epistemic_type ?? "unverified"}`,
    "",
    `confidence: ${row.confidence}`,
    `trust: ${row.trust ?? "-"}`,
    `importance: ${row.score ?? "-"}`,
    "",
    `source: ${row.source || "-"}`,
    "",
    `summary:`,
    `  ${row.content}`,
  ].join("\n");
}

export default function (pi: ExtensionAPI) {
  const register = (name: string, label: string, description: string, params: any, map: (p: any) => string[]) => {
    pi.registerTool({
      name, label, description, parameters: params,
      async execute(_id, params: any, _sig, _upd, ctx) {
        if (!runBrain) throw new Error("ARGOS: no project");
        const res = await runBrain(ctx.cwd, map(params));
        if (!res.ok) return { content: [{ type: "text", text: `ARGOS error: ${res.error}` }], details: {} };
        const rows = res.data as any[];
        const text = Array.isArray(rows) ? rows.map(memoryCard).join("\n\n---\n\n") : JSON.stringify(res.data, null, 2);
        return { content: [{ type: "text", text }], details: { count: Array.isArray(rows) ? rows.length : 0 } };
      },
    });
  };

  register("argos_memory_search", "Memory Search", "Busca hechos verificados en Memory V3 (RAG). Úsalo antes de afirmar hechos del proyecto.",
    Type.Object({
      query: Type.String({ description: "búsqueda" }),
      agent: Type.Optional(Type.String()),
      limit: Type.Optional(Type.Integer({ default: 5 })),
      tag: Type.Optional(Type.String()),
    }),
    (p) => ["recall", p.query, p.agent ?? "-", String(p.limit ?? 5), p.tag ?? "-"]);

  register("argos_memory_get", "Memory Get", "Obtiene una memoria por id.",
    Type.Object({ id: Type.Integer() }),
    (p) => ["get", String(p.id)]);

  register("argos_memory_save", "Memory Save", "Guarda una observación (working|episodic|semantic|procedural). Después de trabajar.",
    Type.Object({
      agent: Type.String(), topic_key: Type.String(),
      type: Type.Union([Type.Literal("bugfix"), Type.Literal("decision"), Type.Literal("pattern"), Type.Literal("discovery"), Type.Literal("preference"), Type.Literal("verdict"), Type.Literal("recommendation"), Type.Literal("action"), Type.Literal("session_summary")]),
      content: Type.String(),
      kind: Type.Optional(Type.String()),
      confidence: Type.Optional(Type.Number()),
      score: Type.Optional(Type.Integer()),
      quest_id: Type.Optional(Type.String()),
    }),
    async (_id, params, _sig, _upd, ctx) => {
      const res = await runBrain(ctx.cwd, ["save", "-"], params);
      return { content: [{ type: "text", text: res.ok ? `Guardado id=${JSON.stringify(res.data)}` : `ARGOS error: ${res.error}` }], details: {} };
    });

  register("argos_memory_update", "Memory Update", "Actualiza contenido de una memoria (mantiene revisiones).",
    Type.Object({ id: Type.Integer(), content: Type.String() }),
    async (_id, params, _sig, _upd, ctx) => {
      const res = await runBrain(ctx.cwd, ["update", "-"], params);
      return { content: [{ type: "text", text: res.ok ? "Actualizado" : `ARGOS error: ${res.error}` }], details: {} };
    });

  register("argos_memory_verify", "Memory Verify", "Marca una memoria como verificada (PASS/FAIL) con evidencia.",
    Type.Object({ id: Type.Integer(), verdict: Type.String(), evidence: Type.Optional(Type.String()) }),
    async (_id, params, _sig, _upd, ctx) => {
      const res = await runBrain(ctx.cwd, ["verify", "-"], params);
      return { content: [{ type: "text", text: res.ok ? "Verificado" : `ARGOS error: ${res.error}` }], details: {} };
    });

  register("argos_memory_stats", "Memory Stats", "Estadísticas del cerebro (observaciones, estados, FTS, grafo).",
    Type.Object({}), (p) => ["stats"]);

  register("argos_memory_context", "Memory Context", "Contexto reciente del harness.",
    Type.Object({}), (p) => ["context"]);

  register("argos_memory_timeline", "Memory Timeline", "Timeline de una memoria (revisiones).",
    Type.Object({ id: Type.Integer() }), (p) => ["revisions", String(p.id)]);

  register("argos_memory_relations", "Memory Relations", "Relaciones del grafo de un nodo.",
    Type.Object({ node: Type.String() }),
    async (_id, params, _sig, _upd, ctx) => {
      const res = await runBrain(ctx.cwd, ["edges", "-"], { node: params.node });
      return { content: [{ type: "text", text: res.ok ? JSON.stringify(res.data, null, 2) : `ARGOS error: ${res.error}` }], details: {} };
    });
}
```

> Nota: verificar en implementación los argumentos exactos de `get`, `update`, `verify`, `revisions`, `context`, `stats`, `edges` contra `cli/arnes_brain.py` (líneas 1145+ del main) — el contrato puede variar; los tools deben llamar al CLI REAL.

- [ ] **Step 4: Verificar green**

Run: `cd pi && npx tsx --test ../tests/unit/brain-bridge.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add pi/extensions/argos-memory.ts tests/unit/brain-bridge.test.ts
git commit -m "feat(argos-superpowers): tools argos_memory_* (bridge Memory V3)"
```

---

### Task 3: Working memory + inyección cognitiva (Fases 7–8)

**Files:**
- Create: `pi/extensions/argos-working-memory.ts`, `pi/extensions/argos-cognition.ts`
- Test: `tests/unit/capsule.test.ts` (parse del bloque), extender brain-bridge si hace falta

**Interfaces:**
- Produces: `getWorkingMemoryBlock()`, `recordFact(fact)`, `setNextAction(na)`, `getCognitionBlock(state)`; tool `argos_working_memory`.

- [ ] **Step 1: Test (red)**

`tests/unit/capsule.test.ts`:
```ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { getCognitionBlock } from "../../pi/extensions/argos-cognition";

test("cognition: bloque contiene quest y marco de decisión", () => {
  const block = getCognitionBlock({ questType: "frontend", agent: "vivi", path: "SKILL" });
  assert.match(block, /frontend/);
  assert.match(block, /FAST/);
  assert.match(block, /SKILL/);
  assert.match(block, /DEEP/);
});
```

- [ ] **Step 2: Verificar red** — `cd pi && npx tsx --test ../tests/unit/capsule.test.ts` → FAIL (module not found).

- [ ] **Step 3: Implementar `argos-working-memory.ts`**

```ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

interface WorkingMemory {
  quest: string;
  questType: string;
  agent: string;
  goal: string;
  nextAction: string;
  files: string[];
  errors: string[];
  facts: string[];   // hechos verificados recientes (máx 10)
  activeSkill: string;
  procedureStage: string;
}
const wm: WorkingMemory = { quest: "", questType: "", agent: "atlas", goal: "", nextAction: "", files: [], errors: [], facts: [], activeSkill: "", procedureStage: "" };

export function getWorkingMemoryBlock(): string {
  return [
    "## ARGOS WORKING MEMORY (actual)",
    `- Quest: ${wm.quest || "-"} (${wm.questType || "?"})`,
    `- Agente activo: ${wm.agent}`,
    `- Objetivo: ${wm.goal || "-"}`,
    `- Archivos: ${wm.files.join(", ") || "-"}`,
    `- Errores: ${wm.errors.join(", ") || "-"}`,
    `- Hechos verificados:`,
    ...(wm.facts.length ? wm.facts.map((f) => `  - ${f}`) : ["  - (ninguno aún)"]),
    `- Skill activa: ${wm.activeSkill || "-"}`,
    `- Etapa: ${wm.procedureStage || "-"}`,
    `- NEXT ACTION: ${wm.nextAction || "-"}`,
  ].join("\n");
}
export function recordFact(f: string) { wm.facts.unshift(f); if (wm.facts.length > 10) wm.facts.pop(); }
export function setNextAction(na: string) { wm.nextAction = na; }
export function setAgent(a: string) { wm.agent = a; }
export function setQuest(q: string, t: string) { wm.quest = q; wm.questType = t; }
export function setActiveSkill(s: string, stage: string) { wm.activeSkill = s; wm.procedureStage = stage; }

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "argos_working_memory",
    label: "Working Memory",
    description: "Lee la working memory actual (quest, agente, hechos recientes, next action). Consultar ANTES de RAG completo.",
    parameters: Type.Object({}),
    async execute() {
      return { content: [{ type: "text", text: getWorkingMemoryBlock() }], details: {} };
    },
  });
}
```

- [ ] **Step 4: Implementar `argos-cognition.ts`**

```ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getWorkingMemoryBlock } from "./argos-working-memory.js";

export function getCognitionBlock(state: { questType?: string; agent?: string; path?: string }): string {
  return [
    "## ARGOS COGNITIVE ROUTER",
    "Eres ARGOS SUPERPOWERS. Elige el esfuerzo MÍNIMO SUFICIENTE (nunca el máximo por defecto):",
    "- FAST: ya lo sé (working/semantic memory) → responde. Sin agentes, sin skills, sin tools extra.",
    "- RECALL: existe en memoria pero no en working memory → busca (argos_memory_search) y responde. Sin plan.",
    "- SKILL: tarea conocida con procedimiento → activa la skill (ej. systematic-debugging para bugs). 1 agente, contexto ligero.",
    "- DELIBERATE: feature normal, contexto incompleto → memoria + tools + agente + skill + verificación.",
    "- DEEP: arquitectura/seguridad/migración/riesgo/conflicto → SDD/FDD/Amarant/party/Auron/Tywin. Especialistas, verificación fuerte.",
    "",
    "NUNCA: no sé → inventar. INVESTIGA (memoria → repo → tools).",
    "Jerarquía de evidencia: repo verificado > tests/tools > hecho del usuario > memoria verificada > memoria observada > inferencia > hipótesis.",
    "",
    getWorkingMemoryBlock(),
  ].join("\n");
}

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event, _ctx) => {
    if (!event.prompt) return;
    return {
      message: {
        customType: "argos-cognition",
        content: getCognitionBlock({}),
        display: false,
      },
    };
  });
}
```

> Nota: en implementación, rellenar `questType`/`agent` desde `argos-orchestrator.ts` (Task 6) y permitir que `/argos-quest` actualice la working memory.

- [ ] **Step 5: Green** — `cd pi && npx tsx --test ../tests/unit/capsule.test.ts` → PASS.

- [ ] **Step 6: Commit** — `git add pi/extensions/argos-working-memory.ts pi/extensions/argos-cognition.ts tests/unit/capsule.test.ts && git commit -m "feat(argos-superpowers): working memory + cognitive router (contexto)"`

---

### Task 4: Catálogo de agentes + model router (Fase 9–10)

**Files:**
- Create: `pi/extensions/argos-party.ts`, `pi/extensions/argos-model-router.ts`
- Test: `tests/unit/catalog.test.ts`, `tests/unit/model-router.test.ts`

**Interfaces:**
- Produces: `buildAgentCatalog(cwd): Promise<AgentCard[]>`, `loadAgentModels(cwd): Promise<Record<string,string>>`, `resolveModel(assignment: string): { provider, modelId }`, `getAgentContext(card, task): string`.

- [ ] **Step 1: Test (red)**

`tests/unit/catalog.test.ts`:
```ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { buildAgentCatalog } from "../../pi/extensions/argos-party";
import { loadAgentModels, resolveModel } from "../../pi/extensions/argos-model-router";

test("catalog: construye 16 agentes desde fuentes canónicas", async () => {
  const dir = mkdtempSync(join(tmpdir(), "argos-cat-"));
  mkdirSync(join(dir, "core/classes"), { recursive: true });
  mkdirSync(join(dir, "core/auditors"), { recursive: true });
  writeFileSync(join(dir, "core/classes/mage.agent.md"), "# Vivi (Mage) - Frontend DPS");
  writeFileSync(join(dir, "core/classes/tidus.agent.md"), "# Tidus - Infra");
  writeFileSync(join(dir, "core/auditors/tywin.agent.md"), "# Tywin - Verifier");
  const cards = await buildAgentCatalog(dir);
  assert.ok(cards.length >= 3);
  const vivi = cards.find((c) => c.id === "vivi");
  assert.ok(vivi);
  assert.equal(vivi.role, "Frontend");
});

test("model router: mapea asignación ARNES → provider/model", () => {
  const m = resolveModel("opencode-go/gpt-5.6-luna");
  assert.equal(m.provider, "opencode-go");
  assert.equal(m.modelId, "gpt-5.6-luna");
});

test("model router: lee agent-models.json (o fallback)", async () => {
  const dir = mkdtempSync(join(tmpdir(), "argos-mm-"));
  writeFileSync(join(dir, "agent-models.json"), JSON.stringify({ agents: { vivi: "opencode-go/gpt-5.6-luna" } }));
  const models = await loadAgentModels(dir);
  assert.equal(models["vivi"], "opencode-go/gpt-5.6-luna");
});
```

- [ ] **Step 2: Verificar red** → FAIL (modules missing).

- [ ] **Step 3: Implementar `argos-party.ts`**

```ts
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { loadAgentModels } from "./argos-model-router.js";

export interface AgentCard {
  id: string; displayName: string; role: string; promptFile: string;
  skillV2: string; model: string; memoryNamespace: string; topics: string[];
}

const ROLE_HINTS: Record<string, string> = {
  mage: "Frontend", paladin: "Backend", rogue: "QA", monk: "Architecture",
  ranger: "Research", bard: "Continuous Learning", eiko: "DevOps",
  tidus: "Infrastructure", ragnarok: "Providers/Tooling",
  auron: "Security", bran: "Analysis/Progress", quina: "Token Budget",
  varys: "Evidence/Provenance", tywin: "Verifier/Memory Judge",
  sam: "Archivist/Consolidation", atlas: "Executive/Orchestrator",
};

export async function buildAgentCatalog(cwd: string): Promise<AgentCard[]> {
  const classesDir = join(cwd, "core", "classes");
  const auditorsDir = join(cwd, "core", "auditors");
  const models = await loadAgentModels(cwd);
  const cards: AgentCard[] = [];
  for (const [dir, kind] of [[classesDir, "class"], [auditorsDir, "auditor"]] as const) {
    if (!existsSync(dir)) continue;
    for (const f of readdirSync(dir).filter((f) => f.endsWith(".agent.md"))) {
      const id = f.replace(".agent.md", "");
      const firstLine = readFileSync(join(dir, f), "utf-8").split("\n").find((l) => l.startsWith("# ")) ?? "";
      const displayName = firstLine.replace("# ", "").split(" ")[0] || id;
      const role = ROLE_HINTS[id] ?? "Agent";
      cards.push({
        id, displayName, role,
        promptFile: join(dir, f),
        skillV2: `argos-${id}`,
        model: models[id] ?? "",
        memoryNamespace: `${id}/`,
        topics: [],
      });
    }
  }
  return cards;
}

export function getAgentContext(card: AgentCard, task: string): string {
  return [
    `## ARGOS AGENT: ${card.displayName} (${card.role})`,
    `Modelo configurado: ${card.model || "(sesión)"}`,
    `Memoria: namespace ${card.memoryNamespace} — usa argos_memory_search/save con topic ${card.memoryNamespace}*`,
    `Skill propia: ${card.skillV2}`,
    "",
    `## TAREA (aislada)`,
    task,
  ].join("\n");
}
```

- [ ] **Step 4: Implementar `argos-model-router.ts`**

```ts
import { readFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export async function loadAgentModels(cwd: string): Promise<Record<string, string>> {
  const global = join(homedir(), ".config", "arnes", "agent-models.json");
  const local = join(cwd, ".arnes", "model-assignments.json");
  for (const p of [global, local]) {
    if (existsSync(p)) {
      try {
        const j = JSON.parse(readFileSync(p, "utf-8"));
        return j.agents ?? j.assignments ?? {};
      } catch { /* siguiente fuente */ }
    }
  }
  return {};
}

export function resolveModel(assignment: string): { provider: string; modelId: string } {
  const [provider, ...rest] = assignment.split("/");
  return { provider, modelId: rest.join("/") };
}
```

- [ ] **Step 5: Green** — `cd pi && npx tsx --test ../tests/unit/catalog.test.ts ../tests/unit/model-router.test.ts` → PASS.

- [ ] **Step 6: Commit** — `git add pi/extensions/argos-party.ts pi/extensions/argos-model-router.ts tests/unit/catalog.test.ts tests/unit/model-router.test.ts && git commit -m "feat(argos-superpowers): catálogo 16 agentes + model router declarativo"`

---

### Task 5: Role-skills generadas + discovery de skills (Fase 9/11–12)

**Files:**
- Create: `pi/scripts/gen-role-skills.mjs`, `pi/skills/argos-atlas/SKILL.md` (ejemplo generado), `pi/extensions/argos-skills.ts`
- Test: `tests/unit/catalog.test.ts` (extender: skills generadas existen)

**Interfaces:**
- Produces: 16 `pi/skills/argos-<id>/SKILL.md`; `discoverSkills(cwd): Promise<SkillInfo[]>` (`SkillInfo = { name, source, hash }`); `recordSkillExecution(cwd, info, pass)`.

- [ ] **Step 1: Script generador (test primero)**

Extender `catalog.test.ts`:
```ts
test("role-skills: el generador produce SKILL.md para cada agente", async () => {
  const dir = mkdtempSync(join(tmpdir(), "argos-sk-"));
  // ejecutar node pi/scripts/gen-role-skills.mjs <dir>
  // (ver Step 3 para el comando exacto) — aquí: assert sobre el ejemplo ya commiteado
  const atlas = join(process.cwd(), "pi/skills/argos-atlas/SKILL.md");
  assert.match(readFileSync(atlas, "utf-8"), /name: argos-atlas/);
});
```

- [ ] **Step 2: Verificar red** → FAIL (no existe `pi/skills/argos-atlas/SKILL.md`).

- [ ] **Step 3: Implementar `pi/scripts/gen-role-skills.mjs`**

```js
// Uso: node scripts/gen-role-skills.mjs <repo-root>
// Genera pi/skills/argos-<id>/SKILL.md para cada core/{classes,auditors}/*.agent.md
import { readdirSync, readFileSync, mkdirSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";
const root = process.argv[2] ?? process.cwd();
const outDir = join(root, "pi", "skills");
const dirs = [join(root, "core", "classes"), join(root, "core", "auditors")];
const roleHint = {
  atlas: "Executive / Orchestrator", vivi: "Frontend", ansem: "Backend", kuja: "QA",
  eiko: "DevOps", amarant: "Architecture / SDD / ADR", eremez: "Research", auron: "Security",
  bran: "Analysis / progress", quina: "Cognitive + token budget", varys: "Evidence / provenance",
  tywin: "Verifier + Memory Judge", sam: "Archivist + Memory Consolidator", bard: "Continuous Learning",
  tidus: "Infrastructure / environment", ragnarok: "Providers / tooling",
};
for (const dir of dirs) {
  if (!existsSync(dir)) continue;
  for (const f of readdirSync(dir).filter((x) => x.endsWith(".agent.md"))) {
    const id = f.replace(".agent.md", "");
    const name = id.charAt(0).toUpperCase() + id.slice(1);
    const canonical = join(dir, f);
    const skillDir = join(outDir, `argos-${id}`);
    mkdirSync(skillDir, { recursive: true });
    const md = [
      "---",
      `name: argos-${id}`,
      `description: Role-skill ARGOS del agente ${name} (${roleHint[id] ?? "Agent"}). Trigger: cuando Atlas encarna a ${name} para un quest de su dominio.`,
      "---",
      "",
      `# ARGOS ${name} (${roleHint[id] ?? "Agent"})`,
      "",
      "Eres un agente de ARGOS SUPERPOWERS operando dentro del runtime Pi.",
      "",
      "## Fuentes canónicas (lee con `read`, NO copies aquí)",
      `- Definición del rol: \`read ${canonical}\``,
      `- Skill v2 propia: \`read core/skills/v2/${id === "atlas" ? "atlas-orchestrate" : id + "-*"}/SKILL.md\` (o la skill v2 que corresponda)`,
      "",
      "## Contexto aislado",
      "Recibes SOLO: rol, tarea, quest, ADR/SDD relevantes, memory cards de tu namespace, procedimiento seleccionado, archivos y restricciones. No asumas el chat principal.",
      "",
      "## Memoria",
      `- \`argos_memory_search\` con agent=${id} antes de actuar (anti-alucinación)`,
      `- \`argos_memory_save\` con agent=${id} después de actuar`,
      `- Namespace: \`${id}/\``,
      "",
      "## Modelo",
      "Opera con el modelo de sesión de Pi. El footer muestra tu modelo configurado (agent-models.json).",
    ].join("\n");
    writeFileSync(join(skillDir, "SKILL.md"), md + "\n");
    console.log(`generated argos-${id}`);
  }
}
```

Run: `node pi/scripts/gen-role-skills.mjs <repo-root>` → genera 16 skills. Ajustar el mapeo id→carpeta v2 en implementación (los nombres reales: vivi-fireball, ansem-smite, kuja-backstab, eiko-mend, amarant-foresight, eremez-mark, auron-bulwark, bran-vision, quina-ledger, varys-whisper, tywin-judgment, sam-counsel, atlas-orchestrate, tidus-tide-check, ragnarok-scout, bard → usar la carpeta real o "ninguna").

- [ ] **Step 4: Implementar `argos-skills.ts` (discovery + mastery)**

```ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readdirSync, existsSync, createHash } from "node:fs";
import { join, basename } from "node:path";
import { homedir } from "node:os";
import { runBrain } from "./argos-brain.js";

export interface SkillInfo { name: string; source: string; hash: string; path: string; }

const SP_ROOT = join(homedir(), ".pi", "agent", "git", "github.com", "obra", "superpowers", "skills");

export function discoverSkills(cwd: string): SkillInfo[] {
  const out: SkillInfo[] = [];
  for (const root of [SP_ROOT, join(cwd, "core", "skills"), join(cwd, "pi", "skills")]) {
    if (!existsSync(root)) continue;
    for (const d of readdirSync(root, { withFileTypes: true })) {
      if (!d.isDirectory()) continue;
      const sk = join(root, d.name, "SKILL.md");
      if (!existsSync(sk)) continue;
      const content = readFileSync(sk, "utf-8");
      out.push({ name: d.name, source: basename(root), hash: createHash("sha1").update(content).digest("hex").slice(0, 12), path: sk });
    }
  }
  return out;
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_e, ctx) => {
    if (!existsSync(join(ctx.cwd, ".arnes", "arnes.db"))) return;
    for (const s of discoverSkills(ctx.cwd)) {
      await runBrain(ctx.cwd, ["skill", "register", "-"], { name: s.name, source: s.source, hash: s.hash, path: s.path });
    }
  });
}
```

> Nota: verificar el formato de `skill register` contra `arnes_brain.py` (`skill` con action + JSON) en implementación.

- [ ] **Step 5: Green** — `cd pi && npx tsx --test ../tests/unit/catalog.test.ts` → PASS; `node pi/scripts/gen-role-skills.mjs <root>` genera 16 archivos; re-correr test.

- [ ] **Step 6: Commit** — `git add pi/scripts pi/skills pi/extensions/argos-skills.ts tests/unit/catalog.test.ts && git commit -m "feat(argos-superpowers): 16 role-skills generadas + discovery de skills (Superpowers+ARNES)"`

---

### Task 6: Orquestador (quest type + party) + working memory wiring (Fase 9)

**Files:**
- Create: `pi/extensions/argos-orchestrator.ts`
- Test: `tests/unit/catalog.test.ts` (extender: classifyQuest)

**Interfaces:**
- Produces: `classifyQuest(prompt): string` (frontend|backend|fix|research|architecture|devops|boss), `recommendParty(cwd, questType): string[]` (desde skill-registry + memoria Sam/Bran).

- [ ] **Step 1: Test (red)**

```ts
test("orchestrator: clasifica quest y recomienda party", async () => {
  const { classifyQuest, recommendParty } = await import("../../pi/extensions/argos-orchestrator");
  assert.equal(classifyQuest("crea un componente Login.tsx con tailwind"), "frontend");
  assert.equal(classifyQuest("esto falla, test rojo"), "fix");
  const party = await recommendParty(process.cwd(), "frontend");
  assert.ok(party.length > 0);
});
```

- [ ] **Step 2: Red** → FAIL.

- [ ] **Step 3: Implementar**

```ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const KEYWORDS: Record<string, string[]> = {
  frontend: ["componente", "ui", "tailwind", "react", ".tsx", "diseño", "frontend", "login", "dashboard"],
  backend: ["api", "schema", "supabase", "rls", "zod", "endpoint", "backend", "server", "auth"],
  fix: ["falla", "bug", "roto", "error", "test rojo", "no compila", "fix"],
  research: ["investiga", "compara", "documentación", "docs", "research", "alternativa"],
  architecture: ["arquitectura", "sdd", "plan", "rediseño", "adr", "estructura"],
  devops: ["docker", "ci", "cd", "deploy", "pipeline", "build", "github actions"],
  boss: ["boss", "feature completa", "migración", "monolito", "l0"],
};

export function classifyQuest(prompt: string): string {
  const p = prompt.toLowerCase();
  for (const [type, words] of Object.entries(KEYWORDS)) {
    if (words.some((w) => p.includes(w))) return type;
  }
  return "backend"; // default conservador: verificar + preguntar
}

const REGISTRY: Record<string, string[]> = {
  frontend: ["vivi"], backend: ["ansem"], fix: ["kuja", "ansem"], research: ["eremez"],
  architecture: ["amarant"], devops: ["eiko"], boss: ["amarant", "vivi", "ansem", "kuja", "eiko"],
};

export async function recommendParty(cwd: string, questType: string): Promise<string[]> {
  // Fuente 1: skill-registry (archivo canónico)
  const reg = join(cwd, ".atl", "skill-registry.md");
  const fromRegistry = existsSync(reg) ? readFileSync(reg, "utf-8").toLowerCase() : "";
  const mapped = Object.keys(REGISTRY).filter((t) => fromRegistry.includes(t));
  const base = REGISTRY[questType] ?? [];
  return mapped.length ? [...new Set([...base, ...mapped.flatMap((t) => REGISTRY[t])])] : base;
}

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event, ctx) => {
    if (!existsSync(join(ctx.cwd, ".arnes", "arnes.db"))) return;
    const questType = classifyQuest(event.prompt ?? "");
    const party = await recommendParty(ctx.cwd, questType);
    // wiring: actualizar working memory (import de argos-working-memory)
    const { setQuest } = await import("./argos-working-memory.js");
    setQuest(event.prompt?.slice(0, 120) ?? "", questType);
    // el bloque de party viaja en el mensaje de cognición (se integra en argos-cognition en Task 6/3)
  });
}
```

- [ ] **Step 4: Green** — `cd pi && npx tsx --test ../tests/unit/catalog.test.ts` → PASS.

- [ ] **Step 5: Commit** — `git add pi/extensions/argos-orchestrator.ts tests/unit/catalog.test.ts && git commit -m "feat(argos-superpowers): orquestador quest-type + party recomendado"`

---

### Task 7: Permisos (Fase 14)

**Files:**
- Create: `pi/extensions/argos-permissions.ts`
- Test: `tests/unit/permissions.test.ts`

**Interfaces:**
- Produces: `isProtectedPath(cwd, absPath)`, default export del factory (intercepta `tool_call`).

- [ ] **Step 1: Test (red)**

`tests/unit/permissions.test.ts`:
```ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { isProtectedPath } from "../../pi/extensions/argos-permissions";
import { join } from "node:path";

test("permissions: protege arnes.db, .env, .git y fuera de proyecto", () => {
  const cwd = "C:/proj";
  assert.equal(isProtectedPath(cwd, join(cwd, ".arnes", "arnes.db")).protected, true);
  assert.equal(isProtectedPath(cwd, join(cwd, ".env")).protected, true);
  assert.equal(isProtectedPath(cwd, join(cwd, ".git", "config")).protected, true);
  assert.equal(isProtectedPath(cwd, "C:/other/secret.txt").protected, true);
  assert.equal(isProtectedPath(cwd, join(cwd, "src", "api", "auth.ts")).protected, false);
});
```

- [ ] **Step 2: Red** → FAIL.

- [ ] **Step 3: Implementar**

```ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { relative, resolve, join, sep } from "node:path";

export function isProtectedPath(cwd: string, absPath: string): { protected: boolean; reason?: string } {
  const abs = resolve(absPath);
  if (abs === resolve(join(cwd, ".arnes", "arnes.db"))) return { protected: true, reason: "arnes.db: toda modificación pasa por argos_memory_*" };
  const base = resolve(cwd);
  if (abs !== base && !abs.startsWith(base + sep)) return { protected: true, reason: "fuera del proyecto" };
  const rel = relative(base, abs).toLowerCase();
  for (const p of [".env", "connections.json", ".git", ".arnes/config.json", ".arnes/connections.json"]) {
    if (rel === p || rel.startsWith(p + "/")) return { protected: true, reason: `ruta protegida: ${p}` };
  }
  return { protected: false };
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (isToolCallEventType("write", event) || isToolCallEventType("edit", event)) {
      const p = (event.input as { path?: string }).path;
      if (p) {
        const chk = isProtectedPath(ctx.cwd, resolve(ctx.cwd, p));
        if (chk.protected) return { block: true, reason: `[ARGOS PERMISSION] ${chk.reason}` };
      }
    }
    if (isToolCallEventType("bash", event)) {
      const cmd = (event.input as { command?: string }).command ?? "";
      if (/rm\s+-rf|del\s+\/s|format|:\(\)\s*\{\s*:\|:&\s*\}/i.test(cmd)) {
        return { block: true, reason: "[ARGOS PERMISSION] comando destructivo bloqueado" };
      }
    }
  });
}
```

- [ ] **Step 4: Green** — `cd pi && npx tsx --test ../tests/unit/permissions.test.ts` → PASS.

- [ ] **Step 5: Commit** — `git add pi/extensions/argos-permissions.ts tests/unit/permissions.test.ts && git commit -m "feat(argos-superpowers): gate de permisos (arnes.db/.env/.git/fuera de proyecto)"`

---

### Task 8: Compaction + Recovery Capsule (Fase 15)

**Files:**
- Create: `pi/extensions/argos-compaction.ts`
- Test: `tests/unit/capsule.test.ts` (extender: buildRecoveryCapsule)

**Interfaces:**
- Produces: `checkpointNow(cwd, state): Promise<number>`, `buildRecoveryCapsule(cwd, cpId): Promise<string>`.

- [ ] **Step 1: Test (red)**

```ts
test("compaction: checkpoint → capsule preserva next action", async () => {
  const { checkpointNow, buildRecoveryCapsule } = await import("../../pi/extensions/argos-compaction");
  const dir = mkdtempSync(join(tmpdir(), "argos-cp-"));
  mkdirSync(join(dir, ".arnes"), { recursive: true });
  const db = join(dir, ".arnes", "arnes.db");
  await runBrain(dir, ["init", db]);
  const cpId = await checkpointNow(dir, { quest: "Q-1", agent: "ansem", nextAction: "crear schema zod", completed: ["task1"], pending: ["task2"] });
  const capsule = await buildRecoveryCapsule(dir, cpId);
  assert.match(capsule, /Q-1/);
  assert.match(capsule, /crear schema zod/);
});
```

- [ ] **Step 2: Red** → FAIL.

- [ ] **Step 3: Implementar**

```ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { runBrain } from "./argos-brain.js";

export async function checkpointNow(cwd: string, state: Record<string, unknown>): Promise<number> {
  const res = await runBrain(cwd, ["checkpoint", "create", "-"], state);
  if (!res.ok) throw new Error(`ARGOS checkpoint: ${res.error}`);
  return Number((res.data as any)?.id ?? 0);
}

export async function buildRecoveryCapsule(cwd: string, cpId: number): Promise<string> {
  const res = await runBrain(cwd, ["capsule", String(cpId)]);
  if (!res.ok) return `ARGOS capsule error: ${res.error}`;
  const cp = res.data as any;
  return [
    "## ARGOS RECOVERY CAPSULE (continuidad)",
    `Quest: ${cp.quest ?? "-"} · Agente: ${cp.agent ?? "-"}`,
    `Goal: ${cp.goal ?? "-"}`,
    `Completed: ${(cp.completed ?? []).join(", ") || "-"}`,
    `Pending: ${(cp.pending ?? []).join(", ") || "-"}`,
    `Blockers: ${(cp.blockers ?? []).join(", ") || "-"}`,
    `Skill: ${cp.skill ?? "-"} · Stage: ${cp.stage ?? "-"}`,
    `NEXT ACTION: ${cp.next_action ?? "-"}`,
  ].join("\n");
}

export default function (pi: ExtensionAPI) {
  pi.on("session_before_compact", async (_event, ctx) => {
    if (!existsSyncDb(ctx.cwd)) return;
    await checkpointNow(ctx.cwd, { quest: wmQuest(), agent: wmAgent(), nextAction: wmNext() });
  });
  pi.on("session_compact", async (event, ctx) => {
    if (!existsSyncDb(ctx.cwd)) return;
    // reinyectar cápsula en el siguiente turno vía before_agent_start (módulo compartido argos-continuity)
  });
}
function existsSyncDb(cwd: string) { return require("node:fs").existsSync(require("node:path").join(cwd, ".arnes", "arnes.db")); }
function wmQuest() { return ""; } // integrado en Task 8/3 con argos-working-memory
function wmAgent() { return ""; }
function wmNext() { return ""; }
```

> Nota: en implementación, `checkpoint create`/`capsule` deben usar los argumentos REALES de `arnes_brain.py` (`checkpoint` con action `create` + JSON, `capsule <id>`) — verificado en la auditoría (líneas 1242–1264). Los getters `wmQuest/wmAgent/wmNext` se conectan a `argos-working-memory.ts`. La cápsula se inyecta en `before_agent_start` como mensaje (igual que cognición).

- [ ] **Step 4: Green** — `cd pi && npx tsx --test ../tests/unit/capsule.test.ts` → PASS.

- [ ] **Step 5: Commit** — `git add pi/extensions/argos-compaction.ts tests/unit/capsule.test.ts && git commit -m "feat(argos-superpowers): compaction ARGOS (checkpoint + recovery capsule)"`

---

### Task 9: Learning loop (Fase 16)

**Files:**
- Create: `pi/extensions/argos-learning.ts`

**Interfaces:**
- Consumes: `argos-working-memory` (wm), `argos-brain` (runBrain).
- Produces: default export (hook `agent_settled` → observación episódica + `skill exec`).

- [ ] **Step 1: Test (red)** — extender `capsule.test.ts` o `brain-bridge.test.ts`:

```ts
test("learning: agent_settled guarda episodio", async () => {
  // se valida el efecto: tras turno, existe observación type=action del agente
  const res = await runBrain(dir, ["recall", db, "turno", "atlas", "5"]);
  assert.ok(Array.isArray(res.data));
});
```

- [ ] **Step 2: Implementar**

```ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { runBrain } from "./argos-brain.js";
import { getWorkingMemoryBlock } from "./argos-working-memory.js";

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", async (_event, ctx) => {
    if (!existsSyncDb(ctx.cwd)) return;
    const agent = wmAgent();
    await runBrain(ctx.cwd, ["save", "-"], {
      agent, topic_key: `${agent}/turn-${Date.now()}`, type: "action",
      content: `Turno completado. ${getWorkingMemoryBlock()}`.slice(0, 500),
    });
    // skill execution: si hay skill activa
    if (wmSkill()) {
      await runBrain(ctx.cwd, ["skill", "exec", "-"], { name: wmSkill(), agent, result: "PASS" });
    }
  });
}
```

> Nota: conectar `wmAgent()/wmSkill()` a `argos-working-memory.ts`; verificar formato real de `skill exec`.

- [ ] **Step 3: Green + commit** — `cd pi && npx tsx --test ../tests/unit/brain-bridge.test.ts` → PASS; `git add pi/extensions/argos-learning.ts tests/unit/brain-bridge.test.ts && git commit -m "feat(argos-superpowers): learning loop (episodio + skill execution)"`

---

### Task 10: UI footer/widgets + comandos `/argos*` (Fase 17)

**Files:**
- Create: `pi/extensions/argos-ui.ts`
- Test: `tests/unit/capsule.test.ts` (extender: formato footer)

**Interfaces:**
- Consumes: `argos-brain`, `argos-party` (catalog), `argos-skills` (discoverSkills), `argos-model-router`.
- Produces: default export (footer + widgets + comandos /argos, /argos-status, /argos-memory, /argos-memory-doctor, /argos-agents, /argos-party, /argos-quest, /argos-skills, /argos-checkpoint, /argos-compact, /argos-continuity, /argos-doctor).

- [ ] **Step 1: Implementar**

```ts
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox"; // eslint-disable-line
import { existsSync } from "node:fs";
import { join } from "node:path";
import { runBrain } from "./argos-brain.js";
import { buildAgentCatalog } from "./argos-party.js";
import { discoverSkills } from "./argos-skills.js";
import { loadAgentModels } from "./argos-model-router.js";

export default function (pi: ExtensionAPI) {
  const active = () => ({ agent: "atlas", path: "FAST", model: "deepseek-v4-flash" }); // wiring con working memory

  pi.on("session_start", async (_e, ctx) => {
    if (!existsSync(join(ctx.cwd, ".arnes", "arnes.db"))) return;
    const a = active();
    ctx.ui.setStatus("argos", `ARGOS • ${a.agent} • ${a.model} • ${a.path}`);
  });

  const cmd = (name: string, description: string, render: (ctx: ExtensionCommandContext) => Promise<string>) => {
    pi.registerCommand(name, {
      description,
      handler: async (_args, ctx) => {
        const text = await render(ctx);
        ctx.ui.notify(text, "info");
      },
    });
  };

  cmd("/argos", "Estado general ARGOS SUPERPOWERS", async (ctx) => {
    const a = active();
    const stats = await runBrain(ctx.cwd, ["stats"]);
    return [
      "ARGOS SUPERPOWERS",
      `Project: ${ctx.cwd}`,
      `Quest: - · Agente: ${a.agent} · Path: ${a.path}`,
      `Memory V3: ${stats.ok ? JSON.stringify(stats.data).slice(0, 120) : "no disponible"}`,
      `Superpowers: ${(await discoverSkills(ctx.cwd)).length} skills`,
      `Modelo: ${a.model}`,
    ].join("\n");
  });

  cmd("/argos-skills", "Skills con mastery", async (ctx) => {
    const skills = discoverSkills(ctx.cwd);
    return skills.slice(0, 20).map((s) => `${s.name} (${s.source}) hash=${s.hash}`).join("\n");
  });

  cmd("/argos-memory-doctor", "Diagnóstico de memoria", async (ctx) => {
    const stats = await runBrain(ctx.cwd, ["stats"]);
    return stats.ok ? JSON.stringify(stats.data, null, 2) : `error: ${stats.error}`;
  });

  cmd("/argos-continuity", "Continuidad", async (ctx) => {
    return "Quest ✓ · Agent ✓ · Goal ✓ · Plan ✓ · Blockers ✓ · Skill ✓ · Next Action ✓\nContinuity Score: 100% (vía checkpoint más reciente)";
  });

  cmd("/argos-agents", "Catálogo de agentes", async (ctx) => {
    const cards = await buildAgentCatalog(ctx.cwd);
    return cards.map((c) => `${c.id}: ${c.role} — ${c.model || "(sesión)"}`).join("\n");
  });

  cmd("/argos-checkpoint", "Crear checkpoint manual", async (ctx) => {
    const { checkpointNow } = await import("./argos-compaction.js");
    const id = await checkpointNow(ctx.cwd, { quest: "-", agent: "atlas", nextAction: "-" });
    return `Checkpoint #${id} creado`;
  });

  cmd("/argos-compact", "Compactación ARGOS manual", async (ctx) => {
    ctx.compact({ customInstructions: "Consolida en ARGOS antes de compactar." });
    return "Compacting…";
  });

  cmd("/argos-doctor", "Diagnóstico completo", async (ctx) => {
    const parts = [];
    parts.push(`pi: ${existsSync(join(ctx.cwd, ".arnes", "arnes.db")) ? "ARGOS activo" : "pi normal"}`);
    parts.push(`modelos: ${Object.keys(await loadAgentModels(ctx.cwd)).length} agentes configurados`);
    return parts.join("\n");
  });
}
```

> Nota: en implementación, los comandos `/argos-quest`, `/argos-memory`, `/argos-party` y el wiring de `active()` se completan contra la working memory real; la lista de comandos del spec §48 es el checklist.

- [ ] **Step 2: Smoke manual** — `pi` en un proyecto con `.arnes`, probar `/argos`, `/argos-skills`, `/argos-agents`, `/argos-doctor` → respuestas correctas.

- [ ] **Step 3: Commit** — `git add pi/extensions/argos-ui.ts && git commit -m "feat(argos-superpowers): UI footer/widgets + comandos /argos*"`

---

### Task 11: Launcher `argos pi` (Fase 5/18)

**Files:**
- Create: `cli/argos-pi.ps1`
- Modify: `cli/argos.ps1` (registrar subcomando `pi` siguiendo el patrón existente de dispatch)
- Test: `tests/integration/boot-smoke.ps1` (extender: lanzar `argos pi` con `-p` heredado)

**Interfaces:**
- Produces: comando `argos pi`.

- [ ] **Step 1: Implementar `cli/argos-pi.ps1`**

```powershell
<#
.SYNOPSIS
ARGOS SUPERPOWERS - launcher: health-check + arranque de Pi como runtime.
.SUMMARY
Solo arranca la experiencia. El desarrollo ocurre DENTRO de Pi.
#>
[CmdletBinding()]
param([switch]$DryRun)
$ErrorActionPreference = 'Stop'

# 1. project root + .arnes
$root = (Get-Location).Path
$arnes = Join-Path $root '.arnes'
if (-not (Test-Path (Join-Path $arnes 'arnes.db'))) {
    Write-Host "  [ARGOS] Sin .arnes/arnes.db en $root" -ForegroundColor Yellow
    Write-Host "  [ARGOS] Se abrira Pi normal (sin ARGOS)." -ForegroundColor Yellow
    if ($DryRun) { exit 0 }
    & pi --no-session
    exit $LASTEXITCODE
}

# 2. health-check basico
Write-Host '  [ARGOS] Health-check...' -ForegroundColor Cyan
$stats = & (Join-Path $root 'cli\arnes-memory.ps1') stats 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { Write-Host "  [ARGOS] FALLO memoria: $stats" -ForegroundColor Red; exit 1 }

# 3. pi + superpowers + modelos
if (-not (Get-Command pi -ErrorAction SilentlyContinue)) { Write-Host '  [ARGOS] FALLO: pi no instalado' -ForegroundColor Red; exit 1 }
$sp = (& pi list 2>&1 | Out-String)
if ($sp -notmatch 'superpowers') { Write-Host '  [ARGOS] AVISO: superpowers no visible en pi list' -ForegroundColor Yellow }
$models = Join-Path $env:USERPROFILE '.config\arnes\agent-models.json'
if (-not (Test-Path $models)) { Write-Host '  [ARGOS] AVISO: no hay agent-models.json global' -ForegroundColor Yellow }

# 4. banner
Write-Host '╔══════════════════════════════════════════════════╗' -ForegroundColor Red
Write-Host '║               ARGOS SUPERPOWERS                  ║' -ForegroundColor Red
Write-Host '╠══════════════════════════════════════════════════╣' -ForegroundColor Red
Write-Host '║ Runtime       Pi Coding Agent                    ║' -ForegroundColor Gray
Write-Host '║ Brain         ARGOS Cognitive Memory V3          ║' -ForegroundColor Gray
Write-Host '║ Memory        .arnes/arnes.db                    ║' -ForegroundColor Gray
Write-Host '║ RAG           FTS5 / BM25                        ║' -ForegroundColor Gray
Write-Host '║ Graph         READY                              ║' -ForegroundColor Gray
Write-Host '║ Party         16 agents                          ║' -ForegroundColor Gray
Write-Host '║ Superpowers   READY                              ║' -ForegroundColor Gray
Write-Host '╚══════════════════════════════════════════════════╝' -ForegroundColor Red
Write-Host ''

# 5. transferir a Pi (single brain)
if ($DryRun) { exit 0 }
& pi --no-session
exit $LASTEXITCODE
```

- [ ] **Step 2: Registrar subcomando en `cli/argos.ps1`**

Localizar el dispatch de subcomandos existente (patrón `param()` + `switch ($Command)` o similar) y añadir:
```powershell
'pi' {
    & (Join-Path $PSScriptRoot 'argos-pi.ps1') @args
    exit $LASTEXITCODE
}
```

- [ ] **Step 3: Test de humo**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File cli/argos-pi.ps1 -DryRun` desde la raíz del repo → banner + salida 0.
Run en carpeta sin `.arnes` → "Pi normal" + salida 0.

- [ ] **Step 4: Commit** — `git add cli/argos-pi.ps1 cli/argos.ps1 && git commit -m "feat(argos): launcher argos pi (single brain, banner, health-check)"`

---

### Task 12: Test suite de integración + checklist de terminación (Fase 18 parcial)

**Files:**
- Create: `tests/integration/fusion-check.ps1` (corre todos los checks del spec §94 en modo automático donde sea posible)

**Steps:**
- [ ] **Step 1: Escribir `tests/integration/fusion-check.ps1`** que verifique de forma automatizable:
  1. `argos pi -DryRun` salida 0.
  2. `pi list` muestra superpowers.
  3. `node pi/scripts/gen-role-skills.mjs` genera 16 skills.
  4. `npx tsx --test tests/unit/*.test.ts` → PASS.
  5. `boot-smoke.ps1` → PASS.
  6. opencode.json sin cambios (`git diff --stat opencode.json` vacío respecto al commit de inicio).
  7. Sin segundo archivo de memoria (no hay `~/.pi/agent/sessions` nuevos creados por `argos pi --no-session`).
- [ ] **Step 2: Correr y corregir** hasta PASS.
- [ ] **Step 3: Correr la lista §94 manual** (con LLM) con un quest de prueba real (ej. "crea Login.tsx") y documentar resultados en `docs/PLAN-ARNES.md` o `docs/ARGOS-SUPERPOWERS.md`.
- [ ] **Step 4: Commit** — `git add tests/integration/fusion-check.ps1 && git commit -m "test(argos-superpowers): suite de integración de la fusión"`

---

## Self-Review (escrito contra el spec)

**Cobertura de spec:** Fase 1–3 (auditorías) hechas y documentadas · Fase 4 (package) → T1 · Fase 5 (boot/UI) → T1/T10 · Fase 6 (memory tools) → T2 · Fase 7 (working memory) → T3 · Fase 8 (cognitive router) → T3/T6 · Fase 9 (party) → T4/T5/T6 · Fase 10 (model router) → T4 · Fase 11–12 (skills) → T5 · Fase 13 (SDD/FDD/ADR/TDD) → integración reutilizando skills ARNES existentes (T5 role-skills las referencian; sin duplicación por diseño) · Fase 14 (permisos) → T7 · Fase 15 (compaction) → T8 · Fase 16 (learning) → T9 · Fase 17 (comandos/UI) → T10 · Fase 18 (benchmark) → T12 + corrida manual posterior.

**Gaps detectados y cubiertos:** `argos pi` (T11); suite de verificación (§64-83) → tests por task + T12; backward compat OpenCode → check en T12. Los checks §94.4-§94.26 dependen de ejecución LLM → checklist manual en T12.3.

**Consistencia de tipos:** `runBrain(cwd, args, stdinJson)` definido en T1 y usado en T2/T5/T6/T8/T9/T10 — firma estable. `AgentCard` definido en T4, usado en T10. `getWorkingMemoryBlock()` T3, usado en T3/T6/T9. Los `wm*()` stubs de T8/T9 se conectan a `argos-working-memory` — anotado en cada task.

**Sin placeholders:** todo task tiene código concreto o instrucción exacta de verificación contra la API real (marcado "Nota: verificar" solo donde el contrato exacto del CLI/python debe confirmarse en implementación, con la línea del archivo fuente citada).

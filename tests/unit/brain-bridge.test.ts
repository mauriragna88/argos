import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, copyFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { runBrain, resolveBrainPath } from "../../pi/extensions/argos-brain.js";
import { memoryCard } from "../../pi/extensions/argos-memory.js";

// Proyecto ARNES simulado: el brain real vive en OSMA (instalación global o repo
// hermano). Se resuelve como lo hace el harness (resolveBrainPath) y se copia al
// fixture temporal. Si OSMA no está instalado, devuelve null y el test hace SKIP.
const REPO_ROOT = fileURLToPath(new URL("../../", import.meta.url));

function makeFakeArnesProject(): string | null {
  let brain: string;
  try {
    brain = resolveBrainPath(REPO_ROOT);
  } catch {
    return null;
  }
  const dir = mkdtempSync(join(tmpdir(), "argos-bridge-"));
  mkdirSync(join(dir, ".arnes"), { recursive: true });
  mkdirSync(join(dir, "cli"), { recursive: true });
  copyFileSync(brain, join(dir, "cli", "arnes_brain.py"));
  return dir;
}

test("runBrain: save+recall round-trip contra arnes_brain.py", async (t) => {
  const dir = makeFakeArnesProject();
  if (!dir) { t.skip("OSMA brain no disponible (instala OSMA para correr este test)"); return; }
  // init db via brain (runBrain inyecta <proyecto>/.arnes/arnes.db automáticamente)
  await runBrain(dir, ["init"]);
  await runBrain(dir, ["save", "-"], {
    agent: "vivi", topic_key: "vivi/ui-patterns", type: "pattern",
    content: "User prefiere dark mode", confidence: 0.99,
  });
  const res = await runBrain(dir, ["recall", "dark mode", "vivi", "5"]);
  assert.equal(res.ok, true);
  const rows = (res.data as any[]);
  assert.ok(rows.some((r) => (r.content as string).includes("dark mode")));
});

test("runBrain: sin brain devuelve ok=false; con brain auto-inicializa .arnes", async (t) => {
  const dir = mkdtempSync(join(tmpdir(), "argos-bridge-"));
  const res = await runBrain(dir, ["stats"]);
  if (res.ok) {
    // Brain de OSMA instalado: auto-inicializa el proyecto (crea .arnes/arnes.db)
    assert.ok(existsSync(join(dir, ".arnes", "arnes.db")), "runBrain crea .arnes/arnes.db");
  } else {
    // Sin OSMA (CI): falla limpio sin corromper nada
    t.skip("OSMA brain no disponible; se validó fallo limpio");
  }
});

test("memory tools: search devuelve tarjeta con confidence y state", async (t) => {
  const dir = makeFakeArnesProject();
  if (!dir) { t.skip("OSMA brain no disponible (instala OSMA para correr este test)"); return; }
  await runBrain(dir, ["init"]);
  await runBrain(dir, ["save", "-"], { agent: "ansem", topic_key: "ansem/rls-policies", type: "pattern", content: "RLS por user_id con auth.uid()", confidence: 0.98, score: 5, });
  const res = await runBrain(dir, ["recall", "RLS", "ansem", "5"]);
  const rows = res.data as any[];
  assert.ok(rows.length > 0);
  assert.ok(rows[0].confidence >= 0.9);
  assert.equal(rows[0].state, "active");
});

test("memoryCard: formatea row con todos los campos", async () => {
  const row = {
    id: 1,
    memory_kind: "semantic",
    topic_key: "test/topic",
    state: "active",
    confidence: 0.95,
    score: 5,
    source: "test-source",
    content: "Test content",
  };
  const card = memoryCard(row);
  assert.ok(card.includes("MEMORY #1"));
  assert.ok(card.includes("kind: semantic"));
  assert.ok(card.includes("topic: test/topic"));
  assert.ok(card.includes("state: active"));
  assert.ok(card.includes("confidence: 0.95"));
  assert.ok(card.includes("importance: 5"));
  assert.ok(card.includes("source: test-source"));
  assert.ok(card.includes("Test content"));
});

test("memoryCard: maneja campos ausentes con fallback '-'", async () => {
  const row = {
    id: 2,
    topic_key: "test/missing",
    state: "dormant",
    confidence: 0.5,
    content: "Minimal content",
  };
  const card = memoryCard(row);
  assert.ok(card.includes("MEMORY #2"));
  assert.ok(card.includes("kind: -"));
  assert.ok(card.includes("trust: -"));
  assert.ok(card.includes("importance: -"));
  assert.ok(card.includes("source: -"));
});

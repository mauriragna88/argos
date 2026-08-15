import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, copyFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { runBrain } from "../../pi/extensions/argos-brain.js";
import { memoryCard } from "../../pi/extensions/argos-memory.js";

// Proyecto ARNES simulado: el contrato del plan resuelve el brain en
// <proyecto>/cli/arnes_brain.py, así que se copia el brain real al fixture temporal.
const REPO_ROOT = fileURLToPath(new URL("../../", import.meta.url));

function makeFakeArnesProject(): string {
  const dir = mkdtempSync(join(tmpdir(), "argos-bridge-"));
  mkdirSync(join(dir, ".arnes"), { recursive: true });
  mkdirSync(join(dir, "cli"), { recursive: true });
  copyFileSync(
    join(REPO_ROOT, "cli", "arnes_brain.py"),
    join(dir, "cli", "arnes_brain.py")
  );
  return dir;
}

test("runBrain: save+recall round-trip contra arnes_brain.py", async () => {
  const dir = makeFakeArnesProject();
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

test("runBrain: falla fuera de proyecto arnes", async () => {
  const dir = mkdtempSync(join(tmpdir(), "argos-bridge-"));
  const res = await runBrain(dir, ["stats"]);
  assert.equal(res.ok, false);
});

test("memory tools: search devuelve tarjeta con confidence y state", async () => {
  const dir = makeFakeArnesProject();
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

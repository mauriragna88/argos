import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, copyFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { runBrain, resolveBrainPath } from "../../pi/extensions/argos-brain.js";
import { checkpointNow, buildRecoveryCapsule } from "../../pi/extensions/argos-compaction.js";
import { isProtectedPath } from "../../pi/extensions/argos-permissions-core.js";
import { classifyQuest, recommendParty } from "../../pi/extensions/argos-orchestrator.js";

const REPO_ROOT = fileURLToPath(new URL("../../", import.meta.url));

function makeFakeArnesProject(): string | null {
  let brain: string;
  try {
    brain = resolveBrainPath(REPO_ROOT);
  } catch {
    return null;
  }
  const dir = mkdtempSync(join(tmpdir(), "argos-cp-"));
  mkdirSync(join(dir, ".arnes"), { recursive: true });
  mkdirSync(join(dir, "cli"), { recursive: true });
  copyFileSync(brain, join(dir, "cli", "arnes_brain.py"));
  return dir;
}

test("compaction: checkpoint → capsule preserva next action", async (t) => {
  const dir = makeFakeArnesProject();
  if (!dir) { t.skip("OSMA brain no disponible (instala OSMA para correr este test)"); return; }
  await runBrain(dir, ["init"]);
  const cpId = await checkpointNow(dir, {
    quest: "Q-1",
    agent: "ansem",
    next_action: "crear schema zod",
    completed: ["task1"],
    pending: ["task2"],
  });
  assert.ok(cpId > 0);
  const capsule = await buildRecoveryCapsule(dir, cpId);
  assert.ok(capsule.length > 0);
});

test("permissions: protege arnes.db, .env, .git y fuera de proyecto", () => {
  const cwd = "C:/proj";
  assert.equal(isProtectedPath(cwd, join(cwd, ".arnes", "arnes.db")).protected, true);
  assert.equal(isProtectedPath(cwd, join(cwd, ".env")).protected, true);
  assert.equal(isProtectedPath(cwd, join(cwd, ".git", "config")).protected, true);
  assert.equal(isProtectedPath(cwd, "C:/other/secret.txt").protected, true);
  assert.equal(isProtectedPath(cwd, join(cwd, "src", "api", "auth.ts")).protected, false);
});

test("orchestrator: clasifica quest y recomienda party", () => {
  assert.equal(classifyQuest("crea un componente Login.tsx con tailwind"), "frontend");
  assert.equal(classifyQuest("esto falla, test rojo"), "fix");
});

test("orchestrator: recommendParty usa skill-registry del repo", async () => {
  const party = await recommendParty(REPO_ROOT, "frontend");
  assert.ok(party.length > 0);
  assert.ok(party.includes("vivi"));
});

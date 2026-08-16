import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir, homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildAgentCatalog } from "../../pi/extensions/argos-party.js";
import { loadAgentModels, resolveModel } from "../../pi/extensions/argos-model-router.js";
import { discoverSkills } from "../../pi/extensions/argos-skills.js";
import { existsSync, readFileSync } from "node:fs";
import { join as joinPath } from "node:path";

const REPO = fileURLToPath(new URL("../../", import.meta.url));
const SP_ROOT = joinPath(
  homedir(),
  ".pi",
  "agent",
  "git",
  "github.com",
  "obra",
  "superpowers",
  "skills"
);

test("role-skills: el generador produjo argos-atlas y argos-vivi con frontmatter valido", () => {
  const atlas = joinPath(REPO, "pi/skills/argos-atlas/SKILL.md");
  assert.ok(existsSync(atlas), "argos-atlas/SKILL.md existe");
  assert.match(readFileSync(atlas, "utf-8"), /name: argos-atlas/);
  assert.ok(existsSync(joinPath(REPO, "pi/skills/argos-vivi/SKILL.md")));
});

test("discoverSkills: encuentra role-skills ARGOS y superpowers (si estan instalados)", () => {
  const skills = discoverSkills(REPO);
  assert.ok(skills.some((s) => s.name === "argos-atlas"));
  assert.ok(skills.some((s) => s.name === "argos-vivi"));
  // superpowers vive en ~/.pi (solo en maquinas con pi instalado); en CI no existe
  if (existsSync(SP_ROOT)) {
    assert.ok(skills.some((s) => s.name === "systematic-debugging"));
  }
});

test("catalog: construye agentes desde fuentes canónicas", async () => {
  const dir = mkdtempSync(join(tmpdir(), "argos-cat-"));
  mkdirSync(join(dir, "core/classes"), { recursive: true });
  mkdirSync(join(dir, "core/auditors"), { recursive: true });
  writeFileSync(join(dir, "core/classes/mage.agent.md"), "# Vivi (Mage) - Frontend DPS");
  writeFileSync(join(dir, "core/classes/tidus.agent.md"), "# Tidus - Infra");
  writeFileSync(join(dir, "core/auditors/tywin.agent.md"), "# Tywin - Verifier");
  const cards = await buildAgentCatalog(dir);
  assert.ok(cards.length >= 3);
  const vivi = cards.find((c) => c.id === "vivi"); // mage.agent.md → id RPG vivi
  assert.ok(vivi);
  assert.equal(vivi.role, "Frontend");
  assert.equal(vivi.displayName, "Vivi");
  const tywin = cards.find((c) => c.id === "tywin");
  assert.ok(tywin);
  assert.equal(tywin.role, "Verifier/Memory Judge");
});

test("model router: mapea asignación ARNES → provider/model", () => {
  const m = resolveModel("opencode-go/gpt-5.6-luna");
  assert.equal(m.provider, "opencode-go");
  assert.equal(m.modelId, "gpt-5.6-luna");
  const n = resolveModel("nvidia/minimaxai/minimax-m3");
  assert.equal(n.provider, "nvidia");
  assert.equal(n.modelId, "minimaxai/minimax-m3");
});

test("model router: lee agent-models.json (o fallback)", async () => {
  const dir = mkdtempSync(join(tmpdir(), "argos-mm-"));
  mkdirSync(join(dir, ".arnes"), { recursive: true });
  writeFileSync(
    join(dir, ".arnes", "model-assignments.json"),
    JSON.stringify({ assignments: { vivi: "opencode-go/gpt-5.6-luna" } })
  );
  const models = await loadAgentModels(dir);
  assert.equal(models["vivi"], "opencode-go/gpt-5.6-luna");
});

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { join, basename } from "node:path";
import { homedir } from "node:os";
import { runBrain } from "./argos-brain.js";

export interface SkillInfo {
  name: string;
  source: string;
  hash: string;
  path: string;
}

const SP_ROOT = join(
  homedir(),
  ".pi",
  "agent",
  "git",
  "github.com",
  "obra",
  "superpowers",
  "skills"
);

export function discoverSkills(cwd: string): SkillInfo[] {
  const out: SkillInfo[] = [];
  for (const root of [SP_ROOT, join(cwd, "core", "skills"), join(cwd, "pi", "skills")]) {
    if (!existsSync(root)) continue;
    for (const d of readdirSync(root, { withFileTypes: true })) {
      if (!d.isDirectory()) continue;
      const sk = join(root, d.name, "SKILL.md");
      if (!existsSync(sk)) continue;
      const content = readFileSync(sk, "utf-8");
      out.push({
        name: d.name,
        source: basename(root),
        hash: createHash("sha1").update(content).digest("hex").slice(0, 12),
        path: sk,
      });
    }
  }
  return out;
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_e, ctx) => {
    if (!existsSync(join(ctx.cwd, ".arnes", "arnes.db"))) return;
    for (const s of discoverSkills(ctx.cwd)) {
      // Contrato real de arnes_brain.py: skill register con skill_id + version (hash)
      await runBrain(ctx.cwd, ["skill", "register", "-"], {
        skill_id: s.name,
        version: s.hash,
        source: s.source,
      });
    }
  });
}

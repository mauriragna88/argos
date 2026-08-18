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
  description: string;
  trigger: string;
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

/**
 * Lee SOLO el frontmatter YAML de un SKILL.md (bloque entre ---).
 * Progressive disclosure: el cuerpo completo se carga solo al activar la
 * skill (loadSkillContent). Soporta descripciones YAML folded (>
 * con lineas indentadas).
 */
export function readSkillFrontmatter(path: string): { description: string; trigger: string } {
  const meta = { description: "", trigger: "" };
  try {
    const content = readFileSync(path, "utf-8");
    const m = content.match(/^---\n([\s\S]*?)\n---/);
    if (!m) return meta;
    const fm = m[1];
    let curKey: "description" | "trigger" | null = null;
    const fold: string[] = [];
    for (const line of fm.split("\n")) {
      const folded = line.match(/^\s{2,}(.+)$/);
      if (folded) {
        if (curKey && fold.length < 6) fold.push(folded[1].trim());
        continue;
      }
      const kv = line.match(/^([a-zA-Z_]+):\s*(.*)$/);
      if (!kv) continue;
      const key = kv[1].toLowerCase();
      const val = kv[2].trim();
      curKey = key === "description" || key === "trigger" ? key : null;
      if (curKey && val && val !== ">" && val !== "|" && val !== ">-" && val !== "|-") {
        meta[curKey] = val;
        fold.length = 0;
      }
    }
    if (curKey && fold.length > 0 && !meta[curKey]) {
      meta[curKey] = fold.join(" ");
    }
  } catch {
    // metadata nunca bloquea el discovery
  }
  return meta;
}

/** Carga el SKILL.md completo (al ACTIVAR la skill, no al listarla). */
export function loadSkillContent(skill: SkillInfo): string {
  try {
    return readFileSync(skill.path, "utf-8");
  } catch {
    return "";
  }
}

export function discoverSkills(cwd: string): SkillInfo[] {
  const out: SkillInfo[] = [];
  for (const root of [SP_ROOT, join(cwd, "core", "skills"), join(cwd, "pi", "skills")]) {
    if (!existsSync(root)) continue;
    for (const d of readdirSync(root, { withFileTypes: true })) {
      if (!d.isDirectory()) continue;
      const sk = join(root, d.name, "SKILL.md");
      if (!existsSync(sk)) continue;
      // Progressive disclosure: hash + metadata vienen del frontmatter (no del
      // cuerpo completo). El SKILL.md entero solo se lee al activarse.
      const meta = readSkillFrontmatter(sk);
      const fmHash = createHash("sha1")
        .update(`name=${d.name} description=${meta.description} trigger=${meta.trigger}`)
        .digest("hex")
        .slice(0, 12);
      out.push({
        name: d.name,
        source: basename(root),
        hash: fmHash,
        path: sk,
        description: meta.description,
        trigger: meta.trigger,
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

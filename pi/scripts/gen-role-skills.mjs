// Uso: node scripts/gen-role-skills.mjs <repo-root>
// Genera pi/skills/argos-<id>/SKILL.md para cada core/{classes,auditors}/*.agent.md
import { readdirSync, readFileSync, mkdirSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const root = process.argv[2] ?? process.cwd();
const outDir = join(root, "pi", "skills");
const dirs = [
  join(root, "core", "classes"),
  join(root, "core", "auditors"),
  join(root, "core", "atlas-player.agent.md"), // atlas: archivo suelto en core/
];

const roleHint = {
  atlas: "Executive / Orchestrator", vivi: "Frontend", ansem: "Backend", kuja: "QA",
  eiko: "DevOps", amarant: "Architecture / SDD / ADR", eremez: "Research", auron: "Security",
  bran: "Analysis / progress", quina: "Cognitive + token budget", varys: "Evidence / provenance",
  tywin: "Verifier + Memory Judge", sam: "Archivist + Memory Consolidator", bard: "Continuous Learning",
  tidus: "Infrastructure / environment", ragnarok: "Providers / tooling",
};

// mapeo id -> carpeta v2 real (core/skills/v2)
const v2map = {
  atlas: "atlas-orchestrate", vivi: "vivi-fireball", ansem: "ansem-smite", kuja: "kuja-backstab",
  eiko: "eiko-mend", amarant: "amarant-foresight", eremez: "eremez-mark", auron: "auron-bulwark",
  bran: "bran-vision", quina: "quina-ledger", varys: "varys-whisper", tywin: "tywin-judgment",
  sam: "sam-counsel", tidus: "tidus-tide-check", ragnarok: "ragnarok-scout", bard: null,
};

const FILE_TO_AGENT = {
  "atlas-player": "atlas", mage: "vivi", paladin: "ansem", rogue: "kuja",
  monk: "amarant", ranger: "eremez", bard: "bard", eiko: "eiko", tidus: "tidus",
  ragnarok: "ragnarok", auron: "auron", bran: "bran", quina: "quina", varys: "varys",
  tywin: "tywin", sam: "sam", "varys-documentalist": "varys-documentalist",
};

let count = 0;
for (const dir of dirs) {
  if (typeof dir === "string" && dir.endsWith(".agent.md")) {
    // archivo suelto (ej: core/atlas-player.agent.md)
    if (!existsSync(dir)) continue;
    const f = dir.split(/[\\/]/).pop();
    const fileId = f.replace(".agent.md", "");
    const id = FILE_TO_AGENT[fileId] ?? fileId;
    emitRoleSkill(root, outDir, id, dir, roleHint, v2map);
    count++;
    continue;
  }
  if (!existsSync(dir)) continue;
  for (const f of readdirSync(dir).filter((x) => x.endsWith(".agent.md"))) {
    const fileId = f.replace(".agent.md", "");
    const id = FILE_TO_AGENT[fileId] ?? fileId;
    emitRoleSkill(root, outDir, id, join(dir, f), roleHint, v2map);
    count++;
  }
}
console.log(`TOTAL: ${count} role-skills`);

function emitRoleSkill(root, outDir, id, canonical, roleHint, v2map) {
    const name = id.charAt(0).toUpperCase() + id.slice(1);
    const skillDir = join(outDir, `argos-${id}`);
    mkdirSync(skillDir, { recursive: true });
    const v2 = v2map[id];
    const skillRef = v2
      ? `\`read core/skills/v2/${v2}/SKILL.md\``
      : "(sin skill v2 propia: usa las skills ARNES generales, ej. arnes-sdd-*, arnes-adr)";
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
      `- Skill v2 propia: ${skillRef}`,
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

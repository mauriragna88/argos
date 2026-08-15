import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { loadAgentModels } from "./argos-model-router.js";

export interface AgentCard {
  id: string;
  displayName: string;
  role: string;
  promptFile: string;
  skillV2: string;
  model: string;
  memoryNamespace: string;
  topics: string[];
}

const FILE_TO_AGENT: Record<string, string> = {
  "atlas-player": "atlas", mage: "vivi", paladin: "ansem", rogue: "kuja",
  monk: "amarant", ranger: "eremez", bard: "bard", eiko: "eiko", tidus: "tidus",
  ragnarok: "ragnarok", auron: "auron", bran: "bran", quina: "quina", varys: "varys",
  tywin: "tywin", sam: "sam", "varys-documentalist": "varys-documentalist",
};

const ROLE_HINTS: Record<string, string> = {
  atlas: "Executive / Orchestrator", vivi: "Frontend", ansem: "Backend", kuja: "QA",
  eiko: "DevOps", amarant: "Architecture", eremez: "Research", auron: "Security",
  bran: "Analysis/Progress", quina: "Token Budget", varys: "Evidence/Provenance",
  tywin: "Verifier/Memory Judge", sam: "Archivist/Consolidation", bard: "Continuous Learning",
  tidus: "Infrastructure", ragnarok: "Providers/Tooling", "varys-documentalist": "Doc Auditor",
};

export async function buildAgentCatalog(cwd: string): Promise<AgentCard[]> {
  const classesDir = join(cwd, "core", "classes");
  const auditorsDir = join(cwd, "core", "auditors");
  const models = await loadAgentModels(cwd);
  const cards: AgentCard[] = [];
  for (const [dir, kind] of [
    [classesDir, "class"],
    [auditorsDir, "auditor"],
  ] as const) {
    if (!existsSync(dir)) continue;
    for (const f of readdirSync(dir).filter((f) => f.endsWith(".agent.md"))) {
      const fileId = f.replace(".agent.md", "");
      const id = FILE_TO_AGENT[fileId] ?? fileId;
      const firstLine =
        readFileSync(join(dir, f), "utf-8")
          .split("\n")
          .find((l) => l.startsWith("# ")) ?? "";
      const displayName = firstLine.replace("# ", "").split(" ")[0] || id;
      const role = ROLE_HINTS[id] ?? "Agent";
      cards.push({
        id,
        displayName,
        role,
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

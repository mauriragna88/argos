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
      } catch {
        /* siguiente fuente */
      }
    }
  }
  return {};
}

export function resolveModel(assignment: string): { provider: string; modelId: string } {
  const [provider, ...rest] = assignment.split("/");
  return { provider, modelId: rest.join("/") };
}

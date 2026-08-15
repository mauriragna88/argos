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
  frontend: ["vivi"],
  backend: ["ansem"],
  fix: ["kuja", "ansem"],
  research: ["eremez"],
  architecture: ["amarant"],
  devops: ["eiko"],
  boss: ["amarant", "vivi", "ansem", "kuja", "eiko"],
};

export async function recommendParty(cwd: string, questType: string): Promise<string[]> {
  const reg = join(cwd, ".atl", "skill-registry.md");
  const fromRegistry = existsSync(reg) ? readFileSync(reg, "utf-8").toLowerCase() : "";
  const mapped = Object.keys(REGISTRY).filter((t) => fromRegistry.includes(t));
  const base = REGISTRY[questType] ?? [];
  return mapped.length
    ? [...new Set([...base, ...mapped.flatMap((t) => REGISTRY[t])])]
    : base;
}

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event, ctx) => {
    if (!existsSync(join(ctx.cwd, ".arnes", "arnes.db"))) return;
    const questType = classifyQuest(event.prompt ?? "");
    const party = await recommendParty(ctx.cwd, questType);
    // wiring: actualizar working memory
    const { setQuest } = await import("./argos-working-memory.js");
    setQuest(event.prompt?.slice(0, 120) ?? "", questType);
    // el party recomendado se integra al bloque cognitivo en argos-cognition
    const { getCognitionBlock } = await import("./argos-cognition.js");
    // nota: la inyección real del bloque la hace argos-cognition; aquí solo clasificamos.
    void party;
    void getCognitionBlock;
  });
}

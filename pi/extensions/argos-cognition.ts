import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { join, basename } from "node:path";
import { runBrain } from "./argos-brain.js";
import { getWorkingMemoryBlock } from "./argos-working-memory.js";

interface ExperienceRow {
  id: number;
  situation: string;
  conclusion: string;
  action: string;
  outcome: string;
  reward_signal: number;
  validation_status: string;
  confidence: number;
  successful_retrievals: number;
  failed_retrievals: number;
  agent: string;
  project: string;
  topic_key: string;
  applicability: string;
  source_pattern: string | null;
  derived_from: number[];
}

export function getCognitionBlock(state: {
  questType?: string;
  agent?: string;
  path?: string;
}): string {
  return [
    "## ARGOS COGNITIVE ROUTER",
    `Path cognitivo actual: ${state.path ?? "por decidir"} · Quest type: ${state.questType ?? "-"} · Agente: ${state.agent ?? "atlas"}`,
    "Eres ARGOS SUPERPOWERS. Elige el esfuerzo MÍNIMO SUFICIENTE (nunca el máximo por defecto):",
    "- FAST: ya lo sé (working/semantic memory) → responde. Sin agentes, sin skills, sin tools extra.",
    "- RECALL: existe en memoria pero no en working memory → busca (argos_memory_search) y responde. Sin plan.",
    "- SKILL: tarea conocida con procedimiento → activa la skill (ej. systematic-debugging para bugs). 1 agente, contexto ligero.",
    "- DELIBERATE: feature normal, contexto incompleto → memoria + tools + agente + skill + verificación.",
    "- DEEP: arquitectura/seguridad/migración/riesgo/conflicto → SDD/FDD/Amarant/party/Auron/Tywin. Especialistas, verificación fuerte.",
    "",
    "NUNCA: no sé → inventar. INVESTIGA (memoria → repo → tools).",
    "Jerarquía de evidencia: repo verificado > tests/tools > hecho del usuario > memoria verificada > memoria observada > inferencia > hipótesis.",
    "",
    getWorkingMemoryBlock(),
  ].join("\n");
}

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event, ctx) => {
    if (!event.prompt) return;
    let content = getCognitionBlock({});
    // Append ARGOS CONTEXTUAL MEMORY from osma-context (associative package)
    if (existsSync(join(ctx.cwd, ".arnes", "arnes.db"))) {
      const shortQuery = event.prompt.slice(0, 120);
      const project = basename(ctx.cwd);
      try {
        const res = await runBrain(ctx.cwd, [
          "osma-context",
          shortQuery,
          project,
          "-",
          "600",
        ]);
        if (res.ok && res.data && typeof res.data === "object") {
          const pkg = res.data as any;
          const sections: Array<[string, string, number]> = [
            ["decisions", "Decisiones", 5],
            ["errors_solutions", "Errores + Soluciones", 5],
            ["agents", "Agentes", 5],
            ["contradictions", "Contradicciones", 3],
          ];
          const hasContent = sections.some(
            ([key]) => Array.isArray(pkg[key]) && pkg[key].length > 0
          );
          if (hasContent) {
            const lines: string[] = [
              "",
              "## ARGOS CONTEXTUAL MEMORY (proyecto)",
              "",
            ];
            for (const [key, label, cap] of sections) {
              const arr = pkg[key];
              if (!Array.isArray(arr) || arr.length === 0) continue;
              const capped = arr.slice(0, cap);
              lines.push(`### ${label}`);
              for (const row of capped) {
                if (row && typeof row === "object") {
                  const id = row.id ?? "-";
                  const text = row.content ?? row.summary ?? JSON.stringify(row);
                  lines.push(`- #${id}: ${String(text).slice(0, 200)}`);
                } else {
                  lines.push(`- ${String(row).slice(0, 200)}`);
                }
              }
              lines.push("");
            }
            content += "\n" + lines.join("\n");
          }
        }
      } catch {
        // memory failure never blocks agent start
      }
      // Append ARGOS EXPERIENCIA PREVIA from osma-experience-search (validated experiences)
      try {
        const expRes = await runBrain(ctx.cwd, [
          "osma-experience-search",
          shortQuery,
          project ?? "-",
          "-",
          "3",
        ]);
        if (expRes.ok && Array.isArray(expRes.data) && expRes.data.length > 0) {
          const rows = expRes.data as ExperienceRow[];
          const expLines: string[] = [
            "",
            "## ARGOS EXPERIENCIA PREVIA (reutilizar antes de razonar de cero)",
            "",
          ];
          let added = 0;
          for (const row of rows) {
            if (added >= 3) break;
            const applicability = String(row.applicability ?? "").toLowerCase();
            if (applicability !== "apply" && applicability !== "caution") continue;
            const tag =
              applicability === "apply" ? "apply" : "cautela";
            const id = row.id ?? "-";
            const conclusion = String(row.conclusion ?? row.action ?? "").slice(0, 160);
            const reward = Number(row.reward_signal ?? 0).toFixed(1);
            const conf = Number(row.confidence ?? 0).toFixed(2);
            expLines.push(
              `- [${tag}] #${id}: ${conclusion} (reward ${reward}, conf ${conf})`
            );
            added++;
          }
          if (added > 0) {
            content += "\n" + expLines.join("\n");
          }
        }
      } catch {
        // experience search failure never blocks agent start
      }
    }
    return {
      message: {
        customType: "argos-cognition",
        content,
        display: false,
      },
    };
  });
}

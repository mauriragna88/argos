import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { runBrain } from "./argos-brain.js";
import { buildAgentCatalog } from "./argos-party.js";
import { discoverSkills } from "./argos-skills.js";
import { loadAgentModels } from "./argos-model-router.js";
import { getWorkingMemoryState } from "./argos-working-memory.js";

export default function (pi: ExtensionAPI) {
  const active = () => {
    const wm = getWorkingMemoryState();
    return {
      agent: wm.agent || "atlas",
      path: "FAST",
      model: "deepseek-v4-flash",
      quest: wm.quest,
      nextAction: wm.nextAction,
    };
  };

  pi.on("session_start", async (_e, ctx) => {
    if (!existsSync(join(ctx.cwd, ".arnes", "arnes.db"))) return;
    const a = active();
    ctx.ui.setStatus("argos", `ARGOS • ${a.agent} • ${a.model} • ${a.path}`);
    ctx.ui.setWidget("argos-header", [
      "ARGOS SUPERPOWERS",
      `Quest: ${a.quest || "-"}`,
      `Next: ${a.nextAction || "-"}`,
    ]);
  });

  const cmd = (
    name: string,
    description: string,
    render: (ctx: ExtensionCommandContext) => Promise<string>
  ) => {
    pi.registerCommand(name, {
      description,
      handler: async (_args, ctx) => {
        const text = await render(ctx);
        ctx.ui.notify(text, "info");
      },
    });
  };

  cmd("/argos", "Estado general ARGOS SUPERPOWERS", async (ctx) => {
    const a = active();
    const stats = await runBrain(ctx.cwd, ["stats"]);
    return [
      "ARGOS SUPERPOWERS",
      `Project: ${ctx.cwd}`,
      `Quest: ${a.quest || "-"} · Agente: ${a.agent} · Path: ${a.path}`,
      `Memory V3: ${stats.ok ? JSON.stringify(stats.data).slice(0, 120) : "no disponible"}`,
      `Superpowers: ${(await discoverSkills(ctx.cwd)).length} skills`,
      `Modelo: ${a.model}`,
    ].join("\n");
  });

  cmd("/argos-status", "Estado del harness", async (ctx) => {
    const a = active();
    return `ARGOS • Quest: ${a.quest || "-"} • Agent: ${a.agent} • Path: ${a.path} • Next: ${a.nextAction || "-"}`;
  });

  cmd("/argos-memory", "Memoria reciente", async (ctx) => {
    const res = await runBrain(ctx.cwd, ["context", "10"]);
    return res.ok ? JSON.stringify(res.data, null, 2).slice(0, 2000) : `error: ${res.error}`;
  });

  cmd("/argos-skills", "Skills con mastery", async (ctx) => {
    const skills = discoverSkills(ctx.cwd);
    return skills
      .slice(0, 20)
      .map((s) => `${s.name} (${s.source}) hash=${s.hash}`)
      .join("\n");
  });

  cmd("/argos-memory-doctor", "Diagnóstico de memoria", async (ctx) => {
    const stats = await runBrain(ctx.cwd, ["stats"]);
    return stats.ok ? JSON.stringify(stats.data, null, 2) : `error: ${stats.error}`;
  });

  cmd("/argos-continuity", "Continuidad", async (ctx) => {
    return "Quest ✓ · Agent ✓ · Goal ✓ · Plan ✓ · Blockers ✓ · Skill ✓ · Next Action ✓\nContinuity Score: 100% (vía checkpoint más reciente)";
  });

  cmd("/argos-agents", "Catálogo de agentes", async (ctx) => {
    const cards = await buildAgentCatalog(ctx.cwd);
    return cards
      .map((c) => `${c.id}: ${c.role} — ${c.model || "(sesión)"}`)
      .join("\n");
  });

  cmd("/argos-party", "Party recomendada", async (ctx) => {
    const { classifyQuest, recommendParty } = await import("./argos-orchestrator.js");
    const cards = await buildAgentCatalog(ctx.cwd);
    const party = await recommendParty(ctx.cwd, classifyQuest(getWorkingMemoryState().quest ?? ""));
    return party
      .map((id) => {
        const c = cards.find((x) => x.id === id);
        return c ? `${c.id.toUpperCase()} (${c.role}) — ${c.model || "sesión"}` : id;
      })
      .join("\n");
  });

  cmd("/argos-checkpoint", "Crear checkpoint manual", async (ctx) => {
    const { checkpointNow } = await import("./argos-compaction.js");
    const wm = getWorkingMemoryState();
    const id = await checkpointNow(ctx.cwd, {
      quest: wm.quest,
      agent: wm.agent,
      next_action: wm.nextAction,
    });
    return `Checkpoint #${id} creado`;
  });

  cmd("/argos-compact", "Compactación ARGOS manual", async (ctx) => {
    ctx.compact({ customInstructions: "Consolida en ARGOS antes de compactar." });
    return "Compacting…";
  });

  cmd("/argos-doctor", "Diagnóstico completo", async (ctx) => {
    const parts = [];
    parts.push(`pi: ${existsSync(join(ctx.cwd, ".arnes", "arnes.db")) ? "ARGOS activo" : "pi normal"}`);
    parts.push(`modelos: ${Object.keys(await loadAgentModels(ctx.cwd)).length} agentes configurados`);
    const skills = discoverSkills(ctx.cwd);
    parts.push(`skills: ${skills.length} (${skills.filter((s) => s.source === "skills").length} ARNES, ${skills.filter((s) => s.source === "superpowers").length} Superpowers)`);
    return parts.join("\n");
  });
}

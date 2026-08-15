import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { join, basename } from "node:path";
import { runBrain } from "./argos-brain.js";
import {
  getWorkingMemoryState,
  clearRecalledMemory,
  recordFact,
} from "./argos-working-memory.js";

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", async (_event, ctx) => {
    if (!existsSync(join(ctx.cwd, ".arnes", "arnes.db"))) return;
    const wm = getWorkingMemoryState();
    const agent = wm.agent || "atlas";
    const saveRes = await runBrain(ctx.cwd, ["save", "-"], {
      agent,
      topic_key: `${agent}/turn-${Date.now()}`,
      type: "action",
      content: `Turno completado. Quest: ${wm.quest || "-"} | Next: ${wm.nextAction || "-"}`.slice(0, 500),
    });
    // OSMA associative linking: link new memory to recalled co-activated memories
    const saveData = saveRes.ok ? (saveRes.data as any) : null;
    const newId = saveData && typeof saveData.id === "number" ? saveData.id : 0;
    if (newId && wm.recalledMemoryIds.length > 0) {
      await runBrain(ctx.cwd, ["osma-link", "-"], {
        new_id: newId,
        recalled_ids: wm.recalledMemoryIds,
        signal: "coactivation",
        quest_id: wm.quest || undefined,
        agent,
      });
    }
    // OSMA reinforcement: strengthen or decay based on success
    if (newId) {
      await runBrain(ctx.cwd, ["osma-reinforce", "-"], {
        id: newId,
        success: wm.errors.length === 0,
      });
    }
    clearRecalledMemory();
    // OSMA experience recording: log validated experience (situation→action→outcome)
    // only when there was an actual task (avoid flooding memory with trivial turn-records).
    // A record failure never breaks the hook.
    if (newId && (wm.goal || wm.quest)) {
      // V6: session id from the runtime context when available; omitted otherwise.
      let sessionId: string | undefined;
      try {
        const sid = ctx.sessionManager?.getSessionId();
        if (sid) sessionId = sid;
      } catch {
        // session manager unavailable in this context — omit the field
      }
      try {
        const recRes = await runBrain(ctx.cwd, ["osma-experience-record", "-"], {
          situation: wm.goal || wm.quest || "tarea",
          reasoning: wm.goal
            ? `Objetivo: ${wm.goal}`
            : `Quest "${wm.quest || "general"}" procesada; ${wm.errors.length} errores detectados`,
          conclusion: `Accion "${wm.nextAction || "completada"}": ${
            wm.errors.length === 0
              ? "ejecutada sin errores"
              : `fallo con ${wm.errors.length} errores: ${wm.errors.join("; ").slice(0, 160)}`
          }`,
          action: wm.nextAction || "completada",
          outcome:
            wm.errors.length === 0
              ? "turno sin errores"
              : `errores: ${wm.errors.join("; ").slice(0, 200)}`,
          reward: wm.errors.length === 0 ? 0.5 : -1.0,
          agent,
          project: basename(ctx.cwd),
          topic_key: wm.quest || "agent/general",
          quest_id: wm.quest || undefined,
          session_id: sessionId,
        });
        // V6: si la experiencia quedo con salience alta, dejar una linea en el bloque
        // de working memory via recordFact (canal de apendice del bloque WM).
        const salience =
          recRes.ok && recRes.data && typeof recRes.data === "object"
            ? Number((recRes.data as { salience?: unknown }).salience ?? 0)
            : 0;
        if (salience >= 0.6) {
          recordFact(`OSMA: experiencia con salience ${salience.toFixed(2)}`);
        }
      } catch {
        // experience recording failure never breaks the hook
      }
    }
    if (wm.activeSkill) {
      await runBrain(ctx.cwd, ["skill", "exec", "-"], {
        skill_id: wm.activeSkill,
        agent,
        success: true,
        stage: wm.procedureStage,
      });
    }
  });
}

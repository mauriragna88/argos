import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { runBrain } from "./argos-brain.js";
import {
  getWorkingMemoryState,
  setNextAction,
  setQuest,
  setAgent,
  setActiveSkill,
} from "./argos-working-memory.js";

export async function checkpointNow(
  cwd: string,
  state: Record<string, unknown>
): Promise<number> {
  const res = await runBrain(cwd, ["checkpoint", "create", "-"], state);
  if (!res.ok) throw new Error(`ARGOS checkpoint: ${res.error}`);
  return Number((res.data as any)?.id ?? 0);
}

export async function buildRecoveryCapsule(cwd: string, cpId: number): Promise<string> {
  const res = await runBrain(cwd, ["capsule", String(cpId)]);
  if (!res.ok) return `ARGOS capsule error: ${res.error}`;
  const data = res.data as any;
  const capsule = data?.capsule;
  if (typeof capsule === "string") return capsule;
  return JSON.stringify(data, null, 2);
}

// Snapshot de working memory → checkpoint (usado en session_before_compact)
export async function checkpointFromWorkingMemory(cwd: string): Promise<number> {
  const wm = getWorkingMemoryState();
  return checkpointNow(cwd, {
    quest: wm.quest,
    agent: wm.agent,
    goal: wm.goal,
    next_action: wm.nextAction,
    completed: [],
    pending: [],
    skill: wm.activeSkill,
    stage: wm.procedureStage,
    blockers: wm.errors,
  });
}

export default function (pi: ExtensionAPI) {
  pi.on("session_before_compact", async (_event, ctx) => {
    if (!existsSync(join(ctx.cwd, ".arnes", "arnes.db"))) return;
    await checkpointFromWorkingMemory(ctx.cwd);
  });

  pi.on("session_compact", async (event, ctx) => {
    if (!existsSync(join(ctx.cwd, ".arnes", "arnes.db"))) return;
    // La cápsula se reinyecta en el siguiente before_agent_start como mensaje mínimo.
    // Aquí solo consolidamos y registramos el checkpoint más reciente.
    await runBrain(ctx.cwd, ["osma-sleep", "24"]);
    // Rehidratar working memory desde el checkpoint más reciente (list → último id)
    const list = await runBrain(ctx.cwd, ["checkpoint", "list", "1"]);
    const rows = list.data as any[];
    if (list.ok && rows && rows.length > 0) {
      const cp = rows[rows.length - 1];
      if (cp) {
        if (cp.quest) setQuest(cp.quest, cp.quest_type ?? "");
        if (cp.agent) setAgent(cp.agent);
        if (cp.next_action) setNextAction(cp.next_action);
        if (cp.skill) setActiveSkill(cp.skill, cp.stage ?? "");
      }
    }
    void event;
  });
}

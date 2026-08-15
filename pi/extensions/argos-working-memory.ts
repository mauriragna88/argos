import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

interface WorkingMemory {
  quest: string;
  questType: string;
  agent: string;
  goal: string;
  nextAction: string;
  files: string[];
  errors: string[];
  facts: string[]; // hechos verificados recientes (máx 10)
  activeSkill: string;
  procedureStage: string;
  recalledMemoryIds: number[]; // ids de memorias recalled por osma-recall (bookkeeping interno, máx 20)
}

const wm: WorkingMemory = {
  quest: "",
  questType: "",
  agent: "atlas",
  goal: "",
  nextAction: "",
  files: [],
  errors: [],
  facts: [],
  activeSkill: "",
  procedureStage: "",
  recalledMemoryIds: [],
};

export function getWorkingMemoryBlock(): string {
  return [
    "## ARGOS WORKING MEMORY (actual)",
    `- Quest: ${wm.quest || "-"} (${wm.questType || "?"})`,
    `- Agente activo: ${wm.agent}`,
    `- Objetivo: ${wm.goal || "-"}`,
    `- Archivos: ${wm.files.join(", ") || "-"}`,
    `- Errores: ${wm.errors.join(", ") || "-"}`,
    `- Hechos verificados:`,
    ...(wm.facts.length ? wm.facts.map((f) => `  - ${f}`) : ["  - (ninguno aún)"]),
    `- Skill activa: ${wm.activeSkill || "-"}`,
    `- Etapa: ${wm.procedureStage || "-"}`,
    `- NEXT ACTION: ${wm.nextAction || "-"}`,
  ].join("\n");
}

export function recordFact(f: string) {
  wm.facts.unshift(f);
  if (wm.facts.length > 10) wm.facts.pop();
}
export function setNextAction(na: string) {
  wm.nextAction = na;
}
export function setAgent(a: string) {
  wm.agent = a;
}
export function setQuest(q: string, t: string) {
  wm.quest = q;
  wm.questType = t;
}
export function setActiveSkill(s: string, stage: string) {
  wm.activeSkill = s;
  wm.procedureStage = stage;
}
export function setGoal(g: string) {
  wm.goal = g;
}
export function addFile(f: string) {
  if (!wm.files.includes(f)) wm.files.push(f);
}
export function addError(e: string) {
  wm.errors.push(e);
  if (wm.errors.length > 5) wm.errors.shift();
}
export function addRecalledMemory(id: number) {
  if (!wm.recalledMemoryIds.includes(id)) {
    wm.recalledMemoryIds.push(id);
    if (wm.recalledMemoryIds.length > 20) wm.recalledMemoryIds.shift();
  }
}
export function clearRecalledMemory() {
  wm.recalledMemoryIds = [];
}
export function getWorkingMemoryState(): WorkingMemory {
  return {
    ...wm,
    files: [...wm.files],
    errors: [...wm.errors],
    facts: [...wm.facts],
    recalledMemoryIds: [...wm.recalledMemoryIds],
  };
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "argos_working_memory",
    label: "Working Memory",
    description:
      "Lee la working memory actual (quest, agente, hechos recientes, next action). Consultar ANTES de RAG completo.",
    parameters: Type.Object({}),
    async execute() {
      return { content: [{ type: "text", text: getWorkingMemoryBlock() }], details: {} };
    },
  });
}

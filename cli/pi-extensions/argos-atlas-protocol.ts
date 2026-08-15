/**
 * ARGOS ATLAS PROTOCOL - extension para Pi CLI
 * ============================================
 * Refuerza el PROTOCOLO DE ORQUESTACION ARNES en CADA prompt (before_agent_start):
 * Atlas (sesion principal) SIEMPRE recuerda que el decide la party y delega con subagent,
 * sin que el usuario nombre agentes. Lee el roster real de ~/.config/arnes/agent-models.json.
 *
 * Instalacion: cli/argos-pi.ps1 la copia a ~/.pi/agent/extensions/argos-atlas-protocol.ts
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";

const ARNES_HOME = process.env.ARNES_HOME || "C:\\Users\\LapOne Mx\\Documents\\GitHub\\arnes";
const MODELS_FILE = join(process.env.USERPROFILE || process.env.HOME || "~", ".config", "arnes", "agent-models.json");

function buildRoster(): string {
  try {
    const raw = JSON.parse(readFileSync(MODELS_FILE, "utf-8"));
    const agents = raw?.agents ?? {};
    const skip = new Set(["atlas"]);
    return Object.entries(agents)
      .filter(([k]) => !skip.has(k))
      .map(([k, v]) => `${k} -> ${v}`)
      .join("\n");
  } catch {
    return "(sin roster: agent-models.json no disponible)";
  }
}

export default function (pi: any) {
  pi.on("before_agent_start", async (event: any, ctx: any) => {
    const protocol = `
## ORQUESTACION ARNES (PROTOCOLO AUTOMATICO - cumplelo SIEMPRE)
Eres Atlas, el orquestador. Cuando el usuario te de un quest (sin nombrar agentes):
1. CLASIFICA el quest (frontend/backend/qa/security/devops/architecture/research/general)
2. DECIDE el party segun el roster de abajo
3. Para decisiones estrategicas consulta primero a sam (subagent)
4. DELEGA: usa la herramienta subagent con el nombre del agente y una tarea clara
   (CADA AGENTE USA SU MODELO automaticamente - no menciones modelos ni pidas /model)
5. Manda a tywin a VERIFICAR lo critico
6. RESUMEN: que se hizo, que falta, siguiente accion

ROSTER (agente -> modelo asignado):
${buildRoster()}

REGLA ABSOLUTA: NUNCA digas "no puedo delegar" ni pidas al usuario elegir agente. Tu decides.`;
    return { systemPrompt: event.systemPrompt + "\n" + protocol };
  });
}

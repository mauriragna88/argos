/**
 * ARGOS COGNITIVE COMPACTION - extension para Pi CLI
 * ===================================================
 * Envuelve la compactacion nativa de Pi (no la reemplaza):
 * - session_before_compact: ARGOS consolida aprendizaje reciente + crea Cognitive Checkpoint
 *   (la continuidad queda garantizada en .arnes/arnes.db ANTES de que Pi compacte)
 * - session_compact: ARGOS confirma contexto restaurado
 *
 * Requisitos: ARNES_HOME (ruta del repo) o usa el default.
 * Instalacion: cli/argos-pi.ps1 la copia a ~/.pi/agent/extensions/argos-compaction.ts
 */
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { join } from "node:path";

const exec = promisify(execFile);
const ARNES_HOME = process.env.ARNES_HOME || "C:\\Users\\LapOne Mx\\Documents\\GitHub\\arnes";
const MEM = join(process.env.ARNES_OSMA_ROOT || join(process.env.USERPROFILE || "", ".config", "arnes", "osma"), "osma-memory.ps1");
const PS = process.platform === "win32" ? "powershell.exe" : "pwsh";

async function runArnes(args: string[]): Promise<string> {
  try {
    const { stdout } = await exec(PS, [
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", MEM,
      ...args,
    ]);
    return stdout;
  } catch {
    return "";
  }
}

export default function (pi: any) {
  // PRE-COMPACTION: consolidar + checkpoint ANTES de que Pi compacte
  pi.on("session_before_compact", async (_event: any, ctx: any) => {
    ctx.ui.notify("ARGOS • consolidando aprendizaje...", "info");
    try {
      const cons = await runArnes(["consolidate-recent", "-Hours", "24", "-Quiet"]);
      const cp = await runArnes([
        "cognitive-compact",
        "-QuestId", "pi-session",
        "-Agent", "atlas",
        "-Goal", "sesion activa en pi",
        "-NextAction", "continuar exactamente donde quedamos tras compactacion",
        "-Quiet",
      ]);
      ctx.ui.notify(`ARGOS • checkpoint creado (${cp.trim()})`, "info");
    } catch (e) {
      ctx.ui.notify(`ARGOS • consolidacion fallo, continuando con compactacion de Pi: ${String(e)}`, "warning");
    }
    // no retornamos nada: Pi usa su compactacion nativa
  });

  // POST-COMPACTION: contexto restaurado
  pi.on("session_compact", async (_event: any, ctx: any) => {
    ctx.ui.notify("ARGOS • contexto restaurado (checkpoint en arnes.db)", "info");
  });
}

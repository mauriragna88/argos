import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

export function isArnesProject(cwd: string): boolean {
  return existsSync(join(cwd, ".arnes", "arnes.db"));
}

// OSMA vive en un repo separado e instalado globalmente. Resolucion:
//  1. $env:ARNES_OSMA_ROOT  2. ~/.config/arnes/osma  3. ../osma  4. ./cli (legacy)
export function resolveBrainPath(cwd: string): string {
  const home = process.env.USERPROFILE || (() => { try { return homedir(); } catch { return ""; } })();
  const candidates: string[] = [];
  if (process.env.ARNES_OSMA_ROOT) candidates.push(process.env.ARNES_OSMA_ROOT);
  if (home) candidates.push(join(home, ".config", "arnes", "osma"));
  candidates.push(resolve(cwd, "..", "osma"));
  candidates.push(resolve(cwd, "cli"));
  for (const root of candidates) {
    for (const name of ["osma_brain.py", "arnes_brain.py"]) {
      const local = join(root, name);
      if (existsSync(local)) return local;
    }
  }
  throw new Error("ARGOS: no se encontró osma_brain.py (instala OSMA: osma/install.ps1 o set ARNES_OSMA_ROOT)");
}

export async function runBrain(
  cwd: string,
  args: string[],
  stdinJson?: unknown
): Promise<{ ok: boolean; data: unknown; error?: string }> {
  const timeoutMs = 5000;
  try {
    const brain = resolveBrainPath(cwd);
    const db = join(cwd, ".arnes", "arnes.db");
    const child = spawn("python", [brain, db, ...args], {
      cwd,
      windowsHide: true,
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    if (stdinJson !== undefined) {
      child.stdin.write(JSON.stringify(stdinJson));
    }
    child.stdin.end();
    // Espera el cierre del proceso con timeout: si el hijo no termina en
    // `timeoutMs` (p.ej. un handle SQLite que no se cerró en Python), lo mata
    // para que node --test no quede colgado esperando el close.
    const timedOut = Symbol("runBrain-timeout");
    const code: number | typeof timedOut = await new Promise((resolve) => {
      const timer = setTimeout(() => {
        child.kill();
        resolve(timedOut);
      }, timeoutMs);
      child.on("close", (c) => {
        clearTimeout(timer);
        resolve(c ?? 0);
      });
      child.on("error", () => {
        clearTimeout(timer);
        resolve(-2);
      });
    });
    // Cierra los streams del hijo para que node no mantenga el event loop abierto.
    child.stdout.destroy();
    child.stderr.destroy();
    child.stdin.destroy();
    if (code === timedOut) {
      return { ok: false, data: null, error: "timeout" };
    }
    if (code !== 0) {
      return { ok: false, data: null, error: stderr.trim() || `exit ${code}` };
    }
    const trimmed = stdout.trim();
    if (!trimmed) return { ok: true, data: null };
    try {
      return { ok: true, data: JSON.parse(trimmed) };
    } catch {
      return { ok: true, data: trimmed };
    }
  } catch (e) {
    return { ok: false, data: null, error: (e as Error).message };
  }
}

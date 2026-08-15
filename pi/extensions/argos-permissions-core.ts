import { relative, resolve, join, sep } from "node:path";

export function isProtectedPath(
  cwd: string,
  absPath: string
): { protected: boolean; reason?: string } {
  const abs = resolve(absPath);
  if (abs === resolve(join(cwd, ".arnes", "arnes.db"))) {
    return {
      protected: true,
      reason: "arnes.db: toda modificación pasa por argos_memory_*",
    };
  }
  const base = resolve(cwd);
  if (abs !== base && !abs.startsWith(base + sep)) {
    return { protected: true, reason: "fuera del proyecto" };
  }
  const rel = relative(base, abs).toLowerCase().replace(/\\/g, "/");
  for (const p of [".env", "connections.json", ".git", ".arnes/config.json", ".arnes/connections.json"]) {
    if (rel === p || rel.startsWith(p + "/")) {
      return { protected: true, reason: `ruta protegida: ${p}` };
    }
  }
  return { protected: false };
}

export function isDangerousCommand(cmd: string): boolean {
  return /rm\s+-rf|del\s+\/s|format|:\(\)\s*\{\s*:\|:&\s*\}/i.test(cmd);
}

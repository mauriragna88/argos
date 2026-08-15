import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isArnesProject } from "./argos-brain.js";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    if (!isArnesProject(ctx.cwd)) return; // pi normal fuera de ARGOS (§53)
    ctx.ui.setStatus("argos", "ARGOS SUPERPOWERS • boot…");
    ctx.ui.setWidget("argos-header", [
      "ARGOS SUPERPOWERS",
      `Project: ${ctx.cwd}`,
      "Memory V3 • READY",
    ]);
    ctx.ui.setStatus("argos", "ARGOS SUPERPOWERS • Memory V3 ✓");
  });
}

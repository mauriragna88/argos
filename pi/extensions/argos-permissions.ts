import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { resolve } from "node:path";
import { isProtectedPath, isDangerousCommand } from "./argos-permissions-core.js";

export { isProtectedPath, isDangerousCommand } from "./argos-permissions-core.js";

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (isToolCallEventType("write", event) || isToolCallEventType("edit", event)) {
      const p = (event.input as { path?: string }).path;
      if (p) {
        const chk = isProtectedPath(ctx.cwd, resolve(ctx.cwd, p));
        if (chk.protected) return { block: true, reason: `[ARGOS PERMISSION] ${chk.reason}` };
      }
    }
    if (isToolCallEventType("bash", event)) {
      const cmd = (event.input as { command?: string }).command ?? "";
      if (isDangerousCommand(cmd)) {
        return { block: true, reason: "[ARGOS PERMISSION] comando destructivo bloqueado" };
      }
    }
  });
}

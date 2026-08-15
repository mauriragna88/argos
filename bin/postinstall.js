#!/usr/bin/env node
// ARNES ARGOS - postinstall: sincroniza agentes, crea conexiones globales y despliega modelos.
// Corre despues de `npm install -g arnes-argos` (o `npm install` local).
"use strict";

const { spawnSync } = require("child_process");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const isWin = process.platform === "win32";
const shell = isWin ? "powershell.exe" : "pwsh";

function runPs(scriptName, extraArgs) {
  const script = path.join(ROOT, "cli", scriptName);
  const args = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script, ...(extraArgs || [])];
  const res = spawnSync(shell, args, { stdio: "inherit", cwd: process.cwd(), env: process.env });
  return res.status === 0;
}

console.log("");
console.log("  ARNES ARGOS - Setup post-install");
console.log("  =================================");

// 1. Sincronizar agentes RPG a OpenCode (~/.config/opencode/agents)
console.log("");
console.log("  [1/3] Sincronizando agentes RPG a OpenCode...");
runPs("atlas.ps1", ["--sync"]);

// 2. Crear conexiones globales de la maquina
console.log("");
console.log("  [2/3] Conexiones globales (~/.config/arnes/connections.json)...");
runPs("argos-connect.ps1", ["init"]);

// 3. Desplegar modelos a los agentes si ya hay config global
console.log("");
console.log("  [3/3] Desplegando modelos configurados...");
runPs("argos-models-apply.ps1");

console.log("");
console.log("  [OK] Instalacion completada. Siguientes pasos:");
console.log("       argos              -> abrir el entorno (primera vez: conecta proveedores y configura modelos)");
console.log("       argos connect      -> conectar proveedores (UNA vez por maquina)");
console.log("       argos configure    -> elegir modelo por agente (UNA vez por maquina)");
console.log("       argos recommend    -> recomendacion inteligente de modelos");
console.log("");

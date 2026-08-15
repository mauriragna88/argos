#!/usr/bin/env node
// ARNES - lanzador multiplataforma de la suite de tests
// Detecta la shell y ejecuta tests/run-all.ps1 (mismo patron que bin/argos.js).
"use strict";

const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");

const ROOT = path.resolve(__dirname, "..");
const extra = process.argv.slice(2);

function detectShell() {
  if (process.platform === "win32") {
    return { cmd: "powershell.exe", flag: "-File" };
  }
  return { cmd: "pwsh", flag: "-File" };
}

function main() {
  const script = path.join(ROOT, "tests", "run-all.ps1");
  if (!fs.existsSync(script)) {
    console.error("[!] No se encontro " + script);
    process.exit(1);
  }
  const { cmd, flag } = detectShell();
  const child = spawn(cmd, ["-NoProfile", "-ExecutionPolicy", "Bypass", flag, script, ...extra], {
    stdio: "inherit",
    cwd: process.cwd(),
    env: process.env
  });
  child.on("error", (err) => {
    console.error("[!] Error lanzando la suite de tests: " + err.message);
    process.exit(1);
  });
  child.on("exit", (code) => process.exit(code === null ? 1 : code));
}

main();

#!/usr/bin/env node
// ARNES ARGOS - lanzador multiplataforma (Windows / macOS / Linux)
// Detecta la shell y ejecuta el CLI real (PowerShell) con los argumentos pasados.
"use strict";

const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");

const ROOT = path.resolve(__dirname, "..");
const args = process.argv.slice(2);

// En Windows PowerShell 5.1 viene preinstalado; en macOS/Linux se usa pwsh.
function detectShell() {
  if (process.platform === "win32") {
    return { cmd: "powershell.exe", flag: "-File" };
  }
  // macOS/Linux: buscar pwsh (PowerShell Core)
  return { cmd: "pwsh", flag: "-File" };
}

function main() {
  const script = path.join(ROOT, "cli", "argos.ps1");
  if (!fs.existsSync(script)) {
    console.error("[!] No se encontro " + script + ". Verifica la instalacion de arnes-argos.");
    process.exit(1);
  }
  const { cmd, flag } = detectShell();
  const child = spawn(cmd, ["-NoProfile", "-ExecutionPolicy", "Bypass", flag, script, ...args], {
    stdio: "inherit",
    cwd: process.cwd(),
    env: process.env
  });
  child.on("error", (err) => {
    if (err.code === "ENOENT") {
      console.error("[!] No se encontro " + cmd + ". En macOS/Linux instala PowerShell Core: https://aka.ms/powershell");
    } else {
      console.error("[!] Error lanzando argos: " + err.message);
    }
    process.exit(1);
  });
  child.on("exit", (code) => process.exit(code === null ? 1 : code));
}

main();

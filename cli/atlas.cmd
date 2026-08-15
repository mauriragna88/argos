@echo off
REM atlas.cmd - Wrapper para ejecutar Atlas Shell desde cualquier cmd/powershell
REM Se instala en $LOCALAPPDATA\Microsoft\WindowsApps\atlas.cmd (ya en PATH)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0atlas-shell.ps1" %*

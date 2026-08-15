@echo off
REM argos.cmd - Wrapper de ARGOS (entorno de los 100 ojos)
REM Lanza cli\argos.ps1. Harness en este repo; memoria en repo OSMA (mauriragna88).
set "ROOT=%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\cli\argos.ps1" %*

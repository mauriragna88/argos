@echo off
REM argos.cmd - Wrapper de ARGOS (el entorno de los 100 ojos)
REM Lanza cli\argos.ps1. Portable: funciona desde donde clones este repo.
REM Memoria en repo OSMA (mauriragna88/osma); harness en este repo argos (mauriragna88/argos).
set "ROOT=%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\cli\argos.ps1" %*

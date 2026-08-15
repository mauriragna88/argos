@echo off
REM argos.cmd - Wrapper de ARNES ARGOS (el entorno de los 100 ojos)
REM Lanza argos.ps1 que detecta proyecto, conecta proveedores, configura modelos y chatea
set "ROOT=C:\Users\LapOne Mx\Documents\GitHub\arnes"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\cli\argos.ps1" %*

# Contribuir a ARNES ARGOS

ARNES ARGOS es un harness de desarrollo con CLI PowerShell, integración con OpenCode, memoria
SQLite y 16 agentes RPG. Las contribuciones deben mantener separadas la lógica del runtime, la
documentación y los artefactos locales de una sesión.

## Preparación

```powershell
# Clona tu fork usando el botón Code de GitHub y entra al repositorio
cd arnes
npm install
argos doctor
```

Para ejecutar el código local sin instalar el binario global:

```powershell
.\cli\argos.ps1 doctor
```

## Validación

Antes de abrir un pull request:

1. Ejecuta `argos doctor` y conserva el resultado.
2. Para cambios PowerShell, valida el parseo de cada script afectado:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  (Resolve-Path '.\cli\argos-opencode.ps1'),
  [ref]$tokens,
  [ref]$errors
) | Out-Null
if ($errors.Count -gt 0) { throw $errors }
```

3. Ejecuta manualmente el flujo modificado. Para cambios de arranque, revisa también
   [`docs/ARGOS-STARTUP.md`](docs/ARGOS-STARTUP.md).
4. No incluyas claves, `connections.json`, bases SQLite locales ni configuraciones privadas.

## Cambios y pull requests

- Usa ramas descriptivas y commits pequeños por responsabilidad.
- No mezcles cambios previos del árbol de trabajo con tu fix.
- Describe el problema, la solución, los archivos afectados y las pruebas ejecutadas.
- Si modificas el CLI, incluye el sistema operativo, versión de PowerShell, comando usado y
  salida relevante.
- Para cambios de arquitectura o metodología, actualiza el spec/ADR correspondiente antes de
  implementar.

## Reportar problemas

Incluye:

- Windows/macOS/Linux y versión de PowerShell.
- Comando exacto (`argos`, `argos doctor`, etc.).
- Punto donde se detuvo y tiempo aproximado.
- Salida completa del error, sin secretos.
- Si había otra instancia de `argos` ejecutándose.

## Código de conducta

Se espera colaboración técnica respetuosa, reportes reproducibles y discusión basada en
evidencia.

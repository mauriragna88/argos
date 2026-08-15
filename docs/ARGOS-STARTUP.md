# Arranque de ARGOS

Esta guía explica qué ocurre cuando ejecutas `argos` y qué revisar si la terminal muestra el
banner y parece no avanzar.

## Flujo de arranque

El flujo normal es:

1. `bin/argos.js` localiza el proyecto y delega al CLI PowerShell.
2. `cli/argos.ps1` muestra el banner y prepara el estado del proyecto.
3. `cli/argos-opencode.ps1` sincroniza agentes, modelos y skill trees.
4. Se verifica la configuración global en `~/.config/arnes/`.
5. Se abre OpenCode con `atlas-player` como agente principal.

La sincronización actualiza archivos bajo `~/.config/opencode/agents/` y puede leer la memoria
propia de ARNES. En el primer arranque o después de cambios grandes puede tardar más porque hay
recorrido del proyecto y copia de recursos.

## Por qué puede pausarse después del banner

La sincronización escribe archivos compartidos de configuración y agentes. Antes, dos comandos
`argos` ejecutados a la vez podían intentar escribir el mismo archivo y producir errores de
archivo bloqueado en Windows.

Ahora `cli/argos-opencode.ps1` usa un mutex nombrado para serializar la sincronización entre
procesos. Si otra instancia está sincronizando, la segunda espera hasta 120 segundos; si el
proceso anterior murió, el sistema puede recuperar el mutex sin dejar archivos de lock huérfanos.

Además, `cli/argos-models-apply.ps1` evita reescribir agentes cuando el contenido no cambió.
Esto reduce el tiempo de arranques repetidos y acorta la ventana en la que los archivos están
siendo modificados.

## Diagnóstico rápido

```powershell
argos doctor
```

Comprueba PowerShell, Python/SQLite, Node/npm, OpenCode, Git, conexiones, modelos, agentes y
Docker opcional.

### El banner aparece y no avanza

1. Espera unos segundos en el primer arranque.
2. Comprueba que no haya otra instancia de `argos` ejecutándose.
3. Ejecuta `argos doctor` en otra terminal.
4. Revisa que existan `~/.config/arnes/agent-models.json` y los agentes instalados.
5. Si el problema persiste, reporta el tiempo de espera y la salida completa sin credenciales.

### Falta configuración

Ejecuta una vez:

```powershell
argos connect
argos configure
```

### OpenCode no aparece

Verifica:

```powershell
opencode --version
```

Si no está instalado, consulta la sección de requisitos del README.

## Rutas importantes

| Ruta | Propósito |
|---|---|
| `~/.config/arnes/connections.json` | Proveedores configurados globalmente |
| `~/.config/arnes/agent-models.json` | Modelo asignado a cada agente |
| `~/.config/opencode/agents/` | Agentes desplegados para OpenCode |
| `.arnes/` | Estado y memoria del proyecto |
| `cli/argos-opencode.ps1` | Sincronización y apertura de OpenCode |
| `cli/argos-models-apply.ps1` | Aplicación idempotente de modelos |

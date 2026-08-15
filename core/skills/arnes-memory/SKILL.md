---
name: arnes-memory
description: >
  Memoria cerebral del harness ARNES. Guarda y busca recuerdos de los agentes
  a traves de ARCHIVOS JSONL (`.arnes/memory/`). Anti-alucinacion por diseno:
  el agente lee HECHOS reales de su memoria antes de actuar, en vez de inventar.
  SOLO usa las herramientas `read` y `write` — sin otras herramientas.
  Trigger: Antes de trabajar, cuando necesites recordar algo de sesiones pasadas,
  cuando termines una tarea y debas guardar lo aprendido, o cuando Atlas te pida contexto.
---

## Purpose

El cerebro del harness. Cada agente tiene su namespace privado en `.arnes/memory/` y puede:
- **Leer** recuerdos relevantes ANTES de trabajar (recall selectivo = no alucinar)
- **Escribir** aprendizajes DESPUES de trabajar (memoria episodica/semantica)
- Los archivos JSONL viajan a git/backup (snapshots en `.arnes/memory/export/`)

## Como usar (solo read + write)

Toda operacion se hace con las herramientas `read` y `write` sobre archivos JSONL.
El harness sincroniza los archivos a arnes.db (import) por fuera de la skill.

### Guardar un recuerdo (despues de trabajar) — write

1. `read` `.arnes/memory/export/<tu>-memory.jsonl` (para conservar lo previo)
2. `write` `.arnes/memory/export/<tu>-memory.jsonl` con el contenido previo + UNA linea nueva:

```json
{"agent": "<tu>", "topic_key": "<tu>/<topic>", "type": "<tipo>", "content": "<leccion breve>", "quest_id": ""}
```

- `<tu>`: tu nombre (vivi, ansem, kuja, atlas...)
- `topic_key`: namespace/topic (ej: `vivi/components-built`, `ansem/rls-policies`)
- `type`: bugfix | decision | pattern | discovery | preference | verdict | recommendation | action | session_summary

Ejemplo (Vivi guarda un patron):
```json
{"agent": "vivi", "topic_key": "vivi/ui-patterns", "type": "pattern", "content": "User prefiere dark mode + rojo atlas en UI. Usar Tailwind container queries.", "quest_id": ""}
```

### Buscar recuerdos (ANTES de trabajar — anti-alucinacion) — read

1. `read` `.arnes/memory/export/<tu>-memory.jsonl` — tu memoria (snapshot)
2. `read` `.arnes/memory/export/*.jsonl` si necesitas contexto del harness completo
3. Busca en el contenido hechos relevantes (ej: "ya existe Sidebar.tsx")
   → si el hecho existe, USALO y NO reinventes ni alucines.

### Ver tu memoria completa

`read` `.arnes/memory/export/<tu>-memory.jsonl`

### Contexto reciente del harness

`read` `.arnes/memory/export/*.jsonl`

### Exportar / importar (para git/backup)

- Los archivos `.arnes/memory/export/*.jsonl` YA son el snapshot portable.
- El harness corre el export/import del CLI por fuera de la skill
  (el agente no ejecuta comandos: solo lee y escribe archivos).

## Flujo obligatorio para cada agente

### ANTES de actuar (recall — nunca alucinar):
1. `read` `.arnes/memory/export/<tu>-memory.jsonl`
2. Si encuentras un hecho (componente existente, patrón que funcionó, bug recurrente),
   ÚSALO en tu trabajo. NO reinventes lo que ya existe.

### DESPUES de actuar (guardar — memoria episodica):
1. `read` `.arnes/memory/export/<tu>-memory.jsonl`
2. `write` el archivo con el contenido previo + 1 linea JSON nueva (formato de arriba)
3. Ejemplos de topic_key:
   - `vivi/components-built` — componentes ya creados (NO recrear)
   - `vivi/ui-patterns` — patrones UI que funcionaron
   - `ansem/rls-policies` — RLS que funcionaron
   - `kuja/bugs-found` — bugs + root cause
   - `eiko/build-failures` — builds rotos + causa

## Reglas de oro

1. **Recuerda antes de actuar** — el recall es OBLIGATORIO antes de trabajo creativo
2. **Guarda despues de actuar** — el aprendizaje es OBLIGATORIO al terminar
3. **Hechos, no opiniones** — guarda lo que PASO, no lo que crees que paso
4. **Conciso pero completo** — suficiente contexto para que tu yo futuro lo entienda
5. **Namespace propio** — no escribas en el namespace de otro agente (eso es del blackboard)
6. **El 4+4=8 aplica** — si el dato es obvio y nunca cambia, no gastes tokens guardandolo
7. **SOLO read + write** — ninguna otra herramienta

## Ubicacion de archivos

- `.arnes/memory/export/*.jsonl` — memoria exportada (lo que lees/escribes; snapshot para git/backup)
- `.arnes/memory/<agente>-memory.jsonl` — memoria viva por agente (legacy, read-only)
- `arnes.db` — SQLite (cerebro del harness; el harness lo sincroniza, NO el agente)
- `cli/` — motor del harness (por fuera de la skill; el agente NO lo invoca)

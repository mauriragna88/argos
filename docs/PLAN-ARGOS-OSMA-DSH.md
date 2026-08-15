# PLAN ARGOS + OSMA + DEEPSEEK HARNESS (+ Claude)

> **Dos arneses, un solo cerebro por proyecto.**
> ARGOS orquesta · OSMA recuerda · DSH trabaja en web · Claude (futuro) como target.
> Creado: 2026-08-15 · Estado: PLAN (pendiente de ejecutar fases A-D)

---

## 1. Los 4 roles (quién es quién)

| Pieza | Tipo | Dónde vive | Desde dónde se abre | Memoria |
|---|---|---|---|---|
| **ARGOS** | Orquestador CLI | `Documents/GitHub/argos` | **Dentro del proyecto** (`argos`) | `.arnes/arnes.db` del proyecto |
| **OSMA** | Motor de memoria | `~/.config/arnes/osma/` (global) | — (lo invocan todos) | `<proyecto>/.arnes/arnes.db` |
| **DSH** (DeepSeek Harness) | Harness web | `~/deepseek-harness` | **Desde CUALQUIER ruta** (`argos target dsh`) | `.arnes/arnes.db` del proyecto elegido dentro |
| **Claude** (cuando haya suscripción) | Target de ARGOS | `~/.claude/` + proyecto | **Dentro del proyecto** (`argos target claude`) | `.arnes/arnes.db` del proyecto |

### Regla de oro: la memoria es del PROYECTO, no del harness

```
<proyecto>/
├── .arnes/
│   ├── arnes.db          ← EL CEREBRO (lo escriben TODOS)
│   ├── config.json
│   └── quest-ledger.json
```

Cualquier CLI (opencode, pi, claude, codex, dsh) lee y escribe el **MISMO**
`.arnes/arnes.db` del proyecto actual. Si cambias de harness, la memoria viaja contigo
porque está en el proyecto, no en el CLI.

### División de responsabilidades (sin solaparse)

- **ARGOS NO reemplaza a DSH**: ARGOS orquesta (party, quests, agentes, decisiones, memoria).
- **DSH NO reemplaza a ARGOS**: DSH es el harness web de sesiones DeepSeek; ARGOS/OSMA viajan
  como capa de memoria dentro de él (plugin `@arnes/dsh-argos-osma`).
- **Claude es OTRO target de ARGOS**: cuando lo actives, ARGOS le despliega la persona Atlas
  + party + memoria, igual que con opencode/codex/freebuff.

---

## 2. Estado actual (verificado 2026-08-15)

| Componente | Estado |
|---|---|
| Plugin `@arnes/dsh-argos-osma` en perfil web de DSH | ✅ Instalado (`~/.dsh/profiles/web/package.json`) |
| DSH web | ✅ Vivo en `http://127.0.0.1:3080` |
| Motor OSMA | ✅ `~/.config/arnes/osma/` (osma_brain.py + osma-memory.ps1) |
| `argos target dsh` desde cualquier ruta | ✅ Usa `$DshDir` absoluto (`~/deepseek-harness`), no depende del cwd |
| Memoria compartida per-proyecto | ✅ El plugin resuelve el root del proyecto y apunta a `<proyecto>/.arnes/arnes.db` |
| Tools `argos_*` en DSH | ✅ status, save, recall, experience record/search, cue, episode, scan |
| Hook de aprendizaje por turno (DSH → OSMA) | ✅ Registra cada turno como observación |
| `argos target claude` escribe la persona a `~/.claude/CLAUDE.md` | ⚠️ **BUG**: escribe a `~/.config/arnes/CLAUDE.md` (Claude Code NO lo lee) |

---

## 3. Plan por fases

### Fase A — DSH como harness global (desde cualquier ruta) ✅ casi listo

Objetivo: abrir la web de DSH sin importar en qué carpeta estés.

```bash
argos target dsh            # desde cualquier ruta → abre http://127.0.0.1:3080
```

Pendientes:
1. Crear wrapper global `dsh.cmd` en `AppData/Local/Microsoft/WindowsApps` (como `argos.cmd`)
   que ejecute `argos target dsh` → así `dsh` abre la web desde cualquier terminal
   sin pasar por `argos`.
2. Verificar el plugin activo: `cli/argos-dsh.ps1 -Status` (perfil `web`).

### Fase B — Memoria compartida end-to-end (prueba de oro)

Objetivo: demostrar que ARGOS, DSH y (futuro) Claude escriben/leen el MISMO `.arnes/arnes.db`.

1. En un proyecto: `argos` → guardar un recuerdo (ej. `argos quest "documenta X"` o tool save).
2. Abrir DSH web en ese mismo proyecto → usar tool `argos_recall` → debe encontrar el recuerdo.
3. (Cuando exista Claude) `argos target claude` → preguntar por ese recuerdo → mismo resultado.

Criterio de éxito: el `id` de la observación guardada es el mismo en los 3 harnesses.

### Fase C — Claude per-proyecto (cuando consigas suscripción)

Objetivo: trabajar con Claude Code + persona Atlas + memoria ARGOS, por proyecto.

1. **Corregir bug de despliegue**: `argos target claude` debe escribir la persona a
   `~/.claude/CLAUDE.md` (y el party a `~/.claude/agents/`), no a `~/.config/arnes/`.
   - En `cli/argos-target.ps1`: `Write-AtlasPersona`/`Write-ClaudeParty` usan `$TargetDir`
     que por defecto es `~/.config/arnes`; debe apuntar a `~/.claude` para el target claude.
2. Asegurar que Claude Code lea la memoria: la persona desplegada referencia
   `.arnes/arnes.db` (el CLI de memoria queda accesible por archivo).
3. `argos target set claude` para dejar Claude como default (opcional).

### Fase D — Reglas de convivencia (anti-solapamiento)

1. **ARGOS** se abre dentro del proyecto (necesita el contexto del proyecto para orquestar).
2. **DSH** se abre desde cualquier ruta (dentro de SU harness eliges el proyecto → la sesión
   lleva ese cwd → el plugin apunta a la memoria correcta).
3. **Claude** se abre dentro del proyecto (igual que ARGOS).
4. Ningún harness escribe sobre la memoria del otro: todos comparten el mismo `.arnes/arnes.db`.
5. Si DSH ya está vivo en `:3080`, `argos target dsh` no abre un segundo servidor
   (ya implementado: detecta el puerto y solo abre el navegador).

---

## 4. Comandos de uso diario

| Quiero... | Comando |
|---|---|
| Orquestar en un proyecto | `argos` (dentro del proyecto) |
| Abrir la web de DeepSeek Harness (desde cualquier ruta) | `argos target dsh` (o `dsh` cuando exista el wrapper) |
| Ver estado del proyecto | `argos status` |
| Ver memoria del proyecto | `argos memory stats` |
| Instalar/ver plugin DSH | `cli/argos-dsh.ps1 -Status` |
| Trabajar con Claude (cuando haya suscripción) | `argos target claude` (dentro del proyecto) |
| Cambiar target default | `argos target set <opencode\|codex\|claude\|freebuff\|dsh>` |

---

## 5. Fixes pendientes (acción concreta)

- [x] **Fase A.1**: wrapper global `dsh.cmd` → `argos target dsh` (2026-08-15)
- [x] **Fase C.1**: `argos target claude` → persona a `~/.claude/CLAUDE.md` + party a `~/.claude/agents/` (2026-08-15)
- [x] **Fase B**: prueba end-to-end de memoria compartida (ARGOS → DSH → Claude) (2026-08-15)

## 7. Independencia ARGOS ↔ OSMA (implementado 2026-08-15)

ARGOS y OSMA son repos independientes: cada uno funciona solo, y juntos se complementan.

- **ARGOS solo (sin OSMA)**: el harness funciona en modo degradado — `Get-OsmaMemoryCli`
  devuelve un stub no-op (`cli/osma-memory-noop.ps1`) que absorbe las llamadas de memoria
  sin romper; `argos doctor` reporta `Memoria OSMA: no instalado`; `argos memory` avisa;
  `argos party` (tracking quest/tareas) aborta con instrucciones porque necesita OSMA real.
- **ARGOS + OSMA juntos**: se resuelven solos (`~/.config/arnes/osma` o repos hermanos
  `../osma`); `argos status` muestra el scan `osma-scan-projects` (cuántos proyectos tienen
  ARGOS+OSMA y su memoria); `argos osma-install` instala el motor en un paso.
- **Nuevos comandos**: `argos osma-install` (instala OSMA), `argos doctor` (check de memoria),
  menú `[O]` para instalar memoria.
- **README**: documenta las 2 formas de bajar los repos (repos hermanos vs OSMA global) y
  el comportamiento standalone vs complemento.
- **Fix en tests**: `tests/run-all.ps1` limpiaba mal `$LASTEXITCODE` entre etapas (bug
  preexistente) — ahora cada etapa arranca con exit code 0, el parseo de scripts reporta
  correcto.

### Fallos de tests preexistentes (NO causados por esta integración)

- Unit tests TS (`tests/unit/capsule.test.ts`) — falla en base (con stash)
- `tests/arnes-graph.tests.ps1` — referencia rota: el archivo no existe
- Política read/write de skills — SKILL.md usa `npm run`/`tsc` (regla del repo)
- Smoke test — `loop-engine chain auto-next` falla en base

---

## 6. Qué NO hacer (anti-patterns)

- NO ejecutar `argos target dsh` esperando que abra un CLI: abre la web (`:3080`).
- NO crear `.arnes` manualmente por proyecto: `argos` lo auto-inicializa al abrir.
- NO usar DSH para orquestar el party de ARGOS: DSH es el harness web, ARGOS el orquestador.
- NO apuntar el wrapper `argos.cmd` a otro repo: debe apuntar a `Documents/GitHub/argos`.

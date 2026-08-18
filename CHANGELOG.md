# Changelog

Todos los cambios relevantes de ARNES ARGOS se registran en este archivo.

## [Unreleased]

### Añadido

- **Modo autónomo por objetivo** (`argos goal <objetivo>` / `/autowork <objetivo>` / "atlas activa
  modo automático <objetivo>"): encadena ciclos completos hasta lograr el objetivo. FAIL/RETOQUE →
  la remediation de Tywin genera el siguiente prompt; PASS → siguiente paso incremental; termina con
  GOAL_COMPLETE, límite de iteraciones o `/autowork stop`/Ctrl+C. Estado persistente en
  `.arnes/goal-state.json` con reanudación (`-Resume`).
- **Decisiones de Atlas con memoria**: cada iteración inyecta el historial del objetivo
  (CONTEXTO DE MEMORIA) a la decisión de Atlas; cada agente guarda qué entregó
  (`<agente>/executions/`), Tywin sus verdicts y Atlas un debrief (`atlas/debriefs/<quest>`).
- **Varys como guardián de la secuencia**: el ciclo compila una bitácora ordenada (quién hizo
  qué y en qué orden), la guarda en memoria (`varys/evidence-packs/<quest>`), la incluye en
  cada reporte y la entrega como contexto de memoria para la siguiente decisión de Atlas.
- `argos target`: selector de entorno de trabajo — abre OpenCode, Codex o Claude con el
  entorno ARNES cargado (personas/agentes/memoria). Default persistido en
  `~/.config/arnes/target.json`; `argos target set <nombre>`, `argos target list`,
  `argos target <nombre> [quest]`.
- **Target Google CLI agy** (`argos target agy`): despliega la persona Atlas y el party a `AGENTS.md` del proyecto y `~/.gemini/GEMINI.md`, valida la conexión con OSMA y lanza `agy --model gemini-3.7-flash-high`.
- **Freebuff como target** (`argos target freebuff`): despliega la persona Atlas + roster del
  party a `AGENTS.md` del proyecto y abre el CLI de Freebuff (gratuito, sin API keys),
  detectado automáticamente en `argos target list` / `auto` y reportado por `argos doctor`.
- `argos stats`: dashboard de actividad (quests, tokens, tasa de éxito, racha, top agentes).
- `argos xp`: ranking de experiencia por agente con niveles.
- `argos theme`: gestión de temas visuales (atlas/vivi/amarant/eiko/auron).
- Niveles XP visibles en `/party` (chat) y en `argos status`.
- Suite de tests unificada: `npm test` (unit TS + funcionales PS + política read/write +
  parseo de scripts + escaneo de secretos + smoke test).
- CI en GitHub Actions (Windows PowerShell 5.1 + Ubuntu/pwsh) con `tests/run-all.ps1`.
- Test del grafo de relaciones (`arnes-graph`) contra SQLite real.
- Test de contrato de orquestación (`arnes-cycle` / `argos-party` / `arnes-engine`) sin llamadas reales.
- Escáner de secretos sobre archivos rastreados (`tests/scan-secrets.ps1`).
- Grafo activado: seed de edges reales del proyecto en `.arnes/graph/edges.jsonl`.
- Doctor más honesto: reporta el nombre de los agentes faltantes.
- `evenatan-ui.ps1` marcado como legado/deprecado (el CLI activo es `argos`).

### Corregido

- Se serializó la sincronización de `argos` con un mutex nombrado para evitar colisiones entre
  dos procesos que actualizan los agentes de OpenCode al mismo tiempo.
- La aplicación de modelos dejó de reescribir archivos de agentes cuando el contenido generado
  es idéntico al existente, reduciendo el tiempo de arranque repetido.
- Tests unitarios TypeScript: imports ESM corregidos (se ejecutan con `node --test` + `tsx`).

### Documentación

- Se aclaró el estado actual del proyecto y la separación entre capacidades implementadas y
  roadmap.
- Se añadió la guía técnica de arranque, contribución y diagnóstico para GitHub.

## Historial

Las funcionalidades anteriores están descritas en `README.md`, `docs/PLAN-ARNES.md` y
`docs/WHAT-IS-LEFT.md`. Las versiones publicadas se añadirán aquí cuando exista un release.

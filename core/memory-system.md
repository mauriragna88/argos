# Sistema de Memoria ARNES (arnes.db)

> La memoria cerebral del harness: 100% local, SQLite + FTS5, CERO dependencias externas.
> Cada agente guarda y consulta SU memoria con namespace propio.

## Arquitectura

| Pieza | Descripción |
|---|---|
| `cli/arnes_brain.py` | Motor: SQLite + FTS5 (búsqueda full-text instantánea) |
| `cli/arnes-memory.ps1` | CLI: `init`, `save`, `search`, `context`, `agent`, `export`, `import`, `stats`, `quest`, `edge` |
| `cli/arnes-graph.ps1` | Capa de relaciones (edges) + BFS path-finding |
| `.arnes/arnes.db` | Base de datos (hipocampo: hechos y recuerdos) |
| `.arnes/memory/export/*.jsonl` | Snapshot portable para git/backup |

## Namespaces por agente

Cada agente tiene su namespace propio (ej: `vivi://ui-patterns`, `ansem://api-schemas`).
Atlas consulta la memoria de un agente sin cargar todo el historial.

## Comandos

```powershell
.\cli\arnes-memory.ps1 init                          # crear arnes.db (schema + FTS5)
.\cli\arnes-memory.ps1 save -Agent vivi -Topic vivi/ui-patterns -Type pattern -Content "Usuario prefiere dark mode"
.\cli\arnes-memory.ps1 search -Query "dark mode" -Agent vivi
.\cli\arnes-memory.ps1 agent -Agent vivi            # contexto del agente
.\cli\arnes-memory.ps1 context                       # contexto reciente del harness
.\cli\arnes-memory.ps1 export -OutDir .arnes/memory/export
.\cli\arnes-memory.ps1 stats
```

## Reglas de uso

1. **Guardar**: al terminar un quest, corregir un bug o tomar una decisión → `save` con `-Type` correcto
   (`bugfix`, `decision`, `pattern`, `discovery`, `preference`, `verdict`, `recommendation`, `action`).
2. **Consultar ANTES de actuar**: anti-alucinación por diseño — el agente busca HECHOS en su memoria
   antes de responder o implementar.
3. **Snapshot**: `export` genera JSONL que se commitea para backup/continuidad entre sesiones.
4. **Grafo**: `arnes-graph.ps1 add/query/neighbors/path` para relaciones entre componentes,
   librerías y agentes ("quién tocó X", "qué depende de Y").

## Continuidad entre sesiones

- Al cerrar sesión: cada agente guarda su digest (`arnes-memory.ps1 save -Topic <agente>/digest-<fecha>`).
- El repositorio guarda los JSONL exportados como snapshot portable.

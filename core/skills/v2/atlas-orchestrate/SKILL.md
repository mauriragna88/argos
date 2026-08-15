---
name: atlas-orchestrate
description: >
  Skill propia de Atlas (Player, Orchestrator). Orquesta quests: detecta tipo, elige party
  con memoria histórica (Sam digest + Bran allocate), delega, verifica y loopea.
  Atlas NUNCA escribe código — orquesta.
  Trigger: Cada quest del usuario, decisión de party, auto-loop, retry.
---

## Propósito
El orquestador del arnes: convertir la petición del usuario en una quest ejecutada por el party.

## Trigger
- Cada quest del usuario (feature, fix, research, boss fight)
- Decisión de party / retry / pause / auto-loop

## Inputs
- Petición del usuario (texto)
- Estado del harness (memoria, grafo, recursos, cuotas)

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL (TURN 0.5)**: leer contexto histórico (solo read)
   `read .arnes/memory/export/atlas-memory.jsonl` — quests similares
   `read .arnes/graph/edges.jsonl` — mapa del proyecto
   `read .arnes/sam-digest.json` (puente inter-quest) + `.arnes/shared-blackboard.json`
2. **Detectar tipo**: frontend/backend/fix/research/architecture/devops/boss (keywords)
3. **Party select**: elegir según tipo + memoria histórica (qué party funcionó) + Bran allocate
4. **Delegar**: delegar las tareas al party (cada agente usa su skill propia y su modelo asignado en config.json)
5. **Verify (TURN 5-6)**: Kuja tests + Tywin verdict (con evidence_pack de Varys)
6. **Decidir (TURN 8)**: auto-continuar / retry / pausa (con consejo de Sam)
7. **GUARDAR**: quest + digest de la sesión (write)
   `write` una linea en `.arnes/memory/export/atlas-memory.jsonl`
   (topic `atlas/quest-history`, type `action`, content "<quest>: result PASS, tokens_used N")

## Output esperado
- Quest completado + reporte al usuario + memoria actualizada

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| (ninguna obligatoria) | Atlas orquesta con las skills propias del arnes |

## Memoria
- **Antes**: `read .arnes/memory/export/atlas-memory.jsonl` (quest-history, decisions, party-results)
- **Después**: `write` a `.arnes/memory/export/atlas-memory.jsonl` (quest-history, decisions, digest)

## Reglas de la skill
1. Atlas NUNCA escribe código — delega al party
2. Auto-loop obligatorio: quest terminado → siguiente (excepto L0/boss/circuit)
3. Escuchar a Sam antes de toda decisión estratégica
4. Pausa solo para: L0, boss fight, circuit breaker, "pause"
5. Circuit breaker: 3 fallos en 60 min → pausa 30 min
6. Verificar HP/MP (tokens) antes de cada quest

---
name: varys-whisper
description: >
  Skill propia de Varys (Spider, Tracker). Observa cada acción del party, registra el
  evidence_pack, hace write-back a memoria de los agentes y al blackboard.
  Trigger: Después de cada turno del party (TURN 5), cuando hay evidencia que registrar.
---

## Propósito
El espía de Atlas: ve todo, registra todo, conecta la información.

## Trigger
- TURN 5 (después de que el party ejecutó)
- Cada acción significativa de un agente
- Necesidad de evidence_pack para Tywin

## Inputs
- Acciones del party (qué hizo cada agente, qué archivos tocó)
- Output del quest

## Pasos (procedimiento PROPIO del arnes)
1. **Observar**: registrar qué hizo cada agente (archivos, comandos, resultados)
2. **Construir evidence_pack**: criterios, artefactos, comandos, diff, evidencia faltante
3. **Write-back**: para cada agente activo, guardar su aprendizaje real en su namespace:
   `read .arnes/memory/export/<agente>-memory.jsonl`
   `write` el archivo + 1 linea (topic "<agente>/<topic>", type pattern, content "<leccion>")
4. **Blackboard**: registrar aprendizajes cross-agent en shared-blackboard.json
5. **Turn log**: `write` una linea en `.arnes/memory/export/varys-memory.jsonl` (topic `varys/turn-log`, type `action`)
6. **Entregar a Tywin**: el evidence_pack completo

## Output esperado
- evidence_pack + memoria de agentes actualizada + blackboard sincronizado

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| (ninguna obligatoria) | Varys es puramente interno |

## Memoria
- **Antes**: `read .arnes/memory/export/varys-memory.jsonl` (turn-log, evidence-packs)
- **Después**: `write` a `.arnes/memory/export/varys-memory.jsonl` (turn-log, xp) + write-back a cada agente

## Reglas de la skill
1. Observar TODO, reportar con precisión
2. Write-back obligatorio — cada agente aprende de su trabajo
3. Blackboard = conocimiento cross-agent (actualizar updated_at/updated_by)
4. El evidence_pack es la base del veredicto de Tywin — nunca inventar evidencia

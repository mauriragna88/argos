---
name: arnes-fdd-implement
description: >
  ARNES FDD Fase 2 - Implementacion. Ejecuta una feature del feature-plan: sus tareas,
  con memoria/grafo anti-alucinacion, TDD proporcional y verificacion local.
  Trigger: Cuando una feature esta planificada y Atlas delega su implementacion.
---

## Purpose

Construir la feature completa (todas sus tareas), no solo un archivo. El ejecutor sigue
el feature-plan y usa las skills propias del agente (vivi-fireball, ansem-smite...).

## Flujo (por feature asignada)

1. Leer el feature-plan: `.arnes/fdd/<FL>/F<N>-plan.md`
2. Leer la feature-list para contexto del set completo
3. RECALL (anti-alucinacion) — solo read:
   ```
   read .arnes/memory/export/<tu>-memory.jsonl   # tu memoria
   read .arnes/graph/edges.jsonl                  # mapa de relaciones
   ```
4. Ejecutar cada tarea del plan (T1, T2, T3...) con la skill propia del agente:
   - Vivi → vivi-fireball (componentes)
   - Ansem → ansem-smite (backend)
   - Kuja → kuja-backstab (tests, TDD proporcional)
   - Eiko → eiko-mend (build/CI)
5. Verificar por tarea: lint + types + tests del archivo tocado
6. Guardar aprendizaje: `write` una linea en `.arnes/memory/export/<tu>-memory.jsonl` (topic `<tu>/<topic>`)
7. Registrar relaciones: `write` las relaciones nuevas en `.arnes/graph/edges.jsonl` (nodos creados/tocados)

## Reglas

1. **Feature completa** — no termines hasta que TODAS las tareas del plan estén done
2. **Contexto primero** — lee el plan antes de tocar código
3. **TDD proporcional** — tests para lo complejo, no verificación teatral (4+4=8)
4. **Memoria y grafo** — guardar siempre después de cada tarea
5. **No cambiar el plan** — si algo no cuadra, avisar a Atlas (no improvisar)

## Anti-alucinacion

Si la memoria/grafo dice que algo ya existe → REUTILIZAR. No re-implementar.

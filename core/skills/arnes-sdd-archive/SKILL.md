---
name: arnes-sdd-archive
description: >
  ARNES SDD Fase 7 - Archivo. Cierra el change: sincroniza el spec a documentacion,
  registra la memoria final, marca el change como archived y limpia el estado activo.
  Trigger: Cuando verify emitio PASS y Atlas aprobo el cierre.
---

## Purpose

La fase **archive** cierra el ciclo SDD. El change queda documentado, la memoria actualizada,
y el grafo refleja las relaciones finales. El siguiente cambio puede comenzar limpio.

## Flujo

1. Verificar que verify emitio PASS (o FAIL aceptado por Atlas con deuda documentada)
2. Registrar el quest final (write):
   ```
   read .arnes/memory/export/atlas-memory.jsonl
   write .arnes/memory/export/atlas-memory.jsonl
     (contenido previo + 1 linea: {"agent":"atlas","topic_key":"atlas/quest-history","type":"action","content":"Change C-XXX PASS, party:[<agentes>], tokens:<N>"})
   ```
3. Guardar resumen en memoria:
   ```
   write una linea en .arnes/memory/export/atlas-memory.jsonl
     (topic "atlas/quest-history", type action, content "Change C-XXX completado: <resumen>")
   ```
4. Actualizar grafo (si quedaron relaciones sin registrar):
   ```
   read .arnes/graph/edges.jsonl
   write .arnes/graph/edges.jsonl
     (contenido previo + 1 linea por relacion: {"source":"<X>","target":"<Y>","relation":"...","agent":"<agente>"})
   ```
5. Marcar todos los archivos del change con Estado: `archived`
6. Exportar snapshot: los JSONL de `.arnes/memory/export/` YA son el snapshot
   (el harness sincroniza a arnes.db por fuera de la skill)
7. Reportar a Atlas: change archivado con resumen

## Reglas

1. **Nada de archivar sin verify** — un change sin verify no existe (gate inalterable)
2. **Memoria final obligatoria** — el quest queda en arnes.db para siempre
3. **Grafo al dia** — las relaciones finales deben estar registradas
4. **Export JSONL** — los JSONL de `.arnes/memory/export/` son el snapshot portable (write directo)
5. **Actualizar docs** — si el change afecta documentacion, se refleja en docs/

## Criterios de "archived" (todo cumplido)

- [ ] verify PASS (o deuda documentada y aceptada)
- [ ] Quest registrado (write a .arnes/memory/export/atlas-memory.jsonl)
- [ ] Memoria guardada (atlas/quest-history)
- [ ] Grafo actualizado
- [ ] JSONL actualizado (snapshot .arnes/memory/export/)

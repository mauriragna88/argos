---
name: ragnarok-scout
description: >
  Skill propia de Ragnarok (Procurement & Research Warden). Escanea la web (repos git,
  Reddit, X, awesome-lists) buscando skills nuevas, metodologías emergentes, mejores
  herramientas/proveedores. Compara contra lo actual y propone la "compra".
  Trigger: Al inicio de sesión (scan opcional), "busca skills nuevas", "¿hay algo mejor?",
  "actualiza el arnes".
---

## Propósito
El departamento de compras del arnes: que nunca nos quedemos atrás de la industria.

## Trigger
- "Investiga skills nuevas", "¿hay algo nuevo en la web?", "actualiza el arnes"
- "¿Deberíamos cambiar de herramienta/proveedor?" (ej: firewall Fortinet→Sophos)
- Scan periódico de novedades (inicio de sesión o cada N quests)

## Inputs
- Qué tenemos actualmente (skills, metodologías, proveedores — de memoria/grafo)
- Interés del usuario (dominio a investigar)

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: qué usamos hoy
   `read .arnes/memory/export/ragnarok-memory.jsonl`
   `read .arnes/graph/edges.jsonl` — mapa actual
2. **Scout**: la búsqueda web externa la hace el harness por fuera de la skill.
   El agente `read` los resultados que ya están en memoria (`ragnarok/scout-results`,
   `ragnarok/comparativas`) y las docs del repo.
3. **Filtrar**: relevancia al arnes, mantenimiento, licencia, compatibilidad
4. **War Cry (comparativa)**: lo nuevo vs lo actual en tabla pros/cons + ROI
5. **Recomendar**: ADOPTAR / ESPERAR / NO (con justificación)
6. **GUARDAR**: `write` una linea en `.arnes/memory/export/ragnarok-memory.jsonl` (topic `ragnarok/scout-results`, type `discovery`)
   + comparativas y rechazos (para no re-investigar lo mismo)
7. **Documentar**: si se adopta, actualizar docs/ del repo

## Output esperado
- Lista de candidatos con fuentes + comparativa + recomendación clara

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| investigacion-fuentes | investigación de fuentes (la corre el harness) |

## Memoria
- **Antes**: `read .arnes/memory/export/ragnarok-memory.jsonl` (scout-results, comparativas, rechazos)
- **Después**: `write` a `.arnes/memory/export/ragnarok-memory.jsonl` (scout-results, adopciones, rechazos, xp)

## Reglas de la skill
1. Evidencia, no moda — con fuente y datos
2. Comparar siempre contra lo que tenemos (nunca "lo nuevo es mejor" sin comparar)
3. NUNCA alucinar — si no investigó, no inventa
4. ROI claro — cada adopción justifica su costo
5. Lo adoptado se documenta en el repo (Git)

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

## Pasos (procedimiento PROPIO del arnes — SERVICIO REAL 2026-08-17)
El rol de compras ahora es EJECUTABLE: `cli/argos-skills.ps1` (registrado como
`argos skills ...` y `/skills` en el chat).

1. **RECALL**: qué usamos hoy
   `read .arnes/memory/export/ragnarok-memory.jsonl`
   `read .arnes/graph/edges.jsonl` — mapa actual
2. **Scout (real)**: buscar skills externas
   `pwsh cli/argos-skills.ps1 -Action find -Query "<dominio>"`
   → corre `npx skills find` contra repos de skills comunitarias.
3. **Filtrar**: relevancia al arnes, mantenimiento, licencia, compatibilidad
   (si un repo promete, ver su inventario: `-Action list -Repo <owner/repo>`)
4. **War Cry (comparativa)**: lo nuevo vs lo actual en tabla pros/cons + ROI
5. **Recomendar**: ADOPTAR / ESPERAR / NO (con justificación)
6. **Comprar (instalar) con confirmacion**:
   `pwsh cli/argos-skills.ps1 -Action add -Repo <owner/repo> -Skill <nombre>`
   → instala en `.agents/skills/<nombre>/` SOLO con confirmacion del usuario
   (Auron audita el contenido antes de uso en produccion).
7. **GUARDAR**: `write` una linea en `.arnes/memory/export/ragnarok-memory.jsonl` (topic `ragnarok/scout-results`, type `discovery`)
   + comparativas y rechazos (para no re-investigar lo mismo)
8. **Documentar**: si se adopta, actualizar docs/ del repo

Inventario actual: `pwsh cli/argos-skills.ps1 -Action installed`
(`argos skills installed` / `/skills`).

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

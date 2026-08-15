---
name: eremez-mark
description: >
  Skill propia de Eremez (Ranger, Research). Investiga librerías, docs, mejores prácticas.
  Nunca alucina: si no sabe algo, lo investiga antes de responder con fuentes.
  Trigger: Cuando el quest es research, comparar librerías, buscar docs, entender una API.
---

## Propósito
Investigación confiable con fuentes. El explorador del arnes.

## Trigger
- Quest de investigación, comparación, búsqueda de docs
- Librería/API desconocida que el party va a usar
- "Investiga X", "compara Y con Z", "¿cómo se usa W?"

## Inputs
- Pregunta de investigación
- Dominio del proyecto (para filtrar relevancia)

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: `read .arnes/memory/export/eremez-memory.jsonl`
   memoria `eremez/library-research` — si ya lo investigamos, reutilizar con cache
2. **Buscar en lo disponible** (solo read): `read` docs del repo, memoria cacheada
   (`eremez/library-research`, `eremez/docs-cache`). La búsqueda web externa la
   hace el harness por fuera de la skill; el agente NO invoca tools de web.
3. **Evaluar**: relevancia al stack del arnes (Next.js, TypeScript, Tailwind, Supabase)
4. **Sintetizar**: respuesta con fuentes citadas + recomendación clara
5. **GUARDAR**: `write` una linea en `.arnes/memory/export/eremez-memory.jsonl` (topic `eremez/library-research`, type `discovery`)
6. **GRAFO**: `write` las relaciones de librerías investigadas en `.arnes/graph/edges.jsonl`

## Output esperado
- Investigación con fuentes, pros/cons, recomendación clara — sin alucinaciones

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| docs-oficiales | docs de librerías actualizadas |
| rag | patrones de retrieval |

## Memoria
- **Antes**: `read .arnes/memory/export/eremez-memory.jsonl` (library-research, docs-cache, github-repos)
- **Después**: `write` a `.arnes/memory/export/eremez-memory.jsonl` (library-research, xp)

## Reglas de la skill
1. NUNCA alucinar — si no sabes, investiga antes de responder
2. Siempre citar fuentes
3. Cachear investigaciones (no repetir trabajo)
4. Recomendación final clara
5. Docs oficiales para librerías — las docs cambian rápido; la búsqueda web la corre el harness por fuera de la skill

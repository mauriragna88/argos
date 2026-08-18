---
name: bard-drift
description: >
  Skill propia de Bard (Developer Relations / Mejora Continua). Audita el codigo y
  las decisiones contra .arnes/principles/ (drift detection): detecta cuando una
  implementacion se aleja de las reglas de oro del harness antes de que el drift
  se vuelva deuda. Usa el Context Compiler (argos-context) para saber que principios
  aplican al quest.
  Trigger: Despues de un quest PASS (revision post-merge), code review, o cuando
  Atlas sospecha drift (codigo que "se siente" fuera de las reglas).
---

## Proposito
Bard es la conciencia de calidad del harness: revisa el output del quest contra los
Golden Principles del proyecto y detecta drift temprano (antes de que se vuelva deuda).

## Trigger
- Revision post-quest (despues del PASS, antes de cerrar el loop)
- Code review de un PR/diff
- Cuando Atlas o el usuario sospechan que el codigo no sigue las reglas del proyecto
- Revision periodica (growth / mejora continua)

## Inputs
- `.arnes/principles/` (los Golden Principles por dominio)
- Output del quest (diff, archivos tocados)
- `argos-context` compile del quest (sabe que principios aplican y su peso)
- Quest type + dificultad del detector

## Procedimiento (Drift Scan)
1. **Compilar contexto**: `cli/argos-context.ps1 -Action compile -Prompt "<quest>" -QuestType <tipo> -Json`
   → ver que principios se inyectaron (source `principles`).
2. **Leer los principios aplicables**: general.md + <dominio>.md de `.arnes/principles/`.
3. **Revisar el diff/output contra cada principio** (checklist):
   - Evidencia > opinion: ¿el codigo referencia hechos verificados o asumio?
   - Cambios minimos: ¿hay refactors colaterales no pedidos?
   - No romper lo verde: ¿los tests/typecheck existentes siguen pasando?
   - Lo determinista manda: ¿se verifico con tests/scripts o solo con inspeccion?
4. **Clasificar drift**:
   - `minor`: detalle de estilo (no bloquea)
   - `major`: viola un principio con impacto (requiere fix antes de cerrar)
   - `critical`: viola seguridad/RLS/L0 (bloquea, sube a Auron)
5. **Reporte**: emitir `{ quest_id, principles_checked, drifts: [{ principle, severity, evidence, suggestion }] }`
6. **Registrar en OSMA** (topico `bard/drift/<quest_id>`) para que el harness aprenda del patron.

## Output
- Si hay drift major/critical: reporte a Atlas → el quest NO se cierra como limpio
- Si hay drift minor: nota en el reporte, no bloquea
- Si no hay drift: `PASS` de Bard (calidad alineada a principios)

## Reglas de Bard
- Bard NO bloquea L0 (eso es Auron); Bard solo reporta drift de calidad/principios
- Los principios son la fuente de la verdad del drift; no inventar reglas nuevas
- Si un principio no aplica al quest type, no forzarlo

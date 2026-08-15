# Contrato de contexto y hand-off de Atlas

Este contrato versionado establece la informacion minima intercambiada en el flujo
`Atlas → executor → Varys → Tywin → Sam → Atlas`. Complementa, pero no sustituye,
los artefactos canónicos de `atlas-advisory-handoff.md`: `evidence_pack`, `verdict`,
`remediation_brief`, `sam_counsel` y `atlas_decision`.

## Archivos

- `core/protocols/atlas-context-handoff.schema.json`: sobre de hand-off por turno.
- `core/protocols/atlas-handoff-state.schema.json`: índice persistente mínimo por quest.

La futura integración puede guardar el índice en
`.arnes/runs/<quest_id>/<attempt_id>/handoff-state.json`. Esta entrega **no crea ni
consume ese archivo en runtime**; solo define el contrato y su validación enfocada.

## Reglas no negociables

- Cada referencia de evidencia, memoria, modelo y hand-off contiene el mismo
  `quest_id` y `attempt_id` del sobre; así se rechaza evidencia de otro intento.
- Los retries crean un nuevo intento y el estado conserva `prior_attempt_refs`; no
  se reemplazan referencias de evidencia, veredicto o remediación anteriores.
- Solo se admiten los saltos de rol definidos por el esquema. Tywin no implementa y
  Sam no decide.
- `model_attribution` siempre declara agente, proveedor, modelo y razón de ruta.
- `evidence_refs` contiene referencias, no copias de diffs, logs o historias.
- `context_scope.full_history_included` DEBE ser `false`. El destinatario recibe un
  resumen breve, secciones autorizadas y referencias de memoria; recupera detalles
  solo si le hacen falta y están autorizados por su rol.
- El estado persistente indexa objetivos, dependencias, refs, atribución de modelos,
  evidencia y siguiente acción. No duplica el historial de agentes.
- Varys → Tywin exige exactamente un `evidence_pack`. Tywin → Sam exige exactamente
  un `verdict` auditado; ante `FAIL_PARTIAL` o `FAIL_TOTAL`, exige exactamente la
  referencia coincidente de un `remediation_brief`. Un FAIL sin brief no puede avanzar.

## Contexto permitido por destinatario

| Destinatario | Contexto mínimo |
|---|---|
| executor | objetivo, criterios, dependencias y ruta asignada |
| Varys | reporte del executor, artefactos y comandos |
| Tywin | evidence pack y criterios; nunca contexto para editar |
| Sam | evidence/verdict/remediación y refs de lecciones históricas |
| Atlas | consejo de Sam, refs de evidencia, estado de dependencias y siguiente acción |

Para validar el contrato de forma determinista:

```powershell
pwsh -NoProfile -File .\cli\test-handoff-contract.ps1
```

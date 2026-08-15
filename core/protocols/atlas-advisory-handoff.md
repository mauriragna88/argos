# Protocolo Atlas: evidencia, auditoria y consejo

Este es el contrato canonico entre el Party, Varys, Tywin, Sam y Atlas. Evita que un resumen narrativo reemplace la evidencia y mantiene una sola autoridad por responsabilidad.

## Flujo obligatorio

1. **Party** termina su trabajo y reporta artefactos, comandos ejecutados y resultados.
2. **Varys** genera un `evidence_pack` con criterios de aceptacion, archivos, diffs, comandos, referencias de salida y evidencia faltante.
3. **Tywin** lee ese paquete y emite un `verdict`.
4. Si el veredicto no es PASS, **Tywin** emite tambien un `remediation_brief` uno-a-uno con los checks fallidos.
5. **Varys** retransmite los artefactos sin reinterpretarlos a Sam y Atlas.
6. **Sam** consulta memoria historica y entrega un consejo: riesgos, orden y party sugerido.
7. **Atlas** registra `atlas_decision` con la accion, motivo y referencia al consejo de Sam. Puede diferir del consejo, pero debe marcarlo como override y justificarlo.
8. Todo retry conserva las referencias del intento anterior y vuelve al gate de Tywin.

## Responsabilidades

| Rol | Hace | No hace |
|---|---|---|
| Varys | Recopila, referencia y retransmite evidencia | Decide, prioriza o edita el brief |
| Tywin | Audita y describe la remediacion verificable | Escribe codigo o asigna party |
| Sam | Recomienda a partir de evidencia e historia | Decide o implementa |
| Atlas | Toma la decision operativa | Omitir el gate de auditoria |

## Artefactos minimos

### evidence_pack

```json
{
  "type": "evidence_pack",
  "quest_id": "Q-022",
  "quest_acceptance_criteria": ["criterio verificable"],
  "agents_and_outputs": [{"agent": "vivi", "files": ["src/Form.tsx"], "claim": "implementado"}],
  "commands": [{"command": "npm test", "exit_code": 0, "output_ref": "run/Q-022/test"}],
  "changed_files": ["src/Form.tsx"],
  "diff_ref": "run/Q-022/diff",
  "unavailable_evidence": []
}
```

### remediation_brief

Solo es requerido para `FAIL_PARTIAL` o `FAIL_TOTAL`. Cada check fallido tiene un item con `file`, `symbol_or_area`, `line_or_range` verificable o `unknown`, `evidence`, `expected_outcome` y `closure_validation`.

## Reglas de enforcement

- No se puede cerrar un FAIL sin `remediation_brief` valido.
- No se puede reintentar sin referencia a la evidencia y remediacion previas.
- Si falta evidencia, Varys lo declara; Tywin decide si el defecto bloquea el veredicto.
- No se puede cerrar un quest sin `sam_counsel` y `atlas_decision` coincidentes con el mismo quest.
- `finalize` solo es valido con verdict PASS; `retry`, `pause` y `escalate` conservan el quest abierto.

Detalles de rol: `core/auditors/varys.agent.md`, `core/auditors/tywin.agent.md` y `core/auditors/sam.agent.md`.

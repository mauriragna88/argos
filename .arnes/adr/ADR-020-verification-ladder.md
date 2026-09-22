# ADR-020 — Verification Ladder de Tywin

> **Fecha**: 2026-09-22
> **Autor**: Amarant (arquitectura) + Tywin (verificación)
> **Estado**: `accepted` (implementada en `core/auditors/tywin.agent.md` 2026-08-17; este ADR la formaliza y la baja a la skill)
> **Relacionado**: ADR-006 (contract audit gate), ADR-017 (contratos), ADR-019 (regressions), Fase 3

---

## Contexto

El veredicto de Tywin podía ser un PASS "por lectura" (inspección LLM) incluso cuando
existía una forma **determinista** de verificarlo (un test, un typecheck, un gate de
contrato). Eso hace el PASS no reproducible y traslada riesgo a producción.

## Decisión

Tywin verifica en **escalera de 6 niveles** y lo declara en el verdict:

| Nivel | Qué verifica | Evidencia |
|---|---|---|
| **L1** STATIC | sintaxis, tipos, lint, estructura | typecheck estricto |
| **L2** MECHANICAL | schemas, mocks, contracts | contrato API/schema valida |
| **L3** BEHAVIORAL | tests del comportamiento | test del bug pasa |
| **L4** QUEST | acceptance criteria del LOOP CONTRACT (ADR-017) | criterios cumplidos |
| **L5** ADVERSARIAL | edge cases, seguridad (romperlo) | bypass RLS intent falla |
| **L6** REGRESSION | guards del dominio siguen verdes (ADR-019) | suite de regresiones pasa |

Reglas:

- **Si existe forma determinista, el PASS exige el comando ejecutado** (`evidence_command`);
  la inspección LLM sola no basta. Un quest con test ejecutable **no puede** ser PASS por
  inspección.
- Nivel mínimo por quest type: trivial/fix → L1+L3 · frontend/backend → L1+L2+L3 ·
  architecture → L1+L4+ADR · L0 → L1+L2+L3+**L5**.
- `verification_level` va SIEMPRE en el verdict JSON (contrato de auditoría existente).
- El gate de contrato (ADR-006) entra como L1/L3 del dominio DB↔Frontend y su FAIL es FAIL.

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. PASS por inspección LLM | Rechazada: no reproducible, sin evidencia ejecutable |
| B. Exigir siempre el nivel máximo | Rechazada: costo innecesario en quests triviales |
| C. **Ladder con nivel mínimo por quest type** (ELEGIDA) | Proporcional al riesgo, con evidencia obligatoria cuando es determinista |

## Consecuencias

- `core/skills/v2/tywin-judgment/SKILL.md` incorpora la ladder al procedimiento del agente.
- Los verdicts ganan un campo comparable ⇒ la telemetría (ADR-012) puede medir
  `first_pass_success` contra el nivel alcanzado en F6 (benchmark).
- L6 conecta directo con Regression Factory (F5): los guards creados se ejecutan como nivel
  de verificación de quests del mismo dominio.

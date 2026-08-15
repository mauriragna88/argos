# ADR-006 — Contract Auditor como gate determinístico propiedad de Tywin

> **Fecha**: 2026-08-11
> **Autor**: Usuario + Sisyphus (orquestación) + Oracle (consulta arquitectura)
> **Estado**: `accepted`
> **Supersede**: (ninguno)

---

## Contexto

El usuario reporta una clase recurrente de bugs en proyectos generados por agentes IA:
el código **parece correcto** pero falla en runtime (demo/producción) porque:

1. El frontend referencia columnas que **no existen** en el schema de la DB
2. Las llaves primarias/foráneas están mal referenciadas o los tipos no coinciden
3. `database.types.ts` está desactualizado respecto a las migraciones
4. El API returna campos que el frontend no consume, o viceversa
5. `supabase-js` `.select("col_inventada")` pasa `tsc` pero explota en runtime

**Estos bugs se descubren únicamente en runtime** — cuando ya costó una sesión completa
generar el código. El ciclo de fix es caro: nueva migración → regenerar types → rewirear
frontend → retest. Además, los agentes guardan quests "exitosos" en memoria que **contienen
los patrones buggy**, reforzando la clase de bug en futuras sesiones.

El análisis del codebase ARNES reveló que **ningún agente existente** cubre validación de
consistencia DB↔API↔Frontend:

| Agente | Audita | Cross-layer? |
|---|---|---|
| Tywin | Output vs spec, per-layer checklists | No |
| Kuja | Tests unit/E2E | No contract testing |
| Auron | OWASP, RLS | Solo seguridad DB |
| Varys-doc | Doc drift | Docs, no schema |

## Decisión

**Crear `arnes-contract-audit` como skill del harness (metodología) con gate determinístico
propiedad de Tywin. NO crear un agente LLM nuevo.**

La arquitectura tiene tres partes:

1. **Skill `arnes-contract-audit`** (`core/skills/arnes-contract-audit/SKILL.md`): documento
   del procedimiento, 34 validaciones en 6 capas (L1-L6), referencia de checks IDs (C1-C34).
   Es la especificación del gate.

2. **Scripts determinísticos por proyecto** (`<project>/scripts/contract-audit/`): el motor
   real que ejecuta las validaciones. Scripts no-LLM: PowerShell + TS + SQL + Vitest. Mismo
   input = mismo output, siempre. `npm run contract:audit` como entry point único.

3. **Integración en el harness**: Tywin invoca `npm run contract:audit` como paso mandatory
   pre-verdict (patch a `tywin-judgment` y `arnes-sdd-verify`). FDD review lo requiere
   también. Auron L0 Gate lo incluye como item pre-demo/deploy.

**Fuente de verdad: migraciones**. `database.types.ts` es derivado (CI-enforced fresh).
Zod schemas son derivado. Código es derivado. Edits fluyen DOWN, nunca UP. El audit
enforces esta cadena.

## Alternativas consideradas

| Alternativa | Pros | Contras |
|---|---|---|
| **A. Nuevo agente LLM "Contract Auditor"** | Dedicado a la tarea, memory propia | Reintroduce el mismo modo de fallo (LLM alucina identificadores); costoso en tokens por validación; no puede vivir en CI sin el harness |
| **B. Extender Varys Documentalist (drift detection)** | Es el especialista en drift existente | Su scope es doc-vs-reality, no DB-vs-código; reusar su pattern sin su dominio es forzar el encaje |
| **C. Extender Tywin + tool determinístico (ELEGIDA)** | Anti-hallucination por diseño; determinista; corre en CI sin harness; reutiliza el pipeline de verdict existente | Requiere parchar 3 skills existentes; scriptes viven por proyecto (no en el harness) |
| **D. Extender arnes-graph con drift detection** | Ya modela relations (table↔component) | Es descriptivo, no audit; necesitaría query layer nuevo;达成ía menos que un script directo |

## Consecuencias

**Positivas**:
- La clase completa de bugs DB↔Frontend se captura **antes** del verdict de Tywin, no en runtime
- Determinismo: mismo schema + mismo código = mismo resultado, siempre
- CI-portable: el gate corre en GitHub Actions sin necesidad del harness
- Costo ~0 tokens por validación (vs. sesión completa de un agente LLM)
- Memoria de Tywin aprende patrones de drift por proyecto → previene recurrencia
- Fuente única de verdad (migrations) elimina la clase "types drift" estructuralmente

**Negativas / Riesgos**:
- Scripts determinísticos viven en cada proyecto target (RES, CHAT), no en el harness →
  debe mantenerse por proyecto (mitigado: skill registry menciona el setup_required)
- Requiere `supabase start` (local stack Docker) para smoke tests → más pesado que un linter
- Cobertura limitada a lo que tsc y el AST audit pueden ver estáticamente →
  strings no-literal en `.select()` son UNVERIFIABLE (regla 6 lo flag, no calla)
- Setup cost por proyecto: ~1-2 días para el gate core
- Supabase CLI versioning volátil — `gen types` output puede cambiar entre versiones

## Razón (por qué esta)

**No se puede fixar alucinación de LLM con otro LLM mirando el código.** El problema raíz
es que el modelo inventa identificadores que parecen plausibles pero no existen. Un agente
"auditor" haría exactamente lo mismo: leer el código, razonar, y concluir "sí, existe" —
con la misma confianza alucinada.

La solución alineada con la filosofía del harness ("los agentes buscan HECHOS antes de
actuar, no opiniun") es **un script que valida hechos reales**: el schema de la DB existe
o no existe; la columna referenciada está en los tipos generados o no está; el FK type
matchea el PK type o no matchea. Sin opiniones. Sin probabilidad. Determinismo puro.

Tywin ya es el engulf final que emite verdict con evidencia. El gate se acopla naturalmente
a su flujo: `evidence_pack → contract audit report → verdict`. Los check IDs (C1-C34) se
convierten en items de remediation cuando hay FAIL, siguiendo su regla existente
("FAIL sin remediation = auditoría incompleta").

---
*Memoria: al registrar, guardar en arnes.db `amarant/arch-decisions`*

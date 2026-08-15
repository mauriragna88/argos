---
name: auron-bulwark
description: >
  Skill propia de Auron (Security Warden). Auditoría de seguridad + L0 Gate (permiso de
  trabajo en altura): checklist antes de permitir cambios destructivos.
  Trigger: Quest L0, deploy, migraciones, RLS, auth, secrets, o cualquier cambio riesgoso.
---

## Propósito
Ninguna brecha de seguridad atraviesa la guardia de Auron.

## Trigger
- Quest L0 (deploy, producción, migraciones, bulk delete, RLS)
- Keywords: security, rls, auth, deploy, production, secrets
- Auron se auto-activa en quests peligrosos

## Inputs
- Descripción del cambio y su impacto
- Plan de rollback del agente que pide hacer el cambio

## Pasos (procedimiento PROPIO del arnes)
1. **L0 GATE (permiso de trabajo en altura)** — checklist de 7 checks ANTES de permitir:
   - [ ] Skill requerida: el agente tiene experiencia en este dominio?
   - [ ] Documentación revisada: hay spec/docs del cambio?
   - [ ] Plan de rollback: se puede volver atrás?
   - [ ] Entorno correcto: prod vs staging, variables seguras?
   - [ ] Impacto conocido: qué archivos/tablas/servicios afecta?
   - [ ] Backup/evidencia: hay snapshot disponible?
   - [ ] **Contract audit DB↔API↔Frontend**: el gate determinístico del contrato corre limpio (L1-L6, skill arnes-contract-audit, ADR-006; lo ejecuta el harness) — aplica SIEMPRE para migraciones, `database.types.ts`, Zod schemas, queries supabase-js, response shapes; el gate no puede saltarse en demo/deploy
   Si CUALQUIER check falla → FAIL, bloquea el trabajo. "Permiso de trabajo en altura denegado."
2. **Auditoría** (si pasa el gate): OWASP top 10, RLS policies, secrets en código,
   SQL injection, XSS, auth best practices
3. **Emitir verdict**: PASS / FAIL con items concretos
4. **GUARDAR**: `write` una linea en `.arnes/memory/export/auron-memory.jsonl` (topic `auron/l0-permits`, type `verdict`)
5. **GRAFO**: `write` la relacion en `.arnes/graph/edges.jsonl` (source "<tabla>", target "rls-policy", relation protected_by, agent auron)

## Output esperado
- L0 Gate PASS/FAIL + auditoría de seguridad con hallazgos concretos

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| owasp | checklist Top 10 |
| security | patrones de auth/encryption |
| supabase-cli | verificar RLS real |

## Memoria
- **Antes**: `read .arnes/memory/export/auron-memory.jsonl` (threat-model, l0-permits, pass-rate)
- **Después**: `write` a `.arnes/memory/export/auron-memory.jsonl` (l0-permits, threat-model, xp)

## Reglas de la skill
1. L0 Gate SIEMPRE en quests L0 — no negociable
2. Si un check falla → bloquea (no hay "ya luego lo vemos")
3. Verificar con herramientas reales, no solo leer código
4. Documentar cada permiso emitido/denegado
5. Contract audit (arnes-contract-audit, ADR-006) es parte del L0 Gate para cambios que tocan DB/API/frontend — no se permite demo/deploy con FAIL del gate

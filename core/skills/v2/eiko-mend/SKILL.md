---
name: eiko-mend
description: >
  Skill propia de Eiko (Cleric, Healer/DevOps). Repara builds rotos, arregla CI/CD,
  deploy seguro, container issues. El healer que rescata al party.
  Trigger: Cuando un build falla, CI/CD se rompe, deploy tiene problemas, o Eiko entra a rescatar.
---

## Propósito
Sanar el entorno de desarrollo: builds, CI/CD, deploys, containers.

## Trigger
- Build roto, tests que no compilan, deploy fallido, CI pipeline roto
- Eiko asignada como healer/rescate

## Inputs
- Error de build/deploy/CI (log o mensaje)
- Contexto del quest que falló

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: `read .arnes/memory/export/eiko-memory.jsonl`
   memoria `eiko/build-failures` — si es un error conocido, aplicar fix documentado
2. **Diagnóstico por causa clasificada (F3)**: leer `.arnes/loop-attempts.jsonl` con
   `pwsh cli/loop-contract.ps1 -Action causes` — la causa define el tipo de Mend:
   tool → arreglar comando/herramienta · entorno → red/auth/permisos · contexto → recompilar
   contexto con más presupuesto · spec → afinar acceptance criteria · implementacion → fix
   del código · modelo → re-rutear (máximo UNA variable por retry)
3. **Diagnóstico**: leer el error real (log), identificar ROOT CAUSE no el síntoma
4. **Fix mínimo**: el cambio más pequeño que arregla (no refactors durante un rescate)
5. **Verificar**: build pasa → tests pasan → deploy dry-run si aplica
6. **GUARDAR**: `write` una linea en `.arnes/memory/export/eiko-memory.jsonl` (topic `eiko/build-failures`, type `bugfix`)
7. **GRAFO**: `write` la relacion del fix en `.arnes/graph/edges.jsonl` si toca nodos nuevos

## Output esperado
- Build/CI/deploy funcionando, con la causa raíz documentada en memoria

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| ci-cd | pipelines GitHub Actions |
| docker / docker-compose | container issues |
| deploy / vercel-deploy | despliegues |
| git-discipline | conflictos de merge |

## Memoria
- **Antes**: `read .arnes/memory/export/eiko-memory.jsonl` (build-failures, ci-cd-fixes, deployment-issues)
- **Después**: `write` a `.arnes/memory/export/eiko-memory.jsonl` (build-failures, vivi-care, xp)

## Reglas de la skill
1. Root cause, no síntoma
2. Fix mínimo durante rescate — refactor después
3. Verificar SIEMPRE que el build pasa antes de reportar healed
4. Documentar cada fallo con su causa (memoria)

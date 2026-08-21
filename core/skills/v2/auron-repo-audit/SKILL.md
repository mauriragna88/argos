---
name: auron-repo-audit
description: >
  Skill de Auron (Security Warden): auditoría de repositorios antes de trabajar sobre
  ellos o antes de un deploy. Detecta secretos/keys expuestos en archivos trackeados por
  git, valores hardcodeados, archivos sensibles (.env) commiteados y verifica la
  visibilidad del repo (público/privado) en GitHub.
  Trigger: Quest que introduce o toca un repo (nuevo repo, fork, clon, cambios sobre
  proyecto que referencia GitHub), scan previo a commit o antes de publicar, o ver si un
  repo del harness/negocio tiene credenciales expuestas.
---

## Propósito
Ninguna clave, token o credencial viaja por commits que se publican, ni por repos
públicos, sin que Auron lo sepa antes. Llama a pensar "¿este repo que voy a tocar está
limpio y tiene la visibilidad correcta?" antes de trabajar.

## Trigger
- Nuevo repo a tocar / fork / clon / cambiar de remote
- Antes de commitear o hacer deploy sobre un repo con integraciones (Supabase, pagos, APIs)
- "audita este repo", "revisa si hay secretos subidos", "¿está público o privado?"
- Integración: paso obligatorio del L0 Gate cuando el cambio toca credenciales o repos
- Rutina periódica: revisar que los repos de negocio sigan privados y sin secrets

## Inputs
- Ruta(s) del repo a auditar (default: repo actual del quest)
- (Opcional) Saber si el repo es de negocio (debe ser privado) o harness/concurso (puede ser público)

## Pasos (procedimiento PROPIO del arnes)
1. **Memoria antes**: `read .arnes/memory/export/auron-memory.jsonl` (topic `auron/secret-audit`, `auron/threat-model`) para no repetir hallazgos ya reportados.
2. **Ejecutar el chequeo determinista**: correr el script de auditoría del harness
   `tests/repo-audit.ps1` (lo ejecuta el harness). Procesa su salida y exit code:
   - Sección 1: secretos en archivos trackeados (JWT supabase, `sb_secret_`, conekta/mp, `ghp_`/`gho_`, tokens `user_`, `sk-`, AWS, claves privadas, `api_key`/`secret`/`password` con valor, `.env` commiteados)
   - Sección 2: visibilidad del repo en GitHub (público/privado) si el remote es github.com
3. **Clasificar hallazgos**: para cada coincidencia, distinguir valor real vs placeholder
   (`xxxx`, `example`, `YOUR_`). Un valor real es CRITICAL y sube a L0.
4. **Emitir verdict** PASS/FAIL con items concretos (archivo:línea + tipo de credencial).
5. **GUARDAR**: `write` una línea en `.arnes/memory/export/auron-memory.jsonl`
   (topic `auron/secret-audit`, type `verdict` o `discovery`) con repo, visibilidad y hallazgos.
6. **GRAFO**: `write` la relación en `.arnes/graph/edges.jsonl` (source "<repo>",
   target "secret-leak", relation "exposes" | "clean", agent auron).

## Output esperado
- Verdict PASS/FAIL de la auditoría del repo + lista de hallazgos (archivo:línea, tipo, gravedad)
- Registro en memoria del estado de cada repo auditado (repo, visibilidad, resultado)

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| security / owasp | criterio de gravedad de la credencial |
| github (MCP) | si hay que inspeccionar historial/commits del remote |
| supabase-cli | verificar si una key expuesta sigue activa en prod |

## Memoria
- **Antes**: `read .arnes/memory/export/auron-memory.jsonl` (secret-audit, threat-model, l0-permits, pass-rate)
- **Después**: `write` a `.arnes/memory/export/auron-memory.jsonl` (secret-audit, threat-model, xp)

## Reglas de la skill
1. Un secret real expuesto es CRITICAL y escala a L0 — no se trabaja el repo hasta limpiar/rotar
2. Solo archivos TRACKEADOS por git cuentan (lo que se publicaría); lo ignorado/untracked se anota aparte
3. Distinguir placeholder de valor real antes de alarmar (evitar falsos positivos)
4. Repos de negocio (con pagos/BD) DEBEN estar privados; harness/concurso pueden ser públicos
5. El script determinista lo ejecuta el harness; la skill solo procesa su salida
6. **SOLO read + write** — no invoca otras herramientas en la skill
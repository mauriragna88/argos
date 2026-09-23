# ADR-024 — Code Mode (política de modos, Auron Gate, sandbox diferido)

> **Fecha**: 2026-09-22
> **Autor**: Amarant (arquitectura) + Auron (gate L0)
> **Estado**: `accepted` (router + gate implementados; sandbox real diferido por diseño)
> **Relacionado**: ADR-006 (contract gate), ADR-018 (causa), Fase 6

---

## Contexto

Algunas tareas necesitan **muchas llamadas de herramienta secuenciales** (o procesar output
grande) donde N tool-calls queman contexto; ejecutar un script local sería más barato. Pero
ejecutar código generado por el modelo es la superficie de riesgo más alta del harness
(destructivo, exfiltración, bypass de gates). El plan pide CODE_MODE **reducido** (script
local sin sandbox, con Auron Gate reforzado) y **sandbox real diferido**.

## Decisión

1. **Router de modo explícito** (`mode-route`): `DIRECT_TOOL` (1-3 llamadas) · `CODE_MODE`
   (secuencia larga ≥4 secuencial) · `AGENT` (juicio del modelo multi-paso) · `SUBAGENT`
   (partes independientes ≥6). El modo CODE_MODE expone `code_mode_requires_gate: true`.
2. **Auron Gate obligatorio sobre código generado** (`mode-route gate`): el script se audita
   ANTES de ejecutarse y se **bloquea** (exit 1) ante: `rm -rf` (incl. `/`, `~`, `*`),
   `Remove-Item -Recurse -Force` sobre raíz/home, `rmdir /s /q`, `del /f /s /q`,
   `format` de disco, `DROP TABLE/DATABASE/SCHEMA`, `TRUNCATE TABLE`, `git push --force`,
   `--no-verify`, pipe remoto a shell (`curl|bash`), `Invoke-Expression`, rutas protegidas
   (`.env`, `.ssh`, `.git`), archivos de credenciales y la memoria OSMA (`arnes.db`).
3. **Sandbox real: diferido.** Ejecutar con aislamiento (contenedor/VM) requiere decidir el
   runtime aislado y está fuera de alcance; hasta entonces CODE_MODE es **opt-in** y el gate
   es la única defensa — por eso es bloqueante, no advertente.
4. El resultado de CODE_MODE se registra en `model_runs` (F1) igual que DIRECT_TOOL, para
   comparar modos en el benchmark (ADR-026).

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Habilitar ejecución directa sin gate | Rechazada: un script "inocente" con `rm -rf` es irreversible |
| B. Sandbox real ahora | Diferida: exige decidir runtime aislado (fuera de alcance de F6) |
| C. **Router + gate bloqueante, sandbox diferido** (ELEGIDA) | Habilita el ahorro de tokens con la superficie de riesgo controlada |

## Consecuencias

- CODE_MODE no se activa solo: el router lo propone y el gate lo autoriza.
- Un intento de bypass (script que esconde lo destructivo) también se bloquea porque el gate
  lee el **texto completo** del script antes de ejecutar.
- Tests: `tests/mode-route.tests.ps1` (router + 6 familias de bloqueo + script seguro con PASS).

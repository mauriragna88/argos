# ADR-005 — Blindaje de encoding: BOM UTF-8 en todos los scripts

> **Fecha**: 2026-08-07
> **Autor**: Atlas + Usuario
> **Estado**: `accepted`

---

## Contexto

El 2026-08-07 `argos` fallaba con "El termino 'tus' no se reconoce como cmdlet" al
ejecutar cualquier quest. La causa NO era logica: era ENCODING. PowerShell 5.1 lee los
.ps1 sin BOM como ANSI (cp1252). Cualquier caracter multibyte (acentos, em-dash, flechas,
caracteres de bloque) corrompe el parseo y palabras del texto quedan interpretadas como
comandos. El texto "tus 16 agentes" del banner se convirtio en el "comando" `tus`.

## Decision

- Todos los scripts `.ps1` del harness deben tener **BOM UTF-8** (bytes EF BB BF al inicio).
- Detectado: 35 scripts sin BOM; 4 con contenido no-ASCII real (riesgo efectivo):
  `test-compaction.ps1` (285 bytes), `argos-engine.ps1`, `activate.ps1`, `atlas.ps1`.
- Corregido: los 4 con riesgo + `argos-opencode.ps1` (el que fallo) + `argos-models-apply.ps1`.
- Regla futura: al crear/editar un .ps1, escribir SIEMPRE con BOM UTF-8.
  Verificar con: `[IO.File]::ReadAllBytes($f)[0..2] -eq 0xEF,0xBB,0xBF`.

## Alternativas consideradas

| Alternativa | Pros | Contras |
|---|---|---|
| BOM UTF-8 en todos | PowerShell 5.1 lee bien; elimina la clase entera de bugs | Archivos con BOM (invisible en editores modernos) |
| Quitar caracteres especiales de los scripts | Evita el sintoma | Pierde acentos en mensajes; el problema sigue latente |
| Migrar a PowerShell 7 (pwsh) | Lee UTF-8 sin BOM nativamente | No es lo que usa el harness hoy |

## Consecuencias

**Positivas**:
- Eliminada la clase de bug "El termino X no se reconoce" por encoding
- Los mensajes con acentos/caracteres especiales se muestran correctamente

**Negativas / Riesgos**:
- Cualquier archivo nuevo debe escribirse con BOM (disciplina)
- Los archivos con BOM pueden verse con 3 bytes extra en editores muy viejos

## Actualizacion 2026-08-15 — EXCEPCION: contenido desplegado a CLIs (sin BOM)

El BOM obligatorio aplica a los **scripts `.ps1` del harness** (los lee PowerShell 5.1).
Pero los archivos de **contenido desplegado a CLIs externos** NO llevan BOM:

- `~/.claude/CLAUDE.md` y `~/.claude/agents/*.md` → Claude Code parsea frontmatter
  YAML que debe empezar exactamente en `---`; un BOM inicial rompe el parseo.
- `~/.codex/AGENTS.md` y `AGENTS.md` de freebuff → mismos motivos.
- `argos-target.ps1` escribe estos destinos con `Write-Utf8NoBom`
  (UTF8Encoding(false)), mientras los `.ps1` siguen con BOM.

Regla: **scripts .ps1 con BOM | contenido para CLIs sin BOM**.

## Razon (por que esta)

"Un bug de encoding parece un bug de logica, y cuesta horas." Blindar el encoding es
prevencion barata contra una clase de error que ya nos costo un quest hoy.

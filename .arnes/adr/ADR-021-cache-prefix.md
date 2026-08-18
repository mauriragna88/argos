# ADR-021 — Cache prefix estable (optimización de tokens)

> **Fecha**: 2026-08-17
> **Autor**: Atlas (orquestación) + Amarant (arquitectura) + Usuario (diagrama del pipeline)
> **Estado**: `accepted`
> **Relacionado**: ADR-014/015/016 (Fase 2), `cli/cache-prefix.ps1`, `cli/argos-context.ps1`

---

## Contexto

El usuario propuso el pipeline: OSMA → (memoria estable | memoria dinámica) → ARGOS →
DeepSeek V4. El objetivo es reforzar la cache y optimizar tokens. Los proveedores
(DeepSeek V4 incluido) cobran el prefix de un prompt MUCHO más barato cuando es
idéntico entre llamadas (prompt caching), pero el harness enviaba el contexto mezclado:
reglas + principios + skills + memoria + evidencia en un solo bloque que cambiaba en
cada turno → cache nunca reutilizable.

## Decisión

Separar el contexto en dos capas explícitas:

1. **PREFIX ESTABLE** (`cli/cache-prefix.ps1 build`): identidad + golden principles +
   metadata de skills (progressive disclosure). Se genera con hash SHA-256 (versión) y
   se guarda en `.arnes/cache-prefix.json`. Debe ser byte-idéntico entre turnos.
2. **PARTE DINÁMICA** (por quest): quest + contrato + evidencia + memoria reciente.
   Nunca cacheable.
3. `verify` detecta invalidación de cache (harness cambió → prefix cambió → recarga).
4. El Context Compiler marca cada fila `cacheable` (principles/skills=true,
   memory/experience/evidence=false) y reporta `tokens_stable`/`tokens_dynamic`.
5. `stats` estima el ahorro (con prefix ~2K tokens → ~70% en 10 turnos).

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Contexto todo en un bloque | Rechazada: mezcla estable+dinámico → cache nunca reutilizable |
| B. Cache prefix separado y versionado (ELEGIDA) | El prefix es contrato byte-idéntico; verify mide hit/miss |
| C. Cachear el contexto completo (todo estable) | Rechazada: la memoria/evidencia del quest DEBE cambiar por turno |

## Consecuencias

- El prefix (2K tokens) se paga ~1 vez; los turnos siguientes pagan solo dinámico.
- La cache se invalida solo cuando el harness cambia (AGENTS.md, principios, skills),
  no por cada quest.
- `.arnes/cache-prefix.json` es artefacto regenerable → gitignore.
- Medible: `stats` reporta ahorro real estimado por sesión.

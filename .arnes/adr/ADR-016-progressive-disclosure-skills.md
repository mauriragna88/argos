# ADR-016 — Progressive disclosure de skills

> **Fecha**: 2026-08-17
> **Autor**: Atlas (orquestación) + Amarant (arquitectura)
> **Estado**: `accepted`
> **Relacionado**: ADR-014 (budgets), Fase 2, ragnarok-scout (Fase skills)

---

## Contexto

Con 30+ skills (propias v2 + pi/skills + superpowers externas), listar el inventario
cargando el SKILL.md completo de cada una inyecta decenas de miles de tokens al contexto
aunque la skill no se use. `discoverSkills()` (PI) leía el archivo completo para cada
skill en cada sesión.

## Decisión

**La metadata vive en el frontmatter; el cuerpo solo se lee al activarse.**

- `readSkillFrontmatter(path)`: parsea solo el bloque `---` del SKILL.md (name,
  description, trigger), soportando descripciones YAML folded (`>`).
- `discoverSkills()` expone `{ name, source, hash, path, description, trigger }` sin
  leer el cuerpo (hash derivado de la metadata, no del contenido).
- `loadSkillContent(skill)`: lee el SKILL.md completo SOLO cuando la skill se activa.
- CLI: `argos skills meta` lista metadata de las 30+ skills sin cargar cuerpos; el
  Context Compiler la usa como fuente `skills` (metadata sola, presupuesto 250 tokens).

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Cargar SKILL.md completo por skill | Rechazada: decenas de K tokens por sesión |
| B. Metadata en frontmatter + cuerpo lazy (ELEGIDA) | Disclosure progresivo: listar = metadata; activar = cuerpo |
| C. Registry externo con descripciones curadas | Rechazada: duplicación con el frontmatter (drift) |

## Consecuencias

- El inventario de skills cuesta ~250 tokens (metadata) en vez de miles.
- La skill se carga con su contenido real al activarse (no pierde detalle).
- El hash cambió de contenido→metadata: los registros previos en arnes.db se
  re-registran con la nueva versión en la próxima sesión (sin daño, upsert).

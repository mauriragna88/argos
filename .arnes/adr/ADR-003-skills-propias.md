# ADR-003 — Skills propias v2 + skills web como complemento

> **Fecha**: 2026-08-05
> **Autor**: Usuario + Atlas
> **Estado**: `accepted`

---

## Contexto

El skill-registry original mapeaba las skills RPG a "origen externo". El usuario decidió
cero dependencia del ecosistema, pero también quiere que los agentes sean "unos cabrones" con
lo mejor de la comunidad.

## Decisión

- **Skills PROPIAS v2** (`core/skills/v2/`): el PROCEDIMIENTO es nuestro — 16 skills de los
  15 agentes con trigger, pasos propios, memoria integrada. Cero ARNES.
- **Skills web** (react, tailwind, superpowers, ui-ux-pro-max, taste-skill...): se MANTIENEN
  como COMPLEMENTO DE PODER — potencian la ejecución, nunca son dependencia obligatoria.

## Alternativas consideradas

| Alternativa | Pros | Contras |
|---|---|---|
| Solo skills web | Poder de la comunidad | Dependencia de terceros, sin identidad |
| Solo skills propias | 100% nuestros | Reinventar la rueda (superpowers tiene 258K⭐) |
| Propias + web como complemento | Identidad + poder | Hay que mapear ambas (ya hecho en skill-registry v2) |

## Consecuencias

**Positivas**:
- Los agentes tienen procedimiento propio (identidad, proceso, memoria)
- Y arsenal de la comunidad (react, tailwind, superpowers) para ejecutar mejor
- Cero ARNES en el skill-registry

**Negativas / Riesgos**:
- Las skills web instaladas siguen en el sistema (no son dependencia pero están)
- Hay que mantener el mapeo skill-registry v2 al día (Ragnarok lo vigila)

## Razón (por qué esta)

"Las skills propias son quién eres, las web son con qué peleas." Identidad nuestra +
poder de la comunidad = agentes cabrones sin depender de nadie.

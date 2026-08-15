# ADR-002 — Proceso de desarrollo propio (SDD + FDD + TDD, con metodos propios)

> **Fecha**: 2026-08-05
> **Autor**: Usuario + Atlas + Amarant
> **Estado**: `accepted`

---

## Contexto

El arnes usaba skills sdd-* del ecosistema (Agent Teams Lite) que dependen de arnes.db como
backend. El usuario decidió independencia total: proceso propio, archivos file-based,
cero ARNES.

## Decisión

Construir el proceso de desarrollo ARNES propio:
- **SDD**: arnes-sdd-* (propose → spec → design → tasks → apply → verify → archive) en `.arnes/sdd/`
- **FDD**: arnes-fdd-* (feature list → plan → implement → review → archive) en `.arnes/fdd/`
- **TDD**: dentro de la implementación (test primero, proporcional a complejidad)
- **ADR**: arnes-adr en `.arnes/adr/` (FASE 5)

## Alternativas consideradas

| Alternativa | Pros | Contras |
|---|---|---|
| Skills sdd-* del ecosistema | Ya instaladas, completas | Dependen de arnes.db + ARNES |
| Proceso propio file-based | 100% nuestro, portable | Hay que construirlo y mantenerlo |

## Consecuencias

**Positivas**:
- Independencia total — el proceso corre con archivos dentro del proyecto
- Adaptable: podemos cambiar cualquier fase sin permiso de nadie
- Conectado a memoria/grafo (cada fase guarda en arnes.db)

**Negativas / Riesgos**:
- Costo de construcción (ya pagado en FASES 3-4)
- Las skills sdd-* ajenas siguen instaladas — se remueven en FASE 6

## Razón (por qué esta)

El arnes es de nosotros: el proceso de desarrollo también. Nadie nos dice cómo trabajar.

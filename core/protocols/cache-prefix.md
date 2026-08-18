# Cache Prefix — Protocolo de optimización de tokens

> **Versión**: 1.0 · **Fase**: Post-F2 (cache reinforcement) · **Autor**: Atlas + Amarant
> **Relacionado**: ADR-021, `cli/cache-prefix.ps1`, `cli/argos-context.ps1` (Fase 2)

---

## 1. Objetivo

Reforzar la cache y optimizar tokens separando el contexto del turno en dos capas,
tal como el pipeline del proveedor las cobra distinto:

```
        OSMA (memoria)
           │
   ┌───────┴────────┐
   │                │
 ESTABLE         DINÁMICA
 (prefix)         (por quest)
   │                │
   └───────┬────────┘
           ▼
        ARGOS
           ▼
     DeepSeek V4 (cache de prefix automático)
```

- **ESTABLE** (cache prefix): identidad + golden principles + metadata de skills.
  Idéntico byte a byte entre turnos → el proveedor lo cachea y los turnos
  siguientes solo pagan la parte dinámica (precio de cache).
- **DINÁMICA**: quest actual + contrato + evidencia + memoria reciente.
  Cambia en cada turno → nunca cacheable.

## 2. Regla de oro: el prefix debe ser BYTE-IDENTICO

El prompt caching del proveedor funciona por **prefijo idéntico**: un espacio, un
salto de línea o un cambio de orden entre turnos invalida la cache completa y el
siguiente turno paga el prefix entero a precio normal.

**Reglas de estabilidad:**
1. El prefix se genera con `cache-prefix.ps1 build` → versión = hash SHA-256 de la
   concatenación exacta de secciones.
2. NUNCA se interpola nada dinámico dentro del prefix (no fechas, no quest ids,
   no nombres de archivo del turno).
3. `cache-prefix.ps1 verify` compara el hash actual contra el del turno anterior:
   - `ESTABLE` → el proveedor reusa la cache (solo pagas dinámico)
   - `CAMBIO` → la cache se invalidó; el próximo turno paga prefix completo.
4. Si algo del harness cambia (AGENTS.md, principios, skills), `build` regenera y
   `verify` lo reporta como cambio esperado (una vez, no por turno).

## 3. Layout del prefix (orden fijo, NO reordenar)

```
== ARGOS CACHE PREFIX - section: identity ==
(bloque de identidad de core/atlas-player.agent.md)

== ARGOS CACHE PREFIX - section: principles ==
(.arnes/principles/general.md + <dominio>.md)

== ARGOS CACHE PREFIX - section: skills ==
(metadata de skills - progressive disclosure, sin cuerpos)
```

Cambiar el ORDER de las secciones = invalidar cache. El orden es contrato.

## 4. Integración con el Context Compiler

`argos-context.ps1` marca cada fila con `cacheable`:
- `cacheable=true`: principles + skills (estables) → cuentan en `tokens_stable`
- `cacheable=false`: memory + experience + evidence (dinámicos) → `tokens_dynamic`

El output del compile reporta `tokens_stable` / `tokens_dynamic` para que el
pipeline sepa cuánto del contexto es recargable de cache por turno.

## 5. Estimación de ahorro

`cache-prefix.ps1 stats` calcula el ahorro teórico en N turnos:

```
sin cache:  (prefix + dinámico) × N
con cache:  prefix (1 vez) + dinámico × N
```

Con prefix ~2K tokens y ~500 dinámicos por turno → **~70% de ahorro en 10 turnos**.

## 6. Comandos

| Comando | Acción |
|---|---|
| `argos cache build` | Regenera el prefix y su hash (tras cambios en harness) |
| `argos cache verify` | Verifica estabilidad vs turno anterior (cache hit/miss) |
| `argos cache stats [turns]` | Ahorro estimado con caching en N turnos |
| `/cache` (chat) | stats del cache prefix |
| Orquestador Step 1.8 | Muestra ESTABLE/CAMBIO antes de cada quest |

## 7. Qué NO hacer

- NO meter datos dinámicos en el prefix (invalida cache por turno)
- NO reordenar las secciones (el orden es parte del hash)
- NO confiar en el caching sin `verify` (el proveedor cachea, nosotros medimos)
- NO tocar el brain OSMA: la memoria sigue en OSMA, el prefix es construcción ARGOS

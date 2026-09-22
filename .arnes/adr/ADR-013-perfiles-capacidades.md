# ADR-013 — Perfiles de capacidades AGENT ≠ MODEL

> **Fecha**: 2026-09-22
> **Autor**: Amarant (arquitectura)
> **Estado**: `accepted` (formato decidido; contenido se llena en F3+ con datos)
> **Relacionado**: ADR-011 (scoring), ADR-012 (telemetría), ADR-004 (modelos por token)

---

## Contexto

Hoy `agent-models.json` ata **directamente** agente→modelo: cambiar de proveedor obliga a
re-asignar agentes a mano y no hay forma de declarar *qué necesita* un agente (razonamiento,
contexto largo, tool use, costo bajo). GAP_ANALYSIS P1.1/P1.2 pide separar el perfil de
capacidades del modelo concreto.

## Decisión

El perfil vive **dentro de la política existente**, no en un archivo nuevo:

```jsonc
// .arnes/model-routing-policy.json (extensión aditiva)
"agents": {
  "atlas": {
    "requires": ["reasoning", "long_context"],
    "prefers": ["cost_low"],
    "fallback": ["opencode-go/qwen3.8-max", "nvidia/deepseek-ai/deepseek-v4-pro"],
    "capability_fit": { "flash": 0.4, "pro": 0.8, "highest": 1.0 }
  }
}
```

Jerarquía (sin romper la fuente declarada):

1. `model-routing-policy.json` sigue siendo **la fuente de verdad declarativa** (ADR-004).
2. `agent-models.json` sigue siendo **la asignación efectiva** (lo que se ejecuta hoy).
3. El perfil solo **ordena candidatos** para Bran/Quina (ADR-011); nunca asigna por sí solo.

`requires` es bloqueante (si ningún modelo conectado lo cumple, se reporta), `prefers` es
desempate, `capability_fit` se calibra con `success_pct` real por route (ADR-012).

## Alternativas consideradas

| Alternativa | Decisión |
|---|---|
| A. Archivo nuevo `agent-profiles.json` | Rechazada: reintroduce la fragmentación que ADR-004 eliminó (5 fuentes) |
| B. **Extensión aditiva de la policy** (ELEGIDA) | Una sola fuente declarativa; los perfiles se leen con el resto de la policy |
| C. No separar agente de modelo | Rechazada: bloquea el objetivo model-agnostic del harness |

## Consecuencias

- Cambiar de proveedor deja de ser re-asignar 16 agentes: se re-evalúan perfiles.
- El contenido de `requires/prefers` se llena **con datos de F1**, no a ojo; hasta entonces
  la clave es opcional y su ausencia no cambia el comportamiento actual.
- Ningún componente cambia la asignación efectiva sin causa clasificada (ADR-018) ni sin
  registro del cambio en `quest-ledger`/ledger de Quina.

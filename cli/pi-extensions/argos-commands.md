# ARGOS Commands (skill de Pi)

Cuando el usuario mencione configurar agentes, correr una quest grande, ver el party,
o use comandos `/argos-*`, usa ARNES ARGOS (el cerebro persistente) via `!argos` (bash tool).

## Comandos disponibles

| Pedido del usuario | Comando en Pi |
|---|---|
| "conecta el agente X con un modelo" | `!argos connect-agent` (muestra SOLO proveedores logueados) |
| "asigna modelo a un agente" | `!argos connect-agent -Agent <nombre>` |
| "corre una quest grande con todo el party" | `!argos party "<quest>"` (Atlas decide, cada agente usa SU modelo) |
| "quest normal" | `!argos quest "<quest>"` (ciclo: Atlas→Amarant→Bard→party→Tywin→Atlas) |
| "verifica conexiones" | `!argos verify` |
| "estado / memoria" | `!argos status` |
| "prueba un modelo" | `!argos test-model <proveedor/modelo>` |

## Reglas

- La fuente de verdad de modelos es `~/.config/arnes/agent-models.json` (NO cambiar en `/model` de Pi salvo override temporal).
- Cada agente (vivi, ansem, auron...) usa SU modelo automaticamente al ser delegado como subagente.
- `argos connect-agent` solo muestra modelos de proveedores CON login real (Pi auth.json + conexiones ARNES).
- Para cambiar el modelo de un agente: pedir `!argos connect-agent -Agent <agente>`.
- Para un proveedor nuevo: loguear primero (`/login` en Pi o `argos connect`) y luego `!argos connect-agent`.

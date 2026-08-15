# Política de routing de modelos por agente

`.arnes/model-routing-policy.json` es la fuente declarativa de las preferencias de modelos para los 13 agentes de Arnes. Su versión inicial se guarda aparte de los archivos heredados: no modifica `model-chain.json` ni `model-assignments.json`.

## Contrato

- Cada agente declara cuatro **aliases lógicos** en `preference_order`.
- Los aliases no son IDs de proveedor ni prometen disponibilidad. El router futuro debe resolverlos contra el catálogo vivo y sólo elegir una coincidencia sana y dentro del presupuesto.
- El primer alias es la preferencia; los demás son fallbacks ordenados.
- Los límites de `provider_budget_defaults` son porcentajes suaves semanales para distribuir consumo. No representan cuotas verificadas de proveedores.

## Validación requerida

Antes de aceptar una política, el configurador/router debe comprobar que:

1. `version` sea compatible y `resolution_mode` sea `catalog_backed_aliases`.
2. Existan exactamente estos 13 agentes: `atlas`, `vivi`, `eiko`, `ansem`, `eremez`, `amarant`, `kuja`, `auron`, `bran`, `quina`, `varys`, `tywin` y `sam`.
3. Cada `preference_order` tenga cuatro aliases únicos.
4. Cada alias exista en `model_capabilities`.
5. Los topes porcentuales sean números entre 0 y 100 y sumen 100.

Un alias sin coincidencia en el catálogo, sin cuota o en cooldown no invalida la política: se omite y se intenta el siguiente fallback sano. Si no existe ninguno, el router debe devolver un estado bloqueado y preservar la evidencia para Atlas, Varys, Tywin y Sam; no debe inventar un ID de modelo.

## Evolución segura

Para añadir un modelo se agrega un alias lógico a `model_capabilities`, se actualizan los órdenes de preferencia y se incrementa `version` de forma compatible. La resolución real de alias, health checks, reintentos y cooldowns pertenece al router de la siguiente oleada.

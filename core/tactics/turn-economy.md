# Tactica 2: Turn Economy

> Como se estructura cada turno del combate, cuantos tokens gastar, cuando paralelizar.

## Turn Structure

Cada quest se ejecuta en turns. Cada turn tiene 4 fases:

```
TURN N:
  Phase 1: PLAN      (1 member, 1-2K tokens, 5-10% del MP)
  Phase 2: EXECUTE   (1-3 members parallel, 50-70% del MP)
  Phase 3: VERIFY    (1 member, 10-20% del MP)
  Phase 4: EVALUATE  (Atlas inline, 0 tokens extra)
```

## Token Budget Rules

Por turn, MP (context window) se divide:
- 60% EXECUTE (donde mas se gasta)
- 15% VERIFY
- 15% PLAN
- 10% buffer (compact si se acaba)

## Parallel Execution Rules

### Cuando SI paralelizar
- Boss fights: 3 members max en EXECUTE
- Feature-full: 2 members max en EXECUTE (Vivi frontend + Paladin backend en paralelo)
- Multi-file refactors: 2 members en EXECUTE (cada uno archivos distintos)

### Cuando NO paralelizar
- Quests triviales: 1 member, 1 turn, done
- Verify: siempre 1 a la vez
- Plan: siempre 1 a la vez
- Cambios en el mismo archivo: sequential

## Turn Limits

| Quest Complexity | Max Turns | Max Tokens per Turn |
|---|---|---|
| trivial | 1 | 1K |
| simple | 2 | 3K |
| medium | 4 | 5K |
| complex | 8 | 8K |
| boss | 15 | 12K |

Si se pasa el max turns: escalar a usuario. Algo esta mal.

## MP Refresh Protocol

Cuando MP baja a 20%:
1. Compact context (retainsol solo lo escencial del quest)
2. Continue con MP refreshed a 100%
3. Marcar en log: `[COMPACT] MP refreshed 20→100`

Esto puede pasar max 2 veces por quest. Al 3er compact: quest too complex, escalar.

## Skip Turn Conditions

- Si EXECUTE phase output no cambia nada (stall detect): skip siguiente PLAN, ir directo a VERIFY
- Si VERIFY pasa en 1 intent: skip siguiente turn, ir a EVALUATE directamente
- Si quest es trivial y exp 95% del plan es simple: skip PLAN, ir directo EXECUTE

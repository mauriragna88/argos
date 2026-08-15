# Loop Engine — Subagente de Atlas

> Mantiene el auto-loop: quest terminado → evaluar → siguiente quest sin esperar al usuario.
> Circuit breaker integrado para evitar loops infinitos.

## Estados del Loop

```
┌──── IDLE ────┐
│  esperando   │
│  user input  │
└──────┬───────┘
       │ user prompt
       ▼
┌── QUESTING ──┐
│  combate     │
│  en progreso │
│  (turn-based)│
└──────┬───────┘
       │ verify_done
       ▼
┌── EVALUATING ┐
│  HP? MP?     │
│  XP? verify? │
└──────┬───────┘
       │
   ┌───┴───┐
   │       │
   ▼       ▼
┌──OK──┐ ┌─PAUSE─┐
│auto  │ │user   │
│next  │ │confirm│
└──┬──┘ └───┬───┘
   │         │
   ▼         ▼
┌── QUESTING ──┐ (or quit)
│  next quest  │
└──────────────┘
```

## Loop State Machine

### State: IDLE
- Party en standby
- Espera input del usuario directamente
- Mostrar prompt: `> █`

### State: QUESTING
- Party activo en turn-based combat
- HP depleting, MP depleting
- No acepta nuevos quests (en cola) hasta terminar actual

### State: EVALUATING
Despues que el party dice "done":
1. **Verify gates**: lint ✓, typescript ✓, tests ✓
2. **HP check**: si HP <= 0, quest fallo
3. **MP check**: si MP <= 0, context compacted
4. **Quality score**: Monk (si estaba) evalua la calidad

### State: AUTO_NEXT (si auto_loop=true)
Si el Evaluation fue OK y hay quests_chain pendientes:
1. Log: `[LOOP] Q1 completado. Auto-iniciando Q2...`
2. Lanzar siguiente quest inmediatamente
3. Sin esperar al usuario

### State: PAUSE_USER (si L0 o boss_fight)
1. Log: `[PAUSE] Quest completado. Esperando confirmacion para siguiente.`
2. Mostrar resultado al usuario
3. Esperar input

### State: CIRCUIT_BREAKER
Si cualquier member falls 3 veces en 60 min:
1. Log: `[BREAKER] <member> blocked 30 min`
2. Marcar member como disabled
3. Buscar fallback party (sustituto)
4. Si no hay sustituto: pausa usuario

## Loop Triggers

### Trigger: quest_done_ok
- Verify gates pass
- HP > 0
- Result = "done"
- Action: si auto_loop:true y quedan quests: lanzar siguiente

### Trigger: quest_done_fail
- Verify gates fail x2
- HP <= 0
- Result = "failed"
- Action: pausa + reporte usuario + circuit_breaker forzado

### Trigger: user_pause
- Action: Loop pausa. Estado = PAUSED_USER. Espera `/resume`

### Trigger: user_quit
- Action: Limpiar turn_state, cerrar party, volver a IDLE

### Trigger: circuit_breach
- Ocurre tras 3 fails consecutivos
- Action: Block agent 30 min

## HP/MP Tracking

```yaml
hp:
  definition: "Budget total de tokens disponibles para el quest actual"
  starts_at: estimated_mp (ver Quest Detector)
  depletes: cada delegacion consume HP
  death: si HP <= 0, quest failed

mp:
  definition: "Context window disponible (memoria de trabajo)"
  starts_at: 100
  depletes: cada file leida consume 2-5 MP
  refresh: cuando se compacta contexto
  zero_mp: el agente no puede retener info → refresh forzado
```

## Anti-Loop-forever Rules

1. **Max retries por quest**: 3 (circuit breaker kicks in en 3 fails agente)
2. **Max quests en cadena**: 5 (mas de 5 requiere user confirm "dial M for murder")
3. **Max tokens per loop**: 100K (si se pasa, pausa)
4. **Max turns per quest**: 10 (si pasa, escalar a usuario)
5. **Stall detection**: si un agente repite el mismo output 2 veces, se considera stall
6. **HP-0 = death**: si HP llega a 0 antes de quest_done, quest failed

## Logging (per turn)

```
[TURN 1] plan | Monk | skill: foresight | HP: 20-2=18 | MP: 100-5=95 | ok
[TURN 2] exec | Vivi | skill: fireball | HP: 18-8=10 | MP: 95-20=75 | ok
[TURN 3] verify | Rogue | skill: backstab | HP: 10-3=7 | MP: 75-15=60 | fail
  ↳ [TURN 3.1] heal | Eiko | skill: mend | HP: 7+5=12 | MP: 60-3=57 | retry
[TURN 4] verify | Rogue | skill: backstab | HP: 12-3=9 | MP: 57-15=42 | ok
[TURN 5] eval | Atlas | quests_left: 1 | auto_next: true
```

## Loop Badge System (Gamification)

Cada 10 quests completados sin fallar, el party gana:
- **Streak 5**: Vivi +5% damage (Fireball upgrades)
- **Streak 10**: Eiko aprende Cura (desbloquea nueva skill)
- **Streak 20**: Monk aprende Meditation full
- **Streak 50**: Full party +1 level (L1→L2)
- **Streak 100**: Boss-level autonomy (L3 unlock for all)

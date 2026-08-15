# Tactica 3: Mana Conservation

> Optimizacion de tokens. Como Atlas ahorra HP (tokens) sin sacrificar calidad.

## Cost Reduction Strategies

### 1. Skill Selection por Budget
Si HP (tokens disponibles) es escaso:
- Vivi: usar Flare (1.5K) en vez de Fireball (2K)
- Paladin: usar Smite (3K) en vez de Holy Ground (6K)
- Rogue: usar Backstab (1K) en vez de Shadow Clone (6K)
- Monk: usar Foresight (2K) en vez de Meditation (10K)
- Ranger: usar Mark (500) en vez de Swarm (3K)

### 2. Parallel vs Sequential Decision
```
Regla: 
  si tokens_total > 10K → sequential (ahorra tokens)
  si tokens_total < 10K → parallel (ahorra tiempo, gasta +30% tokens)
  boss_fight → parallel siempre (tiempo importa mas que costo)
```

### 3. Cache Knowledge
- Ranger puede guardar docs encontradas en `.arnes/research-cache/`
- Si mismo tema fue buscado hace menos de 7 dias → reusar cache, 0 MP
- Invalidate cache si la libreria cambio de version

### 4. Incremental Execution
- No delegar "implementa todo el feature" → delegar 1 archivo a la vez
- Cada sub-delegacion gasta menos tokens que una delegacion masiva
- Trade-off: +2-3 turns, pero -40% tokens

### 5. Skip Non-Critical Turnos
- Verify con lint+typecheck es obligatorio (es 10% MP, previene bugs)
- Verify con test E2E es opcional si HP <20% (Eiko decide)
- Plan se puede skip si el quest es trivial o Monk ya planifico

### 6. Model Selection Affects Cost
| Modelo | Costo aprox | Use for |
|---|---|---|
| DeepSeek V4 Flash | 1x (cheap) | Ranger, research, simples |
| Qwen 3.6 Plus | 2x | Eiko, fixes, devops |
| GLM-5.1 | 3x | Rogue, security |
| MiMo V2.5 Pro | 4x | Vivi Mage (frontend calidad) |
| DeepSeek V4 Pro | 5x | Paladin, backend serio |
| GPT-5.5 | 10x | Monk, Atlas, architect |
| Claude Opus 4 | 15x | Boss fights, critical thinking |

### 7. Battle Pause Protocol
Si HP (tokens) llega a 20% en medio de un quest:
1. Atlas pausa
2. Informa al user: `[COST ALERT] 80% HP used, 20% remaining. Continue or pause?`
3. Si user dice continue: proseguir con skills mas chicas (mas economicas)
4. Si user dice pause: guardar estado en `.arnes/save/quest-state.json`

### 8. Save State para Resume
Permite que un quest se pause y se resume despues:
```json
.arnes/save/quest-state.json:
{
  "quest_id": "login-feature-001",
  "completed_turns": 3,
  "remaining_turns_estimate": 2,
  "hp_used": 45,
  "mp_used": 6000,
  "files_touched": ["src/components/LoginForm.tsx"],
  "next_action": "VERIFY: run vitest for LoginForm"
}
```

/user pe.de escribir `/resume` para continuar exactamente donde se quedo.

### 9. Daily Token Budget
Si user activa `daily_budget` en config:
- Trackear todos los tokens gastados por dia
- Si se pasa el budget: Atlas avisa y pausa auto-loop
- Budget resets a medianoche local time

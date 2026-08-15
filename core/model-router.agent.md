# Model Router — Subagente de Atlas

> Asigna el mejor modelo disponible a cada party member segun suscripcion del usuario.
> Datos actualizados 2026-07-26 desde web search oficial de OpenAI, Anthropic y OpenCode Go.

---

## Catalogo de Modelos 2026 (Validados)

### OpenCode Go ($5-$10/mes)
| Modelo | Tier | Best For | Rate Limit |
|---|---|---|---|
| `grok-4.5` | pro | razonamiento general | 30K req/5h |
| `mimo-v2.5-pro` | pro | frontend/UI/design | 30K req/5h |
| `deepseek-v4-pro` | pro | backend/logica/apiz | 30K req/5h |
| `deepseek-v4-flash` | pro | bulk/trivial/scout | 31K req/5h |
| `qwen3.7-max` | pro | reasoning complejo | 30K req/5h |
| `qwen-3.6-plus` | pro+free | balance general | 30K/5K req/5h |
| `kimi-k2.6` | pro | arquitectura/monk | 30K req/5h |
| `glm-5.2` | pro+free | QA/deteccion | 30K/5K req/5h |
| `minimax-m3` | pro | contexto largo | 30K req/5h |

### Codex (OpenAI)
| Modelo | Plan | Use Case | Rate Limit |
|---|---|---|---|
| `gpt-5.6-sol` | pro ($200) | deep reasoning, boss fights | 15-90 msg/5h |
| `gpt-5.6-terra` | plus/pro | balanceado default | 20-110 msg/5h |
| `gpt-5.6-luna` | plus ($20) | speed/value, frontend | 50-280 msg/5h |
| `gpt-5.5` | plus | general | 5x free |
| `gpt-5.4` | free | rutinario | 5K req/5h |
| `gpt-5.4-mini` | free | trivial | 5K req/5h |

### Claude (Anthropic)
| Modelo | Plan | Use Case | Precio |
|---|---|---|---|
| `claude-opus-5` | max ($100/mes) | razonamiento profundo, monk | $5/MTok |
| `claude-opus-4.8` | pro ($17/mes) | alto razonamiento | $5/MTok |
| `claude-sonnet-5` | pro | balance general | $3/MTok |
| `claude-sonnet-4.5` | free+pro | general | $3/MTok |
| `claude-haiku-4.5` | free | speed, economia | $1/MTok |

---

## Tabla de Routing por Suscripcion × Plataforma

### OpenCode
```yaml
opencode_free:
  atlas:   deepseek-v4-flash
  vivi:    qwen-3.6-plus
  eiko:    qwen-3.6-plus
  paladin: deepseek-v4-flash
  rogue:   glm-5.2
  monk:    deepseek-v4-flash
  ranger:  deepseek-v4-flash
  auron:   deepseek-v4-flash
  bran:    deepseek-v4-flash
  quina:   glm-5.2
  varys:   qwen-3.6-plus
  tywin:   deepseek-v4-flash
  sam:     deepseek-v4-flash

opencode_pro:
  atlas:   mimo-v2.5-pro
  vivi:    mimo-v2.5-pro          # Frontend premium
  eiko:    qwen-3.6-plus
  paladin: deepseek-v4-pro        # Backend premium
  rogue:   glm-5.2                # QA especializado
  monk:    kimi-k2.6              # Arquitectura/razonamiento
  ranger:  deepseek-v4-flash
  auron:   deepseek-v4-pro
  bran:    kimi-k2.6
  quina:   glm-5.2
  varys:   qwen-3.6-plus
  tywin:   deepseek-v4-pro
  sam:     kimi-k2.6
```

### Codex (OpenAI)
```yaml
codex_free:
  atlas:   gpt-5.4
  vivi:    gpt-5.4
  eiko:    gpt-5.4-mini
  paladin: gpt-5.4
  rogue:   gpt-5.4-mini
  monk:    gpt-5.4
  ranger:  gpt-5.4-mini
  auron:   gpt-5.4
  bran:    gpt-5.4
  quina:   gpt-5.4-mini
  varys:   gpt-5.4-mini
  tywin:   gpt-5.4
  sam:     gpt-5.4

codex_plus:
  atlas:   gpt-5.6-terra
  vivi:    gpt-5.6-luna           # speed for frontend
  eiko:    gpt-5.5
  paladin: gpt-5.6-terra
  rogue:   gpt-5.6-luna
  monk:    gpt-5.6-terra
  ranger:  gpt-5.5
  auron:   gpt-5.6-terra
  bran:    gpt-5.6-terra
  quina:   gpt-5.5
  varys:   gpt-5.5
  tywin:   gpt-5.6-terra
  sam:     gpt-5.6-terra

codex_pro:
  atlas:   gpt-5.6-sol            # deep reasoning
  vivi:    gpt-5.6-luna           # speed frontend
  eiko:    gpt-5.6-terra
  paladin: gpt-5.6-sol            # deep backend
  rogue:   gpt-5.6-sol            # deep QA
  monk:    gpt-5.6-sol            # deep architecture
  ranger:  gpt-5.6-terra
  auron:   gpt-5.6-sol
  bran:    gpt-5.6-sol
  quina:   gpt-5.6-terra
  varys:   gpt-5.6-terra
  tywin:   gpt-5.6-sol
  sam:     gpt-5.6-sol
```

### Claude (Anthropic)
```yaml
claude_free:
  atlas:   claude-sonnet-4.5
  vivi:    claude-sonnet-4.5
  eiko:    claude-haiku-4.5
  paladin: claude-sonnet-4.5
  rogue:   claude-haiku-4.5
  monk:    claude-sonnet-4.5
  ranger:  claude-haiku-4.5
  auron:   claude-sonnet-4.5
  bran:    claude-sonnet-4.5
  quina:   claude-haiku-4.5
  varys:   claude-haiku-4.5
  tywin:   claude-sonnet-4.5
  sam:     claude-sonnet-4.5

claude_pro:
  atlas:   claude-opus-4.8
  vivi:    claude-opus-4.8
  eiko:    claude-sonnet-5
  paladin: claude-sonnet-5
  rogue:   claude-sonnet-5
  monk:    claude-opus-4.8
  ranger:  claude-sonnet-5
  auron:   claude-opus-4.8
  bran:    claude-opus-4.8
  quina:   claude-sonnet-5
  varys:   claude-sonnet-5
  tywin:   claude-opus-4.8
  sam:     claude-opus-4.8

claude_max:
  atlas:   claude-opus-5          # deep reasoning
  vivi:    claude-opus-5
  eiko:    claude-sonnet-5
  paladin: claude-opus-4.8
  rogue:   claude-opus-5
  monk:    claude-opus-5
  ranger:  claude-sonnet-5
  auron:   claude-opus-5
  bran:    claude-opus-5
  quina:   claude-sonnet-5
  varys:   claude-sonnet-5
  tywin:   claude-opus-5
  sam:     claude-opus-5
```

---

## Quest Type Overrides

Atlas puede promover agentes a modelo superior segun el tipo de quest:

| Quest Type | Override | Razon |
|---|---|---|
| `boss_fight` | atlas/monk/tywin/sam → highest_reasoning | Arquitectura y verificacion |
| `frontend_quest` | vivi/eiko → best_frontend | UI/design requiere modelo visual |
| `backend_quest` | paladin/auron → best_backend | Logica y seguridad |
| `trivial_quest` | all → cheapest tier | Ahorrar tokens |

---

## Reasoning Level Selection (Codex)

Si Codex es la plataforma, el reasoning level se mapea al quest type:

| Quest Type | Reasoning | Modelo |
|---|---|---|
| `trivial` | `low` | Sol / GPT-5.4-mini |
| `feature` | `medium` | Luna / GPT-5.6-luna |
| `architecture` | `high` | Terra / GPT-5.6-terra |
| `boss_fight` | `ultra` | Sol / GPT-5.6-sol |

---

## Routing Algorithm

```python
def route_models(subscription, quest_type, platform):
    tier = detect_tier(subscription, platform)
    base = RECOMMENDED_PARTY[platform][tier]
    
    # Overrides por quest type
    if quest_type == "boss_fight":
        for agent in ["atlas", "monk", "tywin", "sam"]:
            base[agent] = highest_reasoning_available(platform, tier)
    elif quest_type == "frontend_quest":
        base["vivi"] = best_frontend_model(platform, tier)
        base["eiko"] = base["vivi"]  # Eiko sigue a Vivi
    elif quest_type == "backend_quest":
        base["paladin"] = best_backend_model(platform, tier)
        base["auron"] = base["paladin"]
    
    return base
```

---

## Initial User Onboarding (CLI First-Run)

Cuando el usuario corre `atlas` por primera vez y no existe `.arnes/config.json`:

```
ATLAS: Bienvenido! Necesito configurar tu party antes de empezar.

1. ¿Que plataforma usas?
   [1] OpenCode  [2] Codex  [3] Claude

2. ¿Que plan de suscripcion tienes?
   (filtro segun plataforma elegida)
   OpenCode:  [Free / Pro]
   Codex:     [Free / Plus / Pro]
   Claude:    [Free / Pro / Max]

3. ¿Prefieres economia de tokens o maxima calidad?
   [Ahorrar / Balance / Maxima calidad]

4. Recomendacion de Atlas:
   - Vivi (Frontend):     <modelo>
   - Ansem (Backend):     <modelo>
   - Amarant (Arq):       <modelo>
   - Tywin (Verifier):     <modelo>
   
   Confirmas? [Y/n]

5. Configuracion guardada en .arnes/config.json
   ¡Listo! Escribe tu primer quest.
```

El algoritmo de recomendacion:
- Si "Ahorrar" → tier free o modelos flash/mini
- Si "Balance" → tier pro con modelos balanceados (terra/luna, sonnet)
- Si "Maxima calidad" → highest tier (sol, opus, mimo-v2.5-pro)

---

## Re-Config Command

En cualquier momento el usuario puede:

| Comando | Accion |
|---|---|
| `/platform` | Re-detecta plataforma |
| `/plan` | Re-configura tier de suscripcion |
| `/config` | Edita config.json directamente |

---

## Fallback Chain

Si el modelo asignado falla o responde lento:

1. **Intent 1** → modelo asignado (espera 2s)
2. **Retry 1** → mismo modelo (espera 4s)
3. **Fallback** → siguiente en cadena:
   - `vivi`:      [mimo-v2.5-pro → qwen-3.6-plus → deepseek-v4-flash]
   - `paladin`:   [deepseek-v4-pro → gpt-5.6-terra → claude-sonnet-5]
   - `monk`:      [kimi-k2.6 → gpt-5.6-sol → claude-opus-5]
   - `atlas`:     [mimo-v2.5-pro → gpt-5.6-terra → claude-opus-4.8]
4. **Si solo 1 plano activo** y el modelo falla: pausa party, notifica user
5. **Vivi falling 2x seguidas** → delegar a Paladin + Eiko (front-end tank)
6. **Eiko failing**: pausa critica, party debe detenerse

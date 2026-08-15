# Harness RPG Atlas — Conventions

## Filosofía
Atlas es un harness RPG. Cada agente es un personaje con personalidad, clase, stats, y skills. El objetivo es terminar quests (tareas) con la mejor calidad al menor costo.

## Identidad Visual
- Colores: Rojo `#C8102E` + Negro `#1A1A1A`
- Inspiración: Atlas FC, Liga MX
- CLI theme: Rojo y Negro

## Reglas del Player (Atlas)
1. Atlas NUNCA escribe codigo. Solo orquesta.
2. Atlas detecta el tipo de quest, selecciona party, lanza turnos.
3. Atlas auto-loop: quest terminado -> siguiente quest sin esperar al usuario.
4. Atlas pausa solo para: boss fights (tareas grandes), cambios L0, o cuando el usuario dice "pause".
5. Atlas **DEBE** invocar a Bran en TURN 0.5 (antes de Party Select) para recibir Allocate recomendation.

## Reglas del Strategist (Bran - #2 en jerarquia)
1. Bran lee `.arnes/repo-profile.json` y `.arnes/quest-ledger.json` para recomendar recursos.
2. Bran clasifica el repo en tiers: `lean` (<50 files / <5K LOC), `medium` (50-300 / 5K-30K), `standard` (300-1000 / 30K-100K), `boss` (>1000 / >100K).
3. Bran entrega a Atlas: `party_size`, `members`, `model_tier`, `estimated_cost`, `budget_ok`.
4. Bran NO decide - solo recomienda. Atlas decide.
5. Override manual: `atlas --lean`, `atlas --medium`, `atlas --full-party`, `atlas --boss-party`, `atlas --auto`.
6. Bran re-ejecuta Repo Sizer cada 20 quests o cuando LOC cambia > 30%.

## Reglas del Party
1. Cada miembro tiene una clase fija con personalidad definida.
2. Vivi (Mage) SIEMPRE tiene a Eiko (Cleric) como soporte en quests frontend.
3. Skills gastan MP (context window). HP = tokens restantes.
4. Si un miembro cae (fail x2), Eiko usa Mend. Si Eiko falla, Monk replanifica.
5. 3 caidas en 60 min -> circuit breaker -> 30 min cooldown.

## Reglas de Nomenclatura
- Agentes: `[nombre].agent.md` (ej: `vivi.agent.md`)
- Skills: `[clase]-spells.json` (ej: `mage-spells.json`)
- Config: `.arnes/config.json` (per-proyecto)
- Hooks: `deploy/hooks/[plataforma]/`

## Reglas de Plataforma
El harness funciona en 3 plataformas con la misma logica:
- **OpenCode** via `opencode.json` + `oh-my-opencode.jsonc`
- **Codex** via `.codexrc` config
- **Claude** via `claude_desktop_config.json`

Los prompts se transpilan: el mismo Atlas agent.md sirve para las 3 plataformas. Solo cambia el formato de config outer.

## Reglas de Skill
- Cada skill tiene: name, level, damage, mp_cost, description, trigger
- Skills se desbloquean con XP (uso repetido)
- Damage = efectividad (mas damage = mas archivos/features cubiertos)
- MP cost = tokens aproximados que gasta esa skill

## Reglas de Economia
- Party size 2 = 1x costo baseline (fix simple)
- Party size 4 = 2x costo (feature normal)
- Party size 6 = 4x costo (boss fight / project full)
- Parallelo ejecucion +30% tokens, -50% tiempo
- Atlas muestra costo estimado antes de iniciar cualquier quest

## Repo Tier Thresholds (Bran heuristica)
| Tier | Files | LOC | Modules | Party default | Model tier |
|---|---|---|---|---|---|
| `lean` | < 50 | < 5K | 1-2 | 1-2 miembros | free/flash |
| `medium` | 50-300 | 5K-30K | 3-8 | 2-3 miembros | balance |
| `standard` | 300-1000 | 30K-100K | 9+ | 4-6 miembros | pro |
| `boss` | > 1000 | > 100K | monorepo / 15+ | 6 + auditores | highest |

**Regla de max tier**: si cualquier signal cae en tier superior, el repo_tier final es el max de los tres.

## Atlas CLI Flags (override de Bran)
| Flag | Efecto |
|---|---|
| `atlas --lean` | Forza tier=lean, party max 2, modelos free |
| `atlas --medium` | Forza tier=medium, party max 3, balance tier |
| `atlas --standard` | Forza tier=standard, party 4-6, pro tier |
| `atlas --boss-party` | Forza tier=boss, 6+auditores, highest tier |
| `atlas --full-party` | Fuerza party 6 sin cambiar tier |
| `atlas --auto` | Clear override - Bran decide solo via heuristica |

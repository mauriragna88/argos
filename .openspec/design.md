# Harness RPG "Atlas" — Diseño Técnico

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                     CLI "arnes activate"                         │
│   PowerShell/Bash script que detecta el entorno                  │
│   Pregunta: plataforma, suscripción, party size                 │
│   Carga configuración en {plataforma}/.config/...                │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│              ATLAS PLAYER (Orquestador RPG)                       │
│                                                                   │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────────┐   │
│  │Quest Detector│  │Model Router   │  │Party Builder         │   │
│  │detecta tipo  │  │map subscrip   │  │selecciona clases     │   │
│  │por keywords  │  │→models        │  │por quest type        │   │
│  └──────┬───────┘  └──────┬────────┘  └──────────┬──────────┘   │
│         │                 │                       │              │
│         └─────────────────┼───────────────────────┘              │
│                           │                                      │
│  ┌────────────────────────▼───────────────────────────────┐     │
│  │                 COMBAT LOOP ENGINE                      │     │
│  │  ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐  │     │
│  │  │TURN 1│→  │TURN 2│→  │TURN 3│→  │EVAL  │→  │DONE? │──│     │
│  │  │Plan  │   │Exec  │   │Verify│   │HP/MP │   │→next │  │     │
│  │  └──────┘   └──────┘   └──────┘   └──────┘   │quest │  │     │
│  └─────────────────────────────────────────────┘───────┘  │     │
│                                                             │     │
│  ┌─────────────────────────────────────────────────────────┐│     │
│  │                     PARTY MEMBERS                         ││     │
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐││     │
│  │  │ VIVI │  │PALADN│  │ROGUE │  │ EIKO │  │ MONK │  │RNGR  │││     │
│  │  │Mage  │  │Paladin│  │Rogue │  │Cleric│  │Monk  │  │Ranger│││     │
│  │  │🧙    │  │⚔️    │  │🗡️    │  │💚    │  │📿    │  │🏹    │││     │
│  │  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘││     │
│  └──────────────────────────────────────────────────────────┘│     │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│                 PLATFORM LAYER                                      │
│  ┌────────────┐    ┌────────────┐    ┌────────────┐               │
│  │ OpenCode   │    │   Codex    │    │   Claude    │              │
│  │ DeepSeek   │    │   OpenAI   │    │ Anthropic  │               │
│  │ Qwen/GLM   │    │  GPT-5.5   │    │ Claude 4   │               │
│  └────────────┘    └────────────┘    └────────────┘               │
└───────────────────────────────────────────────────────────────────┘
```

## Config System

### `.arnes/config.json` (per-proyecto)

```json
{
  "version": "1.0.0",
  "player": "Atlas",
  "subscription": {
    "opencode": "pro",
    "codex": null,
    "claude": null
  },
  "preferences": {
    "default_party_size": 4,
    "auto_loop": true,
    "show_tokens": true,
    "theme": "atlas-rojo-negro"
  },
  "characters": {
    "mage": { "name": "[PERSONAJE]", "model": "auto" },
    "paladin": { "name": "[PERSONAJE]", "model": "auto" },
    "rogue": { "name": "[PERSONAJE]", "model": "auto" },
    "cleric": { "name": "[PERSONAJE]", "model": "auto" },
    "monk": { "name": "[PERSONAJE]", "model": "auto" },
    "ranger": { "name": "[PERSONAJE]", "model": "auto" }
  },
  "xp": {
    "mage": { "level": 1, "xp": 0 },
    "paladin": { "level": 1, "xp": 0 },
    "rogue": { "level": 1, "xp": 0 },
    "cleric": { "level": 1, "xp": 0 },
    "monk": { "level": 1, "xp": 0 },
    "ranger": { "level": 1, "xp": 0 }
  }
}
```

### Model Router Tables

#### OpenCode
| Tier | Orquestador (Atlas) | Mage | Paladin | Rogue | Cleric | Monk | Ranger |
|---|---|---|---|---|---|---|---|
| **Free / Anon** | DeepSeek V4 Flash | DeepSeek V4 Pro | DeepSeek V4 Pro | Qwen 3.6 Plus | Qwen 3.6 Plus | DeepSeek V4 Flash | DeepSeek V4 Flash |
| **Pro (paid)** | GPT-5.5 | MiMo V2.5 Pro | DeepSeek V4 Pro | GLM-5.1 | Qwen 3.6 Plus | GPT-5.5 | DeepSeek V4 Flash |

#### Codex (OpenAI)
| Tier | Orquestador | Mage | Paladin | Rogue | Cleric | Monk | Ranger |
|---|---|---|---|---|---|---|---|
| **Free / Anon** | GPT-4o Mini | GPT-4o | GPT-4o | GPT-4o Mini | GPT-4o Mini | GPT-4o | GPT-4o Mini |
| **Pro** | GPT-5.5 / Orion | GPT-5.5 | GPT-5.5 | GPT-5.5 | GPT-4o | GPT-5.5 | GPT-4o Mini |

#### Claude
| Tier | Orquestador | Mage | Paladin | Rogue | Cleric | Monk | Ranger |
|---|---|---|---|---|---|---|---|
| **Pro** | Opus 4 | Opus 4 | Sonnet 4 | Sonnet 4 | Sonnet 4 | Opus 4 | Haiku 4 |
| **Free** | Sonnet 4 | Sonnet 4 | Sonnet 4 | Haiku 4 | Haiku 4 | Sonnet 4 | Haiku 4 |

### Skill Tree — Mage Vivi (Ejemplo)

```
Fireball (L1) ─── 5 uses → Inferno (L3) ─── 10 uses → Meteor Shower (L5)
Flare (L1)    ─── 3 uses → Wall of Fire (L2)
UI Style (L1) ──────────── → Responsive AOE (L2) → Design System Mastery (L4)
```

### File Structure:
```
arnes/
├── .openspec/                        # SDD artifacts
│   ├── proposal.md
│   ├── spec.md
│   └── design.md
├── .atl/                             # Skill registry for harness
│   └── skill-registry.md
├── core/                             # Agent system
│   ├── classes/                      # Class definitions (party members)
│   │   ├── mage.agent.md             # [PERSONAJE] - Frontend
│   │   ├── paladin.agent.md          # [PERSONAJE] - Backend
│   │   ├── rogue.agent.md            # [PERSONAJE] - QA/Security
│   │   ├── cleric.agent.md           # Eiko - Healer/DevOps
│   │   ├── monk.agent.md             # [PERSONAJE] - Architecture
│   │   └── ranger.agent.md           # [PERSONAJE] - Research
│   ├── skills/                       # Spells / Ability Trees
│   │   ├── mage-spells.json          # Vivi Spell Tree
│   │   ├── paladin-skills.json
│   │   ├── rogue-abilities.json
│   │   ├── cleric-heals.json
│   │   ├── monk-skills.json
│   │   └── ranger-skills.json
│   ├── tactics/                      # Combat strategies
│   │   ├── party-composition.md      # Party comp rules
│   │   ├── turn-economy.md           # Turn-based rules
│   │   └── mana-conservation.md      # Token optimization
│   ├── atlas-player.agent.md          # MAIN: Atlas with RPG aware
│   ├── quest-detector.agent.md       # Quest type detection
│   ├── model-router.agent.md         # Model assignment per tier
│   └── loop-engine.agent.md          # Auto-continuation engine
├── cli/                              # CLI scripts
│   └── activate.ps1                  # PowerShell activation script
├── deploy/                           # Platform hooks
│   ├── hooks/
│   │   ├── opencode/
│   │   │   ├── agent.json           # OpenCode agent config (all roles)
│   │   │   └── alt.json             # Oh-My-OpenCode model mapping
│   │   ├── codex/
│   │   │   └── codexrc.json          # Codex config
│   │   └── claude/
│   │       └── claude_desktop_config.json
│   └── cross-platform/
│       └── adapter-rules.md          # Prompt transliteration across platforms
└── CONVENTIONS.md                    # Harness RPG standard conventions
```
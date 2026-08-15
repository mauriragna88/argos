# Harness RPG "Atlas" — Implementation Tasks

## Phase 1: Foundation (Structure & Config)

- [x] **T1.1** Create full directory structure
- [x] **T1.2** Create `.arnes/config.json` template with default values
- [x] **T1.3** Create `.atl/skill-registry.md` — skill inventory for harness
- [x] **T1.4** Create `CONVENTIONS.md` — universal harness conventions

## Phase 2: Party Members (Classes)

- [x] **T2.1** Create `core/classes/mage.agent.md` — Vivi Frontend Mage
- [x] **T2.2** Create `core/classes/paladin.agent.md` — Ansem Backend Paladin
- [x] **T2.3** Create `core/classes/rogue.agent.md` — Kuja QA/Security Rogue
- [x] **T2.4** Create `core/classes/cleric.agent.md` — Eiko Healer/DevOps
- [x] **T2.5** Create `core/classes/monk.agent.md` — Amarant Architecture Monk
- [x] **T2.6** Create `core/classes/ranger.agent.md` — Eremez Research Ranger

## Phase 3: Skill Trees (Spells & Abilities)

- [x] **T3.1** Create `skills/mage-spells.json` — Vivi spell tree (Fireball, Inferno, etc.)
- [x] **T3.2** Create `skills/paladin-skills.json` — Tank/defense skills
- [x] **T3.3** Create `skills/rogue-abilities.json` — Stealth, backstab, traps
- [x] **T3.4** Create `skills/cleric-heals.json` — Eiko healing spells (Mend, Cura, Mass Heal)
- [x] **T3.5** Create `skills/monk-skills.json` — Architecture foresight
- [x] **T3.6** Create `skills/ranger-skills.json` — Tracking, research, swarm

## Phase 4: Tactics Engine

- [x] **T4.1** Create `tactics/party-composition.md` — Which members for which quest
- [x] **T4.2** Create `tactics/turn-economy.md` — Token and turn management in photoshop
- [x] **T4.3** Create `tactics/mana-conservation.md` — Saving strategies

## Phase 5: Atlas Core (Orchestration)

- [x] **T5.1** Create `atlas-player.agent.md` — Full RPG orchestrator with all roles
- [x] **T5.2** Create `quest-detector.agent.md` — Quest detection and classification
- [x] **T5.3** Create `model-router.agent.md` — Subscription tier → model assignment
- [x] **T5.4** Create `loop-engine.agent.md` — Auto-continuation rule set

## Phase 6: CLI

- [x] **T6.1** Create `cli/activate.ps1` — Activation script for PowerShell
- [x] **T6.2** Create `cli/install.sh` — One-liner installer for Linux/Mac
- [x] **T6.3** Create `cli/install.ps1` — Cross-platform installer (Windows/Linux/Mac via pwsh)
- [x] **T6.4** Create `cli/installer-snippet.sh` — Tiny curl-able snippet for README
- [x] **T6.5** Create `cli/activate.sh` — Bash/Linux activation script
- [x] **T6.6** Create `cli/evenatan-ui.ps1` — Interactive UI window (RPG themed)

## Phase 7: Deploy Hooks

- [x] **T7.1** Create `deploy/hooks/opencode/agent.json` — OpenCode agent map
- [x] **T7.2** Create `deploy/hooks/opencode/alt.json` — Oh-My-OpenCode model routing
- [x] **T7.3** Create `deploy/hooks/codex/codexrc.json` — Codex config
- [x] **T7.4** Create `deploy/hooks/claude/config.json` — Claude desktop config
- [x] **T7.5** Create `deploy/cross-platform/adapter-rules.md` — Prompt transliteration

## Phase 8: Verification

- [x] **T8.1** Verify all agent files are syntactically valid
- [x] **T8.2** Verify config schemas are consistent
- [x] **T8.3** Test CLI activation flow (local)
- [x] **T8.4** View SDD verify pass

## Phase 9: Documentalist (NEW 2026-07-27)

- [x] **T9.1** Create `core/auditors/varys-documentalist.agent.md` — Doc auditor
- [x] **T9.2** Add Varys Documentalist to `.atl/skill-registry.md`
- [x] **T9.3** Add `/audit-docs` command to atlas.ps1
- [x] **T9.4** Add pre-commit hook integration
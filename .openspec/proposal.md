# Harness RPG "Atlas" — Propuesta de Cambio

**Change ID**: `harness-rpg-atlas`
**Status**: `proposed`
**Author**: Atlas Team
**Date**: 2026-07-25

## Intent

Construir un harness de IA con temática RPG para desarrollo de software. Reemplaza al orquestador Sisyphus con **Atlas** (Player) — un sistema multi-agente que usa mecánicas de RPG (clases, skills/hechizos, niveles, party composition, turn-based combat) para gestionar agentes de IA en tareas de desarrollo.

## Scope

### In-Scope
1. **Atlas Player Agent**: Orquestador RPG con detección de quests, selección de party, loop autónomo
2. **Party Classes**: 6+ clases RPG con personalidades definidas (Mage=Vivi, Healer=Eiko, etc.) — nombres de personajes de RPG/FF
3. **Skill/Spell System**: Ability tree de skills que las clases desbloquean con el uso
4. **Tactics Engine**: Economía de turnos, ahorro de tokens, parallel vs sequential execution
5. **CLI (Evenatan)** — Ventana interactiva que detecta plataforma (OpenCode/Codex/Claude) y ejecuta el harness
6. **Loop Engine** — Auto-continuación: quest completado → evaluar → siguiente quest sin esperar al usuario
7. **Model Router**: Pregunta plan de suscripción → asigna modelo correcto por rol (Opus/Sonnet/Haiku, Sol/Luna/Terra, etc.)
8. **Deploy Layer**: Hooks para inyectar la config en OpenCode/Codex/Claude con un solo comando

### Out-of-Scope
- UI gráfica (web/app) — solo CLI terminal
- Integración con IDEs externos (VS Code plugin, etc.)
- Base de datos de tracking de XP (se usará localStorage o archivo JSON)
- Conexión con APIs externas más allá de las del agente

## Approach

1. **SDD Design First** — documentación completa antes de código
2. **Templated Agents** — los archivos `.agent.md` se pueden copiar para cualquier plataforma
3. **CLI en PowerShell/Bash* — nativo, sin dependencias de Node.js
4. **Archivos de configuración JSON** para el class registry y model routing
5. **Transpilación de prompts** — un mismo agente funciona en OpenCode, Codex y Claude adaptando el formato del prompt

## Risks

- **Model availability**: los modelos de OpenCode/Codex/Claude cambian sus nombres versiones
- **Token per-financiero**: si el Party usa 6 clases semi-crawl tiene un costo alto (5x tokens)
- **Loop infinito**: el auto-loop puede hacer pings infinitos si no hay cippbreaker bien configurado
- **Compatibilidad**: cada plataforma tiene su propio formato de system prompt

## Dependencies

- Sistema existente de Oh-My-OpenCode (current Sisyphus/S DD agents)
- Skills del ecosistema existentes (65+ skills)
- Oh-My-My-OpenCode JSONC para model routing
# Cross-Platform Adapter Rules

> Atlas RPG funciona en 3 plataformas distintas con la misma logica.
> Este documento define como se transpila el mismo prompt para cada una.

## File-Based Agents (Plataforma-Agnostico)

Los archivos `*.agent.md` en `core/` y `core/classes/` son **platform-agnostic**.
Contienen el system prompt del personaje. Las 3 plataformas los leen igual.

## Diferencias por Plataforma

### OpenCode
- **Config principal**: `opencode.json` (agents + permissions)
- **Model routing**: `oh-my-opencode.jsonc` (models per agent)
- **Skills**: carpeta `~/.config/opencode/skills/`
- **Delegacion**: `task()` tool con `subagent_type` o `category`
- **System prompt syntax**: `{file:./path/to/agent.md}`

### Codex
- **Config principal**: `.codexrc.json` (en el project root)
- **Model routing**: dentro de `.codexrc.json`
- **Skills**: integradas en el system prompt (no separa carpeta)
- **Delegacion**: subagentes via `task` tool (API OpenAI)
- **System prompt syntax**: `system_prompt_file: "path/to/agent.md"`

### Claude (Anthropic)
- **Config principal**: `claude_desktop_config.json` (en `~/.claude/`)
- **Model routing**: dentro del mismo config
- **Skills**: documentos separados importados en el prompt
- **Delegacion**: MCP server bridge o tool use via Sonnet/Opus
- **System prompt syntax**: `system_prompt_file: "path/to/agent.md"`

## Adapter Process

```
arnes/core/atlas-player.agent.md  ──┐
                                     ├──> OpenCode: inject in opencode.json agent section
                                     ├──> Codex: inject in .codexrc.json agents.atlas
                                     └──> Claude: inject in claude_desktop_config.json agents.atlas
```

## Tool Name Mapping

| Concepto (Atlas) | OpenCode | Codex | Claude |
|---|---|---|---|
| Task delegation | `task(subagent_type=...)` | `task` tool (OpenAI) | tool use |
| File read | `read` | `read` | `Read` tool |
| File edit | `edit` | `edit` | `Edit` tool |
| Shell | `bash` | `bash` | `Bash` tool |
| Web search | `websearch_web_search_exa` | built-in | built-in WebSearch |
| Context7 docs | `context7_*` MCP | built-in (if mcp enabled) | MCP server |
| Diagnostics | `lsp_diagnostics` | built-in | built-in |
| Delegation list | `delegation_list` | n/a | n/a |

## Prompt Transpilacion Rules

Cuando Atlas lanza un sub-agente, el adapter transpila:
1. **Skill references**: se mantienen (skills son docs markdown)
2. **Tool names**: se adaptan via los hooks de plataforma
3. **Persona/personalidad**: el agent.md se carga literal
4. **RPG mechanics (HP/MP)**: conceptuales, no afuera del prompt
5. **Loop engine**: implementado en Atlas (primary), no en subagents

## Activacion Cross-Platform

El script `activate.ps1` detecta la plataforma, questions al user, basic:
1. **Detecta**: OpenCode, Codex, Claude (o cualquier combinacion)
2. **Pregunta subscription**: model tier para routing
3. **Inyecta hooks**: copia / merge configs en el destino correcto
4. **Lanza UI Evenatan**: loop interactivo

## Platform-specific Quirks

### OpenCode
- Categoria-based model selection (visual-engineering, deep, etc.)
- Oh-My-OpenCode provee model routing avanzado
- SDD cycle esta soportado nativamente
- Skills: 65+ de serie

### Codex
- Reasoning levels: Sol (low), Luna (medium), Terra (high)
- GPT-5.5 con function calling nativo
- Sin categories nativas — categorias se emulan via system prompts
- Skills: se injectan en el prompt de cada agent

### Claude
- Opus/Sonnet/Haiku con temperamentos distintos
- MCP servers para integrar tools custom
- No categories nativas — roles se mapean a system prompts
- Skills: se cargan como markdown en el prompt

## Fallback Chain (cross-platform)

Si un modelo en una plataforma falla:
1. Probar el mismo modelo en otra plataforma (si esta disponible)
2. Bajar de tier (Opus -> Sonnet -> Haiku)
3. Si no hay fallback: pausar usuario

Ejemplo:
```
Vivi (Claude Opus 4) falla 2 veces
  → Fallback: Codex GPT-5.5
  → Si codex falla: OpenCode MiMo V2.5 Pro
  → Si todos fallan: pause + reportar
```

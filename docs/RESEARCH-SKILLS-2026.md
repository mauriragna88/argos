# Research: Best AI Coding Skills por GitHub Stars y Rankings

> Investigacion realizada el 2026-07-25
> Fuentes: ai-skills.io, firecrawl.dev, composio.dev, thejesh23/ai-plugin-rankings, jaychempan/Agent-Leaderboard

## Top 10 Skills en GitHub (by Stars) - Global

| # | Repo | Stars | Descripcion | Plataformas |
|---|---|---|---|---|
| 1 | obra/superpowers | 258,923 | Agentic skills framework + software development methodology | Claude Code |
| 2 | affaan-m/everything-claude-code (ECC) | 231,967 | Agent harness performance opt: instincts, memory, security | Claude, Codex, Cursor |
| 3 | NousResearch/hermes-agent | 218,516 | The agent that grows with you | Claude Code |
| 4 | x1xhlol/system-prompts-and-models | 137,532 | Extracted system prompts from major AI tools | All |
| 5 | multica-ai/andrej-karpathy-skills | 133,529 | CLAUDE.md distilling Karpathy observations | Claude Code |
| 6 | mattpocock/skills | 88,185 | Skills for Real Engineers (grill-me, handoff, tdd, triage) | Claude Code |
| 7 | nextlevelbuilder/ui-ux-pro-max-skill | 79,571 | Design intelligence for professional UI/UX | Claude |
| 8 | Leonxln/taste-skill | 66,104 | Gives AI good taste - stops generic slop | Claude Code |
| 9 | ComposioHQ/awesome-claude-skills | 68,425 | Curated 1000+ Claude skills productivity | Claude |
| 10 | nexu-io/open-design | 80,502 | Open-source Claude Design alternative | Claude, Codex, Copilot, Cursor |

## Top 10 Skills por USO(identificados por Firecrawl y Composio como los mejores OpenCode Skills)

| # | Skill | Para que sirve | Origina Stars |
|---|---|---|---|
| 1 | Obra Superpowers | Full agentic SDM: brainstorm, plan, TDD, subagents, git worktrees | 258K |
| 2 | Firecrawl | Live web context: search, scrape, crawl, browser automation | Firecrawl blog |
| 3 | stop-slop | Strips AI writing tells: em dashes, jargon, throat-clearing | 13.4K |
| 4 | Handoff (Matt Pocock) | Compresses session into markdown to continue later | 88K (all skills) |
| 5 | Grill Me | Interviews you about plan before any code written | 88K |
| 6 | Understand-Anything | Turns codebase into interactive knowledge graph | alto |
| 7 | Caveman (JuliusBrussee) | Cuts output tokens by 65% keeping tech facts intact | 61K |
| 8 | skill-optimizer | Mines session history for skill-worthy workflows | medio |
| 9 | Vault Daydream | Non-obvious connections between notes for ideas | alto |
| 10 | Composio Skills + CLI | 1000+ SaaS integrations via MCP, native tools, CLI | 68K |

## Top 10 MCP Servers (expansiones para agentes)

| # | Repo | Stars | Uso en Atlas RPG |
|---|---|---|---|
| 1 | punkpeye/awesome-mcp-servers | 87,171 | Catalog to pick MCPs |
| 2 | sansan0/TrendRadar | 57,880 | Trend monitoring |
| 3 | ChromeDevTools/chrome-devtools-mcp | 40,041 | Vivi/Rogue: browser testing |
| 4 | microsoft/playwright-mcp | 32,726 | Rogue: E2E automation |
| 5 | github/github-mcp-server | 29,976 | Ranger: research en repos |
| 6 | bgauryy/octocode-mcp | - | Semantic code research |
| 7 | Cursor-to-API/cursor-api | - | Cursor integration |
| 8 | jlowin/fastmcp | - | Build MCP Pythonic |
| 9 | PatrickJS/awesome-cursorrules | 15K+ | Rules collection |
| 10 | modelcontextprotocol/servers | Oficial | Reference implementations |

## Top AI Frameworks (alternativas a Atlas RPG)

| # | Repo | Stars | Enfoque |
|---|---|---|---|
| 1 | obra/superpowers | 258,923 | Full agentic SDM |
| 2 | FoundationAgents/MetaGPT | 68,127 | Multi-Agent Framework (First AI Software Company) |
| 3 | TauricResearch/TradingAgents | 77,314 | Multi-Agent finance (ideas adaptables) |
| 4 | bytedance/deer-flow | 68,076 | Long-horizon SuperAgent harness |
| 5 | microsoft/autogen | - | Multi-agent collaboration |
| 6 | crewai | - | Multi-agent orchestration |
| 7 | agno-agi/agno | - | Lightweight stateful agents (Phidata) |

## Skills especificos OpenCode que podemos integrar al Atlas RPG

### Para Vivi (Mage - Frontend)

1. **nextlevelbuilder/ui-ux-pro-max-skill** (79K stars) — design intelligence for professional UI
   - RECOMENDADO: este es EL skill para Vivi
2. **Leonxln/taste-skill** (66K) — stops generic slop
   - RECOMENDADO: Vivi nunca hace slop
3. **anthropics/frontend-design** (oficial) — distinctive aesthetic direction
   - RECOMENDADO: complementa ui-ux-pro-max
4. **vercel-labs/react-best-practices** — rulebook React/Next.js performance
   - RECOMENDADO: para Fireball/Inferno spells

### Para Eiko (Cleric - DevOps)

1. **anthropics/webapp-testing** — Playwright local app testing
   - RECOMENDADO: para Verify gates del Eiko
2. **cloudflare/skills** — product map for Workers, storage
   - util si proyecto en Cloudflare
3. **Composio Skills** (68K) — 1000+ SaaS integrations
   - util para deploy a plataformas externas

### Para Paladin (Backend)

1. **supabase/postgres-best-practices** (oficial) — PostgreSQL best practices
   - OBLIGATORIO para Holy Ground spell
2. **stripe/stripe-best-practices** — Stripe integrations
   - util si Paladin tiene que hacer billing
3. **auth0** skills disponible en VoltAgent/awesome-agent-skills
4. **dotnet/skills** — si backend .NET

### Para Rogue (QA/Security)

1. **anthropic/webapp-testing** — Playwright server helpers
   - OBLIGATORIO para Shadow Clone
2. **Trail of Bits security skills** — security oficial
   - OBLIGATORIO para Detect Traps
3. **codebase-recon-skill** — analyzes git history for bug magnets
   - util para Backstab

### Para Monk (Architecture)

1. **obra/superpowers** (258K) — brainstorm → plan → TDD → subagents
   - OBLIGATORIO: este es EL framework para Monk
   - Incluye: writing-plans, systematic-debugging, verification-before-completion
2. **dotnet/skills** — si backend es .NET
3. **Antigravity awesome skills** (1.4K skills antigravity)
   - nos da ideas de patrones

### Para Ranger (Research)

1. **Firecrawl skill** — live web access: search, scrape, crawl, browse
   - OBLIGATORIO: este es EL skill para Ranger
2. **anthropics/skills context7** (MCP) — library docs lookup
   - RECOMENDADO: comlemento Firecrawl
3. **github/github-mcp-server** — GitHub API access (repos, issues, PRs)
   - util para GitHub research
4. **bgauryy/octocode-mcp** — semantic code research
   - avanzado
5. **last30days-skill** — research across Reddit, X, YouTube, HN, Polymarket
   - RECOMENDADO: viaja en el tiempo para research

### Lois generales (cross-party)

1. **VoltAgent/awesome-agent-skills** (28,968 stars) — curated 1000+ official skills
   - BASE: nuestros skills deben venir de aqui
2. **anthropics/skill-creator** — para crear nuevas skills nuestras
3. **caveman** (61K) — 65% less tokens
   - util para loop engine en modo ahorrar
4. **stop-slop** (13K) — quita AI tells de prosa
   - util para outputs de Atlas to User
5. **handoff** (Matt Pocock) — session compression to continue later
   - util para/config save-state en loop engine
6. **grill-me** (Matt Pocock) — entrevista antes de codear
   - util para Monk Foresight spell

## Pinned Skills (Atlas RPG Skill Stack)

Si tuviera que recomendar 12 skills obligatorias para el Harness Atlas RPG:

| # | Skill | RPG Class | Por Que |
|---|---|---|---|
| 1 | obra/superpowers | Monk | Framework completo: brainstorm + plan + TDD + subagents |
| 2 | nextlevelbuilder/ui-ux-pro-max-skill | Vivi | UI/UX intelligence profesional |
| 3 | taste-skill | Vivi | No generic slop |
| 4 | anthropics/frontend-design | Vivi | Distinctive aesthetic direction |
| 5 | vercel-labs/react-best-practices | Vivi | React/Next.js perf rules |
| 6 | supabase/postgres-best-practices | Paladin | PostgreSQL rules |
| 7 | anthropic webapp-testing | Rogue + Eiko | Playwright workflow |
| 8 |Trail of Bits security | Rogue | OWASP official |
| 9 | Firecrawl | Ranger | Live web access |
| 10 | github/github-mcp-server | Ranger | GitHub API |
| 11 | last30days-skill | Ranger | Cross-platform research |
| 12 | anthropics/skill-creator | Atlas meta | creemos propias skills |

## Recursos adicionales

### Awesome Lists (catalogs)

1. VoltAgent/awesome-agent-skills (28,968 stars) - 1000+ skills catalog
2. ComposioHQ/awesome-claude-skills (68K) - curated list
3. hesreallyhim/awesome-claude-code (50K) - handpicked
4. PatrickJS/awesome-cursorrules (15K) - rules collection
5. jaychempan/Agent-Leaderboard - daily updated ranking
6. thejesh23/ai-plugin-rankings - daily plugin rankings
7. ai-skills.io/top-starred - top starred skills

### Marketplaces (para distribuir)

1. Smithery (https://smithery.ai) - MCP + Skills
2. skills.sh (Vercel) - leaderboard + install
3. ComposioHQ - 1000+ skills
4. agent-skill.co - VoltAgent skills

## Pendientes (Issues detectados)

1. **Oh-My-OpenCode** (66K stars) ES uno de los frameworks mas populares y lo usamos ya.
2. **OpenCode** es actualmente el AI coding agent mas starred en GitHub (182K stars) - ya lo usamos.
3. Superpowers (obra) tiene 258K stars - el king. Deberiamos integrar todo el cycle.
4. Pero .opencode/ directory es compatible con Obra Superpowers nativo (docs/README.opencode.md).
5. **ECC** (affaan-m) tiene 231K stars y es multiplataforma - pero no es skill, es harness completo.
6. Existe el estandar `AGENTS.md` que es cross-tool (CLAUDE.md se puede delegar).

## Conclusiones para Atlas RPG

1. **Skills para Vivi**: ui-ux-pro-max-skill + taste-skill + frontend-design (todas antologicas)
2. **Skills para Eiko**: webapp-testing (Anthropic)
3. **Skills para Paladin**: supabase/postgres-best-practices + stripe-best-practices (oficiales)
4. **Skills para Rogue**: trailofbits security + webapp-testing
5. **Skills para Monk**: superpowers (obra) ENTERO - es el framework mas completo
6. **Skills para Ranger**: Firecrawl + github-mcp-server + context7 (ya lo tenemos!)
7. **Cross-party**: skill-creator (para crear nuevas skills), caveman (token saver), handoff (save state)

**Estrategia**: Integrar estos skills en el skill registry de Atlas RPG como "imported skills" con un campo `source: github` y mapearlos a las classes RPG.

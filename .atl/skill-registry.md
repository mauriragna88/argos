# Skill Registry — Harness RPG Atlas (v2 - 2026-08-05)

## Registry Structure
Este archivo mapea las skills de cada clase RPG a las **skills PROPIAS del arnes (v2)**.
CERO referencia a ARNES. Las skills web instaladas (react, tailwind, superpowers...)
son **complemento de poder** — potencian la ejecución, nunca son dependencia obligatoria.

## Class Skill Mapping (v2 — skills PROPIAS)

### Mage (Vivi) — Frontend
| Skill v2 | Skill web complemento | Level | Damage | MP Cost | Trigger |
|---|---|---|---|---|---|
| vivi-fireball | react, tailwind, design-systems, accessibility | 1 | 25HP | 2K tkns | Crear componente React/TSX |
| vivi-flare | react, tailwind, atomic-design | 1 | 20HP | 1.5K tkns | Refinar UI existente |
| vivi-inferno | react + tailwind + design-systems | 3 | 65HP | 8K tkns | Feature frontend completa |
| vivi-meteor | react + tailwind + design-systems + accessibility | 5 | 100HP | 15K tkns | Boss frontend |

### Paladin (Ansem) — Backend
| Skill v2 | Skill web complemento | Level | Damage | MP Cost | Trigger |
|---|---|---|---|---|---|
| ansem-smite | api-design, typescript | 1 | 30HP | 3K tkns | Crear API route |
| ansem-divine-shield | security, owasp, auth-patterns | 2 | 35HP | 4K tkns | Security hardening |
| ansem-holy-ground | schema-design, postgresql, prisma | 3 | 50HP | 6K tkns | Database schema |
| ansem-bulwark | encryption, security | 3 | 45HP | 5K tkns | RLS + auth setup |

### Rogue (Kuja) — QA/Security
| Skill v2 | Skill web complemento | Level | Damage | MP Cost | Trigger |
|---|---|---|---|---|---|
| kuja-backstab | testing-principles, owasp | 1 | 20HP | 1K tkns | Edge case hunt |
| kuja-shadow-clone | vitest, mocking, playwright | 3 | 50HP | 6K tkns | Full test suite |
| kuja-detect-traps | owasp, security | 2 | 30HP | 2K tkns | Security audit |
| kuja-eviscerate | vitest + playwright + testing-principles | 4 | 70HP | 8K tkns | Full E2E + unit |

### Cleric (Eiko) — Healer/DevOps
| Skill v2 | Skill web complemento | Level | Damage | MP Cost | Trigger |
|---|---|---|---|---|---|
| eiko-mend | feedback-loop, validation-pipeline | 1 | +30HP | 1K tkns | Fix broken build |
| eiko-cura | ci-cd, git-discipline | 2 | +50HP | 3K tkns | CI/CD repair |
| eiko-mass-heal | docker-compose, ci-cd, deploy | 3 | +80HP | 5K tkns | Full recovery |
| eiko-esuna | git-discipline | 1 | +20HP | 500 tkns | Resolve merge conflict |

### Monk (Amarant) — Architecture
| Skill v2 | Skill web complemento | Level | Damage | MP Cost | Trigger |
|---|---|---|---|---|---|
| amarant-foresight | project-structure, clean-architecture | 1 | 15HP | 2K tkns | Feature planning |
| amarant-meditation | arnes-sdd-propose/spec/design | 3 | 40HP | 10K tkns | SDD full cycle |
| amarant-zen | arnes-sdd-* + clean-architecture | 5 | 80HP | 12K tkns | Full system design |

### Ranger (Eremez) — Research
| Skill v2 | Skill web complemento | Level | Damage | MP Cost | Trigger |
|---|---|---|---|---|---|
| eremez-mark | context7, web-search | 1 | 10HP | 500 tkns | Find docs |
| eremez-swarm | context7 + web search + github | 2 | 35HP | 3K tkns | Multi-source research |
| eremez-wide-net | web search + github + context7 | 4 | 55HP | 5K tkns | Full competitive analysis |

### Auditores y Especiales (v2 — skills PROPIAS)
| Agente | Skill v2 | Trigger |
|---|---|---|
| Auron | auron-bulwark | L0 Gate + OWASP audit |
| Bran | bran-vision | % completado, dead code, growth |
| Quina | quina-ledger | Token economy, /status |
| Varys | varys-whisper | Observar party, evidence_pack, write-back |
| Tywin | tywin-judgment | Verdict PASS/FAIL con evidencia |
| Tywin | arnes-contract-audit | Contract audit DB↔API↔Frontend (pre-verdict, pre-deploy, post-migration) |
| Sam | sam-counsel | Recomendación con memoria histórica |
| Atlas | atlas-orchestrate | Orquestar quests, party select, loop |
| Tidus | tidus-tide-check | Health-check recursos, cuotas |
| Ragnarok | ragnarok-scout | Scan web, comparativas, compras |

## Compact Rules for Skill Resolution (v2)

Cuando Atlas selecciona un party, resuelve skills así:
- `.tsx` `.jsx` → vivi-fireball (react, tailwind, design-systems)
- `.ts` API routes → ansem-smite (api-design, typescript)
- `*.test.*` `*.spec.*` → kuja-backstab (vitest, playwright, testing-principles)
- `Dockerfile` `docker-compose.yml` → eiko-mend (docker, docker-compose)
- `.github/workflows/` → eiko-mend (ci-cd, git-discipline)
- `schema.prisma` `migrations/` → ansem-smite (prisma, schema-design)
- Architecture docs → amarant-foresight (clean-architecture, arnes-sdd-*)
- Unknown library → eremez-mark (context7, web-search)
- L0 / deploy / RLS → auron-bulwark (L0 Gate obligatorio)
- migraciones / `database.types.ts` / contratos DB↔Frontend → arnes-contract-audit (gate determinístico, ADR-006)
- Queries Supabase / RLS / auth → arnes-contract-audit (leer patrones de auth del proyecto antes de codificar)
- "¿cómo vamos?" / análisis → bran-vision
- "revisa recursos" → tidus-tide-check
- "¿hay algo nuevo?" / compras → ragnarok-scout

### Contract Audit (arnes-contract-audit) — OBLIGATORIO
Audita el contrato de datos DB↔API↔Frontend. Es **MANDATORY pre-verdict** para quests que toquen la superficie DB/frontend (migraciones, `database.types.ts`, tipos compartidos). Referencia: **ADR-006**.

**Carga automática para agentes que escriben código:**
- **Vivi** (frontend): debe cargar la skill antes de escribir cualquier componente que haga queries Supabase
- **Ansem** (backend): debe cargar la skill antes de crear migraciones, schemas o RLS
- **Tywin** (verificador): invoca el gate `npm run contract:audit` como paso mandatory pre-verdict
- **Pasos**:
  1. Leer `scripts/contract-audit/config.json` → sección `auth` para conocer los patrones del proyecto
  2. Conocer tenant column, profile table, helpers de auth, claims JWT usados
  3. NO adivinar — si `config.json` no tiene sección `auth`, correr `argos audit scan` primero
  4. Escribir código que respete esos patrones exactos

## Skills web = COMPLEMENTO DE PODER (se mantienen instaladas)

| Skill web | Potencia a |
|---|---|
| react, tailwind, design-systems, accessibility | Vivi |
| api-design, typescript, postgresql, supabase-cli | Ansem |
| vitest, playwright, testing-principles, mocking | Kuja |
| ci-cd, docker, deploy, git-discipline | Eiko |
| clean-architecture, project-structure | Amarant |
| context7, rag | Eremez |
| owasp, security | Auron |
| superpowers (258K⭐), ui-ux-pro-max (79K⭐), taste-skill (66K⭐) | Party (arsenal extra) |

## GAPs (oportunidades para Ragnarok)
- Contract validation DB↔Frontend: **CERRADO** (arnes-contract-audit, ADR-006)
- Bard: mejorar DX/docs (parcialmente cubierto)
- Performance: query-optimization (Alchemist futuro)
- Marketing/Ventas: vacante (futuro)

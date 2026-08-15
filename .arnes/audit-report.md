# Atlas Harness - Audit Report de Gaps

**Fecha**: 2026-07-28
**Alcance**: 15 agentes (6 party + 7 auditores + atlas-player + bard) + 9 skill trees + harness (loop-engine, model-router, quest-detector)
**Estado base**: atlas-init.ps1 reporta 15 agentes sync, 9 skills sync, smoke test 15/15 PASS
**Metodo**: Lectura completa de cada archivo. Comparacion contra los estandares definidos en proposal.md, spec.md, y la master config.

---

## Resumen Ejecutivo

| Categoria | Total | Completos | Con gaps | Criticidad |
|---|---|---|---|---|
| Party members | 6 | 5 | 1 (hand-offs Varys en todos) | Baja |
| Auditores | 7 | 5 | 2 (Quina incompleto, Tywin corto) | Media |
| Atlas core | 1 | 1 | 0 | - |
| Bard | 1 | 1 | 0 | - |
| Harness specs | 3 | 3 specs existen | 3 sin implementar | Alta |
| Skill trees | 9 | 9 | 0 | - |
| CLI scripts | 11 | 11 | 1 sin integrar (update-ledger) | Alta |

**Gaps principales**:
1. **Quina** es el agente mas debil (45 lineas vs promedio 150). Sin mem_save protocol, sin /status formato, sin circuit breaker ref.
2. **Los 6 party members no mencionan Varys explicitamente** en su seccion de hand-offs. Es implicito via atlas-player.
3. **El harness real no esta implementado**: loop-engine, model-router, quest-detector, circuit-breaker existen como specs markdown pero no hay codigo que los ejecute.
4. **update-ledger.ps1 no se invoca** automaticamente post-quest.

---

## Fase 1: Party Members (6 archivos)

### core/classes/mage.agent.md (Vivi - Frontend Mage)
**Status**: COMPLETO (194 lineas)
**CHEQUEOS**:
- [x] Identidad + stats + personalidad
- [x] Dominio tecnico master
- [x] Skills tree (8 spells con lvl, dmg, mp_cost, trigger)
- [x] Skills externas importadas (5 referencias)
- [x] Reglas inalterables (10 reglas)
- [x] Exclusions + Exclusiones criticas
- [x] Memoria propia (6 namespaces)
- [x] Ejemplo de turno completo
- [x] Protocolo mem_save (mandatorio)
- [x] Anti-patron monotonia

**GAPS**:
- MISSING: Seccion "Hand-offs con Varys" explicita. Varys es quien le delega quests. Vivi lo asume pero no lo documenta.
- MISSING: Seccion "Reglas de Bran/Sam" explicita. mem_save dice que Sam lo lee pero Vivi no sabe que Bran recomienda party size.
- MISSING: Mem_save example esta roto (linea 178 tiene " -join\n\"" colgando).

---

### core/classes/eiko.agent.md (Eiko - Healer/DevOps)
**Status**: COMPLETO (153 lineas)
**CHEQUEOS**:
- [x] Identidad + stats + personalidad (serena, metodica)
- [x] Dominio tecnico (CI/CD, Docker, deploys, git discipline)
- [x] Skills tree (6 spells: Mend, Esuna, Cura, Protect, Shell, Mass Heal)
- [x] Reglas de combate (10 reglas)
- [x] Exclusions + Exclusiones criticas (L0, no force push)
- [x] Memoria propia (5 namespaces)
- [x] Ejemplo de turno
- [x] Protocolo mem_save

**GAPS**:
- MISSING: Seccion "Hand-offs con Varys" explicita.
- MISSING: Seccion "Reglas de Bran/Sam" explicita.
- MISSING: Skills externas importadas (Ansem, Vivi, etc. las tienen; Eiko no).
- MISSING: Mem_save example roto (linea 137 tiene " -join\n\"" colgando).

---

### core/classes/paladin.agent.md (Ansem - Backend Tank)
**Status**: COMPLETO (146 lineas)
**CHEQUEOS**:
- [x] Identidad + stats + personalidad (estoico, metodico)
- [x] Dominio tecnico (12 items: Next.js, Supabase, Prisma, streaming, edge, etc.)
- [x] Skills tree (5 spells: Smite, Divine Shield, Holy Ground, Judgment, Bulwark)
- [x] Skills externas importadas (3: supabase, stripe, trail of bits)
- [x] Reglas inalterables (7 reglas)
- [x] Exclusions
- [x] Memoria propia (7 namespaces)
- [x] Ejemplo de turno
- [x] Protocolo mem_save

**GAPS**:
- MISSING: Seccion "Hand-offs con Varys" explicita.
- MISSING: Seccion "Reglas de Bran/Sam" explicita.
- MISSING: Mem_save example roto (linea 130).

---

### core/classes/rogue.agent.md (Kuja - QA/Security)
**Status**: COMPLETO (149 lineas)
**CHEQUEOS**:
- [x] Identidad + stats + personalidad (elegante, narcisista, dramatico)
- [x] Dominio tecnico (Vitest, Playwright, Stryker, axe-core, OWASP, mocking, factories)
- [x] Skills tree (7 spells: Backstab, Poison Tipped, Detect Traps, Toxin Trace, Shadow Clone, A11y Snare, Eviscerate)
- [x] Skills externas importadas (5 referencias)
- [x] Reglas inalterables (8 reglas)
- [x] Exclusions
- [x] Memoria propia (6 namespaces)
- [x] Ejemplo de turno
- [x] Protocolo mem_save

**GAPS**:
- MISSING: Seccion "Hand-offs con Varys" explicita.
- MISSING: Seccion "Reglas de Bran/Sam" explicita.
- MISSING: Mem_save example roto (linea 133).

---

### core/classes/monk.agent.md (Amarant - Architecture)
**Status**: COMPLETO (146 lineas)
**CHEQUEOS**:
- [x] Identidad + stats + personalidad (silencioso, contemplativo, aforismos)
- [x] Dominio tecnico (Clean Arch, SDD, monorepo, ADRs)
- [x] Skills tree (5 spells: Foresight, Inner Peace, Mantra, Meditation, Zen Architecture)
- [x] Skills externas (obra/superpowers 258K, karpathy, mattpocock grill-me)
- [x] Reglas inalterables (8 reglas)
- [x] Exclusions
- [x] Memoria propia (6 namespaces)
- [x] Ejemplo de turno
- [x] Protocolo mem_save

**GAPS**:
- MISSING: Seccion "Hand-offs con Varys" explicita.
- MISSING: Seccion "Reglas de Bran/Sam" explicita.
- MISSING: Mem_save example roto (linea 130).

---

### core/classes/ranger.agent.md (Eremez - Research)
**Status**: COMPLETO (143 lineas)
**CHEQUEOS**:
- [x] Identidad + stats + personalidad (curioso, meticuloso, no inventa)
- [x] Dominio tecnico (Context7, Exa, GitHub, Firecrawl, MCP)
- [x] Skills tree (5 spells: Mark, Tracker, Scout, Swarm, Wide Net)
- [x] Skills externas (Firecrawl siempre activa + 4 mas)
- [x] Reglas inalterables (6 reglas)
- [x] Exclusions
- [x] Memoria propia (6 namespaces)
- [x] Ejemplo de turno
- [x] Protocolo mem_save

**GAPS**:
- MISSING: Seccion "Hand-offs con Varys" explicita.
- MISSING: Seccion "Reglas de Bran/Sam" explicita.
- MISSING: Mem_save example roto (linea 127).

---

## Fase 2: Auditores (7 archivos)

### core/auditors/varys.agent.md (Varys - Tracker/Compinche)
**Status**: COMPLETO - MODELO A SEGUIR (181 lineas)
**CHEQUEOS**:
- [x] Identidad + stats + personalidad
- [x] Hand-off Protocol con 3 ejemplos concretos (delegacion, reporte, conflicto)
- [x] Activation flow diagram completo
- [x] Skill tree (6 skills)
- [x] Reglas (7 reglas inmutables)
- [x] Exclusions
- [x] Memoria propia (7 namespaces)
- [x] Ejemplo de turno completo (con multiparty)
- [x] Protocolo mem_save

**GAPS**:
- MISSING: Mem_save example roto (linea 165).

**NOTA**: Varys es el agente mejor documentado. Es el patron de referencia para hand-offs.

---

### core/auditors/tywin.agent.md (Tywin - Verifier)
**Status**: CORTO pero funcional (125 lineas)
**CHEQUEOS**:
- [x] Identidad + stats + personalidad (severe, directo, sin compasion)
- [x] Reglas (8 reglas)
- [x] Skill tree (3 skills: Inquisition, Cross-Check, Lannister's Verdict)
- [x] Memoria propia (4 namespaces)
- [x] Ejemplo de turno
- [x] Protocolo mem_save

**GAPS**:
- MISSING: Criterios PASS/FAIL concretos. Las reglas son genericas ("RPG compliance", "Standard check"). Necesita checklist como:
  - Frontend: loading state? error state? empty state? ARIA? mobile-first?
  - Backend: Zod validation? RLS? explicit errors? no any?
  - Tests: coverage > 80%? factories? mock realista?
- MISSING: No menciona criterios para L0 quests (cuando pausa автоматicamente).
- MISSING: Hand-off Protocol explicito (como entra Varys, como sale a Sam).
- MISSING: Skills externas (otros auditores las tienen).
- MISSING: Output format estructurado (Bran y Sam tienen JSON reports; Tywin no).

---

### core/auditors/sam.agent.md (Sam - Elder Counselor)
**Status**: COMPLETO (385 lineas)
**CHEQUEOS**:
- [x] Identidad + stats + personalidad (sabio, paciente)
- [x] Evolucion documentada (de archivist a consejero)
- [x] Flujo operativo (TURN 0 a TURN 8)
- [x] Decision matrix via memoria historica
- [x] Trust score per agent (con ejemplo)
- [x] Anti-repetition mandatory
- [x] Skills tree (8 skills)
- [x] Memoria propia (7 namespaces)
- [x] Output protocol (consejo menor, mayor, trust scores)
- [x] Exclusiones
- [x] Connection con Bran (diferenciador practico)
- [x] Ejemplo de turno completo
- [x] Protocolo mem_save

**GAPS**:
- MISSING: Fallback arnes.db offline - Sam menciona `.arnes/memory/sam-*.jsonl` pero no los scripts que los leen/escriben.
- MISSING: Mem_save example roto (linea 369).

**NOTA**: Sam es el segundo agente mas completo junto con Bran. Complejo pero solido.

---

### core/auditors/bran.agent.md (Bran - Seer/Strategist)
**Status**: COMPLETO (378 lineas)
**CHEQUEOS**:
- [x] Identidad + stats + personalidad (abstracto, flashes de datos)
- [x] Por que Bran ahora es #2 (justificacion de jerarquia)
- [x] 5 responsabilidades (Project Sight, Repo Sizer, Resource Allocator, Growth, Continuous Improvement)
- [x] Repo tier classifier (lean/medium/standard/boss con criterios)
- [x] Override CLI flags (--lean, --full-party, --boss-party, --auto)
- [x] Flujo operativo (Trigger A: arranque, Trigger B: pre-quest, Trigger C: post-quest, Trigger D: /status)
- [x] Output protocol (Allocate JSON, Streak report ASCII, Resource tactician JSON)
- [x] Skills tree (7 skills)
- [x] Memoria propia (5 namespaces)
- [x] Reglas inmutables (8 reglas)
- [x] Exclusiones
- [x] Connection con Sam
- [x] Ejemplo de turno completo
- [x] Protocolo mem_save

**GAPS**:
- MISSING: Mem_save example roto (linea 362).
- TYPO: Linea 241 tiene "南通" (caracteres chinos colados).

**NOTA**: Bran es el agente mas completo del harness. Define la nomenclatura de tiers y allocation.

---

### core/auditors/auron.agent.md (Auron - Security Warden)
**Status**: COMPLETO (101 lineas)
**CHEQUEOS**:
- [x] Identidad + stats + personalidad (callado, seguro, infalible)
- [x] Trigger automatico L0 (tabla de tipos de quest)
- [x] Dominio tecnico (OWASP, RLS, Auth, Encryption, XSS, JWT, CSP, supply chain)
- [x] Skills tree (6 skills con damage)
- [x] Protocolo de entrada forzada (L0 Quest)
- [x] Mem_save obligatorio (con ejemplo concreto)
- [x] Reglas adicionales (6 reglas)
- [x] Exclusions
- [x] Memoria propia (3 namespaces)

**GAPS**:
- MISSING: Skills externas importadas (otros auditores las tienen; Auron podria referenciar owasp, auth-patterns, encryption skills del registry).
- MISSING: Seccion Hand-off Protocol explicito (como entra al party, como sale).
- MISSING: OWASP checklist itemizada (A01-A10) con ejemplos concretos. El dominio lo menciona pero no es un checklist accionable.
- MISSING: Protocolo mem_save completo (tiene version corta, no la version larga con anti-patron monotonia).

---

### core/auditors/quina.agent.md (Quina - Token Banker)
**Status**: MUY INCOMPLETO (45 lineas) - **EL MAS DEBIL DE LOS 13**
**CHEQUEOS**:
- [x] Identidad (parcial - tiene Name/Class/Role/Color/HP/MP/Personality)
- [x] Domain (3 items vagos)
- [x] Skills (3 skills sin lvl, sin damage, sin MP cost, sin trigger)
- [x] Rules (una linea: "Quina NO ejecuta trabajo, solo calcula")
- [x] Memoria (3 namespaces vagos)

**GAPS CRITICOS**:
- MISSING: Skills tree completo (sin lvl, dmg, mp_cost, trigger como los demas)
- MISSING: Hand-off Protocol (como reporta /status, como avisa when budget tight)
- MISSING: Thresholds concretos (warn 80%, critical 95% existen en config.json pero Quina no los documenta)
- MISSING: Output /status format estructurado
- MISSING: Mem_save protocolo completo (no tiene el bloqueo mandatorio)
- MISSING: Exclusions
- MISSING: Ejemplo de turno
- MISSING: Anti-patron monotonia
- MISSING: Connection con Bran (Bran usa datos de Quina para Allocate)
- MISSING: Circuit breaker reference (Quina es quien mas deberia usarlo - budget = 100K tokens上限)

**ACCION REQUERIDA**: Quina necesita un rewrite casi completo. Solo 45 lineas vs 150-380 de los demas.

---

### core/auditors/varys-documentalist.agent.md (Varys Doc - Document Auditor)
**Status**: COMPLETO (186 lineas)
**CHEQUEOS**:
- [x] Identidad + stats + personalidad
- [x] Dominio tecnico (drift detection, stale info, secret detection, typo scan, cross-ref)
- [x] Skills tree (4 spells con lvl, dmg, mp_cost, trigger)
- [x] Reglas (7 reglas)
- [x] Triggers para auditoria periodica
- [x] Memoria propia (7 namespaces)
- [x] Output format YAML estructurado con ejemplo completo
- [x] Exclusions
- [x] Ejemplo de turno
- [x] Activation command (/audit-docs)

**GAPS**:
- MISSING: Protocolo mem_save completo (no tiene el bloque mandatorio como otros).
- MISSING: Skills externas importadas.
- MISSING: Connection con Tywin (en el ejemplo, Tywin confirma el reporte de Varys Doc pero no esta documentado el hand-off).

---

## Fase 3: Harness Real (3 specs sin implementar)

### core/loop-engine.agent.md (146 lineas)
**Status**: SPEC COMPLETO, SIN IMPLEMENTAR
**CHEQUEOS**:
- [x] State machine diagramada (IDLE -> QUESTING -> EVALUATING -> AUTO_NEXT/PAUSE_USER/CIRCUIT_BREAKER)
- [x] HP/MP tracking definido
- [x] Anti-loop-forever rules (6 reglas)
- [x] Logging format per-turn
- [x] Loop badge system (gamification)
- [x] Circuit breaker definido (3 fails/60min = bloqueo 30min)

**GAPS**:
- MISSING: **Codigo que ejecute esto**. El loop engine es solo markdown; no hay powershell/bash/python que implemente la state machine.
- MISSING: Integracion con atlas.ps1 (donde el loop engine deberia invocarse post-quest).

---

### core/model-router.agent.md (289 lineas)
**Status**: SPEC COMPLETO, SIN IMPLEMENTAR
**CHEQUEOS**:
- [x] Catalogo de modelos 2026 (OpenCode, Codex, Claude) con tiers y rate limits
- [x] Routing table por suscripcion × plataforma (free, pro, plus, max)
- [x] Quest type overrides (boss_fight, frontend, backend, trivial)
- [x] Reasoning level selection (Codex)
- [x] Routing algorithm en pseudocode Python
- [x] Onboarding CLI first-run
- [x] Re-config commands
- [x] Fallback chain

**GAPS**:
- MISSING: **Codigo que ejecute esto**. El model router es solo markdown; no hay powershell/bash que asigne modelos.
- MISSING: Integracion con .arnes/config.json (los modelos asignados no se persisten alli).
- MISSING: Deteccion automatica de plataforma (el usuario tiene que elegir manualmente).

---

### core/quest-detector.agent.md (89 lineas)
**Status**: SPEC COMPLETO, SIN IMPLEMENTAR
**CHEQUEOS**:
- [x] Output JSON definido (quest_type, complexity, suggested_party, is_l0, quests_chain, estimated_hp, estimated_mp)
- [x] Detection rules por keyword (frontend, backend, fix, architecture, research, devops, boss)
- [x] Complexity heuristic (trivial..boss)
- [x] Multi-quest chain detection
- [x] Ambiguity handler

**GAPS**:
- MISSING: **Codigo que ejecute esto**. El quest detector es solo markdown; no hay regex/ps1 que clasifique el prompt.
- MISSING: Integracion con atlas.ps1 (cuando el user manda un prompt, no pasa por quest-detector).

---

### .arnes/config.json (circuit breaker)
**Status**: DEFINIDO, SIN ENFORCEMENT
**CHEQUEOS**:
- [x] circuit_breaker definido (threshold=3, window=60min, cooldown=30min)
- [x] combat config (max_retries=2, backoff_ms=[2000,4000])

**GAPS**:
- MISSING: **Codigo que enforze el circuit breaker**. La config esta pero ningun script la lee para bloquear agentes.
- MISSING: Estado del circuit breaker persistido (no hay `.arnes/circuit-breaker.json` con contador de fallos por agente).

---

### CLI scripts (integracion pendiente)

#### cli/update-ledger.ps1 (3720 bytes)
- EXISTE pero no se invoca automaticamente post-quest.
- Necesita hook desde atlas.ps1: `if quest_done { invoke update-ledger.ps1 }`.

#### cli/arnes-memory.ps1 (7010 bytes)
- EXISTE pero no se invoca desde los agentes automaticamente.
- El mem_save mandatorio descrito en los 15 agentes es texto; no hay codigo que ejecute `mem_save`.

#### cli/repo-profile.ps1 (13596 bytes)
- EXISTE y funciona (lo corre atlas-init.ps1).
- Necesita re-ejecucion cada 20 quests como dice Bran. No esta integrado con el loop engine.

---

## Gaps Transversales (afectan a todos los agentes)

### PATTERN: Mem_save example roto en 9 de 13 archivos
Los archivos mage, eiko, paladin, rogue, monk, ranger, varys, sam, bran terminan con un bloque roto:
```
- `vivi/components-built`: <cuando usarlo> - `vivi/ui-patterns`: <cuando usarlo> - `vivi/failed-attempts`: <cuando usarlo> - `vivi/xp`: <cuando usarlo> - `vivi/eiko-requests`: <cuando usarlo> -join "
"
```
Deberia ser una lista multilinea, no una sola linea con `-join "`n"`. Error de formato al copiar el template entre agentes.

### PATTERN: Hand-offs con Varys implicitos en party
Los 6 party members no documentan explicitamente como reciben delegaciones de Varys. Es implícito (Varys esta documentado, pero al leer solo el archivo del party member, no se entiende el flujo).

### PATTERN: Encoding issues
Algunos archivos tienen caracteres UTF-8 mal decodificados: `â€"` deberia ser `—` (em dash), `Ã¡` deberia ser `á`. Aparecen en mage, paladin, rogue, monk, ranger, bran. No rompen funcionalidad per UILabel.

---

## Priorizacion Recomendada

**Cambio pequeno (1-2 horas)**:
1. Fix Quina (rewrite a 120+ lineas con todos los CHEQUEOS)
2. Fix Tywin (agregar criterios PASS/FAIL concretos + output estructurado)
3. Fix mem_save example roto en los 9 archivos (busqueda y reemplazo)
4. Fix encoding issues (re-encode UTF-8)

**Cambio mediano (1 dia)**:
5. Agregar seccion "Hand-offs con Varys" a los 6 party members (referencia cruzada al protocolo de Varys)
6. Agregar seccion "Reglas de Bran/Sam" a los 6 party members (1 parrafo cada uno)
7. Completar Auron (OWASP checklist + hand-off protocol + mem_save version larga)
8. Completar Varys Doc (mem_save + skills externas + hand-off con Tywin)

**Cambio grande (varios dias)**:
9. Implementar loop engine real (powershell que ejecute la state machine)
10. Implementar quest detector real (regex + clasificador)
11. Implementar model router real (script que lea config + asigne modelo al spawn)
12. Implementar circuit breaker enforcement (contador persistente + bloqueo)
13. Integrar update-ledger.ps1 al loop engine (auto-update post-quest)
14. Integrar arnes-memory.ps1 al guardado automatico post-turn
15. Integrar repo-profile.ps1 al streak report de Bran (re-run cada 20 quests)

---

## Conclusion

Los 15 agentes como **archivos de instrucciones** estan 90% completos. Los unicos que necesitan trabajo serio son **Quina** (incompleto) y **Tywin** (corto). El resto tienen gaps uniformes (hand-offs Varys, reglas Bran/Sam, mem_save example roto) que se pueden fixear con un script de busqueda/reemplazo.

El **harness real** - el codigo que hace que los 15 agentes funcionen en conjunto - no existe. Los 3 specs (loop-engine, model-router, quest-detector) estan bien documentados pero sin implementacion. Sin eso, los 15 agentes son instrucciones que un humano lee pero que ninguna maquina orquesta. Ese es el cambio grande que falta.

# ARNES ARGOS — Contexto del harness (para integrar con otra IA / arnes)

> Documento de contexto para dárselo a otra IA o harness y explicarle qué es ARNES ARGOS,
> cómo funciona y cómo se integra. Redactado el 2026-08-06.

---

## 1. Qué es

**ARNES ARGOS** es un harness RPG de desarrollo con **16 agentes de IA** con roles propios
(Atlas, Vivi, Ansem, Kuja, Eiko, Amarant, Eremez, Auron, Bran, Quina, Varys, Tywin, Sam,
Bard, Tidus, Ragnarok). "ARGOS" es el gigante mitológico de los 100 ojos: todo lo ve.

- **Capa de configuración**: conexiones a proveedores de modelos y asignación de modelo por agente (una vez por máquina).
- **Capa de memoria**: cada proyecto tiene SU PROPIO cerebro SQLite (`arnes.db`, FTS5) — conversaciones, decisiones, quests, digests. Aislado por carpeta.
- **Capa de agentes**: los 16 agentes RPG definidos en markdown, con su prompt y SU modelo asignado. Se sincronizan a OpenCode para trabajar ahí.
- **Capa de orquestación**: ciclo completo Atlas → Amarant → Bard → party → Tywin → Atlas, con mejora continua.
- **Independencia**: memoria, metodologías (SDD/FDD/ADR/TDD) y motor propios. Cero dependencia de herramientas de terceros para orquestación.

## 2. Arquitectura

```
+--------------------------------------------------------------+
|  ARNES ARGOS (tu capa)                                        |
|  argos CLI · chat nativo · ciclo orquestador · modo coding    |
|  config global (~/.config/arnes) · memoria por proyecto       |
|  16 agentes RPG + skills propias (SDD/FDD/ADR/TDD)            |
+--------------------------------------------------------------+
|  Motor nativo (argos-engine.ps1)                              |
|  habla DIRECTO con las APIs: bai, nvidia, opencode-go, openai |
|  OpenAI-compatible · function calling · reintentos · UTF-8    |
+--------------------------------------------------------------+
|  Opcional: OpenCode como entorno de trabajo                   |
|  (argos opencode sincroniza agentes+modelos y abre OpenCode)  |
+--------------------------------------------------------------+
```

## 3. Los 16 agentes (party)

| Agente | Clase | Rol | Modelo sugerido |
|---|---|---|---|
| Atlas | Player/Orchestrator | Orquesta, delega, autoriza (nunca codea) | qwen3.8-max |
| Vivi | Mage | Frontend (React/Next/Tailwind) | gpt-5.6-luna |
| Ansem | Paladin | Backend (APIs, Supabase, Zod) | deepseek-v4-flash |
| Kuja | Rogue | QA (tests, edge cases) | deepseek-v4-flash |
| Eiko | Cleric | DevOps (CI/CD, builds, deploy) | deepseek-v4-flash |
| Amarant | Monk | Arquitectura (SDD, ADR, planes) | gpt-5.6-luna |
| Eremez | Ranger | Research (librerías, docs) | deepseek-v4-flash |
| Auron | Warden | Seguridad (OWASP, RLS, L0 gate) | deepseek-v4-pro |
| Bran | Seer | Análisis, % completado, crecimiento | gpt-5.6-luna |
| Quina | Banker | Tokens, presupuesto | deepseek-v4-flash |
| Varys | Spider | Tracker, evidencia | gpt-5.6-luna |
| Tywin | Verifier | Verdict PASS/FAIL con evidencia | deepseek-v4-flash |
| Sam | Archivist | Consejo estratégico con memoria | gpt-5.6-luna |
| Bard | Bard | Mejora continua (qué falta, qué agregar) | deepseek-v4-flash |
| Tidus | Warden | Infra, entorno, health-check | deepseek-v4-flash |
| Ragnarok | Warden | Compras, herramientas, proveedores | gpt-5.6-luna |

**Economía de tokens por diseño**: Atlas (modelo tier) se usa SOLO 2 veces por quest (orquesta + autoriza).
El volumen lo hacen modelos baratos/gratis (DeepSeek Flash, NVIDIA gratis).

## 4. Memoria (por proyecto)

- Cada proyecto tiene su cerebro: `<proyecto>/.arnes/arnes.db` (SQLite + FTS5).
- CLI: `cli/arnes-memory.ps1` (init, save, search, context, agent, export, import, stats, quest, edge).
- Guardado incremental: cada intercambio de chat se guarda al instante (Ctrl+C / apagón no pierde nada).
- Namespaces por agente (ej: `vivi://ui-patterns`, `atlas/chat/2026-08-06`).
- Export/import JSONL para snapshots portables.
- `cli/arnes-graph.ps1`: relaciones entre componentes/librerías/agentes (edges, BFS).

## 5. Configuración (una vez por máquina)

- `~/.config/arnes/connections.json` — proveedores (bai, nvidia, opencode-go, openai...) con keys.
- `~/.config/arnes/agent-models.json` — qué modelo usa cada uno de los 16 agentes.
- Por proyecto: `.arnes/project.json` (perfil: ruta, git, stack, stats), `.arnes/quests/` (reportes), `.arnes/config.json`.

## 6. Comandos (CLI `argos`)

```
argos                     menú (detecta proyecto nuevo y auto-inicializa)
argos connect             conectar proveedores (verifica la key contra la API)
argos configure           elegir modelo por agente (catálogo vivo, buscador)
argos recommend           recomendación inteligente (ahorro/equilibrio/calidad)
argos chat                chat nativo multi-turno con memoria
argos quest "<quest>"     ciclo orquestador completo (6 etapas)
argos code "<quest>"      modo coding: crea/edita archivos reales (pide permiso)
argos opencode            sincroniza agentes+modelos a OpenCode y lo abre
argos verify              verifica conexiones reales contra las APIs
argos doctor              revisa prerequisitos (9 checks)
argos test-model <modelo> prueba "hola" con un modelo específico
argos status              perfil del proyecto + conexiones verificadas
```

## 7. Flujos clave

### Ciclo orquestador (`argos quest`)
1. **ATLAS** detecta el quest, elige el PARTY y el plan general (formato `PARTY: vivi, ansem, ...`).
2. **AMARANT** produce el plan técnico (pasos, archivos, validaciones).
3. **BARD** mejora continua: qué FALTA, qué NO se mencionó, qué AGREGAR (relacionado al proyecto).
4. **PARTY** cada especialista ejecuta su parte con SU modelo.
5. **TYWIN** verifica contra el plan (VERDICT PASS/FAIL + remediation).
6. **ATLAS** autoriza (FINALIZAR) o pide RETOQUE.
→ Reporte en `.arnes/quests/quest-<fecha>.md` + mejoras/verdicts en memoria.

### Modo coding (`argos code`)
- Herramientas: `list_dir`, `read_file`, `write_file`, `edit_file`, `run_command`, `search`.
- Loop agente+herramientas (una herramienta por mensaje), con **puerta de permiso**:
  `[PERMISO] Escribir archivo X? [Y/n]` antes de tocar cualquier archivo.
- Restringido a la carpeta del proyecto; rutas relativas.

### Chat (`argos chat`)
- Multi-turno, memoria incremental por proyecto, cuestionario interactivo (Atlas pregunta con opciones → eliges [1][2][3] o escribes).
- Handoff a coding: `/code <quest>` o oferta automática cuando Atlas no puede escribir archivos.

## 8. Puntos de integración (para conjuntar con otro arnes)

| Recurso | Qué expone | Cómo se usa |
|---|---|---|
| `cli/argos-engine.ps1` | Motor de completions directo a APIs | `& argos-engine.ps1 -Model <id> -System <s> -Message <m> -Tools @(...) -Session @(...)` — devuelve objeto con reply/tool_calls/usage |
| `cli/arnes-memory.ps1` | Memoria SQLite del proyecto | `save/search/context/agent/export/import` (modo `-Quiet` para JSON capturable) |
| `~/.config/arnes/*.json` | Config global (conexiones + modelos) | Leer/escribir para mapear proveedores y asignaciones |
| `.arnes/arnes.db` | El cerebro del proyecto (SQLite+FTS5) | Consultar directamente o via `arnes-memory.ps1` |
| `.arnes/quests/*.md` | Reportes de quests | Historial de trabajo por proyecto |
| `~/.config/opencode/agents/*.md` | Los 16 agentes con frontmatter de modelo | OpenCode los carga como subagentes; otro arnes puede leerlos |
| `cli/arnes_brain.py` | Motor de memoria (python, SQLite) | `python arnes_brain.py <db> <cmd> <args>` — JSON en stdout |
| `core/skills/arnes-sdd-*` | Metodologías SDD/FDD/ADR | Skills markdown reutilizables |

**Regla de oro para integrar**: ARNES es la fuente de verdad de config y memoria.
Si el otro arnes trae su propia memoria/config, mantenlo aislado o mapeado a la nuestra —
no crear dos cerebros mezclados. Los agentes y sus modelos deben salir de nuestra config.

## 9. Ubicación de archivos clave

```
cli/argos.ps1              CLI principal (menú + comandos)
cli/argos-engine.ps1       Motor nativo (llamadas directas a APIs)
cli/arnes-memory.ps1       Memoria (SQLite+FTS5)
cli/arnes_brain.py         Cerebro (python)
cli/arnes-graph.ps1        Relaciones/edges
cli/argos-cycle.ps1        Ciclo orquestador completo
cli/argos-code.ps1         Modo coding (herramientas + permisos)
cli/arnes-chat.ps1         Chat nativo multi-turno
cli/arnes-project.ps1      Perfil del proyecto
cli/arnes-connect.ps1      Gestor de conexiones globales
cli/arnes-recommend.ps1    Recomendación inteligente de modelos
cli/argos-opencode.ps1     Puente a OpenCode
core/classes/*.agent.md    Agentes RPG (fuente)
core/auditors/*.agent.md   Auditores (fuente)
core/skills/arnes-*        Metodologías propias (SDD/FDD/ADR/TDD)
docs/PLAN-ARNES.md         Roadmap y continuidad
```

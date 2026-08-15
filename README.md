# ARGOS — Harness RPG de IA con 16 agentes

> **ARGOS**: el gigante mitológico de los 100 ojos — todo lo ve, todo lo vigila.
> **Rojo y Negro**, como el Atlas de la Liga MX.
> 16 agentes RPG con memoria propia, metodologías propias y cero dependencias externas obligatorias.

**ARGOS** es un harness de desarrollo con 16 agentes RPG (Atlas, Vivi, Ansem, Kuja, Eiko, Amarant, Eremez, Auron, Bran, Quina, Varys, Tywin, Sam, Bard, Tidus, Ragnarok) que orquesta tus proyectos: cada agente tiene su **memoria propia** (SQLite + FTS5), su **modelo de IA configurado**, su **skill propia** y participa en flujos **SDD / FDD / TDD / ADR** propios.

---

## ✨ Características

- **16 agentes RPG** con roles: frontend, backend, QA, DevOps, arquitectura, seguridad, research, infraestructura, compras...
- **Modelo por agente**: cada agente usa SU modelo (Atlas→Qwen3.8 Max, razonamiento→GPT-5.6 Luna, volumen→DeepSeek V4 Flash...). Uso de tokens por modelo real.
- **Memoria propia** (`arnes.db` SQLite + FTS5): los agentes buscan HECHOS antes de actuar (anti-alucinación por diseño).
- **Knowledge Graph**: relaciones entre componentes, librerías y agentes.
- **Configuración UNA vez por máquina**: conexiones de proveedores y modelos por agente se guardan en `~/.config/arnes/` y se despliegan a cualquier proyecto.
- **Metodologías propias**: SDD, FDD, TDD y ADR sin herramientas externas.
- **Multiplataforma**: Windows (PowerShell), macOS/Linux (PowerShell Core) y **Docker** para cualquier PC.
- **Instalable como repo normal** — clona `argos` + `osma` y listo.

---

## 📋 Requisitos

| # | Herramienta | Por qué | Verificar con | Windows | macOS/Linux |
|---|---|---|---|---|---|
| 1 | **PowerShell** | El CLI del harness | `$PSVersionTable.PSVersion` | 5.1+ (preinstalado) | PowerShell Core 7+ (`pwsh`) |
| 2 | **Python 3.8+** | Memoria (arnes.db, solo stdlib) | `python --version` y `python -c "import sqlite3"` | [python.org](https://python.org) | preinstalado |
| 3 | **Node.js 16+** | Instalador npm + OpenCode CLI | `node --version` | [nodejs.org](https://nodejs.org) | [nodejs.org](https://nodejs.org) |
| 4 | **npm** | Instalar el paquete y OpenCode | `npm --version` | viene con Node | viene con Node |
| 5 | **OpenCode CLI** | Motor de agentes | `opencode --version` | `npm i -g opencode-ai` | `npm i -g opencode-ai` |
| 6 | **Git** | Instalar y flujo de trabajo | `git --version` | [git-scm.com](https://git-scm.com) | `apt install git` |
| 7 | **Docker** (opcional) | Opción contenedor (cualquier PC) | `docker --version` | [docker.com](https://docker.com) | [docker.com](https://docker.com) |

> **¿npm o bun?** Usa **npm** (viene con Node.js). **Bun no es necesario** — el paquete está hecho para npm y funciona igual en Windows, macOS y Linux.

### Autodiagnóstico

¿Dudas si te falta algo? El harness lo verifica solo:

```powershell
argos doctor     # o menú [8] Diagnóstico de prerequisitos
```

Revisa los 10 puntos (PowerShell, Python+sqlite3, Node+npm, OpenCode, Freebuff, Git, conexiones globales, modelos por agente, agentes instalados, Docker opcional) y te dice exactamente qué instalar si algo falta.

### Estado actual

La base funcional actual incluye el CLI `argos`, configuración global de proveedores y modelos,
sincronización de agentes con OpenCode, memoria SQLite/FTS5, knowledge graph y metodologías SDD,
FDD y ADR propias. El roadmap y las tareas todavía pendientes están en
[`docs/WHAT-IS-LEFT.md`](docs/WHAT-IS-LEFT.md); los cambios publicados se registran en
[`CHANGELOG.md`](CHANGELOG.md).

---

## 🚀 Instalación

> ARGOS (este repo) es el **harness**. Necesita la **memoria OSMA** (repo
> [mauriragna88/osma](https://github.com/mauriragna88/osma)), que se instala una
> vez por máquina. Ambas repos se clonan o se instalan como cualquier repo normal.

### 1 — Instala la memoria OSMA (una vez por máquina)

```powershell
git clone https://github.com/mauriragna88/osma.git
cd osma
.\install.ps1        # instala en ~/.config/arnes/osma
cd ..
```

### 2 — Clona ARGOS (el harness)

```powershell
git clone https://github.com/mauriragna88/argos.git
cd argos
```

OSMA se resuelve automáticamente: `ARNES_OSMA_ROOT` → `~/.config/arnes/osma`
→ `../osma` → fallback `./cli/`. No necesitas copiar nada.

### Dos formas de bajar los repos (independientes o juntos)

ARGOS y OSMA son **dos repos independientes**: cada uno funciona solo, y
juntos se complementan.

| Bajas solo... | Qué pasa | Cómo activar la memoria |
|---|---|---|
| **ARGOS** | El harness funciona completo (menú, connect, target, chat, quests) con **memoria desactivada** (modo degradado, avisa al usarla) | `argos osma-install` (instala OSMA y listo) |
| **OSMA** | El motor de memoria funciona solo (CLIs `osma-memory` / `osma_brain.py` sobre cualquier `.arnes/arnes.db`) | — |
| **Ambos juntos** | Complemento completo: ARGOS orquesta y OSMA recuerda por proyecto | Se resuelven solos (`~/.config/arnes/osma` o repos hermanos `../osma`) |

```powershell
# Forma A: repos hermanos lado a lado (git clone)
mkdir harness && cd harness
git clone https://github.com/mauriragna88/argos.git
git clone https://github.com/mauriragna88/osma.git   # ARGOS lo encuentra en ../osma

# Forma B: ARGOS como repo + OSMA instalado global (una vez por máquina)
git clone https://github.com/mauriragna88/argos.git
cd osma && .\install.ps1    # copia el motor a ~/.config/arnes/osma
```

> Si bajas solo ARGOS y usas memoria sin OSMA instalado, `argos doctor` te lo
> avisará y `argos osma-install` lo instala en un paso. `argos party` (scheduler
> con tracking de tareas) necesita OSMA y aborta con instrucciones si no está.

### Opción alternativa — instalación directa (one-liner)

```powershell
# Windows (PowerShell)
irm https://raw.githubusercontent.com/mauriragna88/osma/main/install.ps1 | iex
```

### Docker

```bash
git clone https://github.com/mauriragna88/argos.git && cd argos
docker compose run --rm argos         # entra al entorno ARGOS
```

Los volúmenes montan tu configuración y trabajo: `~/.config/arnes`, `~/.config/opencode`
y tu carpeta de trabajo persisten entre ejecuciones.

---
## ⚙️ Configuración — UNA VEZ por máquina

ARNES ARGOS guarda la configuración **global de la máquina** (no por proyecto):

| Documento | Ruta | Contenido |
|---|---|---|
| Conexiones | `~/.config/arnes/connections.json` | Proveedores (OpenCode Go, OpenAI, NVIDIA, B.AI...) con sus keys |
| Modelos por agente | `~/.config/arnes/agent-models.json` | Qué modelo usa cada uno de los 16 agentes |

```powershell
argos connect        # 1. Conecta proveedores (API key verificada o OAuth del plan) — UNA vez
argos configure      # 2. Elige el modelo de cada agente — UNA vez
                     #    Muestra SOLO los modelos de proveedores CONECTADOS (verificados):
                     #    NVIDIA, OpenAI, opencode-go, B.AI (+ lo que conectes)
                     #    Escribe directamente en el buscador de arriba para filtrar (como opencode)
argos recommend      # 3. Alternativa: recomendación inteligente (ahorro/equilibrio/calidad)
```

> El catálogo es **vivo y estricto**: solo se muestran los modelos de las conexiones **verificadas**
> (API probada contra el endpoint `/models` al conectar; OAuth con sesión confirmada en opencode).
> `argos status` te muestra cada conexión con su estado real: `[OK] verificado` / `[!!] key inválida`.
> Escribe en el buscador superior para filtrar en vivo (ej: `nemotron`, `luna`, `qwen3.8`).

Con base en ese documento, ARNES despliega el modelo a cada agente instalado
(`~/.config/opencode/agents/*.md`). Puedes **cambiarlo cuando quieras** desde el menú
o dentro del chat con `/connectagent`.

---

## 🏁 Quickstart

```powershell
# En cualquier carpeta de trabajo:
argos doctor     # (opcional) verifica que tengas todo lo necesario
argos
#    → detecta si el proyecto es nuevo
#    → inicializa .arnes/ (entorno del proyecto)
#    → abre el menú: [1] Chat con Atlas · [2] Conectar proveedores · [3] Configurar modelos
#                        [4] Recomendación · [5] Modo interacción · [6] Estado · [7] Memoria · [8] Diagnóstico
```

Dentro del chat de Atlas:

```
/party          ver el party (16 agentes)
/connectagent   reconfigurar modelos por agente sin salir
/memory         estado de la memoria
/models         catálogo vivo de modelos
/status         estado del harness
/quit           salir
```

Si el comando muestra el banner y tarda en avanzar, consulta
[`docs/ARGOS-STARTUP.md`](docs/ARGOS-STARTUP.md) antes de cerrar la terminal.

### Comandos útiles

```powershell
argos doctor     # diagnóstico de prerequisitos (10 puntos)
argos status     # estado del proyecto + resumen XP
argos stats      # dashboard: quests, tokens, racha, top agentes
argos xp         # ranking de experiencia por agente (nivel)
argos xp vivi    # nivel de un agente específico
argos theme list # temas visuales disponibles
argos theme set vivi  # cambia el tema (atlas/vivi/amarant/eiko/auron)
argos test-model # prueba un modelo con el motor nativo
argos goal "crea la plataforma escolar completa" -MaxIterations 10   # modo autónomo por objetivo
```

### Modo autónomo por objetivo (`argos goal` / `/autowork`)

Atlas NO trabaja en automático por defecto. El modo se activa solo cuando lo pides:

- `argos goal "<objetivo>" [-MaxIterations N] [-Resume]` — persigue el objetivo encadenando ciclos.
- En el chat: `/autowork <objetivo>` (y `/autowork stop` para detener al terminar la iteración).
- Por lenguaje natural: *"atlas activa modo automático <objetivo>"*.

Cómo decide seguir:
- **FAIL / RETOQUE** → la *remediation* de Tywin se convierte en el siguiente prompt.
- **PASS** → Atlas genera el siguiente paso incremental hacia el objetivo.
- Termina con `GOAL_COMPLETE`, al llegar a `MaxIterations`, o con Ctrl+C.

Atlas decide **con memoria, no a ciegas**: cada iteración inyecta a su decisión el
`CONTEXTO DE MEMORIA` — historial del objetivo (qué se hizo, qué verdict, qué quedó
pendiente) **y la bitácora de secuencia** (quién hizo qué y en qué orden). Además, cada
agente guarda en `arnes.db` qué entregó (`<agente>/executions/`), Tywin sus verdicts,
**Varys el evidence pack con la secuencia completa** (`varys/evidence-packs/<quest>`) y
Atlas un debrief (`atlas/debriefs/<quest>`). Así el party evita repetir lo hecho y ataca
lo pendiente.

El estado se guarda en `.arnes/goal-state.json` (incluye el historial); puedes retomar
con `-Resume`.

### Elegir el entorno de trabajo (OpenCode / Codex / Claude / Freebuff)

```powershell
argos                    # menú: [9] Abrir entorno → usa tu default o muestra el selector
argos target list        # CLIs instalados + target actual
argos target set dsh        # fija el default (opencode | codex | claude | freebuff | dsh) — [9] ya no pregunta
argos target codex       # abre Codex con la persona Atlas cargada
argos target claude "haz un login"   # abre Claude con un quest inicial
argos target freebuff    # abre Freebuff con el arnés ARNES cargado (gratis, sin API keys)
argos target opencode    # flujo original (16 agentes + modelos por agente)
argos target dsh          # arranca DeepSeek Harness (pnpm dsh web) con ARGOS/OSMA cargado
```

- **opencode**: sincroniza los 16 agentes RPG con su modelo propio y abre `opencode --agent atlas-player`.
- **codex**: despliega la persona Atlas + roster del party a `~/.codex/AGENTS.md` y abre `codex` (o `codex exec <quest>`).
- **claude**: despliega la persona Atlas a `~/.claude/CLAUDE.md` + los **16 agentes del party** como subagentes (`~/.claude/agents/*.md`) y abre `claude` (o `claude -p <quest>`).
- **freebuff**: despliega la persona Atlas + roster del party a `AGENTS.md` del proyecto y abre `freebuff` (CLI gratuito con modelos de uso libre: DeepSeek V4 Flash/Pro, GPT-5.6 Luna, etc.).
- **dsh**: valida que ARGOS/OSMA estén instalados y arranca **DeepSeek Harness** (pnpm dsh web en http://127.0.0.1:3080). No modifica el AGENTS.md del repo DSH: ARGOS/OSMA cargan vía el plugin. El modelo se elige por sesión en la Web UI (Settings → Models).

La memoria del proyecto (`.arnes/arnes.db`, exports JSONL) queda accesible en los cinco
entornos. Los modelos por agente y el motor OMO son capacidades exclusivas de OpenCode
(formato del CLI); en Codex/Claude/Freebuff el modelo lo gestiona cada CLI.

### Suite de tests

```bash
npm test          # suite completa: unit TS + funcionales PS + política + parseo + secretos + smoke
npm run test:unit # solo tests unitarios TypeScript
```

La suite también corre automáticamente en CI (GitHub Actions) para cada push/PR.

### La cadena de modelos (cómo funciona)

1. `argos configure` guarda el modelo de cada agente en el documento de la máquina.
2. ARNES despliega ese modelo al frontmatter de cada agente instalado en OpenCode.
3. Cuando Atlas delega (ej: Vivi para frontend, Ansem para backend, Auron para seguridad),
   **cada agente usa SU modelo** — el uso de tokens aparece por modelo en tu proveedor.
4. Cambias cuando quieras: menú `[3]` o `/connectagent` en el chat.

---

## 🏢 El party (16 agentes)

| Departamento | Agente | Clase | Modelo sugerido |
|---|---|---|---|
| Dirección | **Atlas** | Player/Orchestrator | Qwen3.8 Max |
| Programación | **Vivi** | Mage (Frontend) | GPT-5.6 Luna |
| Programación | **Ansem** | Paladin (Backend) | DeepSeek V4 Flash |
| QA | **Kuja** | Rogue | DeepSeek V4 Flash |
| DevOps | **Eiko** | Cleric | DeepSeek V4 Flash |
| Arquitectura | **Amarant** | Monk | GPT-5.6 Luna |
| Investigación | **Eremez** | Ranger | DeepSeek V4 Flash |
| Seguridad | **Auron** | Warden (L0 Gate) | DeepSeek V4 Pro |
| Analista | **Bran** | Seer | GPT-5.6 Luna |
| Finanzas | **Quina** | Banker | DeepSeek V4 Flash |
| Tracker | **Varys** | Spider | GPT-5.6 Luna |
| Verificador | **Tywin** | Verifier | DeepSeek V4 Flash |
| Consejero | **Sam** | Archivist | GPT-5.6 Luna |
| Mejora | **Bard** | Bard | GPT-5.6 Luna |
| Infra | **Tidus** | Warden | DeepSeek V4 Flash |
| Compras | **Ragnarok** | Warden | GPT-5.6 Luna |

> Los modelos sugeridos son el default (prioridad "equilibrio"). Ajusta con `argos configure` o `argos recommend`.

---

## 🧠 Memoria propia (arnes.db)

```powershell
.\cli\arnes-memory.ps1 stats                                        # estado del cerebro
.\cli\arnes-memory.ps1 save -Agent vivi -Topic vivi/ui-patterns -Type pattern -Content "..."
.\cli\arnes-memory.ps1 search -Query "dark mode" -Agent vivi
.\cli\arnes-graph.ps1 path -Start "Login.tsx" -End "tailwind"       # knowledge graph
```

## 📋 Metodologías propias

| Metodología | Skills | Para qué |
|---|---|---|
| **SDD** | arnes-sdd-propose/spec/design/tasks/apply/verify/archive | Cambios con spec profunda |
| **FDD** | arnes-fdd-plan/implement/review/archive | Features incrementales |
| **TDD** | kuja-backstab + vitest/playwright | Tests primero, proporcional |
| **ADR** | arnes-adr | Decisiones de arquitectura registradas |
| **Knowledge Graph** | arnes-graph | Relaciones entre componentes/agentes |

## 🔌 Proveedores soportados

- **OpenCode Go** — DeepSeek V4 Flash (workhorse), Qwen3.8 Max (Atlas)
- **OpenAI** (cuenta ChatGPT vía OAuth) — GPT-5.6 Luna/Terra/Sol
- **NVIDIA NIM** (gratis) — DeepSeek V4 Flash/Pro
- **B.AI** — Claude Opus/Fable, GPT-5.6, Qwen3.8
- **Z.AI / SiliconFlow / MiniMax / TokenRouter** — catálogo ampliable

Mini-guía completa: `docs/PROVIDERS-GUIDE.md`

## 📚 Documentación

- `CHANGELOG.md` — cambios publicados y pendientes de release.
- `CONTRIBUTING.md` — instalación para colaboradores, validación y reportes.
- `docs/ARGOS-STARTUP.md` — flujo técnico de arranque y diagnóstico de pausas.
- `docs/PLAN-ARNES.md` — roadmap maestro y continuidad entre sesiones
- `docs/WHAT-IS-LEFT.md` — estado del proyecto
- `docs/USAGE-FLOW.md` — flujo de uso completo
- `docs/PROVIDERS-GUIDE.md` — cómo conectar cada proveedor
- `core/memory-system.md` — sistema de memoria (arnes.db)

## 🤝 Contribuir

Consulta [`CONTRIBUTING.md`](CONTRIBUTING.md) para el flujo completo. En resumen: crea una rama,
valida con `argos doctor`, prueba los scripts PowerShell afectados y separa tus cambios de
cualquier trabajo local previo que no pertenezca a tu contribución.

## 📄 Licencia

MIT — haz lo que quieras, los 100 ojos te observan. 👁️

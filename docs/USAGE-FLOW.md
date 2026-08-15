# Flujo de Uso del Harness RPG Atlas

> Como usar Atlas en la vida real: desde CMD hasta harness activo.

## Instalacion Inicial (una vez por proyecto)

```powershell
# 1. Abre CMD o PowerShell
cd C:\Users\LapOne Mx\Documents\GitHub\mi-proyecto

# 2. Crea symlink o copia arnes al proyecto
# Opcion A: si arnes esta en GitHub, clonar:
git clone https://github.com/tu-usuario/arnes.git .arnes-harness

# Opcion B: copiar la carpeta arnes/ al proyecto
Copy-Item -Recurse C:\Users\LapOne Mx\Documents\GitHub\arnes .\arnes

# 3. Inicializar config del proyecto
.\arnes\cli\activate.ps1
```

El CLI hara 3 preguntas:
1. **Plataforma**: OpenCode / Codex / Claude (autodetectado)
2. **Suscripcion**: Free / Pro / Pro Plus
3. **Modo**: Economy / Balance / Quality

Despues de la primera vez, `.arnes/config.json` queda guardado y no necesita re-configurar.

## Uso Diario - 3 formas de activar Atlas

### Forma 1: Via CLI ARGOS (recomendado para sesion RPG completa)

```powershell
# Entra a la carpeta del proyecto
cd C:\Users\LapOne Mx\Documents\GitHub\mi-proyecto

# Lanza el CLI
.\arnes\cli\activate.ps1
```

Se abre la **ARGOS UI** (terminal RPG roja y negra):
```
================================================================
  ESCRIBE TU QUEST O COMANDO (Ctrl+C para salir)
================================================================
ATLAS> _
```

Ahi escribes quests:
```
ATLAS> crea un login form con validacion Zod
ATLAS> /party      (ver party)
ATLAS> /skills     (ver skills)
ATLAS> /status     (ver HP/MP economy)
ATLAS> /quit       (salir)
```

### Forma 2: Via OpenCode directo (recomendado para workflow normal)

```powershell
# Entra al proyecto
cd C:\Users\LapOne Mx\Documents\GitHub\mi-proyecto

# Abre opencode (que tendra hooks Atlas cargados si hiciste la instalacion)
opencode
```

OpenCode reconocera el agente `atlas` del file `deploy/hooks/opencode/atlas-agent.json` merges con el opencode.json. Al abrir OpenCode, el modelo orquestador sera Atlas automaticamente.

Desde OpenCode, simplemente escribes como siempre:
```
> crea un login form con validacion Zod
```

Atlas (corriendo como el agente primary de OpenCode) detecta el quest, selecciona party, lanza turnos.

### Forma 3: Codex o Claude directo

Para Codex:
```powershell
cd C:\Users\LapOne Mx\Documents\GitHub\mi-proyecto
codex
```
Codex leera `.codexrc.json` (copiado de `deploy/hooks/codex/codexrc.json`) y Atlas sera el agent primary.

Para Claude:
```powershell
# Copiar config previamente a ~/claude/claude_desktop_config.json
claude
```
Claude reconocera el agente Atlas del `claude_desktop_config.json`.

## Flujo Completo de un Quest

```
1. User escribe quest
   ATLAS> crea un dashboard de analytics con graficos

2. Atlas detecta (Quest Detector)
   Quest type: frontend + backend (feature completa)
   Party sugerido: Amarant (plan) + Vivi (UI) + Ansem (API) + Kuja (test) + Eiko (deploy)
   Complexity: boss fight
   Estimated HP: 150, MP: 25K tokens
   Is L0: false (no production change)

3. Atlas muestra plan al user
   ATLAS: [BOSS FIGHT] Dashboard analytics
   Party: Amarant, Vivi, Ansem, Kuja, Eiko
   HP: 150, MP: 25K
   Estimated cost: ~$X.XX
   Confirmar? [S/n]

4. User confirma
   User: S

5. Atlas lanza combat turn-based
   TURN 1 - PLAN
     [AMARANT] Foresight + superpowers brainstorming
     Output: plan con 5 fases, file paths exactos
   
   TURN 2 - EXECUTE (parallel)
     [VIVI] Fireball componente Dashboard.tsx + ChartCard.tsx
     [ANSEM] Smite API /api/analytics/route.ts con Zod
     (paralelo, no desbloquean mismo archivo)
   
   TURN 3 - EXECUTE (continue)
     [VIVI] Flare layouts responsive
     [ANSEM] Holy Ground schema Prisma migration
   
   TURN 4 - VERIFY
     [KUJA] Backstab: test Dashboard render
     [KUJA] Poison Tipped: edge cases de null data
     [EIKO] Build pass + lint pass + types pass
   
   TURN 5 - EVALUATE
     [ATLAS] HP: 85/150 OK. MP: 18K/25K OK.
     [ATLAS] Quest OK. Files: 5 created/modified.

6. Atlas auto-loop:
   ATLAS: Quest completado. 
   HP used: 65, MP used: 7K
   XP gained: Amarant +20, Vivi +25, Ansem +25, Kuja +15, Eiko +10
   Siguiente quest? (auto-loop: si)
   ATLAS> _

7. User escribe siguiente quest o sale
   ATLAS> /quit
```

## Comandos del CLI ARGOS

| Comando | Accion |
|---|---|
| `/party` | Muestra party actual + stats + level + XP |
| `/skills` | Lista skills/spells por miembro |
| `/status` | HP/MP economy del quest actual, streak, tokens usados |
| `/platform` | Re-detecta plataforma (OpenCode/Codex/Claude) |
| `/pause` | Pausa el auto-loop |
| `/resume` | Resume auto-loop |
| `/heal` | Forzar Eiko Mend (reset estado roto) |
| `/class <name>` | Override party: usar solo un miembro (ej: `/class vivi`) |
| `/memory` | Muestra memoria de todos los miembros (arnes.db) |
| `/memory vivi` | Muestra solo memoria de Vivi |
| `/save` | Guarda el estado actual en `.arnes/save/` (handoff) |
| `/load` | Carga un estado guardado para continuar despues |
| `/quit` | Salir del harness |

## Auto-Loop Behavior

Atlas decide automaticamente:

**Auto-continuar (+ lanzar siguiente quest)** cuando:
- quest trivial/simple completado
- HP party > 50%
- No es L0 (production change)
- hay quests en cola (multi-quest detection)
- budget de tokens no excedido

**Pausar (esperar user)** cuando:
- Boss fight completado (quiere user confirmar siguiente paso)
- L0 detectado (production, destructive, schema)
- Budget HP/MP excedido (>85% usado)
- Circuit breaker triggereado (3 fails en 60min)
- User escribio /pause o "pause"
- User dijo "eso es todo por hoy"

**Circuit breaker** (3 fails en 60 min):
- Atlas pausa 30 min
- Miembro que fallo queda blocked
- Fallback: otro miembro toma su rol
- Si no hay fallback → pausa usuario

## Memoria Multi-Agente (arnes.db)

Cada miembro guarda en su namespace propio:
- Vivi: `vivi://ui-patterns`, `vivi://components-built`
- Eiko: `eiko://build-failures`, `eiko://vivi-care`
- Ansem: `ansem://schemas`, `ansem://rls-policies`
- Kuja: `kuja://bugs-found`, `kuja://edge-cases`
- Amarant: `amarant://architecture-decisions`, `amarant://specs-created`
- Eremez: `eremez://library-research`, `eremez://docs-cache`

Atlas lee TODAS las memorias antes de cada quest para:
- No recrear schemas existentes (`ansem://schemas`)
- No rebuscar librerias ya comparadas (`eremez://library-research`)
- Aplicar patterns que funcionaron (`vivi://ui-patterns`)
- Evitar bugs recurrentes (`kuja://bugs-found`)
- Respetar ADRs previos (`amarant://architecture-decisions`)

Asi Atlas es inteligente: aprende del pasado del equipo.

## Atajos utiles

```powershell
# Activar Atlas rapidamente (poner en PATH)
$env:PATH += ";C:\Users\LapOne Mx\Documents\GitHub\arnes\cli"
# Despues solo:
arnes activate

# O crear alias
Set-Alias arnes "C:\Users\LapOne Mx\Documents\GitHub\arnes\cli\activate.ps1"
```

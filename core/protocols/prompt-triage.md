# Prompt Triage Protocol

> **Dueño**: Atlas (Player) · **Estado**: V1.3 · **Fecha**: 2026-08-17
> **Referencia complementaria**: `core/protocols/user-response-adaptation.md` — cómo
> Atlas adapta el formato/tono/fricción al estilo del usuario (memoria `user/style/*` en OSMA).
> **V1.3**: el nivel final se decide con **prompt del usuario + complemento de Atlas**.
> Prompts ambiguos se enriquecen (interpretación + alternativas + planeación mínima)
> ANTES de clasificar; el complemento puede subir el nivel y activar el gate.
> **V1.1**: cierre de ciclo de memoria automático (outcome real en quest-done) + triage
> consumido por el orquestador + comando `/triage-stats`.
> **V1.2**: telemetría formal de modelos (Fase 1) — `cli/model-telemetry.ps1` registra
> cada run en `.arnes/model-runs.jsonl` al cerrar el quest; tools DSH `argos_triage` y
> `argos_model_stats` en el bundle `dsh/argos-osma`.
> **Referencias**: `AGENTS.md` (sección Prompt Triage) · `core/model-router.agent.md` · `core/protocols/atlas-advisory-handoff.md` · `IMPLEMENTATION_PLAN.md` (Fase 1: `osma-model-run`)
> **Regla de oro**: TODO prompt del usuario se clasifica ANTES de ejecutar. Ninguna excepción.

---

## 1. Objetivo

Que el harness decida, con evidencia y memoria, si un prompt lo puede resolver el modelo
de trabajo (flash/workhorse) o si necesita un modelo de razonamiento superior (pro/deep).
El triage emite: **dificultad (1-4) → modelo recomendado → gate de confirmación (solo 3-4)**,
y registra cada decisión + resultado en memoria (`.arnes/triage-log.jsonl` + OSMA) para que
Atlas, en modo automático, elija mejor en el futuro basado en lo que ya funcionó.

## 2. Regla de oro: prompt + complemento de Atlas = nivel final

El nivel NO se decide solo con el prompt crudo del usuario. Si el prompt es ambiguo
(requisitos incompletos, alcance abierto, "como creas mejor", pocas keywords),
Atlas PRIMERO enriquece la idea antes de clasificar:

1. **Interpretar** la intención real detrás del prompt (qué busca el usuario, no solo qué dijo).
2. **Proponer alternativas** (2-3 caminos viables con su trade-off) y preguntar/seleccionar.
3. **Armar planeación mínima**: alcance (archivos/módulos/servicios), dependencias, riesgos.
4. **Re-clasificar con prompt + complemento**: el nivel final refleja el alcance YA enriquecido.

> Si el complemento revela multi-archivo, integración entre sistemas, razonamiento
> multi-paso o decisiones de diseño → el nivel sube (y el gate se activa).
> El triage-log registra `ambiguity` como señal y `notes` con el complemento aplicado.

### 2.1 Señal `ambiguity` (automática en el CLI)

`quest-detector.ps1` marca `ambiguity` cuando: confianza de keywords baja (0-1 aciertos)
o el prompt matchea patrones abiertos ("como creas mejor", "alguna idea", "recomiendame",
"que opinas", "mejor forma", "nose", "no se", "quiza"). Con `ambiguity`, el gate sube:
`auto_pass` → `ask` (Atlas va a complementar y el nivel puede subir). L0/dificultad 4 siguen siendo `required`.

## 3. Clasificación de dificultad (4 niveles)

| Nivel | Nombre | Señales típicas | Modelo |
|---|---|---|---|
| **1** | Trivial | 1 archivo, patrón conocido, sin ambigüedad (renombrar, typo, copy de patrón, string literal) | Flash sobra |
| **2** | Rutina | 1-3 archivos, lógica directa, librerías ya usadas en el repo (componente, endpoint sencillo, test unitario, fix acotado) | Flash bien |
| **3** | Complejo | Arquitectura, refactor multi-archivo, bug intermitente/raíz no evidente, seguridad (RLS/auth/secrets), integración entre sistemas, razonamiento multi-paso, decisiones con trade-offs, tareas con ambigüedad de requisitos | **Recomendar pro/reasoning** ⚠️ |
| **4** | Boss | Diseño de sistema completo, migración grande, debugging profundo, refactor con dependencias en cascada, tareas que requieren plan formal (SDD) + verificación adversarial | **Insistir en modelo fuerte** 🛑 |

Señales de peso para subir de nivel (si 2+ aplican, sube al menos 1 nivel):
- Más de 3 archivos o cambios entre módulos/servicios
- Algoritmo/estructura de datos no trivial o lógica de negocio con casos borde
- Ambigüedad: requisitos incompletos, "diseña como creas mejor"
- El repo no tiene precedente del patrón pedido (búsqueda de similitud < 40%)
- Bug no reproducible a simple vista / error raro / race condition
- Cualquier toque a producción, auth, RLS, secretos o deploy (L0 siempre gana, sin importar nivel)

## 4. Flujo obligatorio por prompt

```
PROMPT del usuario
  ↓
[1. TRIAGE INICIAL] Atlas clasifica: dificultad + señales + similitud (OSMA/blackboard)
  ↓
[2. AMBIGUO?] Si el prompt es ambiguo → Atlas ENRIQUECE:
     interpretación de intención + 2-3 alternativas + planeación mínima (alcance/riesgos)
  ↓
[3. RECLASIFICAR] Nivel FINAL = prompt del usuario + complemento de Atlas
     (el complemento puede subir el nivel → gate se recalcula)
  ↓
[4. VEREDICTO] Output de 1 línea (niveles 1-2) o bloque con recomendación (niveles 3-4)
  ↓
[5. GATE] Nivel 3-4 → preguntar al usuario (ask_user):
         [Cambiar a modelo pro/reasoning] [Seguir con flash] [Dividir la tarea]
    Nivel 1-2 → ejecutar directo (sin gate), salvo L0 (siempre gate)
  ↓
[6. MEMORIA] Registrar decisión + resultado en triage-log.jsonl y OSMA (contrato §6)
  ↓
[7. EXECUTE] Continuar flujo normal (Party Select → Model Route → ... → Tywin → Sam → Atlas)
```

### 4.1 Reglas de gate según auto_loop_level

| Nivel agresión | Nivel 1-2 | Nivel 3 | Nivel 4 |
|---|---|---|---|
| `safe` | sin gate | preguntar siempre | preguntar siempre |
| `balanced` | sin gate | preguntar siempre | preguntar siempre |
| `aggressive` | sin gate | sin gate (solo aviso) | preguntar siempre |

El gate de nivel 4 NUNCA se salta. El gate L0 (producción/destructivo) NUNCA se salta en ningún nivel.

## 5. Decisión de modelo

- **Nivel 1-2** → modelo de trabajo actual (workhorse, ej. `deepseek-v4-flash`). No gastar tokens de razonamiento.
- **Nivel 3** → recomendar `modelo de razonamiento` disponible según suscripción (`model-recommendations.json` / `model-routing-policy.json`):
  - OpenCode Pro: `gpt-5.6-luna` (razonamiento medio) o `deepseek-v4-pro`/`kimi-k2.6` según dominio
  - Codex: `gpt-5.6-terra` (high) · Claude: `claude-sonnet-5`/`opus-4.8`
- **Nivel 4** → `highest_reasoning_available`: Codex `gpt-5.6-sol`, Claude `opus-5`, OpenCode `kimi-k2.6`/`qwen3.8-max`.

### 5.1 Límite honesto (sesión locked)

El modelo de la sesión en curso NO se puede cambiar en caliente (queda fijo al arrancar).
El triage decide la RECOMENDACIÓN; el switch físico lo hace el usuario (1 clic en la UI)
o una sesión nueva con el modelo fuerte. Regla de escalación para el caso inverso:
si una tarea clasificada 1-2 se estanca (3 fallos / 60 min, circuit breaker), se
re-clasifica a 3-4 automáticamente y se recomienda el switch — nunca se insiste con el
mismo modelo sin re-clasificar.

## 6. Contrato de memoria (sync OSMA)

Cada triage DEJA RASTRO. Dos capas:

### 6.1 Event log inmediato — `.arnes/triage-log.jsonl` (append-only)

**Escritura automática**: `cli/quest-detector.ps1` hace append en cada ejecución
(flags `-NoLog` y `-SkipOsma` para desactivar log / consulta OSMA). También emite
`difficulty` (1-4), `model_tier` (flash/pro/highest), `recommended_model` y
`triage_gate` en su salida JSON.

Un objeto JSON por prompt (append, nunca reescribir):

```json
{
  "event": "triage",
  "ts": "2026-08-17T19:00:00-06:00",
  "prompt_type": "frontend | backend | fix | architecture | research | devops | boss",
  "difficulty": 1,
  "signals": ["multi_file", "ambiguity"],
  "similarity": {"matched": true, "qid": "Q-007", "score": 85},
  "model_used": "opencode-go/deepseek-v4-flash",
  "recommendation": "flash",
  "user_decision": "auto",
  "outcome": "PASS | FAIL | ESCALATED | CANCELLED",
  "notes": ""
}
```

### 6.2 Cierre del ciclo (outcome real) — AUTOMÁTICO en `cli/loop-engine.ps1`

El evento del triage nace con `outcome: "PENDING"`. Al cerrar el quest
(`loop-engine.ps1 -Action quest-done`), `Update-TriageOutcome` anota sobre el ÚLTIMO
registro pendiente: `outcome` (PASS/FAIL), `quest_id`, `agent` y `closed_at`.
Regla: append-only — solo se toca el evento aún abierto, los ya cerrados no se reescriben.

### 6.3 Consumo en el orquestador — `cli/atlas-orchestrator.ps1`

El orquestador integra el triage en su decisión:
- Muestra `difficulty`, `recommended_model`, `model_tier` y `triage_gate` (Step 1 y caja de recomendación).
- En modo `-Gate auto`, `triage_gate` en `required`/`ask` fuerza confirmación del usuario
  (además del gate de `recommendation` clásico); `auto_pass` ejecuta directo.
- Si el detector recomienda tier `pro`/`highest` pero el CLI va en tier menor, emite
  `[TRIAGE]` avisando (no bloquea; Atlas decide con información).

### 6.4 Telemetría formal de modelos (Fase 1) — `cli/model-telemetry.ps1`

Cada quest cerrado registra en `.arnes/model-runs.jsonl` (event log append-only,
NO memoria — OSMA sigue siendo el cerebro): agent, model, provider, quest_id,
quest_type, difficulty, route, party, tokens_used, verdict, reward.
- **Hook automático**: `loop-engine.ps1 -Action quest-done` registra el run tomando
difficulty/model del evento triage cerrado (mismo quest_id).
- **Consulta**: `cli/model-telemetry.ps1 -Action stats` (texto o `-Json`) agrega
success_rate, avg_tokens y dificultades por modelo × quest_type.
- **En DSH web**: tools `argos_model_stats` (leer agregados) del bundle `dsh/argos-osma`.
- Quina/Bran usan esto para presupuestar (plan F2) y para la economía de modelos.

### 6.5 Estadísticas — `cli/triage-stats.ps1` (`argos triage-stats` / `/triage-stats`)

Lee `.arnes/triage-log.jsonl` y reporta: volumen y success rate por dificultad,
modelo más usado por dificultad, y qué dificultad→modelo tuvo mejor outcome.
Sirve para que Bran/Quina ajusten la economía de modelos con data real.

### 6.6 Triage en DSH web — bundle `dsh/argos-osma`

El bundle Cordis expone `argos_triage`, que replica la heurística de
`quest-detector.ps1` en JS (keywords + longitud + L0): clasifica dificultad 1-4,
recomienda modelo (flash/pro/highest), gate (`auto_pass`/`ask`/`required`),
consulta experiencias OSMA similares y hace append al mismo `.arnes/triage-log.jsonl`.
Con esto el triage automático también aplica dentro del runtime web de DSH
(el único entorno donde `quest-detector.ps1` no corre).

Lee `.arnes/triage-log.jsonl` y reporta: volumen y success rate por dificultad,
modelo más usado por dificultad, y qué dificultad→modelo tuvo mejor outcome.
Sirve para que Bran/Quina ajusten la economía de modelos con data real.

### 6.7 Memoria asociativa — OSMA (cerebro, lectura en TURN 0.5)

- **Escritura** (al cerrar el quest, junto con `agent_settled`): `osma-experience-record`
  con situation `"prompt triage: <prompt_type> dificultad <n>"`, cues de dificultad/señales,
  reasoning = decisión tomada, conclusion = modelo usado, action = gate aplicado,
  outcome + reward (`+0.5` si PASS con el modelo recomendado, `-1.0` si FAIL).
  (Implementado en `Quest-Done` de `loop-engine.ps1`.)
- **Lectura** (antes de clasificar, §3 paso 1): `osma-experience-search` / `osma-recall`
  con los cues del prompt nuevo → si hay experiencia previa con dificultad similar,
  Atlas la usa para afinar la clasificación (anti-repetición: "la última vez que esto
  se vio nivel 2, falló con flash — sube a 3").
- **Futuro (Fase 1)**: cuando exista `osma-model-run`/`osma-model-stats`
  (IMPLEMENTATION_PLAN.md), el triage también registra la fila de telemetría formal
  (model/provider/quest_type/difficulty/route/verdict/reward). El triage-log NO se
  importa a observaciones OSMA (memoria paralela prohibida) — es solo registro.

## 7. Output del triage (ejemplo real)

```
[ATLAS] Prompt Triage ⚖️
  Dificultad: 3/4 (Complejo) — multi-archivo + lógica de negocio con casos borde
  Similitud:  Q-012 (72%) "API con Zod" → PASS con paladin pro, 8K tokens
  Veredicto:  esto lo resuelve mejor un modelo de razonamiento (deepseek-v4-pro / gpt-5.6-luna)
  ¿Cómo seguimos?  [Cambiar a pro] [Seguir con flash] [Dividir la tarea]
```

## 8. Anti-patterns

- Clasificar 1-2 un prompt que toca producción/auth/RLS (L0 gana siempre)
- Saltarse el gate de nivel 4 o L0 en modo `aggressive`
- No registrar el triage en memoria (decisión sin rastro = no aprendida)
- Dejar eventos con `outcome: PENDING` para siempre (el quest-done debe cerrarlos)
- Gastar modelo pro en tareas nivel 1-2 sin gate (economía de Quina violada)
- Re-clasificar hacia abajo por presión del usuario sin actualizar la memoria

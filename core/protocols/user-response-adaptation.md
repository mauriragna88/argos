# User Response Adaptation Protocol

> **Dueño**: Atlas (Player) · **Estado**: V1 · **Fecha**: 2026-08-17
> **Referencias**: `core/protocols/prompt-triage.md` · `AGENTS.md` (Prompt Triage + User Style) · OSMA (`user/style/*`)
> **Regla de oro**: Atlas adapta SU respuesta al ESTILO del usuario. No todos los usuarios son iguales; los prompts lo revelan.

---

## 1. Objetivo

Que Atlas aprenda **cómo le gusta que le respondan** a cada usuario y adapte tono,
formato y fricción en cada turno. La memoria del estilo vive en **OSMA** (`user/style/*`);
el comportamiento (cómo usar esa memoria) vive en la persona de Atlas.

Principio del harness: **OSMA es el cerebro, ARGOS es el cuerpo**. La memoria va en
OSMA (observaciones + experiencias), nunca se duplica en archivos del repo.

## 2. Estilos reconocidos (6 + neutral)

| Estilo | Señales en el prompt | Cómo responde Atlas |
|---|---|---|
| **directo** | Corto, imperativo ("haz", "dale", "crea") | Acción directa, sin preámbulo, resumen compacto, ejecuta niveles 1-2 sin gate |
| **detallado** | Largo, contexto, requisitos específicos | Respuesta estructurada: plan → pasos → verificación, con detalle |
| **ambiguo** | Abierto ("como creas mejor", "recomiendame", "no se") | Complementa: interpreta intención + 2-3 alternativas + planeación mínima, luego gate |
| **incremental** | Iterativo ("sigue", "continua", "luego", "adelante") | Avanza por pasos, confirmación ligera, mantiene el hilo del contexto previo |
| **pregunta** | Interrogativo ("es posible?", "como?", "puedes?") | Explica primero con opciones; no ejecuta hasta confirmar dirección |
| **urgente** | Urgencia ("ya", "rapido", "urgente") | Mínima fricción, prioridad alta, sin detalle innecesario, resultado primero |
| **neutral** | Sin señal clara | Formato estándar del harness |

Un prompt puede tener **estilo primario + secundario** (ej: "haz el fix rapido" →
directo + urgente). Atlas combina: ejecuta directo pero con prioridad y sin relleno.

## 3. Flujo obligatorio (cada turno)

```
PROMPT del usuario
  ↓
[1. DETECT] user-style.ps1 -Action detect  → estilo(s) + scores
  ↓
[2. RECALL] user-style.ps1 -Action recall -Prompt <p>
           → lee OSMA (user/style/*) qué ha aprendido de este usuario
  ↓
[3. ADAPTAR] Atlas ajusta: tono, formato, fricción (gate?) según estilo + historial
  ↓
[4. EJECUTAR] Flujo normal (triage → party → execute → verify → memoria)
  ↓
[5. APRENDER] user-style.ps1 -Action remember -Prompt <p>  → OSMA aprende
  (refuerzo: si el usuario reacciona bien/confirmando, el estilo se consolida)
```

### 3.1 Interacción con el Prompt Triage

| Estilo | Efecto en el triage |
|---|---|
| **directo / urgente** | Baja fricción: si nivel 1-2, ejecutar sin gate (a menos que L0 — siempre gate) |
| **detallado** | Nivel suele subir por alcance; gate normal del triage aplica |
| **ambiguo** | Gate sube a `ask` (Atlas complementa) — señal `ambiguity` ya en quest-detector |
| **pregunta** | No ejecuta: responde explicación + opciones; el usuario decide |
| **incremental** | No re-explica contexto previo; continúa desde donde iba |

## 4. Contrato de memoria (OSMA `user/style/*`)

### 4.1 Escritura — `remember` (automático al recibir prompt)

`cli/user-style.ps1 -Action remember -Prompt "<p>"` guarda DOS capas en OSMA:
1. **Observación**: `save -Agent atlas -Topic user/style/<primary> -Type preference`
   con content = prompt (truncado) + scores + secundario.
2. **Experiencia**: `experience record` con situation=prompt, conclusion="Responder
   como: <estilo>", reward 0.4 (se refuerza con recalls exitosos).

### 4.2 Lectura — `recall` (antes de responder)

`cli/user-style.ps1 -Action recall -Prompt "<p>"` devuelve:
- `current`: estilo del prompt actual
- `history`: estilos aprendidos de este usuario en OSMA (topic `user/style`)

Si el historial muestra que el usuario casi siempre escribe **directo/urgente**,
Atlas adelanta con menos fricción. Si es **detallado**, entrega estructura completa.
Si es **ambiguo**, complementa antes de clasificar.

### 4.3 Perfil — `profile`

`cli/user-style.ps1 -Action profile` muestra el catálogo de estilos + lo aprendido
del usuario (para revisión manual o diagnóstico).

## 5. Reglas

1. **La memoria vive en OSMA** (`user/style/*`), nunca en archivos del repo como memoria paralela.
2. **El estilo informa, no sobreescribe** — el Prompt Triage (dificultad) y L0 siguen mandando.
3. **Nunca adivinar** — si no hay historial, usar estilo del prompt actual + neutral.
4. **Consistencia**: detector PS (`quest-detector.ps1`) y bundle DSH (`argos_triage`)
   detectan ambigüedad igual; `user-style.ps1` es la capa de estilo para ambos.
5. **El estilo se refuerza con el tiempo**: cada `remember` suma evidencia; el recall
   consolida lo más frecuente (OSMA lo maneja con retrieval strength).

## 6. Anti-patterns

- Responder con formato "genérico" ignorando un historial claro (ej: usuario directo → no darle ensayo)
- Dejar que el estilo salte el gate L0 (producción/destructivo — SIEMPRE gate)
- Guardar el perfil en JSON del repo (memoria paralela prohibida — usar OSMA)
- Tratar todos los prompts igual: un "sigue adelante" no merece el mismo formato que un spec detallado

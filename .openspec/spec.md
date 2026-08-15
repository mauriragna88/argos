# Harness RPG "Atlas" — Especificaciones

## Requirements

### R1 — Atlas Player Agent
El usuario interactúa solo con Atlas. Atlas es el único punto de entrada para cualquier quest.
Atlas NO escribe código — delega a party members.

**Scenarios**:
- **S1.1** — User envía un quest (feature, bug fix, pregunta) → Atlas detecta tipo de quest → Atlas selecciona party → Atlas lanza combate por turnos
- **S1.2** — User pregunta "¿qué puedes hacer?" → Atlas muestra las 6 clases disponibles con sus skills y niveles
- **S1.3** — User dice "usa solo Vivi" → Atlas arma un party minimal con el personaje solicitado + healer de soporte

### R2. Quest Detection (Auto-Routing)
Atlas debe detectar automáticamente el tipo de quest para seleccionar el party adecuado sin que el usuario tenga que especificar qué agentes usar.

**Scenarios**:
- **S2.1** — Frontend quest ("crea un dashboard", "haz un modal") → Party auto-seleccionado: Vivi (Mage) + Eiko (Healer)
- **S2.2** — Backend quest ("crea API de productos") → Party auto-seleccionado: Paladin + Healer
- **S2.3** — Full Feature (Boss Fight) → Party completo con Monk (arquitectura) + Mage + Paladin + Rogue + Healer
- **S2.4** — Bug fix (no sabe si front/back) → Ranger (research) explora primero, luego Party adecuado

### R3. Model Router (Suscripción)
Atlas pregunta al inicio qué plan de suscripción tiene el usuario y asigna los mejores modelos por rol.

**Scenarios**:
- **S3.1** — User tiene plan gratis/anónimo → modelos base (DeepSeek Flash, Haiku, etc.)
- **S3.2** — User tiene plan pagado de OpenCode → modelos Pro/Max (DeepSeek V4 Pro, Qwen 3.6 Plus)
- **S3.3** — User tiene Claude Max → Opus en roles de Monk y Mage, Sonnet en Paladin/Rogue
- **S3.4** — User tiene GPT Pro → Opus/Terra para alta complejidad, Sonnet/Lune para medio, Haiku/Sol para bajo
- **S3.5** — User cambia de plan → Atlas debe preguntar de nuevo y reasignar

### R4. Party System (Clases RPG)
Cada clase tiene: nombre de personaje RPG, personalidad, especialidad técnica, set de skills/hechizos, modelos asignables.

**Scenarios**:
- **S4.1** — Atlas selecciona party para cada quest → cada miembro recibe su system prompt con personalidad RPG
- **S4.2** — Member falla 2 veces → Healer/Eiko intenta restore (Mend), si falla → Monk replanifica
- **S4.3** — Toda la party falla (3 intentos) → se escala al usuario con diagnóstico completo

### R5. Skill System (Hechizos/Ability Tree)
Cada clase tiene un skill tree con niveles. Las skills se mejoran con uso (XP) y desbloquean nuevo poder.

**Scenarios**:
- **S5.1** — Vivi (Mage) usa "Fireball" 5 veces → desbloquea "Inferno": mayor potencia, más elementos generados
- **S5.2** — Eiko (Healer) usa "Mend" exitosamente → gana +5% healing power, desbloquea "Curaga" en niveles
- **S5.3** — Skill Tree visible al inician: muestra todas las skills y sus requirements
- **S5.4** — Skill hereda todas las skills del ecosistema más skills RPG propias

### R6. Tactics Engine (Economía de Combate)
Sistema que determina cuántos miembros usar, en paralelo o secuencial, basado en cost/benefit.

**Scenarios**:
- **S6.1** — User selecciona "modo ahorro" → Party de 2 members, sequential
- **S6.2** — User selecciona "modo calidad" (Boss Fight) → Party completa, parallel attack en cada turno
- **S6.3** — Mostrar costo estimado antes de iniciar la pelea
- **S6.4** — Trackear HP (tokens gastados) y MP (context window restante) en tiempo real

### R7. Loop Engine (Auto-Continuación)
Cuando una quest se completa, Atlas debe verificar resultados y automáticamente lanzar la siguiente sin esperar al usuario.

**Scenarios**:
- **S7.1** — Quest completada exitosamente → Atlas evalúa si hay más en el mapa de quests → lanza siguiente automáticamente
- **S7.2** — Quest completada parcialmente → Atlas solicita al usuario confirmación para correcciones o siguiente paso
- **S7.3** — Quest fallida → Atlas reporta el fall-de state y pregunta "¿Repetir o abandonar?"
- **S7.4** — Circuit breaker: 3 fallos en 60 min → pausa automática por 30 min

### R8. CLI (Evenatan)
Una ventana interactuable desde terminal que inicia el harness.

**Scenarios**:
- **S8.1** — `arnes activate` → Detecta entorno (OpenCode/Codex/Claude) → Pregunta suscripción → Carga party → Listo para quests
- **S8.2** — Tema visual Rojo + Negro (Atlas FC colors)
- **S8.3** — Muestra estado en ventana: party activo, skills disponibles, HP/MP economía de la misión actual
- **S8.4** — Comandos: `/party` (ver equipo), `/skills` (ver hechizos), `/status` (ver HP/MP), `/quit` (salir)

### R9. Deploy / Portability
El harness debe funcionar en OpenCode, Codex, y Claude con la misma lógica.

**Scenarios**:
- **S9.1** — detectar plataforma automáticamente: `arne activate` abre el agente correcto
- **S9.2** — Los mismos agentes (bytes) funcionan en todas las plataformas mediante transpilación de prompts
- **S9.3** — Copiar archivos manualmente
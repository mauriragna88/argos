# Feature Plan — Sistema XP en CLI

> **Feature ID**: `F1` (referencia a FL-20260810-01)
> **Fecha**: 2026-08-10
> **Autor**: Atlas + Sisyphus
> **Estado**: `done`

---

## 1. Descripción (una frase de valor)

Los agentes ganan XP al completar quests y muestran su nivel en `/party` y `/status`,
dando progresión visible al equipo.

## 2. Alcance

**Incluye**:
- Lectura del quest-ledger (`~/.arnes/quest-ledger.json`) como fuente de XP
- Cálculo de XP/nivel por agente con fórmula simple (nivel = piso(sqrt(xp/100)) + 1)
- Comando `argos xp` que muestra ranking de agentes
- Visualización de nivel en el panel de party/status existente

**NO incluye**:
- Desbloqueo de skills por nivel (requiere sistema de skills dinámico — feature futura)
- Persistencia nueva: se reutiliza quest-ledger existente

## 3. Enfoque de implementación

Script PowerShell dedicado `cli/argos-xp.ps1` (mismo patrón de `cli/argos-party.ps1`),
invocado por `cli/argos.ps1` cuando el comando es `xp`. Fórmula documentada y estable.

## 4. Tareas de la feature

- [ ] T1: `cli/argos-xp.ps1` — crear script que lee quest-ledger y calcula XP/nivel (agente: ansem)
- [ ] T2: `cli/argos.ps1` — registrar el comando `argos xp` (agente: ansem)
- [ ] T3: `cli/argos-party.ps1` — mostrar nivel junto a HP/MP cuando exista (agente: vivi)
- [ ] T4: `tests/argos-xp.tests.ps1` — tests de fórmula y parsing (agente: kuja)

## 5. Verificación (criterios de done de la feature)

- [ ] `argos xp` imprime ranking sin errores con el ledger actual
- [ ] Parseo PowerShell limpio para los scripts modificados
- [ ] `argos doctor` sigue en 9/9
- [ ] Nivel mostrado en party/status
- [ ] Memoria guardada (arnes-memory save)

## 6. Estimación

- **Tokens estimados**: 6K
- **Quests estimados**: 1
- **Agentes**: ansem, vivi, kuja

---
*Memoria: al completar, registrar quest + feature done en arnes.db*

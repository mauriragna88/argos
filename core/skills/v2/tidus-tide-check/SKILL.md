---
name: tidus-tide-check
description: >
  Skill propia de Tidus (Infrastructure & Growth Warden). Health-check del entorno:
  disco, RAM, CPU, cuotas de proveedores, skills instaladas. Vigila que el harness
  tenga recursos para trabajar.
  Trigger: Al inicio de sesión, "revisa recursos", "¿estamos lentos?", check de cuotas.
---

## Propósito
El departamento de sistemas del arnes: recursos suficientes para que el party rinda.

## Trigger
- Inicio de sesión (health-check rápido)
- "Revisa recursos", "¿estamos lentos?", "¿cuánta cuota queda?"
- Antes de un boss fight (verificar que la máquina aguanta)

## Inputs
- Estado actual del sistema (se mide, no se adivina)

## Pasos (procedimiento PROPIO del arnes)
1. **Estado disponible**: leer lo que el harness ya dejó (solo read):
   - `read .arnes/config.json` (budget, modelos, cuotas configuradas)
   - `read .arnes/loop-state.json` y `.arnes/circuit-breaker.json` (estado del loop)
   - `read .arnes/memory/export/tidus-memory.jsonl` (historial de health-checks)
   La medición física (disco/RAM/CPU) la hace el harness por fuera de la skill y
   la deja en memoria para que el agente la lea.
2. **Verificar cuotas de proveedores**: consultar estado de Go/OpenAI/NVIDIA (opencode auth)
3. **Verificar skills**: las skills v2 instaladas vs requeridas por el party
4. **Semaforo**: 🟢 todo sano / 🟡 atención (disco < 20%, RAM < 15%) / 🔴 crítico
5. **Recomendar**: liberar disco, cambiar modelo de fallback, etc.
6. **GUARDAR**: `write` una linea en `.arnes/memory/export/tidus-memory.jsonl` (topic `tidus/health-history`, type `pattern`)

## Output esperado
- Reporte de recursos con semáforo y acción recomendada

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| (ninguna obligatoria) | Tidus lee el estado que el harness deja en archivos (.arnes/) |

## Memoria
- **Antes**: `read .arnes/memory/export/tidus-memory.jsonl` (health-history, cuota-alerts)
- **Después**: `write` a `.arnes/memory/export/tidus-memory.jsonl` (health-history, xp)

## Reglas de la skill
1. Proactivo, no reactivo — avisar ANTES del fallo
2. Leer datos reales, no adivinar (lo que el harness dejó en archivos)
3. Hablar con números (GB, %, req restantes)
4. No tocar código de proyecto — Tidus vigila el ENTORNO
5. Si algo crítico → reportar a Atlas + Quina (presupuesto) + Ragnarok (alternativas)

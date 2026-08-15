# Tactica 1: Party Composition

> Reglas para Atlas: cual.party armar segun el tipo de quest.

## Composition Matrix

| Quest Type | Party Size | Miembros | Cost Multiplier | HP Pool | MP Pool |
|---|---|---|---|---|---|
| **trivial** | 1 | Ranger solo (o Vivi sola si frontend trivial) | 1.0x | 10 | 1K |
| **fix-simple** | 2 | Rogue + Eiko | 1.5x | 30 | 5K |
| **frontend** | 2 | Vivi + Eiko | 2.0x | 50 | 8K |
| **backend-API** | 2 | Paladin + Eiko | 2.0x | 60 | 10K |
| **backend-schema** | 3 | Paladin + Rogue + Eiko | 2.5x | 90 | 15K |
| **architecture** | 2 | Monk + Ranger | 1.5x | 20 | 12K |
| **research** | 1 | Ranger solo | 1.0x | 10 | 3K |
| **devops** | 1 | Eiko solo | 1.0x | 50 | 5K |
| **feature-full** | 4 | Vivi+Paladin+Rogue+Eiko | 2.5x | 100 | 18K |
| **boss-fight** | 6 | ALL (Monk+Vivi+Paladin+Rogue+Eiko+Ranger) | 4.0x | 150 | 25K |

## Hard Rules

### 1. Eiko es Support Obligado
Cualquier quest que no sea trivial o research наз́iva Eiko como segundo member.
- Vivi siempre va con Eiko (regla inquebrantable)
- Paladin siempre va con Eiko (build repair)
- Rogue siempre va con Eiko (retry si backstab falla)

### 2. Solo Mode (1 member)
Solo para: research, devops (Eiko), o trivial frontend (Vivi con support optional)
- Si trivial frontend con Vivi sola: HP bajo (20), riesgo:

### 3. Boss Fight = confirm + L0
Boss fights siempre pausan para user confirmation antes de iniciar.
Motivo: 4x costo, 150 HP committed.

### 4. Substitution Rules
Si un member falla 3 veces (circuit breaker):
- Vivi falla → Paladin+ Eiko toman el frontend work
- Paladin falla → Monk hace plan + Ranger researchof alternativas
- Rogue falla → Eiko hace QA manual (curar el problema, no testear)
- Eiko falla → CRITICAL: pausa usuario, Eiko es irremplazable
- Monk falla → Atlas planifica inline (no delega)
- Ranger falla → Atlas busca inline con context7/websearch

### 5. Maximum Parallelism
- Turn EXECUTE puede tener hasta 3 members en paralelo
- Turn VERIFY siempre es 1 member a la vez (sequential, obligatorio)
- Turn PLAN siempre es 1 member (Monk, o Paladin si no hay Monk)

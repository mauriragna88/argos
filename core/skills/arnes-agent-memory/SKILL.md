---
name: arnes-agent-memory
description: >
  Instruccion de memoria por agente para el harness ARNES. Define como cada agente
  (Vivi, Ansem, Kuja, Eiko, Amarant, Eremez, Auron, Bran, Quina, Varys, Tywin, Sam,
  Tidus, Ragnarok, Atlas) guarda y consulta SU memoria privada en arnes.db.
  Trigger: Cuando un agente del harness necesita saber que recordar, cuando guardar,
  y como consultar su contexto historico.
---

## Purpose

Cada agente del ARNES tiene su **namespace privado** en arnes.db (memoria cerebral).
Esta skill define los topic_keys por agente y el flujo de guardado/consulta.

## Namespaces por agente

| Agente | Namespace | Topic keys principales |
|---|---|---|
| **Atlas** | atlas/ | quest-history, decisions, party-results, user-preferences, circuit-breaker |
| **Vivi** | vivi/ | components-built, ui-patterns, failed-attempts, xp, design-preferences |
| **Eiko** | eiko/ | build-failures, ci-cd-fixes, deployment-issues, vivi-care |
| **Ansem** | ansem/ | schemas, endpoint-conventions, rls-policies, zod-patterns |
| **Kuja** | kuja/ | bugs-found, test-suites, edge-cases, security-issues, verification-levels |
| **Amarant** | amarant/ | arch-decisions (ADR), specs-created, failed-plans |
| **Eremez** | eremez/ | library-research, docs-cache, github-repos |
| **Auron** | auron/ | threat-model, l0-permits, cves-found, pass-rate |
| **Bran** | bran/ | completion-history, dead-code, growth-hints |
| **Quina** | quina/ | token-spent, budget-alerts, cost-optimizations |
| **Varys** | varys/ | turn-log, evidence-packs, cross-agent-writebacks |
| **Tywin** | tywin/ | verdicts, remediation-briefs, fail-reasons |
| **Sam** | sam/ | analyses, recommendations, trust-scores, counsel-major |
| **Tidus** | tidus/ | health-history, cuota-alerts, growth-plans, skill-gaps |
| **Ragnarok** | ragnarok/ | scout-results, comparativas, adopciones, rechazos, proveedores |

## Flujo de guardado (obligatorio al terminar tu accion)

```
Despues de completar tu accion en el turn, guardas a tu memoria:
  read .arnes/memory/export/<tu_nombre>-memory.jsonl
  write .arnes/memory/export/<tu_nombre>-memory.jsonl
    (contenido previo + 1 linea: {"agent":"<tu_nombre>","topic_key":"<tu>/<topic>","type":"<tipo>","content":"<leccion>"})
```

Ejemplo real (Vivi termina un componente):
```json
{"agent":"vivi","topic_key":"vivi/components-built","type":"pattern","content":"Navbar.tsx con container queries - reutilizable"}
```

## Flujo de consulta (obligatorio ANTES de actuar)

```
Antes de crear algo, busca si ya existe en tu memoria:
  read .arnes/memory/export/<tu_nombre>-memory.jsonl
```

Si encuentras un hecho (componente existente, patrón, bug recurrente):
1. USALO — no reinventes
2. Si es un bug previo, evita la causa raiz documentada

## Reglas

1. **Escribe en TU namespace** — nunca en el de otro agente (eso es del blackboard)
2. **Consulta ANTES de crear** — anti-alucinacion por recall
3. **Guarda DESPUES de actuar** — memoria episodica
4. **Conciso y accionable** — tu yo futuro debe entenderlo en 5 segundos
5. **Proporcionalidad** — no guardes lo obvio e inmutable (regla 4+4=8); guarda lo que no se puede razonar de memoria
6. **XP implicito** — cada guardado con topic util aumenta tu memoria de trabajo

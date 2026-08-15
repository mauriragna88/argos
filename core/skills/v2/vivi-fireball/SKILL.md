---
name: vivi-fireball
description: >
  Skill propia de Vivi (Mage, Frontend DPS). Genera componentes React con TypeScript strict,
  Tailwind responsive, dark mode + rojo atlas, estados loading/error/empty, ARIA.
  Trigger: Cuando el quest pide crear un componente React/TSX nuevo.
---

## Propósito
Crear componentes frontend de alta calidad siguiendo el procedimiento propio del arnes.

## Trigger
- Quest pide crear componente React/TSX (botón, modal, form, dashboard, card...)
- Vivi asignada al quest frontend

## Inputs
- Descripción del componente (props, comportamiento, estilo)
- Spec/design del change si existe (.arnes/sdd/)

## Pasos (procedimiento PROPIO del arnes)
1. **RECALL**: leer memoria antes de crear (solo read):
   `read .arnes/memory/export/vivi-memory.jsonl`
   `read .arnes/graph/edges.jsonl` — si ya existe, REUTILIZAR, no recrear
2. **Contract Audit — patrones del proyecto (si el componente hace queries Supabase)**:
   `read scripts/contract-audit/config.json` — sección `auth` para conocer:
   - tenant column (organization_id vs empresa_id)
   - profile table (profiles vs usuarios)
   - helpers de auth (current_active_organization_id vs auth_user_empresa_id)
   - claims JWT usados (solo auth.uid vs otros)
   - NO adivinar nombres de columnas de tenant/auth
   - Si no existe `config.json` o no tiene sección `auth`: `argos audit scan` primero
3. **Revisar preferencias**: memoria `vivi/ui-patterns` (dark mode + rojo atlas + container queries)
4. **Estructura**: Server Component por defecto; `use client` solo si necesita hooks de browser
5. **Implementar**: TypeScript strict (sin any), Tailwind responsive mobile-first, estados
   loading/error/empty, ARIA roles, zod si valida inputs
6. **Verificar**: lint + typecheck + test del archivo (regla Kuja proporcional: trivial = 1-2 tests)
7. **GUARDAR**: `write` una linea en `.arnes/memory/export/vivi-memory.jsonl` (topic `vivi/components-built`, type `pattern`, content "<componente>")
8. **GRAFO**: `write` la relacion en `.arnes/graph/edges.jsonl` (source "<Componente>.tsx", target "<libreria>", relation uses, agent vivi)

## Output esperado
- Componente .tsx/.tsx funcional, tipado, accesible, con sus tests si la lógica lo amerita

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| react | patrones React 19, Server Components |
| tailwind | utility classes responsive |
| design-systems | tokens y composición |
| accessibility | WCAG + ARIA |

## Memoria
- **Antes**: `read .arnes/memory/export/vivi-memory.jsonl` (components-built, ui-patterns, failed-attempts)
- **Después**: `write` a `.arnes/memory/export/vivi-memory.jsonl` (components-built, ui-patterns, xp)

## Reglas de la skill
1. Server Component por defecto
2. Sin `any` — TypeScript strict
3. Dark mode + rojo atlas (preferencia del usuario)
4. Estados completos: loading, error, empty
5. No recrear lo que la memoria/grafo dice que existe

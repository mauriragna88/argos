---
name: arnes-contract-audit
description: >
  ARNES Contract Audit. Valida consistencia DB ↔ API ↔ Frontend con scripts determinísticos.
  Propietario: Tywin (lo invoca como paso mandatory pre-verdict). Encadena 6 capas de validación:
  migrations↔types staleness, schema↔código (columnas referenciadas existen), FK/PK integrity,
  API↔Zod contracts, API↔Frontend response shape, runtime smoke tests.
  Trigger: Antes del verdict de Tywin (SDD verify / FDD review), antes de demo/deploy, después de cualquier migración.
---

## Propósito

Evitar la clase completa de bugs donde la IA genera código que **parece correcto** pero falla
en runtime porque:
- El frontend referencia columnas que no existen en la DB
- Las llaves primarias/foráneas están mal referenciadas o no coinciden los tipos
- `database.types.ts` está desactualizado respecto a las migraciones
- El API returna campos que el frontend no consume o viceversa
- `supabase-js` `.select("col_inventada")` pasar el type-check pero fallar en runtime (el #1 gap del stack)

**Estos bugs NO se pueden fixar con otro agente LLM "revisando" — el mismo modo de fallo
(alucinación de identificadores) se reproduciría. La solución es un gate DETERMINÍSTICO: scripts
que validan hechos reales (schema vs código) y fallan igual cada vez.**

## Trigger

- Antes del verdict de Tywin en SDD verify (FASE 6) — mandatory
- Antes del verdict de Tywin en FDD review (FASE 3) — mandatory
- Antes de cualquier demo/deploy (Auron L0 Gate)
- Después de crear o modificar migraciones
- El harness lo ejecuta con `argos audit` — el agente consume el reporte con `read`

## Inputs

- Migraciones SQL del proyecto (`supabase/migrations/*.sql`)
- `database.types.ts` (tipos generados por `supabase gen types`)
- Zod schemas exportados por las API routes (`inputSchema`, `outputSchema`)
- Componentes frontend que consumen datos (`.tsx`, `.ts` con queries supabase-js)
- Local stack de Supabase (para smoke tests) — `supabase start`

## Pasos (procedimiento PROPIO del arnes)

1. **RECALL**: buscar en la memoria ARNES auditorías previas del proyecto
   `read .arnes/memory/export/tywin-memory.jsonl`
   — ver si ya se conocen drifts, patrones recurrentes, campos problemáticos
2. **Gate L1 — Migrations ↔ Types staleness**:
   - `supabase db reset` contra local stack — fail si migraciones no aplican limpio
   - `supabase gen types typescript --local > /tmp/types.ts`
   - `diff /tmp/types.ts database.types.ts` — fail si diff (types stale)
3. **Gate L2 — Schema ↔ Código (columnas referenciadas existen)**:
   - type-check estricto — captura `.eq()`, `.insert()`, `.update()` typos
   - **AST audit** (script propio): extraer todos los `.select("...")` string literals del codebase,
     validar cada token contra las Row types de `database.types.ts`
   - Mismo para `.order()`, `.range()`, join syntax `alias:table!fk(...)`
4. **Gate L2.5 — Auth & Identity Contract (argos audit scan)**:
   - `read scripts/contract-audit/config.json` — sección `auth`:
     - C7: profile table existe y tiene FK a auth.users
     - C8: tenant column es consistente en todas las tablas
     - C9: código frontend usa el mismo nombre de tenant column
     - C10: auth helpers existen en la BD
     - C11: claims JWT usados son los esperados (solo auth.uid si ese es el patrón)
     - C12: RLS policies no tienen USING(TRUE)
     - C13: roles se resuelven como espera el proyecto
     - C14: perfil de usuario se carga correctamente
   - Si no existe sección `auth` en config.json: fallar con remediation "correr argos audit scan"
5. **Gate L3 — Relations (FK/PK integrity)**:
   - Script SQL contra `information_schema`: FK column type == PK type (catches 42804)
   - FK target table/column existe
   - `ON DELETE` semantics match app expectations
6. **Gate L4 — API ↔ Contract (server side)**:
   - Cada route handler exporta `inputSchema` (Zod) — verificador static
   - `select('*')` prohibido (leak de columnas internas)
   - Response shape pasa `outputSchema` (validado en L6 smoke tests)
7. **Gate L5 — API ↔ Frontend (response contract)**:
   - `typedRoutes: true` activo en `next.config` (catches route typos at compile time)
   - Cliente consume `z.infer<typeof outputSchema>` — no hand-rolled interfaces duplicando API
   - snake_case↔camelCase mapping centralizado en un único mapper
8. **Gate L6 — Runtime smoke tests (defense in depth)**:
   - Vitest: cada route hit contra local stack, response parseada con su `outputSchema`
   - `supabase db test` para RLS policies (pgTAP o matrix anon/auth)
9. **Síntesis del reporte**: mapear fails a check-IDs (C1-C38) con file:line evidence
10. **GUARDAR**: `write` una línea en `.arnes/memory/export/tywin-memory.jsonl` (topic `tywin/contract-audits`, type `audit`)
    — guardar drifts encontrados, patrones recurrentes, lecciones para futuras sesiones
11. **Entregar a Tywin**: reporte estructurado — Tywin lo consume como evidence pre-verdict

## Output esperado

```
CONTRACT AUDIT REPORT — <project>
═══════════════════════════════════════════
L1 Migrations↔Types:    [PASS | FAIL: database.types.ts stale vs migrations]
L2 Schema↔Code:         [PASS | FAIL: N column references invalid]
  - C4: src/app/orders/page.tsx:42 .select("custmer_name") → "customer_name" typo
  - C5: src/api/route.ts:18 .eq("statu", "open") → "status" typo
L2.5 Auth&Identity:     [PASS | FAIL: auth pattern mismatch]
  - C8: tenant column "organization_id" en tablas, frontend usa "empresa_id"
  - C11: codigo usa auth.jwt() pero proyecto solo usa auth.uid()
L3 FK/PK integrity:     [PASS | FAIL: M FK mismatches]
  - C12: orders.user_id (uuid) ≠ users.id (text) → 42804 runtime
L4 API↔Contract:        [PASS | FAIL: routes without exported schema]
L5 API↔Frontend:        [PASS | FAIL: response shape mismatch]
L6 Runtime smoke:       [PASS | FAIL: M/N routes failed schema parse]

VERDICT: PASS | FAIL_PARTIAL | FAIL_TOTAL
Remediation (si FAIL):
  - [ ] Regenerar database.types.ts
  - [ ] Fix .select() typos en <files>
  - [ ] Correr "argos audit scan" + fix patrones de auth
  - [ ] ...
```

## Las 38 validaciones (referencia quick-lookup)

### L1 — Migrations ↔ Generated Types (staleness)
- **C1.** `database.types.ts` idéntico a `supabase gen types` output
- **C2.** Sin hand-edits al archivo generado (codegen banner + diff)
- **C3.** Migraciones aplican limpio en local stack (`supabase db reset` exit 0)

### L2 — Schema ↔ Código (column/type correctness) — CAMPO DE BATALLA PRINCIPAL
- **C4.** `.select("...")` strings referencian solo columnas reales (AST audit) ← gap #1 de supabase-js
- **C5.** `.eq/.neq/.in/.gte/.lte/.like/.ilike/.contains/.overlaps` column args son reales
- **C6.** `.insert()/.update()/.upsert()` keys son columnas reales, matchean snake_case exacto
- **C7.** Join syntax `alias:table!fk(...)` referencia FK real (nombre o [fk_col, ref_col])
- **C8.** Type compatibility: uuid→string, numeric→string, timestamptz→ISO string, jsonb→object
- **C9.** Nullability: columnas required siempre provistas en insert; nullable con `??` en read
- **C10.** Enum set de Postgres == union TS (sin missing/extra members)
- **C11.** No `any` ni supabase client untyped (ESLint `no-explicit-any` + custom rule)

### L2.5 — Auth & Identity Contract (específico del proyecto, detectado por `argos audit scan`)
- **C7.** Profile table (`profiles`/`usuarios`) tiene `id` = `auth.users.id` con FK o mismo UUID
- **C8.** Tenant column (`organization_id`/`empresa_id`) existe en todas las tablas de negocio y coincide con el helper de auth
- **C9.** Código frontend usa el mismo nombre de tenant column que el schema (`.eq("organization_id", ...)` vs `.eq("empresa_id", ...)`)
- **C10.** Auth helpers referenciados en RLS (`current_active_organization_id`, `auth_user_empresa_id`, etc.) existen como funciones en la BD
- **C11.** No hay `auth.jwt()`, `auth.email()`, `auth.role()` sueltos donde el proyecto solo usa `auth.uid()`
- **C12.** RLS policies no usan `USING(TRUE)` (tenant isolation siempre activa)
- **C13.** Roles se resuelven como espera el proyecto: DB lookup vs JWT claim vs columna directa
- **C14.** El perfil del usuario se carga correctamente (`.from("profiles").eq("id", auth.uid())` o patrón equivalente)

### L3 — Migrations ↔ Relations (FK/PK integrity)
- **C12.** Tipo FK == tipo PK referenciado (catches Postgres 42804)
- **C13.** Tabla/columna objetivo del FK existe
- **C14.** Código usa FK que existen como constraints reales
- **C15.** `ON DELETE` semantics match app (cascade vs restrict)
- **C16.** PKs son unique/identity (insert retorna la row)

### L4 — API ↔ Contract (server side)
- **C17.** Cada route valida input con `inputSchema` Zod exportado, campos usados
- **C18.** Cada route retorna data matching `outputSchema` (enforced por L6)
- **C19.** Routes solo query columns RLS-visibles para su role
- **C20.** No `select('*')` leakeando columnas internas
- **C21.** Error contract: `{ error: { code, message } }` — no raw Postgres errors
- **C22.** snake_case↔camelCase mapping centralizado
- **C23.** Auth posture match RLS posture (rutas auth nunca usan anon client)

### L5 — API ↔ Frontend (response contract)
- **C24.** Client fetch paths match routes reales (`typedRoutes: true` → compile-time)
- **C25.** HTTP method del cliente matchea handler
- **C26.** Body/params del cliente match `inputSchema` (shared contracts module)
- **C27.** Cliente consume `z.infer<typeof outputSchema>` — no hand-rolled duplicating API shapes
- **C28.** Status-code branches (200/201/400/404/409/500) match API behavior
- **C29.** Date/timezone: timestamptz ISO strings consistentes client-side
- **C30.** Money/numeric-as-string: no arithmetic sobre numerics retornados como string
- **C31.** `null` vs `[]` vs `undefined` handled per contract

### L6 — Runtime safety net (defense in depth)
- **C32.** Zod smoke tests: cada route hit contra local stack, response → outputSchema parse
- **C33.** SQL schema tests (pgTAP): FK/PK/column assertions en SQL
- **C34.** RLS matrix: allowed/denied per role ejecutado contra local stack

## Complementos web (arsenal, NO dependencia)
| Skill web | Cuándo la potencia |
|---|---|
| validation-pipeline | estructura de gates y staged validation |
| testing-principles | qué vale la pena testear, proporcionalidad |
| smoke-testing | runner para smoke tests de las routes |
| typescript | reglas strict que maximizan lo que captura el type-check |
| api-design | convenciones de contract (inputSchema/outputSchema) |
| postgresql | validaciones FK/PK a nivel SQL |
| supabase-cli | introspección de schema, gen types, db test |
| mocking | cuándo mockear el DB vs cuándo usar local stack (spoiler: NUNCA mockear el DB aquí) |

## Memoria
- **Antes**: `search -Agent tywin -Query "contract audit <project>"` — drifts conocidos, patrones recurrentes del proyecto
- **Después**: `save -Agent tywin -Topic tywin/contract-audits -Type audit` — drifts nuevos, lecciones, patrones que se repiten en el proyecto (para pre-venir en futuras sesiones)

## Reglas de la skill

1. **Determinismo, no opinión** — el gate son scripts; mismo input = mismo output siempre
2. **Migrations son la source of truth** — generada types es derivado, Zod es derivado, código es derivado; edits fluyen DOWN nunca UP
3. **Mockear el DB en smoke tests PROHIBIDO** — mocks testean el mock; smoke tests corren contra local stack (`supabase start`)
4. **FAIL sin remediation = auditoría incompleta** (hereda regla de tywin-judgment)
5. **No skipable** — el gate es mandatory pre-verdict (Tywin) y pre-merge (CI); si se puede skipar, la clase de bug sobrevive
6. **Strings no-literal en `.select()` flag** — `.select(\`col_${var}\`)` no se puede verificar estáticamente; el audit debe marcar como UNVERIFIABLE y requerir runtime check, no pasar en silencio
7. **Proporcionalidad** — proyecto S no necesita todas las checks; selecciona tier por tamaño (mínimo L1+L2 siempre; standard = L1+L2+L2.5+L3)
8. **`QueryData` bonus**: usar `QueryData<typeof query>` en supabase-js v2 da type inference del select string —Makes some typos surfacen as type errors. Útil pero NO reemplaza el AST audit (QueryData no valida todos los casos)

## Implementación por proyecto

Los **scripts determinísticos** viven en cada proyecto target (RES, CHAT), no en el repo harness:

```
<project>/
├── scripts/
│   └── contract-audit/
│       ├── types-diff (script)    # L1: gen types + diff
│       ├── select-audit.mjs       # L2 AST: .select() string audit
│       ├── fk-audit.sql           # L3: information_schema queries
│       ├── zod-smoke.test.ts     # L6: route smoke tests
│       └── run-all (script)       # entry: corre todo, exit code = pass/fail
├── package.json
│   "contract:audit": "argos audit"
└── .github/workflows/
    └── contract-audit.yml        # Pre-merge gate
```

El **harness** provee la skill (este doc) y la referencia de checks (arriba); Tywin solicita el gate al harness (`argos audit`) y consume el reporte con `read`.

## Fuente

- ADR-006: "Contract Auditor como gate determinístico propiedad de Tywin"
- Consulta a Oracle: arquitectura para audit DB↔API↔Frontend en stack Next.js+Supabase+TS
- Análisis del codebase ARNES: ningún agente existente cubre cross-layer contract validation
- Gap conocido: `supabase-js` v2 NO type-checks `.select()` strings (documentado en supabase-js README)

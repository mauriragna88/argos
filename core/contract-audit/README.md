# Contract Audit — gate determinístico DB ↔ API ↔ Frontend

Parte del harness ARNES (ADR-006, skill `arnes-contract-audit`).
Propietario: Tywin (lo invoca como paso mandatory pre-verdict).

## Qué valida

| Capa | Checks | Qué atrapa |
|---|---|---|---|
| **L1** Migrations ↔ Types | C1-C3 | `database.types.ts` desactualizado vs migraciones |
| **L2** Schema ↔ Código | C4-C11 | `.select("col_inventada")`, `.eq()` typos, keys de insert/update inexistentes, joins con FK rota |
| **L2.5** Auth & Identity | C7-C14 | Tenant column, profile table, auth helpers, JWT claims usados, RLS pattern |
| **L3** FK/PK integrity | C12-C16 | FK type ≠ PK type (42804), FK target inexistente, ON DELETE inconsistente |
| **L4** API ↔ Contract | C17-C23 | routes sin Zod, `select('*')`, error contract roto |
| **L5** API ↔ Frontend | C24-C31 | response shape mismatch, typedRoutes, snake/camel |
| **L6** Runtime smoke | C32-C34 | smoke tests de routes contra local stack |

## Uso

```powershell
# Desplegar el gate a un proyecto (una vez)
argos audit init

# Correr el gate
argos audit
# o
npm run contract:audit
```

## Cómo se integra

- **Proyecto nuevo**: `argos init` lo despliega automáticamente (forzoso).
- **Proyecto en seguimiento** (RES/CHAT): `argos audit init` una vez, luego corre solo.
- **Tywin**: pre-verdict en SDD verify y FDD review.
- **Auron**: L0 Gate pre-demo/deploy.
- **CI**: GitHub Action `contract-audit.yml` (pre-merge).

## Requisitos por capa

- **L1**: supabase CLI (`supabase start` o proyecto linkeado).
- **L2**: solo Node.js (lectura estática del código, sin stack).
- **L3**: `DATABASE_URL` + `psql` (en CI usa el servicio de Postgres; local usa `supabase start`).
- **L4-L6**: `supabase start` + Vitest (opcional, defensa en profundidad).

## Reglas

1. Migraciones son la **source of truth**; types/Zod/código son derivados. Edits fluyen DOWN.
2. **No skipable** pre-verdict (Tywin) ni pre-merge (CI).
3. Strings no-literal en `.select()` → UNVERIFIABLE, requieren runtime check (no se silencian).
4. FAIL sin remediation = auditoría incompleta.
5. Proyecto S: mínimo L1+L2. Proyecto L: todas las capas.

# Quest Detector — Subagente de Atlas

> **Quest Detector** analiza el prompt del usuario y clasifica el tipo de quest
> para que Atlas pueda seleccionar el party correcto.

## Input
Un string: el prompt del usuario (ej: "crea un login form con validacion Zod")

## Output
```json
{
  "quest_type": "frontend" | "backend" | "fix" | "architecture" | "research" | "devops" | "boss",
  "complexity": "trivial" | "simple" | "medium" | "complex" | "boss",
  "suggested_party": ["vivi", "eiko"],
  "is_l0": false,
  "quests_chain": ["login form tsx", "zod validation schema", "vitest login tests"],
  "estimated_hp": 50,
  "estimated_mp": 8000
}
```

## Detection Rules (Regex / Keywords)

### Frontend
Triggers: `componente`, `ui`, `component`, `tsx`, `jsx`, `css`, `tailwind`, `modal`, `dashboard`, `formulario`, `login form`, `dashboard`, `pagina`, `pantalla`, `responsive`, `animacion`, `sidebar`, `navbar`
Es Party: **Vivi (Mage) + Eiko (Cleric)**

### Backend
Triggers: `api`, `endpoint`, `route`, `supabase`, `postgres`, `prisma`, `schema`, `query`, `mutation`, `rLS`, `server action`, `middleware`, `zod`, `webhook`
Es Party: **[Paladin] + Eiko**

### Fix
Triggers: `bug`, `fix`, `broken`, `error`, `fail`, `no funciona`, `crashea`, `404`, `500`, `regression`
Es Party: **Rogue (Backstab) + Eiko**

### Architecture
Triggers: `arquitectura`, `plan`, `redisen\ar`, `refactor mayor`, `migrar`, `monorepo`, `design system`, `project structure`
Es Party: **Monk + Ranger**
Flags: L0 (requires user confirmation)

### Research
Triggers: `investiga`, `busca`, `compara`, `que libreria`, `mejor forma`, `docs`, `?`, `como se hace`
Es Party: **Ranger solo**

### DevOps
Triggers: `deploy`, `ci`, `cd`, `docker`, `production`, `rollback`, `vercel`, `github actions`, `pipeline`
Es Party: **Eiko solo**
Flags: L0 (mandatory user approval)

### Boss Fight
Triggers: Multiple keywords frontend+backend+test, `feature completa`, `nueva area`, `modulo entero`, `v1`, `mvp`, `from scratch`
Es Party: **Full party (6 miembros)**
Flags: L0 (user confirm before start)

## Complexity Heuristic

| Complexity | HP | MP (tokens) | Confirm? |
|---|---|---|---|
| trivial | 10 | 1K | No |
| simple | 20 | 3K | No |
| medium | 40 | 6K | No |
| complex | 70 | 12K | Si |
| boss | 150 | 25K | Si (L0) |

## Multi-Quest Chain Detection

Si el usuario menciona multiples acciones en un prompt:
- Conjunctions: `y`, `despues`, `luego`, `also`, `and`, `then`, `segundo`, `finalmenta`
- Cada accion count como un sub-quest
- Atlas debe extraer quests en orden, ejecutar secuencialmente, verificar cada uno

### Ejemplo
```
User: "Crea login con Zod, agregale test Vitest, y despues deploy a Vercel"

Quest Detector output:
  quests_chain:
    - Q1: Login form component (frontend, Vivi+Eiko)
    - Q2: Zod schema validation (backend, Paladin)
    - Q3: Vitest tests (fix, Rogue+Eiko)
    - Q4: Deploy Vercel (devops, Eiko solo, L0)
```

## Ambiguity Handler

Si el quest no es claro, Quest Detector retorna `unknown` y Atlas debe:
1. Pedir a Ranger que investigue el codebase primero
2. O preguntar al usuario: "No estoy seguro si esto es frontend o backend. ?Puedes confirmar?"
3. Nunca asumir y lanzar party ciego

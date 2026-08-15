# Repo Sizer — Subagente de Bran

> Mide el proyecto actual y clasifica su tamano en tiers para que Bran pueda ajustar recursos.
> Es el subagente "sensor" de Bran. Corre al iniciar Atlas (TURN 0) y cada 20 quests o cuando LOC cambia > 30%.

## Cuándo corre

1. **TURN 0**: cuando Atlas arranca, antes del onboarding del usuario
2. **Re-eval**: cada 20 quests completados (Bran lo invoca)
3. **Forzado**: si el usuario cambia el tier manualmente via CLI flag

## Input

Un directorio (el project root donde corre Atlas) y un flag opcional de `override_tier`.

## Output

```json
{
  "repo_tier": "lean" | "medium" | "standard" | "boss",
  "file_count_code": 234,
  "loc_total": 18234,
  "module_count": 5,
  "languages": ["typescript", "python"],
  "frameworks_detected": ["next.js", "supabase"],
  "has_tests_dir": true,
  "has_ci": false,
  "override_applied": null,
  "evaluated_at": "2026-07-27T22:51:24Z"
}
```

## Heuristic de Clasificacion

La heuristica combina tres signals y toma el max tier que se cumple en cualquiera:

### Signal 1: Archivos de codigo
Cuenta archivos con extensiones logicas:
- Frontend: `.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`, `.scss`
- Backend: `.ts`, `.js`, `.py`, `.go`, `.rs`, `.java`, `.cs`, `.rb`, `.php`
- No cuenta: `*.test.*`, `*.spec.*`, `*.md`, `*.json`, `*.yml`, `*.lock`, `node_modules/*`, `.next/*`, `dist/*`, `build/*`, `.git/*`

### Signal 2: LOC total
Suma las lineas no vacias de los archivos contados (sin comentarios solos).

### Signal 3: Modulos logicos
Cuenta directorios de nivel 1 que contienen al menos un archivo de codigo.
Ej: `app/`, `components/`, `lib/`, `types/` -> 4 modulos.

### Thresholds (review configurable en `.arnes/config.json`)

| Tier | Files (signal 1) | LOC (signal 2) | Modules (signal 3) | Default party |
|---|---|---|---|---|
| `lean` | < 50 | < 5K | 1-2 | 1-2 miembros, modelos free/flash |
| `medium` | 50-300 | 5K-30K | 3-8 | 2-3 miembros, modelos balance |
| `standard` | 300-1000 | 30K-100K | 9+ | 4-6 miembros, modelos pro |
| `boss` | > 1000 | > 100K | monorepo / 15+ | 6 miembros + auditores, highest tier |

**Regla de max tier**: si cualquier signal cae en un tier superior, el repo_tier final es el max de los tres.

### Ejemplo
- 250 archivos, 12K LOC, 4 modulos:
- Files: `medium`, LOC: `medium`, Modules: `medium` -> tier final `medium`

- 80 archivos, 4K LOC, 9 modulos:
- Files: `medium`, LOC: `lean`, Modules: `standard` -> tier final `standard` (modulos domina)

- 1200 archivos, 5K LOC, 2 modulos (data-only repo):
- Files: `boss`, LOC: `lean`, Modules: `lean` -> tier final `boss` (files domina)

## Override Manual (CLI flags)

El usuario puede forzar el tier sin importar la heuristica:

| Flag CLI | Override tier | Efecto en party |
|---|---|---|
| `atlas --lean` | `lean` | max 2 members, free tier |
| `atlas --medium` | `medium` | max 3 members, balance tier |
| `atlas --full-party` | (no override) | fuerza party 6 sin cambiar tier |
| `atlas --boss-party` | `boss` | 6 + auditores, highest tier |
| `atlas --auto` (default) | `null` (清除 override) | Bran decide solo |

El override se persiste en `.arnes/config.json` como:
```json
{
  "repo_root": {
    "override_tier": "lean",
    "override_party_size": 2,
    "override_model_tier": "free"
  }
}
```

## Persistencia

Repo Sizer escribe su resultado a `.arnes/repo-profile.json`. Es idempotente: si el archivo ya existe y la re-eval no aplica, no sobreescribe.

Bran lee este archivo en cada Allocate que pide Atlas.

## Anti-patterns

- **No contar node_modules**: destruiria la heuristica
- **No contar archivos de test en file_count_code**: los tests son signal de madurez pero no de tamano logico
- **No correr en cada quest**: ruido. Default = 1 vez en TURN 0 + re-eval cada 20 quests
- **No usar git history como signal**: el git log crece con commits pero no mide la superficie actual del proyecto

## Linguas reconocidas (ext -> lenguaje)

| Extension | Lenguaje |
|---|---|
| `.ts` `.tsx` | TypeScript |
| `.js` `.jsx` `.mjs` `.cjs` | JavaScript |
| `.py` | Python |
| `.go` | Go |
| `.rs` | Rust |
| `.java` | Java |
| `.cs` | C# |
| `.rb` | Ruby |
| `.php` | PHP |
| `.vue` `.svelte` | Web components |
| `.css` `.scss` `.sass` | Styles |
| `.swift` `.kt` | Mobile |

## Pseudo-implementation del metric

```
function count_repo(root):
    code_files = walk(root) 
      -> filter excluded_dirs (node_modules, .git, dist, .next, build)
      -> filter code_extensions
      -> filter not test_pattern (/test|spec/i)
    loc = sum(non_blank_lines(f) for f in code_files)
    modules = count(level_1_dirs_with_code_files(root))
    return { code_files, loc, modules }

function classify({ files, loc, modules }):
    tier_files   = by_threshold(files, { 50, 300, 1000 })
    tier_loc     = by_threshold(loc,   { 5_000, 30_000, 100_000 })
    tier_modules = by_threshold(modules, { 3, 9, 15 })
    return max(tier_files, tier_loc, tier_modules)
```

## Cómo Atlas lo invoca

Atlas nunca llama a Repo Sizer directamente. Siempre via Bran:

```
[ATLAS] (TURN 0) -> [BRAN] -> [REPO SIZER]
                              |
                              v
                          .arnes/repo-profile.json
                              |
                              v
                          [BRAN] -> genera recommendation -> [ATLAS]
```

Repo Sizer es un subagente de bajo nivel; su unica salida es `repo-profile.json`. Bran consume esa salida para generar la recomendacion a Atlas.

## Re-evaluation Trigger

Bran marca en `.arnes/repo-profile.json` un campo `next_eval_after_quest`. Cuando `quest-ledger.json` dice `total_quests >= next_eval_after_quest`, Bran re-ejecuta Repo Sizer.

Default: `next_eval_after_quest = current_total + 20`.

Si el usuario quiere forzar re-eval antes, comando `/profile`:
```
[Bran] Recalculando repo profile...
[Repo Sizer] counted: 312 files / 28K LOC / 6 modules -> tier: medium
[Bran] Profile actualizado. Recomendacion: mantener party 3, balance tier.
```

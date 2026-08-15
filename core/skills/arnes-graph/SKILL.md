---
name: arnes-graph
description: >
  Grafo de relaciones del harness ARNES. Guarda RELACIONES entre nodos (componentes,
  librerias, agentes, modulos, tablas) en ARCHIVOS JSONL (`.arnes/graph/edges.jsonl`).
  Responde preguntas de relacion: "quien toco X", "que depende de Y", "existe camino entre A y B".
  Anti-alucinacion por relaciones: si el grafo dice que un componente YA usa Zod,
  el agente NO lo reimplementa.
  SOLO usa las herramientas `read` y `write` — sin otras herramientas.
  Trigger: Cuando necesites saber relaciones entre codigo, quien trabajo en que zona,
  dependencias entre componentes, o mapear el proyecto.
---

## Purpose

El grafo complementa la memoria: la memoria guarda los HECHOS (observaciones), el grafo
guarda las CONEXIONES (edges). Cuando necesitas saber "quien toco esto" o "que usa que",
lees el grafo — es más rápido y preciso que adivinar.

## Como usar (solo read + write)

Todas las operaciones se hacen con `read` / `write` sobre `.arnes/graph/edges.jsonl`
(1 relacion por linea). El harness sincroniza el archivo al grafo SQLite por fuera de la skill.

### Agregar una relacion (despues de trabajar) — write

1. `read` `.arnes/graph/edges.jsonl` (conserva lo previo; si no existe, se crea)
2. `write` `.arnes/graph/edges.jsonl` con el contenido previo + UNA linea nueva:

```json
{"source": "<X>", "target": "<Y>", "relation": "<relacion>", "agent": "<tu>", "created_at": "<fecha>"}
```

Relaciones comunes:
- `uses` — un componente usa una libreria
- `imports` — un componente importa otro
- `created_by` — un agente creo un nodo
- `touched_by` — un agente trabajo en un nodo
- `protected_by` — una tabla esta protegida por una policy
- `depends_on` — un modulo depende de otro
- `implements` — una clase implementa una interfaz

Ejemplo (Vivi crea Navbar.tsx con tailwind):
```json
{"source": "Navbar.tsx", "target": "tailwind", "relation": "uses", "agent": "vivi", "created_at": "2026-08-06"}
```

### Consultar relaciones de un nodo — read

1. `read` `.arnes/graph/edges.jsonl`
2. Filtra las lineas donde `source` o `target` = el nodo buscado

### Vecinos (recorrido de relaciones)

`read` `.arnes/graph/edges.jsonl` y recorre las lineas cuyo `source`/`target`
toca el nodo (repitiendo hasta la profundidad deseada).

### Path-finding (camino entre nodos)

`read` `.arnes/graph/edges.jsonl` y traza el camino más corto encadenando
lineas: Login.tsx →[imports]→ Sidebar.tsx →[uses]→ tailwind.

### Stats del grafo

`read` `.arnes/graph/edges.jsonl` y cuenta: total de edges, por relacion, por agente.

## Preguntas que responde (ejemplos reales)

| Pregunta | Que lees |
|---|---|
| "¿Qué usa Login.tsx?" | edges con source=Login.tsx |
| "¿Quién trabajó en auth?" | edges con source/target=auth o nodos cercanos |
| "¿Sidebar depende de tailwind?" | camino entre Sidebar.tsx y tailwind |
| "¿Hay relación entre users y vivi?" | camino entre users y vivi |
| "¿Qué componentes creó Vivi?" | edges con relation=created_by y agent=vivi |

## Flujo obligatorio (anti-alucinacion)

### ANTES de crear algo nuevo:
1. `read` `.arnes/graph/edges.jsonl` — ¿el nodo ya existe? ¿alguien lo toco?
2. Filtra por el nodo/libreria en cuestion — ¿que se conecta?
3. Si el grafo muestra que X YA usa Y → NO lo reimplementes, reutiliza

### DESPUES de trabajar:
1. `read` `.arnes/graph/edges.jsonl`
2. `write` el archivo + 1 linea por relacion nueva (source/target/relation/agent)
3. Esto alimenta el mapa del proyecto para toda la empresa ARNES

## Reglas de oro

1. **El grafo es el neocortex** — guarda RELACIONES, no hechos (los hechos van a arnes-memory)
2. **Nodos son cosas**: componentes, librerias, tablas, agentes, modulos, servicios
3. **Aristas son acciones**: uses, imports, created_by, touched_by, depends_on
4. **Anti-alucinacion**: si el grafo dice que existe, existe. No lo re-inventes.
5. **Siempre con `agent`**: cada relacion sabe QUIEN la creo (auditabilidad)
6. **Proporcionalidad**: no agregues edges obvios que nunca cambian (4+4=8)
7. **Despues de un quest grande**: registra TODAS las relaciones nuevas del trabajo
8. **SOLO read + write** — ninguna otra herramienta

## Ejemplo completo de una sesion

```
1. Vivi crea Navbar.tsx (usa tailwind)
   read .arnes/graph/edges.jsonl → write + {"source":"Navbar.tsx","target":"tailwind","relation":"uses","agent":"vivi"}

2. Ansem consulta antes de tocar auth:
   read .arnes/graph/edges.jsonl → ve que Login.tsx ya existe y usa zod → NO reimplementa

3. Atlas pregunta "quien puede tocar el Login sin romper nada?"
   read .arnes/graph/edges.jsonl → ve vivi (creo Login) y la relacion con Sidebar → sabe a quien delegar
```

## Ubicacion

- `.arnes/graph/edges.jsonl` — archivo de edges (lo que lees/escribes)
- `arnes.db` — tabla edges del harness (el harness la sincroniza, NO el agente)
- `cli/` — motor del harness (por fuera de la skill; el agente NO lo invoca)

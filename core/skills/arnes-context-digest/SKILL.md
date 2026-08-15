---
name: arnes-context-digest
description: >
  Consolidacion de memoria del harness ARNES — el "sueno" del agente. Al cierre de
  sesion (o periodicamente), cada agente resume sus aprendizajes del dia y los guarda
  compactos en arnes.db. Evita la fragmentacion de memoria y mantiene los recuerdos
  accionables a largo plazo.
  Trigger: Al cerrar sesion, al terminar un quest grande, o cuando la memoria de un
  agente crece sin control.
---

## Purpose

Como el cerebro humano consolida memorias mientras duermes, ARNES consolida las
observaciones del dia en digests compactos. Esto mantiene la memoria accionable:
pocas observaciones de calidad, no miles de fragmentos.

## Cuando consolidar

1. **Al cerrar sesion** (obligatorio — parte del SESSION CLOSE PROTOCOL)
2. **Despues de un quest grande** (boss fight completado)
3. **Cuando un agente tiene >50 observaciones** en su namespace (fragmentacion)

## Como consolidar

### Paso 1 — Revisar lo que se guardo hoy
```
read .arnes/memory/export/<tu_nombre>-memory.jsonl
read .arnes/memory/export/*.jsonl   # contexto del harness
```

### Paso 2 — Resumir en un digest (guardar como observacion tipo session_summary)
```
read .arnes/memory/export/<tu_nombre>-memory.jsonl
write .arnes/memory/export/<tu_nombre>-memory.jsonl
  (contenido previo + 1 linea: {"agent":"<tu_nombre>","topic_key":"<tu>/digest-YYYY-MM-DD","type":"session_summary","content":"RESUMEN COMPACTO DEL DIA"})
```

Ejemplo de digest (Vivi):
```
"Digest 2026-08-05: Cree Navbar.tsx (container queries) y Login.tsx (zod+dark mode).
Patron: dark mode + rojo atlas siempre. Aprendi: usar use client solo para hooks de browser.
Fallo: intente grid en un componente server - no aplica. Proxima vez: client component para interactivos."
```

### Paso 3 — Exportar snapshot (para git/backup)
```
Los archivos .arnes/memory/export/*.jsonl YA son el snapshot portable.
El harness lo exporta por fuera de la skill; el agente no ejecuta comandos.
```

## Formato del digest (compacto y accionable)

```
Digest <fecha>:
- Cree/Hice: <items concretos>
- Patron aprendido: <leccion reutilizable>
- Falle con: <error + causa raiz>
- Proxima vez: <accion correcta>
```

## Reglas

1. **Compacto** — 5-10 lineas maximo por digest
2. **Accionable** — tu yo futuro debe poder actuar solo con el digest
3. **Incluye fallos** — los errores son los recuerdos mas valiosos (no repetir)
4. **Patrones sobre datos** — guarda el PATRON, no el dato crudo
5. **Se exporta al final** — el snapshot JSONL es lo que viaja a git

## SESSION CLOSE PROTOCOL (obligatorio)

Antes de terminar una sesion, Atlas DEBE ejecutar:
1. Cada agente que trabajo guarda su digest (Paso 2)
2. Atlas guarda su propio digest: `atlas/digest-YYYY-MM-DD`
3. Export: los JSONL de `.arnes/memory/export/` quedan como snapshot (harness lo sincroniza)
4. Actualizar `docs/PLAN-ARNES.md` (fases completadas, gotchas)
5. Registrar quests finalizados: escribir una linea en `.arnes/memory/export/atlas-memory.jsonl`
   con type `action` y topic `atlas/quest-history` (descripcion, result, tokens_used)

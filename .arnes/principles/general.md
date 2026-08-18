# Golden Principles — Generales

Reglas de oro del harness para TODO quest:

1. **Evidencia sobre opinión**: busca hechos verificables (repo, tests, tools) antes de razonar. La jerarquía: repo verificado > tests > hecho del usuario > memoria verificada > inferencia.
2. **Cambios mínimos**: el parche más pequeño que resuelve el problema. No refactors colaterales.
3. **No romper lo verde**: un cambio no puede romper tests/typecheck existentes.
4. **Preguntar antes de asumir** en decisiones con trade-offs (alternativas reales); avanzar cuando la respuesta es obvia.
5. **Memoria primero**: consultar experiencias previas antes de razonar de cero (evitar repetir errores).
6. **Lo determinista manda**: si existe forma determinista de verificar, úsala antes que inspección LLM.
7. **Degradación parcial**: si una fuente falla, continúa con las demás; nunca bloquees el turno por una fuente.

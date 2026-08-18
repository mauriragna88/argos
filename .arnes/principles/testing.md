# Golden Principles — Testing

1. **Proporcionalidad**: esfuerzo del test proporcional a la complejidad del código. No sobre-verificar lo trivial.
2. **FAIL→guard**: todo bug arreglado merece un test que capture la regresión para siempre (Regression Factory).
3. **Verificación por ladder**: nivel de verificación según riesgo (L1 estático → L6 regresión). No inspección LLM si hay forma determinista.
4. **Tests que fallan de verdad**: el test debe fallar con el bug presente y pasar con el fix. Nunca tests que pasan por accidente.
5. **Cobertura de estados**: casos borde (vacío, error, límites) ≥ caso feliz.

# Golden Principles — Seguridad

1. **L0 = humano en el loop**: producción, auth, RLS, deploy requieren confirmación explícita. Inalterable.
2. **Auron siempre en superficie de seguridad**: auth, tokens, secrets, RLS → se une al party solo.
3. **Secrets nunca en el repo**: ni hardcodeados, ni en git, ni en logs.
4. **RLS es la última línea**: políticas row-level verificadas, no solo confianza en el cliente.
5. **Auditoría después del fix**: un fix de seguridad se convierte en guard de regresión (security test).

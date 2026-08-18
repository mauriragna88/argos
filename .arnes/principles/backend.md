# Golden Principles — Backend

1. **Validación en la frontera**: Zod/schema en el borde de la API; nunca confiar en input sin validar.
2. **Fuente de verdad única**: migraciones > tipos derivados. Los edits fluyen DOWN, nunca UP.
3. **Contrato explícito**: endpoints documentados (openapi/spec) y consistentes con el schema.
4. **Errores estructurados**: códigos y mensajes consistentes; sin excepciones silenciosas.
5. **RLS por defecto**: toda query a datos sensibles pasa por row-level security; nunca bypass.

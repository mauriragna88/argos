# Catálogo dinámico de modelos

El catálogo consulta la disponibilidad real en cada ejecución; la configuración
existente se usa únicamente para mostrar modelos que dejaron de estar activos.
Un modelo configurado **no** se considera disponible sin una respuesta exitosa
de OpenCode.

```powershell
# JSON compacto para automatización
.\cli\model-catalog.ps1

# JSON legible y filtrado a un proveedor
.\cli\model-catalog.ps1 -Pretty -Provider nvidia
```

La salida exitosa es un arreglo de objetos estables con `full_id`, `provider`,
`label`, `source`, `availability` y `checked_at` (UTC). Los registros con
`source: "configured"` y `availability: "unavailable"` son referencias de
visualización; no son candidatos de ejecución.

Si OpenCode no está disponible o el comando falla, el script devuelve código
no cero y un objeto JSON con `error.code`, `error.message` y `checked_at`.
No inventa modelos ni disponibilidad.

La consulta tiene un límite de 30 segundos por defecto para no bloquear el
loop de Atlas. Puede ajustarse para operaciones controladas con
`-TimeoutSeconds` (de 1 a 300).

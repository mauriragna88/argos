# Comandos de rutas de modelo

Los comandos de esta página son **de observación y previsualización**: no
escriben `model-chain.json`, `model-assignments.json`, ni el estado de
failover. La ejecución y el watchdog se integrarán después.

`atlas configure` sí guarda la cadena heredada de failover, pero ahora valida
los cuatro IDs contra el **catálogo completo** de OpenCode: los slots pueden
mezclar proveedores, cada ID debe existir y no se permiten duplicados.

```powershell
atlas models                         # catálogo vivo + configurados
atlas models -Provider nvidia        # filtra por proveedor
atlas routes                         # orden declarativo de los 13 agentes
atlas provider-status                # modelos sanos + caps semanales declarados
atlas route auto vivi                # preview del primer fallback sano
atlas route manual vivi minimax_m3   # preview de alternativa autorizada
```

`manual` no acepta un ID arbitrario: recibe un alias que ya pertenezca al
orden de preferencia del agente y exige que tenga un modelo `live`,
`available` y saludable en el catálogo. Eso evita que un override aparente
funcionar cuando el proveedor no está disponible.

Para automatización o pruebas, el backend read-only admite un fixture:

```powershell
.\cli\model-route-status.ps1 auto -Agent vivi -CatalogPath .\catalog.json -Json
.\cli\test-model-route-status.ps1
```

El estado de proveedor muestra los *soft caps* de la política; todavía no son
medición de cuota ni consumo real. Por diseño, un catálogo vivo que falla no
se suplanta con modelos configurados: la previsualización se detiene de forma
segura.

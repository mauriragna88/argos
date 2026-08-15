# Agent model resolver

`cli/agent-model-resolver.ps1` resolves a **single agent** using the ordered
capabilities in `.arnes/model-routing-policy.json` and a catalog produced by
`cli/model-catalog.ps1`. It is read-only and intentionally does not modify the
legacy `model-chain.json` or `model-assignments.json` files.

```powershell
# Deterministic / CI input
.\cli\agent-model-resolver.ps1 -Agent vivi -CatalogPath .\catalog.json -Json

# Query OpenCode through the approved live catalog
.\cli\agent-model-resolver.ps1 -Agent tywin -LiveCatalog -Json
```

Success is structured JSON with `agent`, `selected_model`, `provider`,
`preference_index`, and `reason`. A model is selectable only when the catalog
says `source: live` and `availability: available` (and, if supplied, health is
`healthy`). When no candidate is live the command returns an `unresolved`
decision and exit code `2`; catalog/policy failures return exit code `1`.

Run the deterministic verification without calling OpenCode:

```powershell
.\cli\test-agent-model-resolver.ps1
```

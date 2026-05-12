# External Project Links

Place optional JSON link files here if you want to override how a sibling install is detected.

The framework already scans:

- `C:/Games/PokemonMultiverse`
- the parent directory of this game (`C:/Games` on this machine)
- [ExpansionLibrary](/C:/Games/PIF/ExpansionLibrary)

You only need a link file if you want to:

- point to a project outside those roots
- disable direct mounting for a detected install
- override the display name
- point the framework at a prepared/extracted `Data` snapshot while keeping assets in the original install
- set a manual entry map/position
- reserve a specific virtual map block

Use [external_project_link.template.json](/C:/Games/PIF/ExpansionLinks/external_project_link.template.json) as the starting point.

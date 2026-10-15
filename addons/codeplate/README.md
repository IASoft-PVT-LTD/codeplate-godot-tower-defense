# CodePlate add-on

Shared tools for CodePlate Godot templates. Don't edit these files in a project: they're replaced when the template updates. Put project-specific checks in `res://checks/tests/` and screenshot setup in `res://tools/screenshot_hooks.gd`.

| File | What it does |
|---|---|
| `checks/run.gd` | The check runner: `godot --headless --path . --script res://addons/codeplate/checks/run.gd [-- filter]`. Ends with `CODEPLATE CHECKS: PASS` or `FAIL`. |
| `checks/check_case.gd` | `CheckCase`, the base class for checks: `expect`, `expect_eq`, `frames`, `until`, `mouse_button`, `mouse_drag_to`, `action`. |
| `checks/builtin/test_codeplate_project.gd` | Project-wide checks: `assets.json` against the files, every `res://` path exists, and every preset in `export_presets.cfg` includes the data files (JSON, text, CSV, Markdown) the game reads at runtime. |
| `tools/screenshot.gd` | Screenshots for agents. Run without `--headless`. Customised by `res://tools/screenshot_hooks.gd`. |
| `ui/settings_screen.gd` | `CodePlateSettings`, the settings + credits overlay games open from their title screen: music and effects volume, fullscreen, reset progress (with a confirmation), and a Credits page built from `res://CREDITS.md` (HTML comments hidden). It talks to the `Game` autoload by name: `music_volume`, `sfx_volume`, `fullscreen`, their `set_*()` functions, `save_settings()` and `reset_progress()`; a missing one hides its control. `CodePlateSettings.open(title_screen)` adds it; pass `true` as a second argument for all-caps text. Under the CodePlate Free License the page always shows "Built with CodePlate (codeplate.io)". Exports must include `CREDITS.md` and `LICENSE.md` (`include_filter`). |

**Finding Godot:** CodePlate's tools and the briefs look for the binary in this order: the `GODOT` environment variable, then PATH (`where godot*`, `which godot godot4`), then the usual install folders. On Windows use the `_console.exe` build, which prints output.

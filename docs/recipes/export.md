# Export (build the game)

Use when the user wants a playable build for desktop, web or mobile.

1. **Export templates.** Godot needs export templates matching the editor version exactly (4.7.2).
   - They come from the official download page (`Godot_v4.7.2-stable_export_templates.tpz`, about 1 GB).
   - Ask the user before downloading. Or let them install the templates from the editor: Editor → Manage Export Templates.
2. **Presets.** `export_presets.cfg` ships two: **Android** (see `export-android.md`) and **Web**. The Web preset is single-threaded (`thread_support=false`) and builds to `export/web/index.html`. For a desktop build, have the user add a preset in the editor (Project → Export), or copy the Web preset's filters into a new `[preset.N]` by hand and set its platform and `export_path`.
   - Builds go under `export/` (`export/web/`, `export/android/`...). Create the folder if it's missing. `export/` is git-ignored and holds an empty `.gdignore` so Godot doesn't import the builds; keep that file. The same goes for `shots/` (screenshots).
   - `exclude_filter` keeps `checks/*`, `tools/*`, `docs/*`, `shots/*` and `export/*` out of the game. A new preset needs the same; a check fails otherwise.
   - `include_filter` matters: the game reads `content/` (JSON and the ASCII maps), `assets.json` (sprite frame sizes) and `CREDITS.md` (the Credits page) and `LICENSE.md` (which decides whether the CodePlate credit shows) at runtime, and none of them is a Godot resource. Without the filter the exported game starts with no content and its credits fall back to the CodePlate line alone.
   - `thread_support=false` makes the web build single-threaded, so it runs on any static host. Threaded builds need the COOP/COEP headers set on the server, so a check keeps Web presets single-threaded.
3. **Export headless:**
   ```
   godot --headless --path . --export-release "Web" export/web/index.html
   godot --headless --path . --export-release "Windows" export/windows/MyGame.exe
   ```
   `export/` is git-ignored.
4. **Platform notes:**
   - **Web:** uses the Compatibility renderer, as browsers need. Serve the folder over HTTP to test. Touch works: tap tiles, towers and buttons.
   - **Desktop:** the window opens at 1440×810 (3× the pixel view); `window_width_override` / `window_height_override` in `project.godot` change that.
   - **Phones:** see `add-touch-polish.md` (bigger targets, landscape only). The HUD has pause and speed buttons.
   - **macOS:** builds need signing and notarizing for distribution, with the user's Apple developer account.
   - **Android:** see `export-android.md` (the project ships an Android preset).
   - **iOS:** needs a Mac with Xcode and an Apple developer account.

## Verify

1. Run the checks before exporting.
2. Confirm the export exits with status 0 and the output exists.
3. Ask the user to run the build on the target platform.

# Export to Android

Use when the user wants the game on an Android phone or tablet: a debug APK to try on a device or emulator now, and a start on a Play Store release later.

The template ships a ready `export_presets.cfg` with one preset, **Android** (debug-signed APK, arm64-v8a, no Gradle). Touch input already works. `add-touch-polish.md` has bigger touch targets. The title screen's hint switches to touch wording on a touch screen.

1. **Install the toolchain** once. Ask before downloading anything.
   - **Godot 4.7.2 export templates** (`Godot_v4.7.2-stable_export_templates.tpz`, Editor > Manage Export Templates). They must match the editor version exactly.
   - **JDK 17** (any build: Temurin, Microsoft, Zulu).
   - **Android SDK**: the command-line tools, then `sdkmanager "platform-tools" "build-tools;36.0.0" "platforms;android-36"` (accept the licenses with `sdkmanager --licenses`).
   - **A debug keystore.** Debug builds are signed with it; it holds nothing secret:
     ```
     keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999
     ```
2. **Tell Godot where they are.** Godot reads them from its editor settings, not from the project: `export/android/android_sdk_path`, `export/android/java_sdk_path` and `export/android/debug_keystore` (user `androiddebugkey`, password `android`). Set them once in the editor (Editor > Editor Settings > Export > Android), or write them into the editor settings file (`editor_settings-4.7.tres` in Godot's config folder: `%APPDATA%\Godot` on Windows, `~/Library/Application Support/Godot` on macOS, `~/.config/godot` on Linux). If the SDK path setting is empty, the `ANDROID_HOME` environment variable is used. Write the paths in `docs/project.md`, never in the project's files.
3. **Set the identity** in `export_presets.cfg`, preset "Android":
   - `package/unique_name`: it ships as `com.example.towerdefense`. **Change it** to the user's own reverse-domain name (`com.theirstudio.theirgame`: letters, digits and underscores, each part starting with a letter). It identifies the app on a device and in Google Play, and Play rejects `com.example`. Changing it later makes Android treat the game as a different app.
   - `package/name`: the name under the launcher icon (`Lantern Keep` now; keep it in step with `config/name` in `project.godot`).
   - `version/code` (an integer that goes up on every upload) and `version/name` (shown to players).
4. **Icons.** The preset points at three placeholder layers in `assets/launcher/`, made from the app icon:
   - `adaptive_foreground.png` (432x432): the picture, kept inside the central 288x288 because launchers crop the rest into a circle, squircle or square.
   - `adaptive_background.png` (432x432): opaque; a flat color or soft pattern.
   - `adaptive_monochrome.png` (432x432): a white shape on transparent, which Android 13+ recolors for themed icons.

   Replace all three with the user's art at exactly 432x432 (keep the file names), update their entries in `assets.json` (size, `use`, `license`, `credit`), and rerun `godot --headless --path . --import`. `main_192x192` stays empty: Godot falls back to `config/icon` (`assets/ui/icon.png`) for old launchers, so replace that too.
5. **Orientation and look.** The orientation comes from the project, not the preset: this game is landscape (the project doesn't set `display/window/handheld/orientation`, so it's the default, landscape). Change it in `project.godot`. `screen/immersive_mode=true` hides the status and navigation bars; set it to `false` if the user wants them.
6. **Keep the data in the build.** `include_filter` in the preset names the files the game reads that aren't Godot resources: `*.json`, `*.txt`, `CREDITS.md` and `LICENSE.md` (this game's data: content/: the JSON and the ASCII maps (`*.txt`)). Without them the APK starts with no content. When you add a data file of a new type (say `.csv`), add it to `include_filter` of **every** preset. A check fails if a preset leaves one out.
7. **Export the debug APK** from this folder:
   ```
   godot --headless --path . --import
   godot --headless --path . --export-debug "Android" export/android/godot-tower-defense-debug.apk
   ```
   `export/` is git-ignored. The command prints `Signed` and ends with `[ DONE ] export`.
8. **Test it.**
   - **Phone:** enable Developer options and USB debugging, plug it in, then `adb install -r export/android/godot-tower-defense-debug.apk`.
   - **Emulator:** the preset builds arm64-v8a, which runs on phones and on arm64 emulators (Apple silicon). For an x86_64 emulator on Intel or AMD, export a copy with `architectures/arm64-v8a=false` and `architectures/x86_64=true` (don't commit that change), then `adb install` it. Start the emulator with `-gpu host`.
   - Look at the title screen (touch wording, not key names), start a level, and confirm taps or the on-screen controls respond and the content is there ("0 LEVELS" means the data filter is wrong).
   - `adb logcat -s godot` shows the game's errors.

## What a Google Play release needs on top of this

The debug APK is for testing; Play doesn't take it. Go through this with the user, and re-check Google's current rules before submitting, because they change.

- **An Android App Bundle (.aab), not an APK.** That needs the Gradle build: set `gradle_build/use_gradle_build=true` and `gradle_build/export_format=1` in a release preset, install the Android build template (Project > Install Android Build Template; it adds an `android/` folder), and export with `--export-release`. Godot's docs list the extra SDK packages the Gradle build needs.
- **A release (upload) keystore the user creates and guards.** Never commit it or its passwords. Give Godot the path, alias and passwords through the editor settings or the environment variables `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. Back it up somewhere private; Play App Signing holds the final signing key.
- **Target API 36** as of October 2026 (set `gradle_build/target_sdk` if Godot's default is lower), with arm64-v8a included.
- **The final package name** (not `com.example`), a `version/code` that rises with each upload, and, under the free license, the credit "Built with CodePlate (codeplate.io)" kept where players see it.
- **The store listing:** name, short and full description, icon (512x512), feature graphic (1024x500), screenshots, a privacy policy URL, the content rating and data-safety forms. The user does this in Play Console themselves (a developer account, one-time fee).

## Verify

1. Run the two check commands in `AGENTS.md`. The second must end with `CODEPLATE CHECKS: PASS`.
2. Export the debug APK (step 7), confirm the command exits 0 and the `.apk` exists.
3. If an Android device or emulator is available, install it and do step 8; otherwise tell the user the build is untested on a device.
4. Confirm `package/unique_name` is no longer `com.example.towerdefense`, and that `export_presets.cfg` holds no local paths or passwords.

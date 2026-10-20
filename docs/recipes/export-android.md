# Export to Android

Use when the user wants the game on an Android phone or tablet: a debug APK to try on a device or emulator now, and a start on a Play Store release later.

The template ships a ready `export_presets.cfg` with two Android presets: **Android** (debug-signed APK, arm64-v8a, no Gradle: for phones and Apple-silicon emulators) and **Android test APK** (the same with x86_64 added, for emulators on Intel or AMD machines). On a touch screen the game switches to its touch layout by itself (`touch_ui` in `config/game_config.tres`, see `add-touch-polish.md`): thumb-sized buttons, the HUD and map kept clear of the camera cutout and the gesture bar, and two taps to spend gold.

1. **Install the toolchain** once. Ask before downloading anything.
   - **Godot 4.7.2 export templates** (`Godot_v4.7.2-stable_export_templates.tpz`, Editor > Manage Export Templates). They must match the editor version exactly.
   - **JDK 17** (any build: Temurin, Microsoft, Zulu).
   - **Android SDK**: the command-line tools, then `sdkmanager "platform-tools" "build-tools;36.0.0" "platforms;android-36"` (accept the licenses with `sdkmanager --licenses`).
   - **A debug keystore.** Debug builds are signed with it; it holds nothing secret:
     ```
     keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999
     ```
2. **Tell Godot where they are.** Godot reads them from its editor settings, not from the project: `export/android/android_sdk_path`, `export/android/java_sdk_path` and `export/android/debug_keystore` (user `androiddebugkey`, password `android`). Set them once in the editor (Editor > Editor Settings > Export > Android), or write them into the editor settings file (`editor_settings-4.7.tres` in Godot's config folder: `%APPDATA%\Godot` on Windows, `~/Library/Application Support/Godot` on macOS, `~/.config/godot` on Linux). If the SDK path setting is empty, the `ANDROID_HOME` environment variable is used. Write the paths in `docs/project.md`, never in the project's files.
   If Godot can't see that folder (a sandboxed shell or agent on Windows can have its own `%APPDATA%`), set `APPDATA` for the Godot command only, to a folder holding `Godot\editor_settings-4.7.tres` and `Godot\export_templates\4.7.2.stable\`.
3. **Set the identity** in `export_presets.cfg`, in **both** Android presets:
   - `package/unique_name`: it ships as `com.example.towerdefense`. **Change it** to the user's own reverse-domain name (`com.theirstudio.theirgame`: letters, digits and underscores, each part starting with a letter). It identifies the app on a device and in Google Play, and Play rejects `com.example`. Changing it later makes Android treat the game as a different app.
   - `package/name`: the name under the launcher icon (`Lantern Keep` now; keep it in step with `config/name` in `project.godot`).
   - `version/code` (an integer that goes up on every upload) and `version/name` (shown to players).
   - The export paths name the template (`godot-tower-defense-debug.apk`); rename them after the game if the user likes.
4. **Icons.** The presets point at three placeholder layers in `assets/launcher/`, made from the app icon:
   - `adaptive_foreground.png` (432x432): the picture, kept inside the central 288x288 because launchers crop the rest into a circle, squircle or square.
   - `adaptive_background.png` (432x432): opaque; a flat color or soft pattern. Android 12+ also shows this layer behind the icon on the launch screen of a Gradle build, so pick a color that leads into the game's first screen.
   - `adaptive_monochrome.png` (432x432): a white shape on transparent, which Android 13+ recolors for themed icons.

   Replace all three with the user's art at exactly 432x432 (keep the file names), update their entries in `assets.json` (size, `use`, `license`, `credit`), and rerun `godot --headless --path . --import`. `main_192x192` stays empty: Godot falls back to `config/icon` (`assets/ui/icon.png`) for old launchers, so replace that too.
5. **Orientation and look.** The orientation comes from the project, not the preset: this game is landscape (the project doesn't set `display/window/handheld/orientation`, so it's the default, landscape), and it stays landscape when the phone's rotation is locked to portrait. `screen/immersive_mode=true` hides the status and navigation bars; set it to `false` if the user wants them. `screen/edge_to_edge=true` draws under the camera cutout too: the HUD, the map and the menus keep out of it themselves (`Game.safe_insets()`), so keep it on. The view fills the whole screen at any aspect ratio (`window/stretch/aspect="expand"` in `project.godot`): on a wide phone the HUD moves to a column at the right and the map grows into the rest. The first launch of an immersive app shows Android's "Viewing full screen" hint, and Android 12+ shows the icon on a plain launch screen before the game starts; neither is a bug.
6. **Permissions.** The game needs none. Keep every `permissions/*` in the presets `false` (no `INTERNET` either). If you add ads, sign-in or analytics, add only the permissions their documentation lists, and say so in the store's data-safety form. `user_data_backup/allow=false` keeps the save file out of Android's cloud backup; set it to `true` if the user wants progress restored on a new phone.
7. **Keep the data in the build.** `include_filter` in the preset names the files the game reads that aren't Godot resources: `*.json`, `*.txt`, `CREDITS.md` and `LICENSE.md` (this game's data: `content/`, the JSON files and the ASCII maps). `exclude_filter` keeps the project's `codeplate.json` (and a `package.json`, if the user adds one) out. Without the data the APK starts with no content. When you add a data file of a new type (say `.csv`), add it to `include_filter` of **every** preset. A check fails if a preset leaves one out.
8. **Export the debug APK** from this folder:
   ```
   godot --headless --path . --import
   godot --headless --path . --export-debug "Android" export/android/godot-tower-defense-debug.apk
   ```
   For an emulator on an Intel or AMD machine, export `"Android test APK"` to `export/android/godot-tower-defense-test.apk` instead. `export/` is git-ignored. The command prints `Signed` and ends with `[ DONE ] export`.
9. **Test it.**
   - **Phone:** enable Developer options and USB debugging, plug it in, then `adb install -r export/android/godot-tower-defense-debug.apk`.
   - **Emulator:** a Pixel image (`system-images;android-35;google_apis;x86_64` on Intel or AMD, the arm64 one on Apple silicon) with `-gpu host`. `avdmanager create avd` may print "Could not load devices from ... devices.xml"; the AVD it makes still works. Godot's Android export restarts the adb server, which drops the emulator's connection: run `adb wait-for-device` before `adb install`. A Pixel in landscape has its camera cutout on one side: check that the gold, the map and the pause button sit clear of it.
   - **Back and Home:** Back in a level opens the pause menu, Back again goes to the level select, Back on the title asks before leaving. Home mid-level and back again shows the pause menu.
   - **Driving it from a computer:** `adb shell input tap X Y` presses menus and map cells (in screen pixels). Each `adb` call can take a second or more (a `screencap` longer) and the battle keeps running in between, so play at 1x when timing matters. From Git Bash on Windows set `MSYS_NO_PATHCONV=1`, or paths like `/sdcard/shot.png` get rewritten.
   - Look at the title screen (touch wording, not key names), start a level, build a tower with two taps, and confirm the content is there ("0 LEVELS" means the data filter is wrong).
   - `adb logcat -s godot` shows the game's errors.

## What a Google Play release needs on top of this

The debug APK is for testing; Play doesn't take it. Go through this with the user, and re-check Google's current rules before submitting, because they change.

- **An Android App Bundle (.aab), not an APK.** That needs the Gradle build: add a third preset, "Android release", copied from "Android" with `gradle_build/use_gradle_build=true` and `gradle_build/export_format=1`, and Godot's Android build template in an `android/` folder. Godot's docs list the extra SDK packages the Gradle build needs. `gradle_build/min_sdk` and `gradle_build/target_sdk` only apply to Gradle builds; the debug APKs above report Godot's own defaults whatever the preset says.
- **Building it headless.** Project > Install Android Build Template is an editor menu. On the command line, `--install-android-build-template` only works together with an export. A Gradle daemon left running keeps Godot from exiting after `[ DONE ] export`, so switch the daemon off. Install the template fresh for each build and delete it afterwards: `android/` is git-ignored, and its XML and JSON files would fail the add-on's export-data check while they sit in the project. With the release keystore variables below set, in bash:
  ```
  export GRADLE_OPTS="-Dorg.gradle.daemon=false"
  rm -rf android
  godot --headless --path . --import
  godot --headless --path . --install-android-build-template --export-release "Android release" export/android/game.aab
  rm -rf android
  ```
  In PowerShell, set `$env:GRADLE_OPTS = "-Dorg.gradle.daemon=false"` and use `Remove-Item -Recurse -Force android` for the two `rm` lines. A release build takes a minute or two. Once it works, put these lines in a script in the project (say `tools/build_android.sh` or `.ps1`) so nobody types the keystore variables by hand. The script reads the password from the environment (on Windows, the user's environment variables) and never prints it.
- **Check what you built.** `jarsigner -verify -verbose -certs export/android/game.aab` shows the upload key's certificate, and `keytool -printcert -jarfile export/android/game.aab` prints its fingerprint for Play Console. To confirm the permissions and `targetSdkVersion`, read the merged manifest under `android/build/build/intermediates/merged_manifest/` before `android/` is deleted (skip the last `rm` once). Look for `<uses-permission` lines: the game asks for none. AndroidX's `ProfileInstallReceiver` carries `android:permission="android.permission.DUMP"`, which only says who may call that receiver; it is not a permission the game requests. The `bundletool` jar inside Gradle's cache can't be run on its own; download bundletool from Google to turn a bundle into APKs for a device.
- **A release (upload) keystore the user creates and guards.** Never commit it or its passwords. Give Godot the path, alias and passwords through the editor settings or the environment variables `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. Back it up somewhere private; Play App Signing holds the final signing key.
- **Target API 36** as of October 2026 (set `gradle_build/target_sdk` if Godot's default is lower), with arm64-v8a included.
- **The final package name** (not `com.example`), a `version/code` that rises with each upload, and, under the free license, the credit "Built with CodePlate (codeplate.io)" kept where players see it.
- **A logo before the title**, if the user wants their studio's: `splash_image` and `splash_text` in `config/game_config.tres` (`ui/splash.tscn` shows them; empty means straight to the title).
- **The store listing:** name, short and full description, icon (512x512), feature graphic (1024x500), screenshots, a privacy policy URL, the content rating and data-safety forms. The user does this in Play Console themselves (a developer account, one-time fee). Phone screenshots come from the screenshot tool: `screen=battle wave=4 touch=1 size=2400x1080`.

## Verify

1. Run the two check commands in `AGENTS.md`. The second must end with `CODEPLATE CHECKS: PASS`.
2. Export the debug APK (step 8), confirm the command exits 0 and the `.apk` exists.
3. If an Android device or emulator is available, install it and do step 9; otherwise tell the user the build is untested on a device.
4. Confirm `package/unique_name` is no longer `com.example.towerdefense` in either Android preset, and that `export_presets.cfg` holds no local paths or passwords.

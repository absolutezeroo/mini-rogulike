# Android build

Everything is ready in `export_presets.cfg` (preset **Android**): the app takes the game's name
(`config/name_localized`: "The Well of Souls", "Le Puits des Âmes" on a French phone), package
`com.absolutezeroo.puitsdesames`, version 0.2.0 (code 2), arm64-v8a, landscape, immersive, the
Vibrate permission, no Gradle build needed. Tests and tools are left out (`exclude_filter`). The
icon is adaptive (`assets/icon/`: the hero over the well's glow and its souls, plus a monochrome
version for themed icons); the splash shows it on the night color.
Saves stay in the user folder named "Mini Roguelike" (`config/custom_user_dir_name`), the project's first name: don't
change it, or players lose their saves.

- **From the phone** (Godot's Android editor): Project > Export > Android > Export Project. The
  editor signs debug builds with its own key. Debug builds show the DBG button; a release build
  hides it.
- **From a computer**: install the Android export templates (Editor > Manage Export Templates)
  and set the Java and Android SDK paths in Editor Settings > Export > Android (only the SDK's
  build-tools are needed: `apksigner`); then
  `godot --headless --export-debug "Android" build/le-puits-des-ames.apk` (or `--export-release`).
- **Release**: make your own key once and keep it safe (every update must be signed with it):
  `keytool -genkeypair -v -keystore puits-release.keystore -alias puits -keyalg RSA -keysize 2048
  -validity 10000`. Never put it, or its password, in git: give it to Godot through the
  environment (`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `..._USER`, `..._PASSWORD`) or the preset's
  fields on your own machine only.
- **Play Store** (preset **Android Play Store**): the same app as an AAB, built with Gradle. Install
  the Android build template once (Project > Install Android Build Template; the `android/` folder
  it makes is not in git), then `godot --headless --export-release "Android Play Store"
  build/le-puits-des-ames.aab`. Raise `version/code` (and `version/name`) for each upload.
- **Privacy policy**: `docs/privacy.html` (the game sends nothing anywhere; saves stay on the
  phone). With GitHub Pages on (Settings > Pages > branch `main`, folder `/docs`) it is at
  `https://absolutezeroo.github.io/mini-rogulike/privacy.html`, the link the Play Console asks for.

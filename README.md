# Scanine app icon: wordmark

The "scanine" wordmark from the splash screen, navy #1F3864 on cloud #EEF1F6, inside the 66 dp adaptive-icon safe zone.

## Option A: flutter_launcher_icons (easiest)
1. Copy `flutter/assets/icon/` into your project's `assets/icon/` and declare it in pubspec.yaml under `flutter: assets:` if you also show it in-app (not needed for the launcher icon).
2. Add to pubspec.yaml:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.1

flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/icon.png"
  min_sdk_android: 21
  adaptive_icon_background: "#EEF1F6"
  adaptive_icon_foreground: "assets/icon/foreground.png"
  adaptive_icon_monochrome: "assets/icon/monochrome.png"
```
3. Run:
```
flutter pub get
dart run flutter_launcher_icons
```

## Option B: drop-in Android resources
Copy `android/res/` over `android/app/src/main/res/`. In `AndroidManifest.xml` the application tag should have
`android:icon="@mipmap/ic_launcher"` and `android:roundIcon="@mipmap/ic_launcher_round"`.

## Play Store
`play-store/ic_launcher-playstore-512.png` is the 512 x 512 listing icon (full bleed, no transparency; the store applies its own mask).

## Files
- `android/res/mipmap-*/ic_launcher.png`, `ic_launcher_round.png`: legacy icons (48, 72, 96, 144, 192 px).
- `android/res/mipmap-*/ic_launcher_foreground.png`, `ic_launcher_monochrome.png`: adaptive layers (108 dp: 108, 162, 216, 324, 432 px).
- `android/res/mipmap-anydpi-v26/*.xml`, `values/ic_launcher_background.xml`: adaptive icon definition and background colour.
- `svg/`: editable sources.

# Scanine — Flutter demo build

Screens only. **No model, no classification.** The result is canned so the
flow can be demonstrated end to end. This is Phase 3 of the migration plan;
Phase 0 (model conversion) is deliberately skipped for now.

What works for real: the camera opens, five frames are genuinely captured,
and the last one appears on the result screen.

---

## 1. Install Flutter (budget the most time here)

The SDK install is the part most likely to eat your evening, not the code.

1. Install the Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. In VS Code: Extensions → install **Flutter** (it pulls in Dart automatically)
3. Run this and clear every Android issue it lists:

```
flutter doctor
```

If it complains about Android licences:

```
flutter doctor --android-licenses
```

Accept all of them. This one blocks the build with an unhelpful error if skipped.

## 2. Create the project

```
flutter create --org com.scanine --platforms=android scanine_app
cd scanine_app
```

## 3. Drop these files in

Replace the generated `lib/` folder with the `lib/` folder from this bundle.
You should end up with:

```
lib/
  main.dart
  models/screening_result.dart
  screens/home_screen.dart
  screens/camera_screen.dart
  screens/analyzing_screen.dart
  screens/result_screen.dart
  theme/tokens.dart
```

## 4. Add the camera dependency

```
flutter pub add camera
```

That is the only package needed. Deliberately minimal — every extra
dependency is another thing that can fail to resolve tonight.

## 5. Android config

Open `android/app/build.gradle` (or `build.gradle.kts`) and make sure the
minimum SDK is at least 21:

```
minSdkVersion 21
```

The `camera` plugin declares the CAMERA permission itself, so the manifest
usually needs no edit. If the camera fails to open on device, add this to
`android/app/src/main/AndroidManifest.xml` above `<application>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

## 6. Run it

Plug in your phone with USB debugging on, then:

```
flutter devices     # confirm the phone is listed
flutter run
```

**Use a real phone, not the emulator.** The emulator's fake camera will
make you doubt working code.

---

## The demo path

Home → **Start screening** → camera opens → tap the shutter five times →
analysing animation → result screen. On the result screen, tap the small
(!) next to the timestamp to show the FAD / Hotspot disclosure sheet.

Total run time about 30 seconds. Practise it once before you present.

---

## What to say tomorrow

Be straight about the state, because someone will ask.

> The UI is fully ported to Flutter and running natively on Android. The
> camera pipeline is live — it captures real frames. Classification is
> still stubbed while we convert the model from TensorFlow.js to TFLite,
> which is the next step. We also found a preprocessing bug in the current
> training notebook that we're fixing as part of that work.

That last sentence turns a gap into evidence of real engineering.

Do **not** let anyone believe the canned "Ringworm 95%" is a live
prediction. It is hardcoded in `models/screening_result.dart` under
`ScreeningResult.demo()`.

---

## When you wire the model in

Only one function changes: `ScreeningResult.demo()` in
`lib/models/screening_result.dart`. The guidance table, the urgency
routing and every screen stay exactly as they are.

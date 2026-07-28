# Platform setup

Kabootar commits its full **Android** native shell (`android/`: Gradle wrapper,
`build.gradle.kts`, `MainActivity`, manifests, launcher icons) so the app builds
straight from a clean clone, with no `flutter create` step and no drift. For
**iOS**, only `ios/Runner/Info.plist` is committed (the local-network and
Bluetooth usage strings plus the Bonjour service Multipeer needs); the rest of
the Xcode project is generated once, locally.

The app id is `dev.studchat.studchat` (kept from the project's original name so
existing installs upgrade in place); the Flutter org is therefore `dev.studchat`.

## Android: build from a clean clone

With [Flutter](https://docs.flutter.dev/get-started/install) installed, from the
repo root:

```bash
flutter pub get
dart run flutter_launcher_icons          # generate the launcher icon
bash tool/patch_nearby_plugin.sh         # modernise the legacy mesh plugin
bash tool/patch_gradle.sh                # enable core-library desugaring (notifications)
flutter build apk --release --split-per-abi
```

Both patch scripts are idempotent, so re-running them is safe. This is exactly
what CI does in `.github/workflows/build-apk.yml`.

## iOS: one-time bootstrap

`Info.plist` is committed, but the Xcode project shell is not. Generate it once
(this fills in the shell **without overwriting** the committed `Info.plist`):

```bash
flutter create . --platforms=ios --org dev.studchat
cd ios && pod install
```

## Minimum platform versions

`flutter_nearby_connections` requires:

| Platform | Minimum |
| -------- | ------- |
| Android  | `minSdk 21` |
| iOS      | `12.0` |

Android is already set in the committed `android/app/build.gradle.kts`
(`minSdk = flutter.minSdkVersion`, which meets 21), so there is nothing to change
there. For iOS, set `platform :ios, '12.0'` in `ios/Podfile` before
`pod install`.

## Run it

```bash
flutter run                 # on a connected device
```

The mesh needs **two physical devices on the same OS family** to demonstrate
delivery (Android to Android, or iOS to iOS; see the README on the cross-platform
wall). Emulators have no real Bluetooth/Wi-Fi radios, so peer discovery will not
work on them.

## Verify the routing logic without a device

The store-and-forward engine is framework-free and fully covered by a
dependency-free harness that needs only the Dart SDK:

```bash
dart run tool/engine_check.dart
```

See [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) for what it proves.

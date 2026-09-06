# Tayo Mobile

Flutter client for the Tayo family-management app. The backend API lives in
`../tayo-api` in the parent workspace.

## Current Scope

- Registration, login, logout against the Laravel Sanctum API
- Household creation, listing, and viewing
- Household member listing
- Auth-aware routing (splash → login/register → create-household → home)

See [docs/DECISIONS.md](docs/DECISIONS.md) for the architecture decisions
behind these features and the constraints that follow from them.

## Requirements

- Flutter SDK (`^3.13.2` per `pubspec.yaml`)
- Android SDK + platform-tools (device or emulator), and/or Xcode for iOS
- A running `tayo-api` instance to talk to (see that project's README)

## Local Setup

From this directory:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

The API base URL defaults to `http://127.0.0.1:8000/api/v1` (see
`lib/core/config/env.dart`). Override it per target:

- **Physical device / wireless debugging** — use your machine's LAN IP
  instead of `127.0.0.1`, e.g. `--dart-define=API_BASE_URL=http://192.168.x.x:8000/api/v1`
- **Android emulator** — use `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`
  (the emulator's loopback alias for the host machine)

### Running on a physical Android device over Wi-Fi

With the device connected via USB first:

```bash
adb tcpip 5555
adb connect <device-ip>:5555
flutter run -d <device-ip>:5555
```

You can then unplug the USB cable. Note that some OEM power-saving settings
(e.g. MIUI) suspend Wi-Fi when the screen locks, which drops the ADB
connection — just reconnect and re-run if that happens.

## Project Structure

```
lib/
  core/        # config, networking (ApiClient/Dio), routing, storage, theme
  features/    # auth, households, members, home — each split into
               # data/domain/presentation
  shared/      # cross-feature models, widgets, components
```

See [docs/DECISIONS.md](docs/DECISIONS.md) ADR-007 for the rationale behind
this layering.

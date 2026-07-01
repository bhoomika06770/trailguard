# TrailGuard — Build & Installation Guide

## Prerequisites

### 1. Install Flutter SDK

```bash
# Download Flutter (Linux/macOS)
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor
```

Windows: Download from https://docs.flutter.dev/get-started/install/windows

### 2. Android SDK

Install Android Studio (recommended) or standalone Android SDK:
- Minimum API: 26 (Android 8.0)
- Target API: 34 (Android 14)
- Build tools: 34.0.0

### 3. Java (JDK 17+)

```bash
sudo apt install openjdk-17-jdk    # Linux
brew install openjdk@17             # macOS
```

---

## Project Setup

```bash
# 1. Extract the project
unzip trailguard_complete.zip
cd trailguard

# 2. Get Flutter dependencies
flutter pub get

# 3. Verify no issues
flutter analyze
```

---

## Build APK

### Debug Build (for testing)
```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### Release Build (for distribution)
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Split by ABI (smaller APK per device architecture)
```bash
flutter build apk --split-per-abi --release
# Produces:
#   app-armeabi-v7a-release.apk   (32-bit ARM)
#   app-arm64-v8a-release.apk     (64-bit ARM — most modern phones)
#   app-x86_64-release.apk        (emulator/x86)
```

### App Bundle (for Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## Install on Android Device

### Via ADB (USB debugging)
```bash
# Enable USB debugging on phone:
# Settings → About Phone → tap Build Number 7x → Developer Options → USB Debugging

# Connect phone, then:
adb devices                    # confirm device is listed
adb install app-release.apk   # install
adb shell am start -n com.trailguard.app/.MainActivity  # launch
```

### Via File Transfer
1. Copy `app-release.apk` to phone storage
2. Open Files app → navigate to APK
3. Tap to install
4. Allow "Install from unknown sources" if prompted

---

## Signing for Release

Create a keystore (one-time):
```bash
keytool -genkey -v \
  -keystore trailguard-release.jks \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias trailguard
```

Create `android/key.properties`:
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=trailguard
storeFile=../trailguard-release.jks
```

Update `android/app/build.gradle` to reference the keystore, then:
```bash
flutter build apk --release
```

---

## Permissions Granted on First Launch

TrailGuard will request:
1. **Location (Precise)** — tap "While using app" or "Always"
2. **Background Location** — required for tracking while screen off
3. **Notifications** — for safety alerts

> **Important:** Grant "Allow all the time" for background location. Without it, tracking stops when the screen locks.

---

## Offline Map Tiles Setup

For fully offline maps (no internet at all), pre-download tiles:

### Option A: MBTiles file
1. Download an MBTiles file for your region from:
   - https://download.geofabrik.de (OpenStreetMap extracts)
   - https://openmaptiles.org/docs/
2. Copy to device: `adb push region.mbtiles /sdcard/trailguard/maps/`
3. Update `map_screen.dart` tile provider to read local MBTiles

### Option B: flutter_map_tile_caching (built-in)
The app uses online OSM tiles by default but caches them for offline use:
```dart
// In map_screen.dart, replace TileLayer with:
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  tileProvider: FMTCStore('mapStore').getTileProvider(),
)
```
Then use the FMTC package to pre-cache a region before hiking.

---

## ML Model Update

After retraining (see ml_training/train_model.py):

```bash
# Copy updated weights
cp ml_training/lr_weights.json assets/models/lr_weights.json

# Rebuild app
flutter build apk --release
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `flutter: command not found` | Add Flutter to PATH |
| `JAVA_HOME not set` | Set JDK 17 path |
| Build fails with Gradle error | Run `flutter clean && flutter pub get` |
| GPS not working on emulator | Use a physical device or enable emulator location |
| Background tracking stops | Grant "Allow all the time" location permission |
| Map shows blank tiles | Check internet connection for first tile download |
| `MissingPluginException` | Run `flutter clean` and rebuild |

---

## Minimum Device Requirements

| Requirement | Minimum |
|-------------|---------|
| Android Version | 8.0 (API 26) |
| RAM | 2 GB |
| Storage | 100 MB (app) + map tiles |
| GPS | Required |
| Processor | ARMv7 or ARM64 |

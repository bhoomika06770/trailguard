# TrailGuard
### Offline Intelligent Hiker Safety System

> *"Is the hiker moving safely, confidently — and if not, how can they recover?"*

TrailGuard is a production-quality Android application that operates **completely offline** and helps hikers navigate safely using GPS-based behavioral analysis, terrain awareness, and on-device machine learning.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│              TrailGuard Android App              │
├──────────────┬──────────────────────────────────┤
│  UI Layer    │  Dashboard · Map · Analytics     │
│  (Flutter)   │  Sessions · Emergency            │
├──────────────┼──────────────────────────────────┤
│  Service     │  GpsTrackingService              │
│  Layer       │  HikingSessionService            │
│              │  AlertService                    │
├──────────────┼──────────────────────────────────┤
│  ML Layer    │  FeatureExtractor (9 features)   │
│              │  MLInferenceEngine (LR model)    │
├──────────────┼──────────────────────────────────┤
│  Data Layer  │  SQLite (DatabaseHelper)         │
│              │  lr_weights.json (model bundle)  │
└──────────────┴──────────────────────────────────┘
```

---

## Modules

| # | Module | Description |
|---|--------|-------------|
| 1 | GPS Tracking Engine | Background GPS via Geolocator |
| 2 | Offline Map System | flutter_map + OpenStreetMap tiles |
| 3 | Trajectory Storage | SQLite persistence |
| 4 | Behavioral Feature Extraction | 9 features computed in real-time |
| 5 | Terrain Awareness | Slope & elevation from GPS altitude |
| 6 | Navigation Confidence Engine | 0–100 score, 3 risk bands |
| 7 | ML Disorientation Detection | Logistic Regression (98.5% acc) |
| 8 | Alert System | Push notifications + vibration |
| 9 | Safe Route Recovery | Reverse trajectory replay |
| 10 | Stable Zone Detection | Auto-detected safe zones |
| 11 | Emergency Assistance | SOS, report generation |
| 12 | Dashboard UI | Live GPS + behavioral indicators |
| 13 | Analytics & Visualization | fl_chart time-series charts |
| 14 | Local Database | SQLite with 6 tables |
| 15 | ML Training Pipeline | Python scikit-learn scripts |

---

## Features

- **Fully offline** — no internet needed during hikes
- **Real-time behavioral analysis** — 9 ML features extracted from GPS
- **On-device ML** — logistic regression with bundled weights
- **Confidence Score** — 0–100 navigation confidence gauge
- **Reverse trajectory recovery** — guides hiker back to last safe point
- **Safe zone detection** — automatically marks stable trail sections
- **Emergency SOS** — generates rescue report with last known coordinates
- **Analytics** — confidence, speed, elevation, risk trend charts
- **Dark map mode** — OpenStreetMap with dark color filter

---

## Installation

### Prerequisites

- Flutter SDK 3.0+
- Android Studio / VS Code
- Android device or emulator (API 26+)

### Steps

```bash
# Clone repository
git clone https://github.com/yourname/trailguard.git
cd trailguard

# Install dependencies
flutter pub get

# Build APK
flutter build apk --release

# APK location
build/app/outputs/flutter-apk/app-release.apk
```

### Debug Build (Faster)
```bash
flutter run --debug
```

### Install on Device
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## ML Training Pipeline

To retrain the model with your own data:

```bash
cd ml_training

# Install Python dependencies
pip install pandas numpy scikit-learn matplotlib seaborn

# Train with default 3000 synthetic samples
python train_model.py

# Train with plots
python train_model.py --plots

# Custom sample count + output path
python train_model.py --samples 10000 --output ../assets/models/lr_weights.json
```

### Model Performance (Synthetic Dataset)
| Metric | Logistic Regression | Random Forest |
|--------|---------------------|---------------|
| Accuracy | **98.5%** | 97.7% |
| F1 Score | **98.5%** | 97.7% |
| CV F1 (5-fold) | **98.4% ± 0.5%** | 97.7% ± 0.6% |

---

## Database Schema

### sessions
| Column | Type | Description |
|--------|------|-------------|
| id | TEXT PK | UUID |
| name | TEXT | Session label |
| start_time | INTEGER | Unix ms |
| end_time | INTEGER | Unix ms |
| dest_lat / dest_lon | REAL | Optional destination |
| total_distance | REAL | Meters |
| is_active | INTEGER | 1 = active |
| emergency_triggered | INTEGER | 1 = SOS used |

### gps_points
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto |
| session_id | TEXT FK | → sessions |
| latitude / longitude | REAL | WGS84 |
| altitude | REAL | Meters |
| speed | REAL | m/s |
| bearing | REAL | Degrees 0–360 |
| accuracy | REAL | Meters |
| timestamp | INTEGER | Unix ms |

### features
| Column | Type | Description |
|--------|------|-------------|
| direction_variance | REAL | 0–1 |
| backtracking_ratio | REAL | 0–1 |
| path_efficiency | REAL | 0–1 |
| loop_score | REAL | 0–1 |
| movement_entropy | REAL | 0–1 |
| speed_stability | REAL | 0–1 |
| stop_frequency | REAL | 0–1 |
| elevation_change | REAL | meters |
| terrain_slope | REAL | degrees |

### predictions
| Column | Type | Description |
|--------|------|-------------|
| disorientation_probability | REAL | 0.0–1.0 |
| confidence_score | INTEGER | 0–100 |
| risk_level | TEXT | SAFE/CAUTION/DISORIENTED |

---

## Behavioral Features

| Feature | Formula | Interpretation |
|---------|---------|----------------|
| Direction Variance | Circular variance of bearings | High = chaotic direction changes |
| Backtracking Ratio | Reversals / total steps | High = frequent U-turns |
| Path Efficiency | Straight-line / actual distance | Low = wandering |
| Loop Score | Repeated path visits | High = circular movement |
| Movement Entropy | Shannon entropy of bearing sectors | High = random movement |
| Speed Stability | Inverse of speed coefficient of variation | Low = erratic speed |
| Stop Frequency | Stops per unit time | High = abnormal pausing |
| Elevation Change | Total altitude delta | Terrain difficulty |
| Terrain Slope | Avg slope in degrees | Route difficulty |

---

## Risk Classification

| Confidence Score | Risk Level | Action |
|-----------------|------------|--------|
| 61–100 | 🟢 SAFE | Normal hiking |
| 31–60 | 🟡 CAUTION | Increase awareness |
| 0–30 | 🔴 HIGH RISK | Alert + recovery route |

Disorientation threshold: **70% probability**

---

## Project Structure

```
trailguard/
├── lib/
│   ├── main.dart                          # App entry + navigation
│   ├── core/
│   │   ├── constants/app_constants.dart   # All thresholds & config
│   │   ├── database/database_helper.dart  # SQLite CRUD
│   │   ├── models/                        # Data models
│   │   │   ├── gps_point.dart
│   │   │   ├── hiking_session.dart
│   │   │   ├── behavioral_features.dart
│   │   │   ├── safety_prediction.dart
│   │   │   └── safe_zone.dart
│   │   └── services/
│   │       ├── gps_tracking_service.dart  # Module 1
│   │       ├── feature_extractor.dart     # Modules 4 & 5
│   │       ├── hiking_session_service.dart # Orchestrator
│   │       └── alert_service.dart         # Module 8
│   ├── ml/
│   │   └── ml_inference_engine.dart       # Modules 6 & 7
│   └── features/
│       ├── dashboard/dashboard_screen.dart  # Module 12
│       ├── map/map_screen.dart              # Module 2
│       ├── analytics/analytics_screen.dart  # Module 13
│       ├── sessions/                        # History
│       └── emergency/emergency_screen.dart  # Module 11
├── assets/
│   └── models/lr_weights.json             # Bundled ML weights
├── ml_training/
│   └── train_model.py                     # Module 15
├── android/app/src/main/
│   └── AndroidManifest.xml                # All permissions
└── pubspec.yaml                           # Dependencies
```

---

## Permissions Required

| Permission | Purpose |
|------------|---------|
| ACCESS_FINE_LOCATION | GPS tracking |
| ACCESS_BACKGROUND_LOCATION | Background tracking while screen off |
| FOREGROUND_SERVICE | GPS background service |
| WAKE_LOCK | Prevent CPU sleep during hiking |
| VIBRATE | Alert vibration |
| POST_NOTIFICATIONS | Alert push notifications |
| SEND_SMS | Emergency SMS (when network available) |

---

## Research Contribution

This project shifts the paradigm of hiking apps from passive navigation to **active behavioral safety monitoring**:

1. **GPS Trajectory Feature Engineering** — 9 features engineered from raw GPS streams
2. **Real-Time Disorientation Detection** — ML inference every 10 seconds
3. **Terrain-Aware Analysis** — terrain slope modulates sensitivity
4. **Navigation Confidence Estimation** — composite weighted scoring
5. **Reverse Trajectory Recovery** — reverse replay of safe trail segments
6. **Fully Offline ML Deployment** — bundled weights, zero cloud dependency

---

*TrailGuard — Final Year Engineering Major Project*

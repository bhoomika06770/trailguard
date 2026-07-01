# TrailGuard User Manual

## Overview

TrailGuard is your intelligent offline hiking companion. It monitors your movement patterns in real time and warns you if it detects signs of disorientation — even without any internet connection.

---

## Getting Started

### First Launch

When you open TrailGuard for the first time:

1. Tap **Allow** when asked for location permission
2. Select **Allow all the time** for background location (required for trail tracking)
3. Tap **Allow** for notifications (required for safety alerts)

---

## Screen Guide

### 📊 Dashboard (Home)

The main screen shows everything at a glance.

**Status Banner (top)**
- 🟢 **SAFE** — You are moving confidently on trail
- 🟡 **CAUTION** — Movement patterns suggest reduced confidence
- 🔴 **DISORIENTED** — Possible disorientation detected

**Navigation Confidence Score**
- The circular gauge (0–100) shows your current confidence score
- Higher = safer movement
- Below 30: High risk zone
- 30–60: Moderate risk
- 60+: Stable navigation

**GPS Status**
Shows live latitude, longitude, altitude, speed, bearing, and GPS accuracy.

**Behavioral Analysis**
Six bars show the real-time state of your movement:
- **Path Efficiency** — Are you taking a direct route? (high = good)
- **Direction Stability** — Consistent bearing? (high = good)
- **Speed Stability** — Consistent pace? (high = good)
- **Backtracking** — Reversing frequently? (low = good)
- **Loop Detection** — Revisiting areas? (low = good)
- **Movement Entropy** — Random direction changes? (low = good)

**Start/Stop Hike Buttons**

---

### 🗺️ Map Screen

Shows your real-time position on an offline OpenStreetMap.

**Elements on the map:**
- **Glowing dot** — Your current location (color matches risk level)
- **Green line** — Your GPS breadcrumb trail
- **Green circles** — Detected safe zones
- **Dashed orange line** — Recovery route (appears when disoriented)

**Controls:**
- **GPS icon (top right)** — Toggle follow-me mode
- **Undo icon** — Manually activate recovery route
- Pinch to zoom, drag to scroll

**Recovery Route Banner**
When disorientation is detected, an orange banner appears at the top with instructions. Follow the dashed orange line back to your last safe zone.

---

### 📈 Analytics Screen

Four chart tabs showing your hike data:

| Tab | What it shows |
|-----|--------------|
| **Confidence** | Navigation confidence score over time |
| **Speed** | Walking/hiking speed in km/h |
| **Elevation** | Altitude profile of your route |
| **Risk Trend** | Disorientation probability % over time |

Dashed lines show risk thresholds:
- Red dashed line = 70% threshold (alert zone)
- Orange dashed line = 45% threshold (caution zone)

---

### 📋 Sessions Screen

Browse all your past and current hike sessions.

Each card shows:
- Hike name and date
- Duration
- Total distance (km)
- Whether a destination waypoint was set
- Emergency icon (🚨) if SOS was triggered

---

### 🆘 Emergency Screen

Use this screen if you are lost or in danger.

**SOS Button (large red button)**
Tap to activate Emergency Mode. This:
- Records your last known GPS coordinates
- Saves the emergency event to the local database
- Displays a confirmation

**Last Known Location**
Shows your most recent GPS fix — share this with rescuers.

**Generate & Copy Report**
Generates a full emergency report including:
- Last known coordinates
- Timestamp
- Last 20 trail points
- Session summary

The report is copied to your clipboard so you can paste it into any messaging app when connectivity becomes available.

**If You Are Lost — STOP Method**
1. **STOP** — Stay calm, do not keep wandering
2. **THINK** — Review where you last were safe
3. **OBSERVE** — Look for landmarks around you
4. **PLAN** — Follow the Map screen's recovery route

---

## Starting a Hike

1. Open the **Dashboard** screen
2. Tap **Start Hike**
3. Enter a name for your hike (or keep the default)
4. Optionally toggle **Set Destination Waypoint** and enter coordinates
5. Tap **Start Hike**

The app immediately begins GPS tracking and behavioral analysis. Keep the app running (screen can be off).

---

## Ending a Hike

1. Return to **Dashboard**
2. Tap **End Hike**
3. Your session is saved to history automatically

---

## Understanding Alerts

### 🟡 Caution Notification
> *"Movement patterns suggest reduced navigation confidence"*

This means your disorientation probability has exceeded 45%. Review your path on the Map screen and check the recovery route.

### 🔴 Disorientation Alert
> *"Possible Disorientation Detected — Confidence: XX%"*

Your disorientation probability exceeded 70%. The app will:
- Send a push notification with vibration
- Display the recovery route on the map
- Update the status banner to RED

### 🆘 Emergency Mode (Auto-Activated)
If disorientation persists for **10 minutes**, the app automatically activates Emergency Mode and saves your location.

---

## Offline Operation

TrailGuard works completely without internet. However:

- **Map tiles** — Tiles load from cache. For new areas, connect to WiFi before hiking to pre-load tiles, then hike offline.
- **GPS** — Works without internet (uses satellite signals only)
- **ML analysis** — Runs entirely on-device
- **Emergency SMS** — Queued and sent automatically when connectivity returns

---

## Battery Tips

- GPS is battery-intensive. Carry a power bank for long hikes.
- TrailGuard samples GPS every 5 seconds — this is battery-efficient.
- Reduce screen brightness while hiking.
- Use "Battery saver" GPS mode only if battery is critical (reduces accuracy).

---

## Privacy

All your data stays on your device. TrailGuard:
- Never uploads GPS data to any server
- Never requires an account or login
- Stores all data in a local SQLite database
- Only sends emergency SMS if you explicitly activate SOS and have network

---

## Frequently Asked Questions

**Q: Why does TrailGuard need background location?**
A: GPS tracking must continue when the screen turns off. Without background location, the trail stops recording as soon as you lock the phone.

**Q: Does TrailGuard work without any internet?**
A: Yes, completely. GPS, ML analysis, and all features work offline. Map tiles may be cached from a prior connection.

**Q: How accurate is the disorientation detection?**
A: The ML model achieves ~98.5% accuracy on test data. In practice, it is calibrated to minimize false alerts on flat urban terrain while remaining sensitive on mountain trails.

**Q: Can I set a destination for navigation?**
A: Yes. When starting a hike, toggle "Set Destination Waypoint" and enter GPS coordinates. The app will track your progress toward that point as a behavioral feature.

**Q: What happens to my data if I uninstall the app?**
A: All session history is deleted with the app. Export emergency reports before uninstalling if you need to keep them.

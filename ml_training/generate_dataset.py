"""
TrailGuard Dataset Generator
=============================
Generates a realistic labelled CSV dataset from simulated GPS hike trajectories.
Unlike the purely statistical generator in train_model.py, this script
simulates actual GPS coordinate streams and runs the same feature extraction
logic used in the app — ensuring training data matches production behaviour.

Output: trailguard_dataset.csv

Usage:
    python generate_dataset.py
    python generate_dataset.py --hikes 200 --output my_dataset.csv
"""

import argparse
import math
import random
import numpy as np
import pandas as pd
from dataclasses import dataclass, field
from typing import List, Optional

# ──────────────────────────────────────────────────────────────
# GPS Point
# ──────────────────────────────────────────────────────────────
@dataclass
class GpsPoint:
    lat: float
    lon: float
    altitude: float
    speed: float          # m/s
    bearing: float        # 0–360
    timestamp: float      # seconds since start

    def distance_to(self, other: 'GpsPoint') -> float:
        R = 6371000.0
        lat1, lat2 = math.radians(self.lat), math.radians(other.lat)
        dlat = math.radians(other.lat - self.lat)
        dlon = math.radians(other.lon - self.lon)
        a = math.sin(dlat/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin(dlon/2)**2
        return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

    def bearing_to(self, other: 'GpsPoint') -> float:
        lat1, lat2 = math.radians(self.lat), math.radians(other.lat)
        dlon = math.radians(other.lon - self.lon)
        y = math.sin(dlon) * math.cos(lat2)
        x = math.cos(lat1)*math.sin(lat2) - math.sin(lat1)*math.cos(lat2)*math.cos(dlon)
        return (math.degrees(math.atan2(y, x)) + 360) % 360


# ──────────────────────────────────────────────────────────────
# Trajectory Simulators
# ──────────────────────────────────────────────────────────────

def _meters_to_deg_lat(m: float) -> float:
    return m / 111320.0

def _meters_to_deg_lon(m: float, lat: float) -> float:
    return m / (111320.0 * math.cos(math.radians(lat)))

def simulate_safe_hike(rng: random.Random, n_pts: int = 40) -> List[GpsPoint]:
    """Confident hiker on a defined trail: consistent speed, few direction changes."""
    lat, lon = rng.uniform(10.0, 25.0), rng.uniform(70.0, 85.0)
    alt = rng.uniform(300, 2000)
    base_bearing = rng.uniform(0, 360)
    pts = []
    t = 0.0
    for _ in range(n_pts):
        # Slight bearing wobble
        bearing = (base_bearing + rng.gauss(0, 8)) % 360
        speed = rng.gauss(1.3, 0.15)  # ~4.7 km/h with small variance
        dist = speed * 5.0  # 5-second sample
        rad = math.radians(bearing)
        dlat = _meters_to_deg_lat(dist * math.cos(rad))
        dlon = _meters_to_deg_lon(dist * math.sin(rad), lat)
        lat += dlat
        lon += dlon
        alt += rng.gauss(1.5, 2.0)
        pts.append(GpsPoint(lat, lon, alt, max(0.0, speed), bearing, t))
        t += 5.0
    return pts

def simulate_disoriented_hike(rng: random.Random, n_pts: int = 40) -> List[GpsPoint]:
    """Lost hiker: erratic directions, loops, frequent stops, low path efficiency."""
    lat, lon = rng.uniform(10.0, 25.0), rng.uniform(70.0, 85.0)
    alt = rng.uniform(400, 2200)
    pts = []
    t = 0.0
    prev_bearing = rng.uniform(0, 360)
    for i in range(n_pts):
        # Large random bearing shifts, frequent reversals
        if rng.random() < 0.35:
            bearing = (prev_bearing + 180 + rng.uniform(-30, 30)) % 360
        else:
            bearing = rng.uniform(0, 360)
        speed = 0.0 if rng.random() < 0.25 else rng.gauss(0.7, 0.4)
        speed = max(0.0, speed)
        dist = speed * 5.0
        rad = math.radians(bearing)
        dlat = _meters_to_deg_lat(dist * math.cos(rad))
        dlon = _meters_to_deg_lon(dist * math.sin(rad), lat)
        # Occasionally revisit recent spots (loop behaviour)
        if i > 8 and rng.random() < 0.3 and pts:
            target = pts[max(0, i - rng.randint(3, 8))]
            lat, lon = target.lat + rng.gauss(0, 0.00005), target.lon + rng.gauss(0, 0.00005)
        else:
            lat += dlat
            lon += dlon
        alt += rng.gauss(0, 8.0)  # erratic altitude
        pts.append(GpsPoint(lat, lon, max(0, alt), speed, bearing, t))
        prev_bearing = bearing
        t += 5.0
    return pts

def simulate_caution_hike(rng: random.Random, n_pts: int = 40) -> List[GpsPoint]:
    """Hiker uncertain about route: moderate direction changes, occasional stops."""
    lat, lon = rng.uniform(10.0, 25.0), rng.uniform(70.0, 85.0)
    alt = rng.uniform(250, 1800)
    base_bearing = rng.uniform(0, 360)
    pts = []
    t = 0.0
    for i in range(n_pts):
        if rng.random() < 0.20:
            bearing = (base_bearing + rng.gauss(180, 40)) % 360
        else:
            bearing = (base_bearing + rng.gauss(0, 35)) % 360
        speed = 0.0 if rng.random() < 0.15 else rng.gauss(1.0, 0.35)
        speed = max(0.0, speed)
        dist = speed * 5.0
        rad = math.radians(bearing)
        dlat = _meters_to_deg_lat(dist * math.cos(rad))
        dlon = _meters_to_deg_lon(dist * math.sin(rad), lat)
        lat += dlat
        lon += dlon
        alt += rng.gauss(2.5, 5.0)
        pts.append(GpsPoint(lat, lon, max(0, alt), speed, bearing, t))
        t += 5.0
    return pts


# ──────────────────────────────────────────────────────────────
# Feature Extraction (mirrors Dart FeatureExtractor)
# ──────────────────────────────────────────────────────────────

def _angle_diff(a: float, b: float) -> float:
    d = abs(b - a) % 360
    return 360 - d if d > 180 else d

def direction_variance(pts: List[GpsPoint]) -> float:
    if len(pts) < 3:
        return 0.0
    bearings = [pts[i-1].bearing_to(pts[i]) for i in range(1, len(pts))]
    sin_s = sum(math.sin(math.radians(b)) for b in bearings)
    cos_s = sum(math.cos(math.radians(b)) for b in bearings)
    R = math.sqrt(sin_s**2 + cos_s**2) / len(bearings)
    return float(np.clip(1 - R, 0, 1))

def backtracking_ratio(pts: List[GpsPoint]) -> float:
    if len(pts) < 3:
        return 0.0
    count = 0
    for i in range(2, len(pts)):
        b1 = pts[i-2].bearing_to(pts[i-1])
        b2 = pts[i-1].bearing_to(pts[i])
        if _angle_diff(b1, b2) > 150:
            count += 1
    return float(np.clip(count / (len(pts) - 2), 0, 1))

def path_efficiency(pts: List[GpsPoint]) -> float:
    if len(pts) < 2:
        return 1.0
    straight = pts[0].distance_to(pts[-1])
    actual = sum(pts[i-1].distance_to(pts[i]) for i in range(1, len(pts)))
    return float(np.clip(straight / actual if actual > 0 else 1.0, 0, 1))

def loop_score(pts: List[GpsPoint], radius: float = 30.0) -> float:
    if len(pts) < 5:
        return 0.0
    half = len(pts) // 2
    loop_count = 0
    for i in range(half, len(pts)):
        for j in range(0, i - 3):
            if pts[i].distance_to(pts[j]) < radius:
                loop_count += 1
                break
    return float(np.clip(loop_count / (len(pts) - half), 0, 1))

def movement_entropy(pts: List[GpsPoint]) -> float:
    if len(pts) < 3:
        return 0.0
    counts = [0] * 8
    for i in range(1, len(pts)):
        b = pts[i-1].bearing_to(pts[i])
        counts[int(b / 45) % 8] += 1
    total = len(pts) - 1
    entropy = 0.0
    for c in counts:
        if c > 0:
            p = c / total
            entropy -= p * math.log2(p)
    return float(np.clip(entropy / 3.0, 0, 1))

def speed_stability(pts: List[GpsPoint]) -> float:
    speeds = [p.speed for p in pts if p.speed >= 0]
    if not speeds:
        return 1.0
    mean = np.mean(speeds)
    if mean < 0.01:
        return 0.5
    cv = np.std(speeds) / mean
    return float(np.clip(1 / (1 + cv), 0, 1))

def stop_frequency(pts: List[GpsPoint]) -> float:
    if not pts:
        return 0.0
    stops = sum(1 for p in pts if p.speed < 0.3)
    return float(np.clip(stops / len(pts), 0, 1))

def elevation_change(pts: List[GpsPoint]) -> float:
    if len(pts) < 2:
        return 0.0
    return sum(abs(pts[i].altitude - pts[i-1].altitude) for i in range(1, len(pts)))

def terrain_slope(pts: List[GpsPoint]) -> float:
    if len(pts) < 2:
        return 0.0
    slopes, count = 0.0, 0
    for i in range(1, len(pts)):
        hdist = pts[i-1].distance_to(pts[i])
        if hdist > 0.5:
            elev = abs(pts[i].altitude - pts[i-1].altitude)
            slopes += math.degrees(math.atan(elev / hdist))
            count += 1
    return slopes / count if count > 0 else 0.0

def extract_features(pts: List[GpsPoint], label: int) -> dict:
    return {
        'direction_variance':  direction_variance(pts),
        'backtracking_ratio':  backtracking_ratio(pts),
        'path_efficiency':     path_efficiency(pts),
        'loop_score':          loop_score(pts),
        'movement_entropy':    movement_entropy(pts),
        'speed_stability':     speed_stability(pts),
        'stop_frequency':      stop_frequency(pts),
        'elevation_change':    elevation_change(pts),
        'terrain_slope':       terrain_slope(pts),
        'label': label,
        'label_name': ['SAFE', 'CAUTION', 'DISORIENTED'][label],
    }


# ──────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='TrailGuard Dataset Generator')
    parser.add_argument('--hikes', type=int, default=300,
                        help='Number of simulated hikes per class')
    parser.add_argument('--pts', type=int, default=40,
                        help='GPS points per hike window')
    parser.add_argument('--seed', type=int, default=42)
    parser.add_argument('--output', type=str,
                        default='trailguard_dataset.csv')
    args = parser.parse_args()

    rng = random.Random(args.seed)
    records = []

    simulators = [
        (simulate_safe_hike, 0, 'SAFE'),
        (simulate_caution_hike, 1, 'CAUTION'),
        (simulate_disoriented_hike, 2, 'DISORIENTED'),
    ]

    print(f"Generating {args.hikes * 3} labelled hike windows...")
    for sim_fn, label, label_name in simulators:
        for i in range(args.hikes):
            pts = sim_fn(rng, n_pts=args.pts)
            record = extract_features(pts, label)
            records.append(record)
        print(f"  {label_name}: {args.hikes} hikes generated")

    df = pd.DataFrame(records).sample(frac=1, random_state=args.seed).reset_index(drop=True)

    df.to_csv(args.output, index=False)
    print(f"\nDataset saved to: {args.output}")
    print(f"Shape: {df.shape}")
    print("\nClass distribution:")
    print(df['label_name'].value_counts())
    print("\nFeature statistics:")
    print(df.drop(columns=['label', 'label_name']).describe().round(3))
    print("\nTo train the model with this dataset:")
    print("  python train_model.py  (or pipe this CSV into a custom training loop)")


if __name__ == '__main__':
    main()

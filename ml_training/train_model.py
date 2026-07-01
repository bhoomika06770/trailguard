"""
TrailGuard ML Training Pipeline
================================
Module 15: Machine Learning Training Pipeline

Trains a Logistic Regression and Random Forest classifier on
synthetic hiker GPS behavioral features, then exports the
logistic regression weights as lr_weights.json for on-device inference.

Requirements:
    pip install pandas numpy scikit-learn matplotlib seaborn

Usage:
    python train_model.py
    python train_model.py --output ../assets/models/lr_weights.json
"""

import json
import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score,
    f1_score, confusion_matrix, classification_report
)

# ──────────────────────────────────────────────────────────────
# 1. Synthetic Dataset Generator
# ──────────────────────────────────────────────────────────────
def generate_dataset(n_samples: int = 3000, seed: int = 42) -> pd.DataFrame:
    """
    Generate synthetic hiker behavioral features with 3 classes:
        0 = SAFE, 1 = CAUTION, 2 = DISORIENTED
    """
    rng = np.random.default_rng(seed)

    records = []

    # SAFE hikers: efficient, stable, low entropy
    n_safe = n_samples // 3
    for _ in range(n_safe):
        records.append({
            'direction_variance': rng.beta(1.5, 6),       # low
            'backtracking_ratio': rng.beta(1.2, 8),       # low
            'path_efficiency':    rng.beta(7, 2),          # high
            'loop_score':         rng.beta(1, 9),          # low
            'movement_entropy':   rng.beta(2, 5),          # moderate-low
            'speed_stability':    rng.beta(6, 2),          # high
            'stop_frequency':     rng.beta(1.5, 7),        # low
            'elevation_change':   abs(rng.normal(3, 2)),
            'terrain_slope':      abs(rng.normal(4, 3)),
            'label': 0,
        })

    # CAUTION hikers: some backtracking, moderate efficiency
    n_caution = n_samples // 3
    for _ in range(n_caution):
        records.append({
            'direction_variance': rng.beta(3, 4),
            'backtracking_ratio': rng.beta(2.5, 5),
            'path_efficiency':    rng.beta(4, 3),
            'loop_score':         rng.beta(2, 6),
            'movement_entropy':   rng.beta(4, 3),
            'speed_stability':    rng.beta(3, 3),
            'stop_frequency':     rng.beta(3, 5),
            'elevation_change':   abs(rng.normal(8, 5)),
            'terrain_slope':      abs(rng.normal(10, 6)),
            'label': 1,
        })

    # DISORIENTED hikers: high variance, low efficiency, loops
    n_disoriented = n_samples - n_safe - n_caution
    for _ in range(n_disoriented):
        records.append({
            'direction_variance': rng.beta(6, 2),          # high
            'backtracking_ratio': rng.beta(5, 2),          # high
            'path_efficiency':    rng.beta(2, 7),          # low
            'loop_score':         rng.beta(5, 2),          # high
            'movement_entropy':   rng.beta(6, 2),          # high
            'speed_stability':    rng.beta(2, 5),          # low
            'stop_frequency':     rng.beta(5, 2.5),        # high
            'elevation_change':   abs(rng.normal(15, 10)),
            'terrain_slope':      abs(rng.normal(18, 8)),
            'label': 2,
        })

    df = pd.DataFrame(records)
    df = df.sample(frac=1, random_state=seed).reset_index(drop=True)

    # Clip all 0-1 features
    feat_01 = [
        'direction_variance', 'backtracking_ratio', 'path_efficiency',
        'loop_score', 'movement_entropy', 'speed_stability', 'stop_frequency'
    ]
    for col in feat_01:
        df[col] = df[col].clip(0.01, 0.99)

    return df


# ──────────────────────────────────────────────────────────────
# 2. Feature Engineering Validation
# ──────────────────────────────────────────────────────────────
FEATURE_COLS = [
    'direction_variance', 'backtracking_ratio', 'path_efficiency',
    'loop_score', 'movement_entropy', 'speed_stability',
    'stop_frequency', 'elevation_change', 'terrain_slope'
]
LABEL_NAMES = ['SAFE', 'CAUTION', 'DISORIENTED']


def explore_dataset(df: pd.DataFrame) -> None:
    print("\n── Dataset Overview ──────────────────────────")
    print(df.describe().round(3))
    print("\nClass distribution:")
    for label, name in enumerate(LABEL_NAMES):
        count = (df['label'] == label).sum()
        print(f"  {name}: {count} ({count/len(df)*100:.1f}%)")


# ──────────────────────────────────────────────────────────────
# 3. Training
# ──────────────────────────────────────────────────────────────
def train_and_evaluate(df: pd.DataFrame) -> tuple:
    X = df[FEATURE_COLS].values
    y = df['label'].values

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    scaler = StandardScaler()
    X_train_s = scaler.fit_transform(X_train)
    X_test_s = scaler.transform(X_test)

    # ── Logistic Regression ───────────────────────────────
    lr = LogisticRegression(
        C=1.0,
        max_iter=1000,
        solver='lbfgs',
        random_state=42,
    )
    lr.fit(X_train_s, y_train)

    # ── Random Forest ─────────────────────────────────────
    rf = RandomForestClassifier(
        n_estimators=100,
        max_depth=8,
        min_samples_split=10,
        random_state=42,
        n_jobs=-1,
    )
    rf.fit(X_train_s, y_train)

    return lr, rf, scaler, X_train_s, X_test_s, y_train, y_test


def evaluate_model(model, X_test, y_test, name: str) -> dict:
    y_pred = model.predict(X_test)

    metrics = {
        'accuracy':  round(accuracy_score(y_test, y_pred), 4),
        'precision': round(precision_score(y_test, y_pred, average='weighted', zero_division=0), 4),
        'recall':    round(recall_score(y_test, y_pred, average='weighted', zero_division=0), 4),
        'f1_score':  round(f1_score(y_test, y_pred, average='weighted', zero_division=0), 4),
    }

    print(f"\n── {name} Evaluation ──────────────────────────")
    print(f"  Accuracy : {metrics['accuracy']:.4f}")
    print(f"  Precision: {metrics['precision']:.4f}")
    print(f"  Recall   : {metrics['recall']:.4f}")
    print(f"  F1 Score : {metrics['f1_score']:.4f}")
    print("\n  Classification Report:")
    print(classification_report(y_test, y_pred, target_names=LABEL_NAMES))

    return metrics, y_pred


# ──────────────────────────────────────────────────────────────
# 4. Export model for on-device deployment
# ──────────────────────────────────────────────────────────────
def export_lr_weights(lr: LogisticRegression, scaler: StandardScaler,
                      metrics: dict, output_path: str) -> None:
    """
    Export logistic regression weights to JSON for Flutter on-device inference.
    Uses binary classification (DISORIENTED vs rest) for simplicity.
    We re-train a binary LR for DISORIENTED class (label=2).
    """
    # The deployed model predicts P(DISORIENTED)
    # We use the 3rd class coefficients from the multi-class LR
    class_idx = 2  # DISORIENTED

    bias = float(lr.intercept_[class_idx])
    weights = [bias] + [float(w) for w in lr.coef_[class_idx]]

    export = {
        "model_type": "logistic_regression",
        "version": "1.0.0",
        "trained_on": "synthetic_hiker_dataset_v1",
        "classes": LABEL_NAMES,
        "feature_names": FEATURE_COLS,
        "weights": weights,
        "feature_mean": [float(m) for m in scaler.mean_],
        "feature_std":  [float(s) for s in scaler.scale_],
        "threshold": 0.70,
        "caution_threshold": 0.45,
        "accuracy": metrics['accuracy'],
        "f1_score": metrics['f1_score'],
    }

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w') as f:
        json.dump(export, f, indent=2)

    print(f"\n✓ Model weights exported to: {output_path}")
    print(f"  Weights vector length: {len(weights)} (bias + {len(FEATURE_COLS)} features)")


# ──────────────────────────────────────────────────────────────
# 5. Visualization
# ──────────────────────────────────────────────────────────────
def plot_confusion_matrix(y_test, y_pred, model_name: str) -> None:
    cm = confusion_matrix(y_test, y_pred)
    plt.figure(figsize=(7, 5))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
                xticklabels=LABEL_NAMES, yticklabels=LABEL_NAMES)
    plt.title(f'{model_name} — Confusion Matrix')
    plt.ylabel('True Label')
    plt.xlabel('Predicted Label')
    plt.tight_layout()
    plt.savefig(f'{model_name.lower().replace(" ", "_")}_confusion.png', dpi=120)
    plt.close()
    print(f"  Saved: {model_name.lower().replace(' ', '_')}_confusion.png")


def plot_feature_importance(rf: RandomForestClassifier) -> None:
    importances = rf.feature_importances_
    sorted_idx = np.argsort(importances)[::-1]
    plt.figure(figsize=(9, 5))
    plt.bar(range(len(FEATURE_COLS)),
            importances[sorted_idx],
            color='#3FB950')
    plt.xticks(range(len(FEATURE_COLS)),
               [FEATURE_COLS[i] for i in sorted_idx],
               rotation=40, ha='right', fontsize=10)
    plt.title('Random Forest — Feature Importances')
    plt.ylabel('Importance')
    plt.tight_layout()
    plt.savefig('feature_importance.png', dpi=120)
    plt.close()
    print("  Saved: feature_importance.png")


def plot_class_distributions(df: pd.DataFrame) -> None:
    fig, axes = plt.subplots(3, 3, figsize=(14, 10))
    colors = ['#3FB950', '#F0883E', '#FF3D3D']
    for idx, col in enumerate(FEATURE_COLS):
        ax = axes[idx // 3][idx % 3]
        for label, name in enumerate(LABEL_NAMES):
            subset = df[df['label'] == label][col]
            ax.hist(subset, bins=30, alpha=0.6,
                    label=name, color=colors[label])
        ax.set_title(col, fontsize=10)
        ax.legend(fontsize=7)
    plt.suptitle('Feature Distributions by Class', fontsize=13)
    plt.tight_layout()
    plt.savefig('feature_distributions.png', dpi=100)
    plt.close()
    print("  Saved: feature_distributions.png")


# ──────────────────────────────────────────────────────────────
# 6. Cross-validation
# ──────────────────────────────────────────────────────────────
def cross_validate(model, X: np.ndarray, y: np.ndarray, name: str) -> None:
    scores = cross_val_score(model, X, y, cv=5, scoring='f1_weighted')
    print(f"\n  {name} 5-fold CV F1: {scores.mean():.4f} ± {scores.std():.4f}")


# ──────────────────────────────────────────────────────────────
# 7. Main
# ──────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description='TrailGuard ML Training')
    parser.add_argument('--samples', type=int, default=3000)
    parser.add_argument('--output', type=str,
                        default='../assets/models/lr_weights.json')
    parser.add_argument('--plots', action='store_true',
                        help='Generate visualizations')
    args = parser.parse_args()

    print("TrailGuard ML Training Pipeline")
    print("=" * 45)

    # Generate data
    print(f"\n[1/5] Generating synthetic dataset ({args.samples} samples)...")
    df = generate_dataset(n_samples=args.samples)
    explore_dataset(df)

    # Train
    print("\n[2/5] Training models...")
    lr, rf, scaler, X_train_s, X_test_s, y_train, y_test = train_and_evaluate(df)

    # Evaluate
    print("\n[3/5] Evaluating models...")
    lr_metrics, lr_pred = evaluate_model(lr, X_test_s, y_test, "Logistic Regression")
    rf_metrics, rf_pred = evaluate_model(rf, X_test_s, y_test, "Random Forest")

    # Cross-validate
    print("\n[4/5] Cross-validation...")
    X_all = StandardScaler().fit_transform(df[FEATURE_COLS].values)
    cross_validate(lr, X_all, df['label'].values, "Logistic Regression")
    cross_validate(rf, X_all, df['label'].values, "Random Forest")

    # Export
    print("\n[5/5] Exporting model weights...")
    export_lr_weights(lr, scaler, lr_metrics, args.output)

    # Plots (optional)
    if args.plots:
        print("\n  Generating plots...")
        plot_confusion_matrix(y_test, lr_pred, "Logistic Regression")
        plot_confusion_matrix(y_test, rf_pred, "Random Forest")
        plot_feature_importance(rf)
        plot_class_distributions(df)

    print("\n✓ Training pipeline complete.")
    print(f"  LR accuracy: {lr_metrics['accuracy']:.4f}")
    print(f"  RF accuracy: {rf_metrics['accuracy']:.4f}")
    print(f"  Weights saved to: {args.output}")


if __name__ == '__main__':
    main()

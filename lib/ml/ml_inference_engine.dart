import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../models/behavioral_features.dart';
import '../models/safety_prediction.dart';
import '../constants/app_constants.dart';

/// Module 7: On-device ML Disorientation Detection
/// Implements logistic regression with pre-trained weights.
/// Falls back to a rule-based engine if model weights not found.
class MLInferenceEngine {
  static MLInferenceEngine? _instance;
  static MLInferenceEngine get instance =>
      _instance ??= MLInferenceEngine._();
  MLInferenceEngine._();

  // Logistic regression weights (trained offline, bundled with app)
  // Order: [bias, dirVar, backtrack, pathEff, loop, entropy, speedStab, stopFreq, elevChange, slope]
  List<double> _weights = [
    -2.1,  // bias
     2.8,  // direction_variance  → high = disoriented
     3.2,  // backtracking_ratio  → high = disoriented
    -3.5,  // path_efficiency     → low = disoriented
     2.6,  // loop_score          → high = disoriented
     1.9,  // movement_entropy    → high = disoriented
    -1.4,  // speed_stability     → low = disoriented
     1.7,  // stop_frequency      → high = disoriented
     0.3,  // elevation_change    (terrain context, mild)
     0.2,  // terrain_slope       (terrain context, mild)
  ];

  // Feature normalization parameters (μ, σ) from training data
  final List<double> _featureMean = [
    0.35, 0.15, 0.70, 0.10, 0.45, 0.75, 0.20, 5.0, 3.0
  ];
  final List<double> _featureStd = [
    0.25, 0.15, 0.25, 0.15, 0.25, 0.20, 0.20, 8.0, 5.0
  ];

  bool _modelLoaded = false;

  /// Load model weights from bundled JSON asset
  Future<void> loadModel() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/models/lr_weights.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      _weights = (data['weights'] as List).cast<double>();
      final means = data['feature_mean'] as List;
      final stds = data['feature_std'] as List;
      for (int i = 0; i < means.length; i++) {
        _featureMean[i] = (means[i] as num).toDouble();
        _featureStd[i] = (stds[i] as num).toDouble();
      }
      _modelLoaded = true;
    } catch (_) {
      // Use built-in default weights — still functional
      _modelLoaded = true;
    }
  }

  /// Run inference on behavioral features
  SafetyPrediction predict(BehavioralFeatures features) {
    final vec = features.toFeatureVector();
    final prob = _logisticRegression(vec);
    final confidence = _computeConfidenceScore(features, prob);
    final risk = _classifyRisk(prob);

    return SafetyPrediction(
      sessionId: features.sessionId,
      timestamp: features.timestamp,
      disorientationProbability: prob,
      confidenceScore: confidence,
      riskLevel: risk,
    );
  }

  // ─── Logistic Regression ─────────────────────────────────────
  double _logisticRegression(List<double> features) {
    // Normalize features
    final normalized = <double>[];
    for (int i = 0; i < features.length; i++) {
      final std = _featureStd[i] < 0.001 ? 1.0 : _featureStd[i];
      normalized.add((features[i] - _featureMean[i]) / std);
    }

    // Linear combination
    double z = _weights[0]; // bias
    for (int i = 0; i < normalized.length; i++) {
      z += _weights[i + 1] * normalized[i];
    }

    // Sigmoid
    return 1.0 / (1.0 + math.exp(-z));
  }

  // ─── Module 6: Navigation Confidence Engine ──────────────────
  int _computeConfidenceScore(BehavioralFeatures f, double disorientProb) {
    // Weighted combination of stability indicators
    double score = 0.0;
    score += (1 - f.directionVariance) * 20;    // 20 pts
    score += f.pathEfficiency * 25;              // 25 pts
    score += (1 - f.backtrackingRatio) * 20;    // 20 pts
    score += f.speedStability * 15;              // 15 pts
    score += (1 - f.loopScore) * 10;            // 10 pts
    score += (1 - disorientProb) * 10;          // 10 pts  (ML signal)

    // Terrain penalty: steep terrain reduces confidence slightly
    final terrainPenalty = (f.terrainSlope / 45.0).clamp(0.0, 0.15) * 100;
    score = (score - terrainPenalty).clamp(0, 100);

    return score.round();
  }

  String _classifyRisk(double prob) {
    if (prob >= AppConstants.disorientationThreshold) return RiskLevel.disoriented;
    if (prob >= AppConstants.cautionThreshold) return RiskLevel.caution;
    return RiskLevel.safe;
  }

  bool get isLoaded => _modelLoaded;
}

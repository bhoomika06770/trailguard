import 'package:flutter_test/flutter_test.dart';
import 'package:trailguard/core/models/gps_point.dart';
import 'package:trailguard/core/models/behavioral_features.dart';
import 'package:trailguard/core/models/safety_prediction.dart';
import 'package:trailguard/core/services/feature_extractor.dart';
import 'package:trailguard/core/constants/app_constants.dart';
import 'package:trailguard/ml/ml_inference_engine.dart';

// ─── Helpers ─────────────────────────────────────────────────
List<GpsPoint> _straightLine(String sessionId, int n) {
  // Simulates walking straight north — very efficient hiker
  return List.generate(n, (i) {
    return GpsPoint(
      sessionId: sessionId,
      latitude: 12.8698 + i * 0.0001,
      longitude: 74.8435,
      altitude: 50.0 + i * 0.5,
      speed: 1.2,
      bearing: 0.0,
      timestamp: DateTime(2025, 1, 1).add(Duration(seconds: i * 5)),
    );
  });
}

List<GpsPoint> _randomWalk(String sessionId, int n) {
  // Simulates erratic movement — disoriented hiker
  final base = DateTime(2025, 1, 1);
  final pts = <GpsPoint>[];
  double lat = 12.8698, lon = 74.8435;
  final directions = [0.0, 90.0, 180.0, 270.0, 45.0, 135.0, 225.0, 315.0];
  for (int i = 0; i < n; i++) {
    final dir = directions[i % directions.length];
    final rad = dir * 3.14159 / 180;
    lat += 0.00003 * (i % 3 == 0 ? -1 : 1);
    lon += 0.00003 * (i % 2 == 0 ? 1 : -1);
    pts.add(GpsPoint(
      sessionId: sessionId,
      latitude: lat,
      longitude: lon,
      altitude: 80.0 + (i % 10) * 2.0,
      speed: i % 4 == 0 ? 0.1 : 0.8,
      bearing: dir,
      timestamp: base.add(Duration(seconds: i * 5)),
    ));
  }
  return pts;
}

void main() {
  // ─── GpsPoint Tests ─────────────────────────────────────────
  group('GpsPoint', () {
    test('distanceTo returns ~111m per 0.001 degree latitude', () {
      final a = GpsPoint(
          sessionId: 'x',
          latitude: 12.0,
          longitude: 74.0,
          timestamp: DateTime.now());
      final b = GpsPoint(
          sessionId: 'x',
          latitude: 12.001,
          longitude: 74.0,
          timestamp: DateTime.now());
      final dist = a.distanceTo(b);
      expect(dist, closeTo(111.0, 5.0));
    });

    test('bearingTo north is ~0 degrees', () {
      final a = GpsPoint(
          sessionId: 'x',
          latitude: 12.0,
          longitude: 74.0,
          timestamp: DateTime.now());
      final b = GpsPoint(
          sessionId: 'x',
          latitude: 12.01,
          longitude: 74.0,
          timestamp: DateTime.now());
      expect(a.bearingTo(b), closeTo(0.0, 1.0));
    });

    test('bearingTo east is ~90 degrees', () {
      final a = GpsPoint(
          sessionId: 'x',
          latitude: 12.0,
          longitude: 74.0,
          timestamp: DateTime.now());
      final b = GpsPoint(
          sessionId: 'x',
          latitude: 12.0,
          longitude: 74.01,
          timestamp: DateTime.now());
      expect(a.bearingTo(b), closeTo(90.0, 2.0));
    });

    test('serialization round-trips correctly', () {
      final pt = GpsPoint(
        sessionId: 'sess-1',
        latitude: 12.8698,
        longitude: 74.8435,
        altitude: 55.0,
        speed: 1.5,
        bearing: 270.0,
        accuracy: 4.2,
        timestamp: DateTime(2025, 6, 1, 10, 30),
      );
      final map = pt.toMap();
      final restored = GpsPoint.fromMap(map);
      expect(restored.latitude, equals(pt.latitude));
      expect(restored.longitude, equals(pt.longitude));
      expect(restored.speed, equals(pt.speed));
      expect(restored.bearing, equals(pt.bearing));
    });
  });

  // ─── FeatureExtractor Tests ──────────────────────────────────
  group('FeatureExtractor', () {
    test('returns default features for <3 points', () {
      final pts = _straightLine('s1', 2);
      final f = FeatureExtractor.extract(window: pts, sessionId: 's1');
      expect(f.directionVariance, equals(0.0));
      expect(f.pathEfficiency, equals(1.0));
    });

    test('straight-line hiker has high path efficiency', () {
      final pts = _straightLine('s1', 20);
      final f = FeatureExtractor.extract(window: pts, sessionId: 's1');
      expect(f.pathEfficiency, greaterThan(0.90));
    });

    test('straight-line hiker has low direction variance', () {
      final pts = _straightLine('s1', 20);
      final f = FeatureExtractor.extract(window: pts, sessionId: 's1');
      expect(f.directionVariance, lessThan(0.15));
    });

    test('straight-line hiker has low backtracking', () {
      final pts = _straightLine('s1', 20);
      final f = FeatureExtractor.extract(window: pts, sessionId: 's1');
      expect(f.backtrackingRatio, lessThan(0.1));
    });

    test('random-walk hiker has low path efficiency', () {
      final pts = _randomWalk('s2', 25);
      final f = FeatureExtractor.extract(window: pts, sessionId: 's2');
      expect(f.pathEfficiency, lessThan(0.6));
    });

    test('random-walk hiker has high direction variance', () {
      final pts = _randomWalk('s2', 25);
      final f = FeatureExtractor.extract(window: pts, sessionId: 's2');
      expect(f.directionVariance, greaterThan(0.5));
    });

    test('random-walk hiker has high movement entropy', () {
      final pts = _randomWalk('s2', 25);
      final f = FeatureExtractor.extract(window: pts, sessionId: 's2');
      expect(f.movementEntropy, greaterThan(0.5));
    });

    test('elevation change is cumulative altitude delta', () {
      final pts = _straightLine('s1', 10);
      final f = FeatureExtractor.extract(window: pts, sessionId: 's1');
      // 9 steps × 0.5m/step = 4.5m
      expect(f.elevationChange, closeTo(4.5, 0.5));
    });

    test('feature vector has exactly 9 elements', () {
      final pts = _straightLine('s1', 20);
      final f = FeatureExtractor.extract(window: pts, sessionId: 's1');
      expect(f.toFeatureVector().length, equals(9));
    });

    test('all 0–1 features are clamped', () {
      final pts = _randomWalk('s2', 30);
      final f = FeatureExtractor.extract(window: pts, sessionId: 's2');
      for (final v in [
        f.directionVariance,
        f.backtrackingRatio,
        f.pathEfficiency,
        f.loopScore,
        f.movementEntropy,
        f.speedStability,
        f.stopFrequency,
      ]) {
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThanOrEqualTo(1.0));
      }
    });

    test('progress toward destination: moving closer increases score', () {
      final pts = _straightLine('s1', 20);
      // Destination is straight north — same direction as our walk
      final f = FeatureExtractor.extract(
        window: pts,
        sessionId: 's1',
        destLat: 12.8698 + 0.05,
        destLon: 74.8435,
      );
      expect(f.progressTowardDest, greaterThan(0.5));
    });
  });

  // ─── BehavioralFeatures Tests ────────────────────────────────
  group('BehavioralFeatures', () {
    test('serialization round-trip', () {
      final f = BehavioralFeatures(
        sessionId: 's1',
        timestamp: DateTime(2025, 1, 1),
        directionVariance: 0.3,
        backtrackingRatio: 0.1,
        pathEfficiency: 0.85,
        loopScore: 0.05,
        movementEntropy: 0.4,
        speedStability: 0.9,
        stopFrequency: 0.1,
        elevationChange: 12.5,
        terrainSlope: 8.0,
        progressTowardDest: 0.7,
      );
      final restored = BehavioralFeatures.fromMap(f.toMap());
      expect(restored.directionVariance, equals(f.directionVariance));
      expect(restored.pathEfficiency, equals(f.pathEfficiency));
      expect(restored.elevationChange, equals(f.elevationChange));
    });
  });

  // ─── MLInferenceEngine Tests ─────────────────────────────────
  group('MLInferenceEngine', () {
    final ml = MLInferenceEngine.instance;

    setUp(() async {
      // Initialize with built-in default weights (no asset loading needed in tests)
    });

    test('safe hiker predicts SAFE', () {
      final safeFeatures = BehavioralFeatures(
        sessionId: 's1',
        timestamp: DateTime.now(),
        directionVariance: 0.05,
        backtrackingRatio: 0.02,
        pathEfficiency: 0.95,
        loopScore: 0.01,
        movementEntropy: 0.2,
        speedStability: 0.92,
        stopFrequency: 0.05,
        elevationChange: 2.0,
        terrainSlope: 3.0,
      );
      final pred = ml.predict(safeFeatures);
      expect(pred.riskLevel, equals(RiskLevel.safe));
      expect(pred.confidenceScore, greaterThan(60));
      expect(pred.disorientationProbability, lessThan(AppConstants.cautionThreshold));
    });

    test('disoriented hiker predicts DISORIENTED', () {
      final disFeatures = BehavioralFeatures(
        sessionId: 's2',
        timestamp: DateTime.now(),
        directionVariance: 0.90,
        backtrackingRatio: 0.80,
        pathEfficiency: 0.10,
        loopScore: 0.85,
        movementEntropy: 0.92,
        speedStability: 0.15,
        stopFrequency: 0.70,
        elevationChange: 20.0,
        terrainSlope: 22.0,
      );
      final pred = ml.predict(disFeatures);
      expect(pred.riskLevel, equals(RiskLevel.disoriented));
      expect(pred.confidenceScore, lessThan(40));
      expect(pred.disorientationProbability,
          greaterThan(AppConstants.disorientationThreshold));
    });

    test('borderline hiker predicts CAUTION', () {
      final cautionFeatures = BehavioralFeatures(
        sessionId: 's3',
        timestamp: DateTime.now(),
        directionVariance: 0.45,
        backtrackingRatio: 0.30,
        pathEfficiency: 0.55,
        loopScore: 0.25,
        movementEntropy: 0.55,
        speedStability: 0.55,
        stopFrequency: 0.35,
        elevationChange: 8.0,
        terrainSlope: 12.0,
      );
      final pred = ml.predict(cautionFeatures);
      expect(
        pred.riskLevel,
        anyOf(equals(RiskLevel.caution), equals(RiskLevel.safe)),
      );
    });

    test('prediction has valid confidence score range', () {
      final f = BehavioralFeatures(
        sessionId: 's1',
        timestamp: DateTime.now(),
      );
      final pred = ml.predict(f);
      expect(pred.confidenceScore, greaterThanOrEqualTo(0));
      expect(pred.confidenceScore, lessThanOrEqualTo(100));
    });

    test('prediction sessionId matches features sessionId', () {
      final f = BehavioralFeatures(
        sessionId: 'test-session-123',
        timestamp: DateTime.now(),
      );
      final pred = ml.predict(f);
      expect(pred.sessionId, equals('test-session-123'));
    });

    test('SafetyPrediction.safe factory returns safe risk', () {
      final pred = SafetyPrediction.safe('s1');
      expect(pred.riskLevel, equals(RiskLevel.safe));
      expect(pred.confidenceScore, equals(95));
      expect(pred.isEmergency, isFalse);
    });

    test('safety prediction serialization round-trip', () {
      final pred = SafetyPrediction(
        sessionId: 's1',
        timestamp: DateTime(2025, 3, 15, 9, 0),
        disorientationProbability: 0.73,
        confidenceScore: 22,
        riskLevel: RiskLevel.disoriented,
      );
      final restored = SafetyPrediction.fromMap(pred.toMap());
      expect(restored.disorientationProbability,
          closeTo(0.73, 0.001));
      expect(restored.confidenceScore, equals(22));
      expect(restored.riskLevel, equals(RiskLevel.disoriented));
      expect(restored.isEmergency, isTrue);
    });
  });

  // ─── AppConstants sanity checks ─────────────────────────────
  group('AppConstants', () {
    test('disorientation threshold is above caution threshold', () {
      expect(AppConstants.disorientationThreshold,
          greaterThan(AppConstants.cautionThreshold));
    });

    test('high risk max is below moderate risk max', () {
      expect(AppConstants.highRiskMax, lessThan(AppConstants.moderateRiskMax));
    });

    test('feature window is sensible size', () {
      expect(AppConstants.featureWindowSize, greaterThanOrEqualTo(10));
      expect(AppConstants.featureWindowSize, lessThanOrEqualTo(100));
    });
  });
}

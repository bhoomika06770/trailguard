import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_constants.dart';
import '../database/database_helper.dart';
import '../models/gps_point.dart';

/// Module 1: GPS Tracking Engine
class GpsTrackingService {
  static final GpsTrackingService instance = GpsTrackingService._();
  GpsTrackingService._();

  final _db = DatabaseHelper.instance;
  StreamSubscription<Position>? _positionSub;
  final StreamController<GpsPoint> _pointController =
      StreamController<GpsPoint>.broadcast();

  String? _activeSessionId;
  GpsPoint? _lastPoint;
  int _pointCount = 0;

  Stream<GpsPoint> get positionStream => _pointController.stream;
  GpsPoint? get lastPoint => _lastPoint;
  String? get activeSessionId => _activeSessionId;
  bool get isTracking => _positionSub != null;

  // ─── Permission ──────────────────────────────────────────────
  Future<bool> requestPermissions() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return false;
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<bool> get isLocationEnabled =>
      Geolocator.isLocationServiceEnabled();

  // ─── Start Tracking ──────────────────────────────────────────
  Future<void> startTracking(String sessionId) async {
    _activeSessionId = sessionId;
    _pointCount = 0;

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: AppConstants.minDistanceMeters.toInt(),
      intervalDuration:
          const Duration(seconds: AppConstants.gpsIntervalSeconds),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'TrailGuard is tracking your hike',
        notificationTitle: 'TrailGuard Active',
        enableWakeLock: true,
      ),
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition);
  }

  void _onPosition(Position pos) {
    final point = GpsPoint(
      sessionId: _activeSessionId!,
      latitude: pos.latitude,
      longitude: pos.longitude,
      altitude: pos.altitude,
      speed: pos.speed.clamp(0, 50),
      bearing: pos.heading,
      accuracy: pos.accuracy,
      timestamp: pos.timestamp,
    );

    _lastPoint = point;
    _pointController.add(point);
    _pointCount++;

    // Persist async (fire-and-forget, non-blocking)
    _db.insertGpsPoint(point.toMap());
  }

  // ─── Stop Tracking ───────────────────────────────────────────
  Future<void> stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _activeSessionId = null;
  }

  // ─── Current Location ────────────────────────────────────────
  Future<GpsPoint?> getCurrentLocation(String sessionId) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return GpsPoint(
        sessionId: sessionId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        altitude: pos.altitude,
        speed: pos.speed.clamp(0, 50),
        bearing: pos.heading,
        accuracy: pos.accuracy,
        timestamp: pos.timestamp,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Load Recent Trail ───────────────────────────────────────
  Future<List<GpsPoint>> getRecentTrail(String sessionId,
      {int limit = AppConstants.trajectoryBufferSize}) async {
    final maps = await _db.getGpsPoints(sessionId, limit: limit);
    return maps.map(GpsPoint.fromMap).toList();
  }

  Future<List<GpsPoint>> getTrailWindow(String sessionId) async {
    final maps = await _db.getRecentGpsPoints(
        sessionId, AppConstants.featureWindowSize);
    return maps.reversed.map(GpsPoint.fromMap).toList();
  }

  void dispose() {
    _positionSub?.cancel();
    _pointController.close();
  }
}

// ─── Background Service Initializer ──────────────────────────
Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: AppConstants.channelId,
      initialNotificationTitle: 'TrailGuard',
      initialNotificationContent: 'Hike tracking active',
      foregroundServiceNotificationId: AppConstants.notificationId,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  // Background tracking continues via geolocator foreground config
  service.on('stop').listen((_) => service.stopSelf());
}

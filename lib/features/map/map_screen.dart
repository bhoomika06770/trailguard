import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/models/gps_point.dart';
import '../../core/models/safe_zone.dart';
import '../../core/models/safety_prediction.dart';
import '../../core/services/gps_tracking_service.dart';
import '../../core/services/hiking_session_service.dart';
import '../../core/constants/app_constants.dart';

/// Module 2: Offline Map System using flutter_map + OpenStreetMap tiles
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _sessionService = HikingSessionService.instance;
  final _gps = GpsTrackingService.instance;
  final _mapCtrl = MapController();

  StreamSubscription<GpsPoint>? _gpsSub;
  StreamSubscription<SafetyPrediction>? _predSub;

  LatLng? _currentPos;
  final List<LatLng> _trail = [];
  List<SafeZone> _safeZones = [];
  SafetyPrediction? _prediction;
  bool _followUser = true;
  bool _showRecovery = false;
  List<LatLng> _recoveryRoute = [];

  @override
  void initState() {
    super.initState();
    _gpsSub = _gps.positionStream.listen((p) {
      setState(() {
        _currentPos = LatLng(p.latitude, p.longitude);
        _trail.add(_currentPos!);
        if (_trail.length > AppConstants.trajectoryBufferSize) {
          _trail.removeAt(0);
        }
        _safeZones = _sessionService.safeZones;
      });
      if (_followUser) {
        _mapCtrl.move(_currentPos!, _mapCtrl.camera.zoom);
      }
    });
    _predSub = _sessionService.predictionStream.listen((pred) {
      setState(() => _prediction = pred);
      if (pred.riskLevel == RiskLevel.disoriented && !_showRecovery) {
        _activateRecovery();
      }
    });
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _predSub?.cancel();
    super.dispose();
  }

  void _activateRecovery() {
    final route = _sessionService.getRecoveryRoute();
    setState(() {
      _recoveryRoute =
          route.map((p) => LatLng(p.latitude, p.longitude)).toList();
      _showRecovery = true;
    });
  }

  void _dismissRecovery() => setState(() => _showRecovery = false);

  Color get _markerColor {
    final level = _prediction?.riskLevel ?? RiskLevel.safe;
    if (level == RiskLevel.disoriented) return const Color(0xFFFF3D3D);
    if (level == RiskLevel.caution) return const Color(0xFFF0883E);
    return const Color(0xFF3FB950);
  }

  @override
  Widget build(BuildContext context) {
    final center = _currentPos ?? const LatLng(12.8698, 74.8435); // Mangaluru

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trail Map'),
        actions: [
          IconButton(
            tooltip: _followUser ? 'Following' : 'Free scroll',
            icon: Icon(
              _followUser ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: _followUser
                  ? const Color(0xFF3FB950)
                  : const Color(0xFF8B949E),
            ),
            onPressed: () => setState(() => _followUser = !_followUser),
          ),
          if (_prediction?.riskLevel == RiskLevel.disoriented)
            IconButton(
              tooltip: 'Recovery Route',
              icon: const Icon(Icons.undo, color: Color(0xFFF0883E)),
              onPressed: _activateRecovery,
            ),
        ],
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
            maxZoom: 18,
            minZoom: 5,
            onTap: (_, __) => setState(() => _followUser = false),
          ),
          children: [
            // ── Offline Tile Layer ────────────────────────────
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.trailguard.app',
              // For production, set tileProvider to a cached/offline provider:
              // tileProvider: FMTCStore('mapStore').getTileProvider(),
              fallbackUrl:
                  'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
              maxZoom: 18,
              tileBuilder: _darkTileBuilder,
            ),

            // ── Safe Zones ────────────────────────────────────
            CircleLayer(
              circles: _safeZones
                  .map((z) => CircleMarker(
                        point: LatLng(z.centerLat, z.centerLon),
                        radius: z.radiusMeters,
                        useRadiusInMeter: true,
                        color:
                            const Color(0xFF3FB950).withOpacity(0.15),
                        borderColor: const Color(0xFF3FB950),
                        borderStrokeWidth: 1.5,
                      ))
                  .toList(),
            ),

            // ── Recovery Route ────────────────────────────────
            if (_showRecovery && _recoveryRoute.isNotEmpty)
              PolylineLayer(polylines: [
                Polyline(
                  points: _recoveryRoute,
                  color: const Color(0xFFF0883E),
                  strokeWidth: 4,
                  isDotted: true,
                ),
              ]),

            // ── Breadcrumb Trail ──────────────────────────────
            if (_trail.isNotEmpty)
              PolylineLayer(polylines: [
                Polyline(
                  points: _trail,
                  color: const Color(0xFF3FB950).withOpacity(0.8),
                  strokeWidth: 3,
                ),
              ]),

            // ── Current Location Marker ───────────────────────
            if (_currentPos != null)
              MarkerLayer(markers: [
                Marker(
                  point: _currentPos!,
                  width: 24,
                  height: 24,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _markerColor,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: _markerColor.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 3,
                        )
                      ],
                    ),
                  ),
                ),
              ]),
          ],
        ),

        // ── Recovery Banner ───────────────────────────────────
        if (_showRecovery)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _RecoveryBanner(
              route: _recoveryRoute,
              currentPos: _currentPos,
              onDismiss: _dismissRecovery,
            ),
          ),

        // ── Map Legend ────────────────────────────────────────
        Positioned(
          bottom: 16,
          right: 16,
          child: _MapLegend(prediction: _prediction),
        ),

        // ── No tracking hint ─────────────────────────────────
        if (_sessionService.currentSession == null)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2128).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Start a hike to see your trail',
                  style:
                      TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _darkTileBuilder(
      BuildContext ctx, Widget tile, TileImage tileImage) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -0.2126, -0.7152, -0.0722, 0, 255,
        -0.2126, -0.7152, -0.0722, 0, 255,
        -0.2126, -0.7152, -0.0722, 0, 255,
        0, 0, 0, 1, 0,
      ]),
      child: tile,
    );
  }
}

// ─── Recovery Banner ─────────────────────────────────────────
class _RecoveryBanner extends StatelessWidget {
  final List<LatLng> route;
  final LatLng? currentPos;
  final VoidCallback onDismiss;

  const _RecoveryBanner({
    required this.route,
    this.currentPos,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0883E).withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3), blurRadius: 8)
        ],
      ),
      child: Row(children: [
        const Icon(Icons.undo, color: Colors.black, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RECOVERY ROUTE ACTIVE',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
                Text(
                  'Follow the dashed orange line to return to safety',
                  style: TextStyle(
                      color: Colors.black.withOpacity(0.75),
                      fontSize: 11),
                ),
              ]),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.black, size: 18),
          onPressed: onDismiss,
        )
      ]),
    );
  }
}

// ─── Map Legend ───────────────────────────────────────────────
class _MapLegend extends StatelessWidget {
  final SafetyPrediction? prediction;
  const _MapLegend({this.prediction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2128).withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _LegendItem(color: const Color(0xFF3FB950), label: 'Trail'),
        _LegendItem(
            color: const Color(0xFF3FB950).withOpacity(0.4),
            label: 'Safe Zone'),
        _LegendItem(color: const Color(0xFFF0883E), label: 'Recovery'),
        if (prediction != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Conf: ${prediction!.confidenceScore}%',
              style: const TextStyle(
                  color: Color(0xFF8B949E), fontSize: 10),
            ),
          ),
      ]),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Container(width: 12, height: 4, color: color,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8B949E), fontSize: 10)),
      ]),
    );
  }
}

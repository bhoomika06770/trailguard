import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/services/hiking_session_service.dart';
import '../../core/services/gps_tracking_service.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/gps_point.dart';

/// Module 11: Emergency Assistance
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final _sessionService = HikingSessionService.instance;
  final _gps = GpsTrackingService.instance;
  final _db = DatabaseHelper.instance;

  GpsPoint? _lastKnownPos;
  bool _emergencyActive = false;
  String? _reportPath;

  @override
  void initState() {
    super.initState();
    _updateLocation();
  }

  void _updateLocation() {
    setState(() => _lastKnownPos = _gps.lastPoint);
  }

  Future<void> _triggerSOS() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        title: const Text('Confirm SOS',
            style: TextStyle(color: Color(0xFFFF3D3D))),
        content: const Text(
          'This will activate Emergency Mode and save your last known location for rescue teams.',
          style: TextStyle(color: Color(0xFF8B949E)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF8B949E)))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3D3D)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Activate SOS')),
        ],
      ),
    );

    if (confirm != true) return;

    _updateLocation();
    await _sessionService.logEmergency('Manual SOS activated by hiker');
    setState(() => _emergencyActive = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency mode activated. Location saved.'),
          backgroundColor: Color(0xFFFF3D3D),
        ),
      );
    }
  }

  Future<void> _generateReport() async {
    _updateLocation();
    final session = _sessionService.currentSession;
    final pos = _lastKnownPos;
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');

    final trail = session != null
        ? await _sessionService.getSessionTrail(session.id)
        : <GpsPoint>[];

    final report = StringBuffer()
      ..writeln('=== TRAILGUARD EMERGENCY REPORT ===')
      ..writeln('Generated: ${fmt.format(now)}')
      ..writeln()
      ..writeln('HIKER LAST KNOWN LOCATION:')
      ..writeln('  Latitude:  ${pos?.latitude ?? "Unknown"}')
      ..writeln('  Longitude: ${pos?.longitude ?? "Unknown"}')
      ..writeln('  Altitude:  ${pos?.altitude.toStringAsFixed(1) ?? "Unknown"} m')
      ..writeln('  Timestamp: ${pos != null ? fmt.format(pos.timestamp) : "Unknown"}')
      ..writeln()
      ..writeln('SESSION INFO:')
      ..writeln('  Session: ${session?.name ?? "No active session"}')
      ..writeln('  Started: ${session != null ? fmt.format(session.startTime) : "N/A"}')
      ..writeln('  Trail points: ${trail.length}')
      ..writeln()
      ..writeln('TRAIL COORDINATES (last 20 points):');

    for (final pt in trail.reversed.take(20)) {
      report.writeln(
          '  ${fmt.format(pt.timestamp)} → ${pt.latitude.toStringAsFixed(5)}, ${pt.longitude.toStringAsFixed(5)}');
    }

    report.writeln()
    ..writeln('EMERGENCY MESSAGE FOR RESCUE:')
    ..writeln('  A hiker using TrailGuard has activated an SOS alert.')
    ..writeln('  Last known coordinates: ${pos?.latitude}, ${pos?.longitude}')
    ..writeln('  Please send help to the above location.');

    // Save to database as emergency log
    if (session != null) {
      await _db.insertEmergencyLog({
        'session_id': session.id,
        'timestamp': now.millisecondsSinceEpoch,
        'last_lat': pos?.latitude,
        'last_lon': pos?.longitude,
        'message': report.toString(),
        'sent': 0,
      });
    }

    // Copy to clipboard for sharing
    await Clipboard.setData(ClipboardData(text: report.toString()));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Emergency report copied to clipboard. Share with rescue team.'),
          duration: Duration(seconds: 4),
        ),
      );
    }

    setState(() => _reportPath = 'Saved to database');
  }

  @override
  Widget build(BuildContext context) {
    final pos = _lastKnownPos;
    final session = _sessionService.currentSession;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _updateLocation),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── SOS Button ─────────────────────────────────────
          _SOSButton(
            active: _emergencyActive,
            onPressed: _triggerSOS,
          ),
          const SizedBox(height: 20),

          // ── Last Known Location ─────────────────────────────
          _EmergencyCard(
            icon: Icons.location_pin,
            title: 'Last Known Location',
            iconColor: const Color(0xFFFF3D3D),
            children: [
              _InfoRow('Latitude',
                  pos?.latitude.toStringAsFixed(6) ?? 'No GPS signal'),
              _InfoRow('Longitude',
                  pos?.longitude.toStringAsFixed(6) ?? 'No GPS signal'),
              _InfoRow('Altitude',
                  pos != null
                      ? '${pos.altitude.toStringAsFixed(1)} m'
                      : 'Unknown'),
              if (pos != null)
                _InfoRow('Last Update',
                    DateFormat('HH:mm:ss').format(pos.timestamp)),
            ],
          ),
          const SizedBox(height: 12),

          // ── Session Info ────────────────────────────────────
          _EmergencyCard(
            icon: Icons.route,
            title: 'Current Session',
            iconColor: const Color(0xFFF0883E),
            children: [
              _InfoRow('Name', session?.name ?? 'No active session'),
              if (session != null) ...[
                _InfoRow('Started',
                    DateFormat('HH:mm').format(session.startTime)),
                _InfoRow('Duration',
                    '${session.duration.inMinutes} minutes'),
                _InfoRow('Total Trail Points',
                    '${_sessionService.trailBuffer.length}'),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // ── Emergency Actions ───────────────────────────────
          _EmergencyCard(
            icon: Icons.send,
            title: 'Emergency Actions',
            iconColor: const Color(0xFF58A6FF),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Generate an emergency report with your location and trail history. Copy and share via any app when connectivity is available.',
                  style: TextStyle(
                      color: Color(0xFF8B949E), fontSize: 12),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _generateReport,
                  icon: const Icon(Icons.file_copy_outlined,
                      color: Color(0xFF58A6FF)),
                  label: const Text('Generate & Copy Report',
                      style: TextStyle(color: Color(0xFF58A6FF))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF58A6FF)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (_reportPath != null) ...[
                const SizedBox(height: 8),
                Text('✓ $_reportPath',
                    style: const TextStyle(
                        color: Color(0xFF3FB950), fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // ── Safety Instructions ─────────────────────────────
          _EmergencyCard(
            icon: Icons.info_outline,
            title: 'If You Are Lost',
            iconColor: const Color(0xFF3FB950),
            children: const [
              _InstructionItem('1', 'STOP — Stay calm. Do not panic.'),
              _InstructionItem('2', 'THINK — Review your last safe location.'),
              _InstructionItem(
                  '3', 'OBSERVE — Check your surroundings for landmarks.'),
              _InstructionItem('4',
                  'PLAN — Use the Map screen to follow the recovery route.'),
              _InstructionItem('5',
                  'STAY PUT if injured — use this screen to generate a rescue report.'),
            ],
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────
class _SOSButton extends StatelessWidget {
  final bool active;
  final VoidCallback onPressed;
  const _SOSButton({required this.active, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? null : onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFFF3D3D).withOpacity(0.2)
              : const Color(0xFFFF3D3D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF3D3D), width: 2),
          boxShadow: [
            if (!active)
              BoxShadow(
                color: const Color(0xFFFF3D3D).withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              )
          ],
        ),
        child: Column(children: [
          Icon(
            active ? Icons.emergency : Icons.sos,
            size: 48,
            color: active ? const Color(0xFFFF3D3D) : Colors.white,
          ),
          const SizedBox(height: 8),
          Text(
            active ? 'EMERGENCY ACTIVE' : 'SOS — EMERGENCY',
            style: TextStyle(
              color: active ? const Color(0xFFFF3D3D) : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          Text(
            active
                ? 'Emergency logged. Location saved.'
                : 'Tap to activate emergency mode',
            style: TextStyle(
              color: active
                  ? const Color(0xFFFF3D3D).withOpacity(0.7)
                  : Colors.white.withOpacity(0.8),
              fontSize: 13,
            ),
          ),
        ]),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final List<Widget> children;

  const _EmergencyCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: Color(0xFFE6EDF3),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ]),
          const Divider(height: 16, color: Color(0xFF30363D)),
          ...children,
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFF8B949E), fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: Color(0xFFE6EDF3),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

class _InstructionItem extends StatelessWidget {
  final String step;
  final String text;
  const _InstructionItem(this.step, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF3FB950).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Text(step,
              style: const TextStyle(
                  color: Color(0xFF3FB950),
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFF8B949E), fontSize: 12)),
        ),
      ]),
    );
  }
}

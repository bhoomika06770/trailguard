import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StartSessionDialog extends StatefulWidget {
  const StartSessionDialog({super.key});

  @override
  State<StartSessionDialog> createState() => _StartSessionDialogState();
}

class _StartSessionDialogState extends State<StartSessionDialog> {
  final _nameCtrl = TextEditingController();
  final _destLatCtrl = TextEditingController();
  final _destLonCtrl = TextEditingController();
  bool _hasDestination = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text =
        'Hike ${DateFormat('MMM d · HH:mm').format(DateTime.now())}';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _destLatCtrl.dispose();
    _destLonCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    double? destLat;
    double? destLon;
    if (_hasDestination) {
      destLat = double.tryParse(_destLatCtrl.text);
      destLon = double.tryParse(_destLonCtrl.text);
      if (destLat == null || destLon == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Enter valid destination coordinates')),
        );
        return;
      }
    }

    Navigator.pop(context, {
      'name': _nameCtrl.text.trim().isEmpty
          ? 'Hike ${DateTime.now().hour}:${DateTime.now().minute}'
          : _nameCtrl.text.trim(),
      'destLat': destLat,
      'destLon': destLon,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C2128),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.hiking, color: Color(0xFF3FB950), size: 24),
        SizedBox(width: 10),
        Text('Start New Hike',
            style: TextStyle(
                color: Color(0xFFE6EDF3),
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ]),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Color(0xFFE6EDF3)),
            decoration: const InputDecoration(
              labelText: 'Hike Name',
              prefixIcon: Icon(Icons.label_outline,
                  color: Color(0xFF8B949E), size: 20),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Set Destination Waypoint',
                style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 14)),
            subtitle: const Text('For progress tracking & navigation',
                style:
                    TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
            value: _hasDestination,
            activeColor: const Color(0xFF3FB950),
            onChanged: (v) => setState(() => _hasDestination = v),
          ),
          if (_hasDestination) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _destLatCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: const TextStyle(color: Color(0xFFE6EDF3)),
              decoration: const InputDecoration(
                labelText: 'Destination Latitude',
                prefixIcon: Icon(Icons.gps_fixed,
                    color: Color(0xFF8B949E), size: 20),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _destLonCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: const TextStyle(color: Color(0xFFE6EDF3)),
              decoration: const InputDecoration(
                labelText: 'Destination Longitude',
                prefixIcon: Icon(Icons.gps_fixed,
                    color: Color(0xFF8B949E), size: 20),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3FB950).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF3FB950).withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline,
                  color: Color(0xFF3FB950), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'TrailGuard will monitor your movement and alert you if disorientation is detected.',
                  style: TextStyle(
                      color: Color(0xFF8B949E), fontSize: 11),
                ),
              ),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFF8B949E))),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Start Hike'),
        ),
      ],
    );
  }
}

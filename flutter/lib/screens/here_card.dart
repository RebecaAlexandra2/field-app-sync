import 'package:flutter/material.dart';

import '../permissions.dart';

class HereCard extends StatefulWidget {
  const HereCard({super.key});

  @override
  State<HereCard> createState() => _HereCardState();
}

class _HereCardState extends State<HereCard> {
  String _location = 'not asked yet';
  bool _busy = false;

  Future<void> _requestLocation() async {
    setState(() => _busy = true);

    try {
      final allowed = await ensureLocation(context);

      if (!mounted) return;

      setState(() {
        _location = allowed ? 'allowed' : 'not allowed';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _location = 'error: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Location: $_location'),
            // image_picker foloseste camera sistemului;
            // aplicatia nu cere permisiunea CAMERA.
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy ? null : _requestLocation,
              child: Text(_busy ? 'Checking…' : 'Where am I?'),
            ),
          ],
        ),
      ),
    );
  }
}

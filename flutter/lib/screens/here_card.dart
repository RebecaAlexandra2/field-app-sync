import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../location.dart';

class HereCard extends ConsumerStatefulWidget {
  const HereCard({super.key});

  @override
  ConsumerState<HereCard> createState() => _HereCardState();
}

class _HereCardState extends ConsumerState<HereCard> {
  bool _busy = false;
  String? _error;

  Future<void> _locate() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final fix = await locate(context, ref);

      if (!mounted) return;

      if (fix == null) {
        setState(() => _error = 'Location: not allowed');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not get location: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fix = ref.watch(fixProvider);
    final heading =
        fix == null ? null : ref.watch(headingProvider).value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              fix != null
                  ? 'You: ${fix.lat.toStringAsFixed(5)}, '
                      '${fix.lng.toStringAsFixed(5)} · '
                      '±${fix.accuracy.round()} m'
                  : _busy
                      ? 'Finding you…'
                      : 'No position yet',
            ),
            const SizedBox(height: 8),
            Text(
              heading != null
                  ? 'Facing: ${heading.round()}° ${compassPoint(heading)}'
                  : kIsWeb
                      ? 'Facing: no compass on the web'
                      : 'Facing: waiting for the compass',
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy ? null : _locate,
              child: Text(_busy ? 'Finding you…' : 'Where am I?'),
            ),
          ],
        ),
      ),
    );
  }
}
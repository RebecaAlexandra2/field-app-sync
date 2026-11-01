import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> ensureLocation(BuildContext context) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    if (context.mounted) {
      await _offer(
        context,
        'Location is off on this phone',
        Geolocator.openLocationSettings,
      );
    }
    return false;
  }

  final status = await Permission.location.request();

  if (status.isGranted || status.isLimited) return true;

  if (status.isPermanentlyDenied && context.mounted) {
    await _offer(
      context,
      'Location is off for the field app',
      openAppSettings,
    );
  }

  return false;
}

Future<void> _offer(
  BuildContext context,
  String title,
  Future<bool> Function() open,
) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: const Text(
          'The field app tags your photos and new pins with where you stand. '
          'You can turn it on in Settings → Permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              open();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
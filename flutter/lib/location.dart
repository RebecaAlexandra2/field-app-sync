import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'permissions.dart';

double normalizeHeading(double h) => ((h % 360) + 360) % 360;

const _points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

String compassPoint(double h) =>
    _points[(normalizeHeading(h) / 45).round() % 8];

class Fix {
  const Fix(this.lat, this.lng, this.accuracy, this.at);

  final double lat;
  final double lng;
  final double accuracy;
  final String at;
}

class FixNotifier extends Notifier<Fix?> {
  @override
  Fix? build() => null;

  void set(Fix fix) => state = fix;
}

final fixProvider = NotifierProvider<FixNotifier, Fix?>(
  FixNotifier.new,
);

final headingProvider = StreamProvider.autoDispose<double?>((ref) {
  if (kIsWeb) return Stream.value(null);

  final events = FlutterCompass.events;
  if (events == null) return Stream.value(null);

  return events.map((event) {
    final heading = event.heading;
    return heading == null ? null : normalizeHeading(heading);
  });
});

Future<Fix?> locate(BuildContext context, WidgetRef ref) async {
  if (!await ensureLocation(context)) return null;
  if (!context.mounted) return null;

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
    ),
  );

  final fix = Fix(
    position.latitude,
    position.longitude,
    position.accuracy,
    position.timestamp.toUtc().toIso8601String(),
  );

  if (!context.mounted) return null;

  ref.read(fixProvider.notifier).set(fix);
  return fix;
}
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../contract/contract.dart';
import '../location.dart';
import '../providers.dart';
import '../session.dart';
import 'status_chip.dart';

const tiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const bucharest = LatLng(44.4355, 26.1025);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _busy = false;

  Future<void> _addMissed() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final fix = await locate(context, ref);
      if (fix == null || !mounted) return;

      final id = await ref
          .read(databaseProvider)
          .addMissedEntrance(
            fix.lat,
            fix.lng,
            const Uuid().v4(),
            const Uuid().v4(),
          );

      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {
        // Cladirea este deja salvata.
      }

      if (mounted) {
        context.push('/entrances/$id/survey');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add building: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entrances = ref.watch(entrancesProvider).value ?? const <Entrance>[];

    final done = entrances
        .where((e) => e.surveyStatus != SurveyStatus.not_started)
        .length;

    final links =
        ref.watch(connectivityProvider).value ??
        const [ConnectivityResult.other];

    final online = !links.contains(ConnectivityResult.none);
    final token = ref.watch(tokenProvider).value;

    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(initialCenter: bucharest, initialZoom: 13),
          children: [
            TileLayer(
              urlTemplate: tiles,
              userAgentPackageName: 'ro.rau.field_app',
            ),
            MarkerLayer(
              markers: [
                for (final e in entrances)
                  Marker(
                    point: LatLng(
                      e.correctedLat ?? e.lat,
                      e.correctedLng ?? e.lng,
                    ),
                    width: 44,
                    height: 44,
                    child: Semantics(
                      button: true,
                      label: '${e.street} ${e.number}, ${e.entranceName}',
                      child: GestureDetector(
                        onTap: () => context.push('/entrances/${e.id}'),
                        child: Icon(
                          Icons.location_on,
                          size: 40,
                          color: statusColor[e.surveyStatus],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entrances.length} entrances · $done surveyed',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: online
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF6B7280),
                            label: Text(
                              online
                                  ? 'Online · ${links.isEmpty ? 'unknown' : links.first.name}'
                                  : 'Offline — saved on the phone',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            token == null
                                ? 'token …'
                                : 'token ••••${token.substring(token.length - 4)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: FloatingActionButton.extended(
            tooltip: 'Add a building that is not on the map, here',
            onPressed: _busy ? null : _addMissed,
            icon: const Icon(Icons.add_location_alt),
            label: Text(_busy ? 'Finding you...' : 'Missed building'),
          ),
        ),
      ],
    );
  }
}

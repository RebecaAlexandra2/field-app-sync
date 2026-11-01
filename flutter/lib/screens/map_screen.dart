import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../contract/contract.dart';
import '../providers.dart';
import 'status_chip.dart';

const tiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const bucharest = LatLng(44.4355, 26.1025);

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entrances =
        ref.watch(entrancesProvider).value ?? const <Entrance>[];

    final done = entrances
        .where((e) => e.surveyStatus != SurveyStatus.not_started)
        .length;

    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: bucharest,
            initialZoom: 13,
          ),
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
                  child: Text(
                    '${entrances.length} entrances · $done surveyed',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
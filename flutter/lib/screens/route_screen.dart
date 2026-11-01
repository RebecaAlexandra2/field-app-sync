import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../contract/contract.dart';
import '../providers.dart';
import 'status_chip.dart';

class RouteScreen extends ConsumerWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(fixturesProvider);
    final found = ref.watch(entrancesProvider);

    final route = f.routes.firstWhere((r) => r.workerId == f.me);

    final stops = f.stops.where((s) => s.routeId == route.id).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    if (found.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (found.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('My route')),
        body: Center(
          child: Text('Could not load entrances: ${found.error}'),
        ),
      );
    }

    final byId = {
      for (final e in found.value ?? const <Entrance>[]) e.id: e,
    };

    return Scaffold(
      appBar: AppBar(title: Text('${route.name} · ${route.date}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: stops.length,
        itemBuilder: (context, i) {
          final stop = stops[i];
          final e = byId[stop.entranceId];

          if (e == null) {
            return Card(
              child: ListTile(
                leading: Text('${stop.order}'),
                title: const Text('Entrance unavailable'),
              ),
            );
          }

          return Card(
            child: ListTile(
              leading: Text(
                '${stop.order}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              title: Text('${e.street} ${e.number}'),
              subtitle: Text(e.entranceName),
              trailing: StatusChip(status: e.surveyStatus),
              onTap: () => context.push('/entrances/${e.id}'),
            ),
          );
        },
      ),
    );
  }
}

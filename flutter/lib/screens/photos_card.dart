import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../location.dart';
import '../photos.dart';
import '../providers.dart';

class PhotosCard extends ConsumerStatefulWidget {
  const PhotosCard({super.key, required this.entranceId});

  final String entranceId;

  @override
  ConsumerState<PhotosCard> createState() => _PhotosCardState();
}

class _PhotosCardState extends ConsumerState<PhotosCard> {
  ExifSummary? _exif;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<ExifSummary?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final summary = await action();

      if (summary != null && mounted) {
        setState(() => _exif = summary);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not save photo: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final found = ref.watch(photosProvider(widget.entranceId));
    final list = found.value ?? const [];
    final muted = Theme.of(context).textTheme.bodySmall;
    final errorColor = Theme.of(context).colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Photos (${list.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => takePhoto(context, ref, widget.entranceId),
                      ),
              child: Text(_busy ? 'Saving…' : 'Take a photo'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => pickPhoto(context, ref, widget.entranceId),
                      ),
              child: const Text('From the gallery'),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: errorColor)),
            if (found.hasError)
              Text(
                'Could not load photos: ${found.error}',
                style: TextStyle(color: errorColor),
              ),
            if (_exif case final x?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Last file's EXIF: ${x.camera ?? 'no camera name'} · "
                  "${x.shotAt ?? 'no time'} · "
                  "GPS in EXIF: ${x.gpsInExif ? 'yes' : 'no'}",
                  style: muted,
                ),
              ),
            for (final p in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(
                    dimension: 56,
                    child: kIsWeb
                        ? Image.network(p.localUri, fit: BoxFit.cover)
                        : Image.file(File(p.localUri), fit: BoxFit.cover),
                  ),
                ),
                title: Text(
                  DateTime.parse(p.takenAt)
                      .toLocal()
                      .toString()
                      .substring(0, 19),
                ),
                subtitle: Text(
                  [
                    p.lat == null || p.lng == null
                        ? 'no position'
                        : '${p.lat!.toStringAsFixed(5)}, '
                            '${p.lng!.toStringAsFixed(5)}',
                    if (p.heading case final h?)
                      'facing ${h.round()}° ${compassPoint(h)}',
                    p.fileName,
                  ].join(' · '),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
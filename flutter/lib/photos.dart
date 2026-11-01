import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:drift/drift.dart' show Value;
import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'db/database.dart';
import 'location.dart';
import 'providers.dart';

class ExifSummary {
  const ExifSummary(this.camera, this.shotAt, this.gpsInExif);

  final String? camera;
  final String? shotAt;
  final bool gpsInExif;
}

Future<ExifSummary> readExif(List<int> bytes) async {
  final tags = await readExifFromBytes(bytes);

  String? s(String key) => tags[key]?.printable;

  final camera = [
    s('Image Make'),
    s('Image Model'),
  ].whereType<String>().join(' ');

  return ExifSummary(
    camera.isEmpty ? null : camera,
    s('EXIF DateTimeOriginal') ?? s('Image DateTime'),
    tags.containsKey('GPS GPSLatitude'),
  );
}

Future<String> _keep(
  XFile picked,
  List<int> bytes,
  String id,
) async {
  if (kIsWeb) {
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  final docs = await getApplicationDocumentsDirectory();
  final folder = await Directory(
    '${docs.path}/photos',
  ).create(recursive: true);

  final file = await File(picked.path).copy('${folder.path}/$id.jpg');
  return file.path;
}

Future<ExifSummary> _save(
  AppDatabase db,
  String entranceId,
  XFile picked, {
  Fix? where,
  double? heading,
  required String takenAt,
}) async {
  final id = const Uuid().v4();
  final now = DateTime.now().toUtc().toIso8601String();
  final bytes = await picked.readAsBytes();
  final localUri = await _keep(picked, bytes, id);

  await db.into(db.photos).insert(
        PhotosCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          entranceId: entranceId,
          fileName: '$id.jpg',
          takenAt: takenAt,
          lat: Value(where?.lat),
          lng: Value(where?.lng),
          heading: Value(heading),
          localUri: localUri,
        ),
      );

  return readExif(bytes);
}

Future<ExifSummary?> takePhoto(
  BuildContext context,
  WidgetRef ref,
  String entranceId,
) async {
  final db = ref.read(databaseProvider);
  final picked = await ImagePicker().pickImage(
    source: ImageSource.camera,
  );

  if (picked == null || !context.mounted) return null;

  final takenAt = DateTime.now().toUtc().toIso8601String();
  final fix = await locate(context, ref).catchError((_) => null);

  if (!context.mounted) return null;

  final heading = fix == null
      ? null
      : ref.read(headingProvider).value;

  return _save(
    db,
    entranceId,
    picked,
    where: fix,
    heading: heading,
    takenAt: takenAt,
  );
}
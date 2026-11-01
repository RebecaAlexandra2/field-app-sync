import { eq } from 'drizzle-orm';
import { useLiveQuery } from 'drizzle-orm/expo-sqlite';
import * as Crypto from 'expo-crypto';
import { Directory, File, Paths } from 'expo-file-system';
import * as ImagePicker from 'expo-image-picker';
import { Platform } from 'react-native';
import { db } from './db/db';
import { type PhotoRow, photos } from './db/schema';
import { locate } from './location';
import { ensureCamera } from './permissions';
import { useField } from './store';

export type ExifSummary = {
  camera: string | null;
  shotAt: string | null;
  gpsInExif: boolean;
};

export function readExif(
  exif: Record<string, unknown> | null | undefined,
): ExifSummary {
  const s = (key: string) =>
    exif?.[key] == null ? null : String(exif[key]);

  return {
    camera: [s('Make'), s('Model')].filter(Boolean).join(' ') || null,
    shotAt: s('DateTimeOriginal') ?? s('DateTime'),
    gpsInExif: exif?.GPSLatitude != null,
  };
}

function keep(uri: string, id: string): string {
  if (Platform.OS === 'web') return uri;

  const folder = new Directory(Paths.document, 'photos');
  folder.create({ idempotent: true, intermediates: true });

  const file = new File(folder, `${id}.jpg`);
  new File(uri).copySync(file);

  return file.uri;
}

async function save(
  entranceId: string,
  asset: ImagePicker.ImagePickerAsset,
  where: { lat: number; lng: number } | null,
  heading: number | null,
  takenAt: string,
) {
  const id = Crypto.randomUUID();
  const now = new Date().toISOString();

  const row: typeof photos.$inferInsert = {
    id,
    createdAt: now,
    updatedAt: now,
    entranceId,
    fileName: `${id}.jpg`,
    remoteUrl: null,
    takenAt,
    lat: where?.lat ?? null,
    lng: where?.lng ?? null,
    heading,
    uploadState: 'pending',
    reviewStatus: 'pending',
    reviewNote: null,
    reviewedBy: null,
    replacesPhotoId: null,
    syncState: 'pending',
    lastError: null,
    localUri: keep(asset.uri, id),
  };

  await db.insert(photos).values(row);
  return readExif(asset.exif);
}

export async function takePhoto(
  entranceId: string,
): Promise<ExifSummary | null> {
  if (!(await ensureCamera())) return null;

  const result = await ImagePicker.launchCameraAsync({
    mediaTypes: ['images'],
    exif: true,
    quality: 1,
  });

  if (result.canceled) return null;

  const takenAt = new Date().toISOString();
  const fix = await locate().catch(() => null);

  return save(
    entranceId,
    result.assets[0],
    fix,
    fix ? useField.getState().heading : null,
    takenAt,
  );
}

export function usePhotos(entranceId: string): PhotoRow[] {
  return useLiveQuery(
    db.select().from(photos).where(eq(photos.entranceId, entranceId)),
    [entranceId],
  ).data;
}

function exifTime(shotAt: string | null): string | null {
  const m = shotAt?.match(
    /^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})/,
  );

  if (!m) return null;

  const [y, mo, d, h, mi, se] = m.slice(1).map(Number);
  return new Date(y, mo - 1, d, h, mi, se).toISOString();
}

export async function pickPhoto(
  entranceId: string,
): Promise<ExifSummary | null> {
  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ['images'],
    exif: true,
    quality: 1,
  });

  if (result.canceled) return null;

  const asset = result.assets[0];
  const takenAt =
    exifTime(readExif(asset.exif).shotAt) ?? new Date().toISOString();

  return save(entranceId, asset, null, null, takenAt);
}
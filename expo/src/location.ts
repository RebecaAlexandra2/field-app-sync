import * as Location from 'expo-location';
import { useEffect } from 'react';
import { Platform } from 'react-native';
import { ensureLocation } from './permissions';
import { type Fix, useField } from './store';

export const normalizeHeading = (h: number) =>
  ((h % 360) + 360) % 360;

const POINTS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

export const compassPoint = (h: number) =>
  POINTS[Math.round(normalizeHeading(h) / 45) % 8];

export async function locate(): Promise<Fix | null> {
  if (!(await ensureLocation())) return null;

  const p = await Location.getCurrentPositionAsync({
    accuracy: Location.Accuracy.High,
  });

  const fix: Fix = {
    lat: p.coords.latitude,
    lng: p.coords.longitude,
    accuracy: p.coords.accuracy,
    at: new Date(p.timestamp).toISOString(),
  };

  useField.getState().setFix(fix);
  return fix;
}

export function useHeading(allowed: boolean) {
  useEffect(() => {
    if (!allowed || Platform.OS === 'web') return;

    let subscription: Location.LocationSubscription | undefined;
    let stopped = false;

    Location.watchHeadingAsync((h) => {
      const raw = h.trueHeading >= 0 ? h.trueHeading : h.magHeading;
      useField.getState().setHeading(normalizeHeading(raw));
    }).then((s) => {
      if (stopped) s.remove();
      else subscription = s;
    });

    return () => {
      stopped = true;
      subscription?.remove();
    };
  }, [allowed]);
}
import * as Haptics from 'expo-haptics';
import { router } from 'expo-router';
import { useState } from 'react';
import { Alert, Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { EntranceMap } from '../../components/EntranceMap';
import { locate } from '../../location';
import { addMissedEntrance, useEntrances } from '../../store';
import { useColors } from '../../theme';

export default function MapScreen() {
  const insets = useSafeAreaInsets();
  const colors = useColors();
  const entrances = useEntrances();
  const done = entrances.filter(
    (e) => e.surveyStatus !== 'not_started',
  ).length;
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const addMissed = async () => {
    setBusy(true);
    setError(null);

    try {
      const fix = await locate();

      if (!fix) {
        setError('Location: not allowed');
        return;
      }

      const id = await addMissedEntrance(fix);

      try {
        await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      } catch {
        // Clădirea este deja salvată dacă vibrația nu este disponibilă.
      }

      router.push(`/survey/${id}`);
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      setError(message);
      Alert.alert('Could not add building', message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <View style={[styles.screen, { backgroundColor: colors.background }]}>
      <EntranceMap />

      <View
        style={[
          styles.banner,
          { top: insets.top + 8, backgroundColor: colors.card },
        ]}
      >
        <Text style={{ color: colors.text, fontWeight: '600' }}>
          {entrances.length} entrances · {done} surveyed
        </Text>

        {error && (
          <Text style={{ color: colors.error }}>{error}</Text>
        )}
      </View>

      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Add a building that is not on the map, here"
        disabled={busy}
        onPress={addMissed}
        style={[
          styles.fab,
          {
            backgroundColor: colors.primary,
            opacity: busy ? 0.6 : 1,
          },
        ]}
      >
        <Text style={{ color: colors.onPrimary, fontWeight: '700' }}>
          {busy ? 'Finding you…' : '+ Missed building'}
        </Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  fab: {
    position: 'absolute',
    right: 16,
    bottom: 32,
    minHeight: 52,
    paddingHorizontal: 18,
    borderRadius: 26,
    justifyContent: 'center',
        zIndex: 100,
    elevation: 20,
  },
  banner: {
    position: 'absolute',
    left: 16,
    right: 16,
    padding: 12,
    borderRadius: 12,
    alignItems: 'center',
    gap: 4,
  },
});
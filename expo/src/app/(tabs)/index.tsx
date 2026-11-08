import { signOut } from 'firebase/auth';
import { auth } from '../../firebase';
import { SyncBar } from '../../components/SyncBar';
import * as Haptics from 'expo-haptics';
import { useNetworkState } from 'expo-network';
import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import {
  Alert,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { EntranceMap } from '../../components/EntranceMap';
import { locate } from '../../location';
import { lastTab } from '../../session';
import { addMissedEntrance, useEntrances } from '../../store';
import { useColors } from '../../theme';

export default function MapScreen() {
  const [reopen] = useState(() => Platform.OS === 'web' ? null : lastTab.get());
  useEffect(() => {
    if (reopen === '/route' || reopen === '/inbox') router.replace(reopen);
  }, [reopen]);
  const insets = useSafeAreaInsets();
  const colors = useColors();
  const entrances = useEntrances();
  const done = entrances.filter(
    (e) => e.surveyStatus !== 'not_started',
  ).length;

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const network = useNetworkState();
  

  const online =
    network.isConnected !== false &&
    network.isInternetReachable !== false;

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
        // Cladirea este deja salvata.
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
      <View
        style={[
          styles.banner,
          { top: insets.top + 8, backgroundColor: colors.card },
          Platform.OS === 'web' && { position: 'relative', top: 0, left: 0, right: 0, margin: 16 },
        ]}
      >
        <Text style={{ color: colors.text, fontWeight: '600' }}>
          {entrances.length} entrances · {done} surveyed
        </Text>

        <View style={styles.chips}>
          <View
            style={[
              styles.chip,
              { backgroundColor: online ? '#16a34a' : '#6b7280' },
            ]}
          >
            <Text style={styles.chipText}>
              {online
                ? `Online · ${network.type ?? '…'}`
                : 'Offline — saved on the phone'}
            </Text>
          </View>

          <Text style={{ color: colors.muted, fontSize: 12 }}>
            {auth.currentUser?.email}</Text>
        </View>

        <Pressable accessibilityRole="button" onPress={() => signOut(auth)}><Text style={{ color: colors.primary }}>Sign out</Text></Pressable>
        <SyncBar />
        {error && (
          <Text style={{ color: colors.error }}>{error}</Text>
        )}
      </View>

      <View style={{ flex: 1 }}><EntranceMap /></View>

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
    gap: 8,
    zIndex: 100,
    elevation: 20,
  },
  chips: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    flexWrap: 'wrap',
    gap: 8,
  },
  chip: {
    borderRadius: 12,
    paddingHorizontal: 10,
    paddingVertical: 4,
  },
  chipText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
});

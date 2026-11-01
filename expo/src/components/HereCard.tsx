import { useState } from 'react';
import { Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { compassPoint, locate, useHeading } from '../location';
import { useField } from '../store';
import { useColors } from '../theme';

export function HereCard() {
  const colors = useColors();
  const fix = useField((s) => s.fix);
  const heading = useField((s) => s.heading);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useHeading(fix !== null);

  return (
    <View style={[styles.card, { borderColor: colors.border }]}>
      <Text style={{ color: colors.text }}>
        {fix
          ? `You: ${fix.lat.toFixed(5)}, ${fix.lng.toFixed(5)} · ${
              fix.accuracy === null
                ? 'accuracy unknown'
                : `±${Math.round(fix.accuracy)} m`
            }`
          : busy
            ? 'Finding you…'
            : 'No position yet'}
      </Text>

      <Text style={{ color: colors.text }}>
        {heading === null
          ? Platform.OS === 'web'
            ? 'Facing: no compass on the web'
            : 'Facing: waiting for the compass'
          : `Facing: ${Math.round(heading)}° ${compassPoint(heading)}`}
      </Text>

      {error && <Text style={{ color: colors.error }}>{error}</Text>}

      <Pressable
        accessibilityRole="button"
        style={[styles.button, { borderColor: colors.primary }]}
        disabled={busy}
        onPress={async () => {
          setBusy(true);
          setError(null);

          try {
            const position = await locate();
            if (!position) setError('Location: not allowed');
          } catch (e) {
            setError(e instanceof Error ? e.message : String(e));
          } finally {
            setBusy(false);
          }
        }}
      >
        <Text style={{ color: colors.primary, fontWeight: '700' }}>
          Where am I?
        </Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    alignSelf: 'stretch',
    borderWidth: 1,
    borderRadius: 12,
    padding: 12,
    gap: 8,
  },
  button: {
    minHeight: 48,
    borderWidth: 2,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
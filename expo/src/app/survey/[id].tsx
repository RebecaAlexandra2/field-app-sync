import { auth } from '../../firebase';
import { pushSurveys } from '../../sync';
import { useForm } from '@tanstack/react-form';
import * as Haptics from 'expo-haptics';
import { router, useLocalSearchParams } from 'expo-router';
import { useState, type ReactNode } from 'react';
import {
  Pressable,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from 'react-native';
import { KeyboardAwareScrollView } from 'react-native-keyboard-controller';
import { type Entrance, EntranceSurvey } from '../../contract/contract';
import { locate } from '../../location';
import { submitSurvey, useEntrance } from '../../store';
import { type Colors, useColors } from '../../theme';

const toNumber = (text: string) =>
  text.trim() === '' ? Number.NaN : Number(text);

const toNullable = (text: string) =>
  text.trim() === '' ? null : Number(text);

const fromNumber = (n: number | null) =>
  n === null || Number.isNaN(n) ? '' : String(n);

export default function SurveyScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const entrance = useEntrance(id);

  if (!entrance) return null;

  return <SurveyForm id={id} entrance={entrance} />;
}

function SurveyForm({ id, entrance }: { id: string; entrance: Entrance }) {
  const colors = useColors();
  const [locating, setLocating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const form = useForm({
    defaultValues: {
      coordsConfirmed: entrance.coordsConfirmed,
      correctedLat: entrance.correctedLat,
      correctedLng: entrance.correctedLng,
      street: entrance.street,
      number: entrance.number,
      entranceName: entrance.entranceName,
      addressConfirmed: entrance.addressConfirmed,
      stories: entrance.stories ?? Number.NaN,
      flats: entrance.flats ?? Number.NaN,
      elevators: entrance.elevators ?? Number.NaN,
      yearBuilt: entrance.yearBuilt ?? Number.NaN,
      groundFloorCommercial: entrance.groundFloorCommercial ?? false,
      comment: entrance.comment,
    },
    validators: { onChange: EntranceSurvey },
    onSubmit: async ({ value }) => {
      setError(null);

      try {
        await submitSurvey(id, EntranceSurvey.parse(value));
      const uid = auth.currentUser?.uid;
      if (uid) void pushSurveys(uid).catch(console.warn);
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
        return;
      }

      try {
        await Haptics.notificationAsync(
          Haptics.NotificationFeedbackType.Success,
        );
      } catch {
        // Salvarea rămâne validă dacă vibrația nu este disponibilă.
      }

      router.back();
    },
  });

  const input = [
    styles.input,
    { color: colors.text, borderColor: colors.border },
  ];

  return (
    <KeyboardAwareScrollView
      bottomOffset={80}
      keyboardShouldPersistTaps="handled"
      style={{ flex: 1, backgroundColor: colors.background }}
    >
      <View style={styles.content}>
        <form.Field name="coordsConfirmed">
          {(field) => (
            <Row
              label="The pin is at the door"
              colors={colors}
              errors={field.state.meta.errors}
              touched={field.state.meta.isTouched}
            >
              <Switch
                value={field.state.value}
                onValueChange={field.handleChange}
              />
            </Row>
          )}
        </form.Field>

        <form.Subscribe selector={(s) => s.values.coordsConfirmed}>
          {(confirmed) =>
            confirmed ? null : (
              <View style={styles.pair}>
                <form.Field name="correctedLat">
                  {(field) => (
                    <Labeled
                      label="Corrected latitude"
                      colors={colors}
                      errors={field.state.meta.errors}
                      touched={field.state.meta.isTouched}
                    >
                      <TextInput
                        style={input}
                        keyboardType="decimal-pad"
                        value={fromNumber(field.state.value)}
                        onChangeText={(t) =>
                          field.handleChange(toNullable(t))
                        }
                        onBlur={field.handleBlur}
                      />
                    </Labeled>
                  )}
                </form.Field>

                <form.Field name="correctedLng">
                  {(field) => (
                    <Labeled
                      label="Corrected longitude"
                      colors={colors}
                      errors={field.state.meta.errors}
                      touched={field.state.meta.isTouched}
                    >
                      <TextInput
                        style={input}
                        keyboardType="decimal-pad"
                        value={fromNumber(field.state.value)}
                        onChangeText={(t) =>
                          field.handleChange(toNullable(t))
                        }
                        onBlur={field.handleBlur}
                      />
                    </Labeled>
                  )}
                </form.Field>

                <Pressable
                  accessibilityRole="button"
                  disabled={locating}
                  style={[
                    styles.outline,
                    { borderColor: colors.primary },
                  ]}
                  onPress={async () => {
                    setLocating(true);
                    setError(null);

                    try {
                      const fix = await locate();

                      if (!fix) {
                        setError('Location: not allowed');
                        return;
                      }

                      form.setFieldValue(
                        'correctedLat',
                        Number(fix.lat.toFixed(5)),
                      );
                      form.setFieldValue(
                        'correctedLng',
                        Number(fix.lng.toFixed(5)),
                      );
                    } catch (e) {
                      setError(
                        e instanceof Error ? e.message : String(e),
                      );
                    } finally {
                      setLocating(false);
                    }
                  }}
                >
                  <Text
                    style={{ color: colors.primary, fontWeight: '700' }}
                  >
                    {locating ? 'Finding you…' : 'Use my position'}
                  </Text>
                </Pressable>
              </View>
            )
          }
        </form.Subscribe>

        {(['street', 'number', 'entranceName'] as const).map((name) => (
          <form.Field key={name} name={name}>
            {(field) => (
              <Labeled
                label={{
                  street: 'Street',
                  number: 'Number',
                  entranceName: 'Entrance',
                }[name]}
                colors={colors}
                errors={field.state.meta.errors}
                touched={field.state.meta.isTouched}
              >
                <TextInput
                  style={input}
                  value={field.state.value}
                  onChangeText={field.handleChange}
                  onBlur={field.handleBlur}
                />
              </Labeled>
            )}
          </form.Field>
        ))}

        <form.Field name="addressConfirmed">
          {(field) => (
            <Row
              label="I checked the address"
              colors={colors}
              errors={field.state.meta.errors}
              touched={field.state.meta.isTouched}
            >
              <Switch
                value={field.state.value}
                onValueChange={field.handleChange}
              />
            </Row>
          )}
        </form.Field>

        {(
          [
            ['stories', 'Stories'],
            ['flats', 'Flats'],
            ['elevators', 'Elevators'],
            ['yearBuilt', 'Year built'],
          ] as const
        ).map(([name, label]) => (
          <form.Field key={name} name={name}>
            {(field) => (
              <Labeled
                label={label}
                colors={colors}
                errors={field.state.meta.errors}
                touched={field.state.meta.isTouched}
              >
                <TextInput
                  style={input}
                  keyboardType="number-pad"
                  value={fromNumber(field.state.value)}
                  onChangeText={(t) => field.handleChange(toNumber(t))}
                  onBlur={field.handleBlur}
                />
              </Labeled>
            )}
          </form.Field>
        ))}

        <form.Field name="groundFloorCommercial">
          {(field) => (
            <Row
              label="Shops on the ground floor"
              colors={colors}
              errors={field.state.meta.errors}
              touched={field.state.meta.isTouched}
            >
              <Switch
                value={field.state.value}
                onValueChange={field.handleChange}
              />
            </Row>
          )}
        </form.Field>

        <form.Field name="comment">
          {(field) => (
            <Labeled
              label="Comment"
              colors={colors}
              errors={field.state.meta.errors}
              touched={field.state.meta.isTouched}
            >
              <TextInput
                style={[input, styles.multiline]}
                multiline
                value={field.state.value ?? ''}
                onChangeText={(t) =>
                  field.handleChange(t === '' ? null : t)
                }
                onBlur={field.handleBlur}
              />
            </Labeled>
          )}
        </form.Field>

        {error && <Text style={{ color: colors.error }}>{error}</Text>}

        <form.Subscribe
          selector={(s) => [s.canSubmit, s.isSubmitting] as const}
        >
          {([canSubmit, isSubmitting]) => (
            <Pressable
              accessibilityRole="button"
              accessibilityState={{
                disabled: !canSubmit || isSubmitting,
              }}
              disabled={!canSubmit || isSubmitting}
              onPress={() => form.handleSubmit()}
              style={[
                styles.button,
                {
                  backgroundColor: canSubmit
                    ? colors.primary
                    : colors.border,
                },
              ]}
            >
              <Text
                style={{ color: colors.onPrimary, fontWeight: '700' }}
              >
                {isSubmitting ? 'Saving…' : 'Submit survey'}
              </Text>
            </Pressable>
          )}
        </form.Subscribe>
      </View>
    </KeyboardAwareScrollView>
  );
}

type FieldProps = {
  label: string;
  colors: Colors;
  errors: unknown[];
  touched: boolean;
  children: ReactNode;
};

function Errors({
  errors,
  touched,
  colors,
}: Omit<FieldProps, 'label' | 'children'>) {
  if (!touched || errors.length === 0) return null;

  const text = errors
    .map((e) =>
      typeof e === 'object' && e && 'message' in e
        ? String(e.message)
        : String(e),
    )
    .join(' · ');

  return <Text style={{ color: colors.error }}>{text}</Text>;
}

function Labeled({ label, colors, children, ...rest }: FieldProps) {
  return (
    <View style={styles.field}>
      <Text style={{ color: colors.muted }}>{label}</Text>
      {children}
      <Errors colors={colors} {...rest} />
    </View>
  );
}

function Row({ label, colors, children, ...rest }: FieldProps) {
  return (
    <View style={styles.field}>
      <View style={styles.row}>
        <Text style={{ color: colors.text, flex: 1 }}>{label}</Text>
        {children}
      </View>
      <Errors colors={colors} {...rest} />
    </View>
  );
}

const styles = StyleSheet.create({
  content: { padding: 16, gap: 14 },
  field: { gap: 4 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    minHeight: 48,
  },
  pair: { gap: 14 },
  input: {
    borderWidth: 1,
    borderRadius: 10,
    paddingHorizontal: 12,
    minHeight: 48,
    fontSize: 16,
  },
  multiline: {
    minHeight: 96,
    textAlignVertical: 'top',
    paddingTop: 12,
  },
  outline: {
    minHeight: 48,
    borderWidth: 2,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  button: {
    minHeight: 52,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 8,
  },
});
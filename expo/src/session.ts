import * as Crypto from 'expo-crypto';
import * as SecureStore from 'expo-secure-store';
import Storage from 'expo-sqlite/kv-store';
import { useEffect, useState } from 'react';
import { Platform } from 'react-native';

const TOKEN = 'field.token';
const LAST_TAB = 'field.lastTab';

async function loadToken(): Promise<string> {
  const web = Platform.OS === 'web';

  const get = (key: string) =>
    web ? Storage.getItem(key) : SecureStore.getItemAsync(key);

  const set = (key: string, value: string) =>
    web
      ? Storage.setItem(key, value)
      : SecureStore.setItemAsync(key, value);

  const saved = await get(TOKEN);

  if (saved) return saved;

  const token = `placeholder-${Crypto.randomUUID()}`;
  await set(TOKEN, token);

  return token;
}

export function useToken(): string | null {
  const [token, setToken] = useState<string | null>(null);

  useEffect(() => {
    loadToken().then(setToken);
  }, []);

  return token;
}

export const lastTab = {
  get: () => Storage.getItemSync(LAST_TAB),
  set: (path: string) => Storage.setItemSync(LAST_TAB, path),
};
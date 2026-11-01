import {
  drizzle,
  type ExpoSQLiteDatabase,
} from 'drizzle-orm/expo-sqlite';
import { migrate } from 'drizzle-orm/expo-sqlite/migrator';
import { openDatabaseAsync } from 'expo-sqlite';
import migrations from '../../drizzle/migrations';
import * as schema from './schema';
import { seedIfEmpty } from './seed';

export let db: ExpoSQLiteDatabase<typeof schema>;

export async function openDb() {
  const sqlite = await openDatabaseAsync('field.db', {
    enableChangeListener: true,
  });

  db = drizzle(sqlite, { schema });

  await migrate(db, migrations);
  await seedIfEmpty(db);
}
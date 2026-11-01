import { eq } from 'drizzle-orm';
import { useLiveQuery } from 'drizzle-orm/expo-sqlite';
import { create } from 'zustand';
import type {
  Building,
  Entrance,
  EntranceSurvey,
} from './contract/contract';
import { ME } from './contract/fixtures';
import { db } from './db/db';
import { buildings, entrances } from './db/schema';

export function useEntrances(): Entrance[] {
  return useLiveQuery(db.select().from(entrances)).data;
}

export function useEntrance(
  id: string,
): Entrance | null | undefined {
  const { data, updatedAt } = useLiveQuery(
    db.select().from(entrances).where(eq(entrances.id, id)),
    [id],
  );

  return updatedAt ? (data[0] ?? null) : undefined;
}

export function useBuilding(id: string): Building | undefined {
  return useLiveQuery(
    db.select().from(buildings).where(eq(buildings.id, id)),
    [id],
  ).data[0];
}

export async function submitSurvey(
  id: string,
  survey: EntranceSurvey,
) {
  const now = new Date().toISOString();

  await db
    .update(entrances)
    .set({
      ...survey,
      surveyStatus: 'submitted',
      surveyedBy: ME,
      surveyedAt: now,
      updatedAt: now,
      syncState: 'pending',
      lastError: null,
    })
    .where(eq(entrances.id, id));
}

export type Fix = {
  lat: number;
  lng: number;
  accuracy: number | null;
  at: string;
};

type FieldState = {
  fix: Fix | null;
  heading: number | null;
  setFix: (fix: Fix | null) => void;
  setHeading: (heading: number | null) => void;
};

export const useField = create<FieldState>()((set) => ({
  fix: null,
  heading: null,
  setFix: (fix) => set({ fix }),
  setHeading: (heading) => set({ heading }),
}));
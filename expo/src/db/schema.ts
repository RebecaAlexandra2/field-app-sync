import { integer, real, sqliteTable, text } from 'drizzle-orm/sqlite-core';
import type {
  ReviewStatus,
  SurveyStatus,
  SyncState,
  UploadState,
} from '../contract/contract';

const row = () => ({
  id: text().primaryKey(),
  createdAt: text().notNull(),
  updatedAt: text().notNull(),
});

const local = () => ({
  syncState: text().$type<SyncState>().notNull().default('pending'),
  lastError: text(),
});

export const buildings = sqliteTable('buildings', {
  ...row(),
  label: text().notNull(),
  comment: text(),
  ...local(),
});

export const entrances = sqliteTable('entrances', {
  ...row(),
  buildingId: text().notNull().references(() => buildings.id),
  lat: real().notNull(),
  lng: real().notNull(),
  street: text().notNull(),
  number: text().notNull(),
  entranceName: text().notNull(),
  coordsConfirmed: integer({ mode: 'boolean' }).notNull(),
  correctedLat: real(),
  correctedLng: real(),
  addressConfirmed: integer({ mode: 'boolean' }).notNull(),
  stories: integer(),
  flats: integer(),
  elevators: integer(),
  yearBuilt: integer(),
  groundFloorCommercial: integer({ mode: 'boolean' }),
  comment: text(),
  surveyStatus: text().$type<SurveyStatus>().notNull(),
  surveyedBy: text(),
  surveyedAt: text(),
  ...local(),
});

export const photos = sqliteTable('photos', {
  ...row(),
  entranceId: text().notNull().references(() => entrances.id),
  fileName: text().notNull(),
  remoteUrl: text(),
  takenAt: text().notNull(),
  lat: real(),
  lng: real(),
  heading: real(),
  uploadState: text().$type<UploadState>().notNull().default('pending'),
  reviewStatus: text().$type<ReviewStatus>().notNull().default('pending'),
  reviewNote: text(),
  reviewedBy: text(),
  replacesPhotoId: text(),
  ...local(),
  localUri: text().notNull(),
});

export type PhotoRow = typeof photos.$inferSelect;
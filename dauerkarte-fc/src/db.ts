import { openDB, type DBSchema, type IDBPDatabase } from 'idb';
import type { Match, Usage } from './types';
import { defaultUsageFor } from './types';

const DB_NAME = 'dauerkarte-fc-koeln';
const DB_VERSION = 1;

interface DauerkarteDB extends DBSchema {
  matches: {
    key: number;
    value: Match;
  };
  usage: {
    key: number;
    value: Usage;
  };
  meta: {
    key: string;
    value: unknown;
  };
}

let dbPromise: Promise<IDBPDatabase<DauerkarteDB>> | null = null;

function getDb(): Promise<IDBPDatabase<DauerkarteDB>> {
  if (!dbPromise) {
    dbPromise = openDB<DauerkarteDB>(DB_NAME, DB_VERSION, {
      upgrade(db) {
        if (!db.objectStoreNames.contains('matches')) {
          db.createObjectStore('matches', { keyPath: 'matchID' });
        }
        if (!db.objectStoreNames.contains('usage')) {
          db.createObjectStore('usage', { keyPath: 'matchID' });
        }
        if (!db.objectStoreNames.contains('meta')) {
          db.createObjectStore('meta');
        }
      },
    });
  }
  return dbPromise;
}

export async function getAllMatches(): Promise<Match[]> {
  const db = await getDb();
  const matches = await db.getAll('matches');
  return matches.sort((a, b) => a.matchday - b.matchday);
}

export async function getAllUsage(): Promise<Usage[]> {
  const db = await getDb();
  return db.getAll('usage');
}

/**
 * Persists freshly-fetched matches without ever touching existing `usage`
 * entries. New matches get a default usage entry created alongside them.
 */
export async function mergeMatches(matches: Match[]): Promise<void> {
  const db = await getDb();
  const tx = db.transaction(['matches', 'usage'], 'readwrite');
  const matchStore = tx.objectStore('matches');
  const usageStore = tx.objectStore('usage');

  await matchStore.clear();
  for (const match of matches) {
    await matchStore.put(match);
    const existingUsage = await usageStore.get(match.matchID);
    if (!existingUsage) {
      await usageStore.put(defaultUsageFor(match.matchID));
    }
  }
  await tx.done;
}

export async function putUsage(usage: Usage): Promise<void> {
  const db = await getDb();
  await db.put('usage', usage);
}

export async function getUsage(matchID: number): Promise<Usage | undefined> {
  const db = await getDb();
  return db.get('usage', matchID);
}

export async function setMeta(key: string, value: unknown): Promise<void> {
  const db = await getDb();
  await db.put('meta', value, key);
}

export async function getMeta<T>(key: string): Promise<T | undefined> {
  const db = await getDb();
  return db.get('meta', key) as Promise<T | undefined>;
}

export interface BackupData {
  version: 1;
  exportedAt: string;
  matches: Match[];
  usage: Usage[];
}

export async function exportBackup(): Promise<BackupData> {
  const [matches, usage] = await Promise.all([getAllMatches(), getAllUsage()]);
  return {
    version: 1,
    exportedAt: new Date().toISOString(),
    matches,
    usage,
  };
}

export async function importBackup(data: BackupData): Promise<void> {
  const db = await getDb();
  const tx = db.transaction(['matches', 'usage'], 'readwrite');
  await tx.objectStore('matches').clear();
  await tx.objectStore('usage').clear();
  for (const match of data.matches) {
    await tx.objectStore('matches').put(match);
  }
  for (const usage of data.usage) {
    await tx.objectStore('usage').put(usage);
  }
  await tx.done;
}

import type { Match } from './types';
import { getAllMatches, mergeMatches, setMeta, getMeta } from './db';

/** Saison-Jahr für OpenLigaDB (bl1/{SEASON}). Bei Saisonwechsel hier anpassen. */
export const SEASON = 2026;

const API_URL = `https://api.openligadb.de/getmatchdata/bl1/${SEASON}`;

const LAST_UPDATED_KEY = 'lastUpdated';
const LAST_ERROR_KEY = 'lastError';

interface OpenLigaTeam {
  teamId: number;
  teamName: string;
}

interface OpenLigaGroup {
  groupOrderID: number;
  groupName: string;
}

interface OpenLigaMatch {
  matchID: number;
  matchDateTime: string;
  matchDateTimeUTC: string;
  team1: OpenLigaTeam;
  team2: OpenLigaTeam;
  group: OpenLigaGroup;
}

function normalizeTeamName(name: string): string {
  return name.toLowerCase().replace(/\s+/g, '');
}

function isFcKoeln(name: string): boolean {
  const normalized = normalizeTeamName(name);
  return normalized.includes('1.fckoeln') || normalized.includes('köln') || normalized.includes('koeln');
}

function toMatch(raw: OpenLigaMatch): Match {
  return {
    matchID: raw.matchID,
    matchday: raw.group?.groupOrderID ?? 0,
    date: raw.matchDateTime ?? raw.matchDateTimeUTC,
    opponent: raw.team2?.teamName ?? 'Unbekannt',
    season: SEASON,
  };
}

/** Lädt zuerst aus IndexedDB (offline-fähig), aktualisiert optional im Hintergrund. */
export async function loadMatches(): Promise<{ matches: Match[]; error: string | null }> {
  const cached = await getAllMatches();
  if (cached.length > 0) {
    return { matches: cached, error: null };
  }
  return refreshMatches();
}

/** Ruft OpenLigaDB ab, filtert Heimspiele des 1. FC Köln und merged ins matches-Store. */
export async function refreshMatches(): Promise<{ matches: Match[]; error: string | null }> {
  try {
    const response = await fetch(API_URL);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const data: OpenLigaMatch[] = await response.json();
    const homeMatches = data
      .filter((m) => isFcKoeln(m.team1?.teamName ?? ''))
      .map(toMatch)
      .sort((a, b) => a.matchday - b.matchday);

    await mergeMatches(homeMatches);
    await setMeta(LAST_UPDATED_KEY, new Date().toISOString());
    await setMeta(LAST_ERROR_KEY, null);

    return { matches: homeMatches, error: null };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unbekannter Fehler';
    await setMeta(LAST_ERROR_KEY, message);
    const cached = await getAllMatches();
    return { matches: cached, error: message };
  }
}

export async function getLastUpdated(): Promise<string | undefined> {
  return getMeta<string>(LAST_UPDATED_KEY);
}

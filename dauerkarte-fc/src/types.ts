export type UsageType = 'eigen' | 'sitznachbar' | 'freundeskreis' | 'boerse';

export type UsageStatus = 'offen' | 'erhalten' | 'entfaellt';

export interface Match {
  matchID: number;
  matchday: number;
  /** ISO date string (matchDateTime from OpenLigaDB) */
  date: string;
  opponent: string;
  season: number;
}

export interface Usage {
  matchID: number;
  usage: UsageType;
  user: string;
  amount: number;
  status: UsageStatus;
  gotFromNeighbor: boolean;
  done: boolean;
}

export interface MatchWithUsage extends Match {
  usageEntry: Usage;
}

export const USAGE_LABELS: Record<UsageType, string> = {
  eigen: 'Eigennutzung',
  sitznachbar: 'Sitznachbar',
  freundeskreis: 'Freundeskreis',
  boerse: 'Spieltagsbörse',
};

export const STATUS_LABELS: Record<UsageStatus, string> = {
  offen: 'offen',
  erhalten: 'erhalten',
  entfaellt: 'entfällt',
};

export function defaultUsageFor(matchID: number): Usage {
  return {
    matchID,
    usage: 'eigen',
    user: '',
    amount: 0,
    status: 'entfaellt',
    gotFromNeighbor: false,
    done: false,
  };
}

export function statusForUsageChange(usage: UsageType): UsageStatus {
  return usage === 'freundeskreis' || usage === 'boerse' ? 'offen' : 'entfaellt';
}

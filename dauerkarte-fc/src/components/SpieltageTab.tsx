import type { MatchWithUsage, Usage } from '../types';
import { MatchCard } from './MatchCard';
import { downloadAllMatchesIcs } from '../ics';

interface Props {
  entries: MatchWithUsage[];
  onUsageChange: (usage: Usage) => void;
  onRefresh: () => void;
  refreshing: boolean;
  lastUpdated: string | null;
  refreshError: string | null;
}

export function SpieltageTab({
  entries,
  onUsageChange,
  onRefresh,
  refreshing,
  lastUpdated,
  refreshError,
}: Props) {
  return (
    <div className="tab-content">
      <div className="toolbar">
        <button type="button" className="btn btn--primary" onClick={onRefresh} disabled={refreshing}>
          {refreshing ? 'Aktualisiere…' : 'Aktualisieren'}
        </button>
        <button
          type="button"
          className="btn btn--ghost"
          onClick={() => downloadAllMatchesIcs(entries)}
          disabled={entries.length === 0}
        >
          Alle Erinnerungen exportieren
        </button>
      </div>

      {refreshError && (
        <p className="hint hint--warning">
          Aktualisierung fehlgeschlagen ({refreshError}). Zeige zwischengespeicherte Daten.
        </p>
      )}
      {lastUpdated && !refreshError && (
        <p className="hint">Zuletzt aktualisiert: {new Date(lastUpdated).toLocaleString('de-DE')}</p>
      )}

      {entries.length === 0 && (
        <p className="hint">
          Keine Heimspiele geladen. Prüfe die Internetverbindung und tippe auf „Aktualisieren".
        </p>
      )}

      <div className="match-list">
        {entries.map((entry) => (
          <MatchCard
            key={entry.matchID}
            match={entry}
            usage={entry.usageEntry}
            onChange={onUsageChange}
          />
        ))}
      </div>
    </div>
  );
}

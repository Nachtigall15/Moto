import { useCallback, useEffect, useState } from 'react';
import type { Match, MatchWithUsage, Usage } from './types';
import { defaultUsageFor } from './types';
import { getAllMatches, getAllUsage, putUsage } from './db';
import { loadMatches, refreshMatches, getLastUpdated } from './api';
import { SpieltageTab } from './components/SpieltageTab';
import { UebersichtTab } from './components/UebersichtTab';

type Tab = 'spieltage' | 'uebersicht';

function combine(matches: Match[], usageList: Usage[]): MatchWithUsage[] {
  const usageByMatch = new Map(usageList.map((u) => [u.matchID, u]));
  return matches.map((match) => ({
    ...match,
    usageEntry: usageByMatch.get(match.matchID) ?? defaultUsageFor(match.matchID),
  }));
}

export default function App() {
  const [tab, setTab] = useState<Tab>('spieltage');
  const [entries, setEntries] = useState<MatchWithUsage[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const [lastUpdated, setLastUpdated] = useState<string | null>(null);
  const [refreshError, setRefreshError] = useState<string | null>(null);

  const reloadFromDb = useCallback(async () => {
    const [matches, usageList] = await Promise.all([getAllMatches(), getAllUsage()]);
    setEntries(combine(matches, usageList));
  }, []);

  useEffect(() => {
    (async () => {
      const { matches, error } = await loadMatches();
      const usageList = await getAllUsage();
      setEntries(combine(matches, usageList));
      setRefreshError(error);
      const updated = await getLastUpdated();
      setLastUpdated(updated ?? null);
    })();
  }, []);

  async function handleRefresh() {
    setRefreshing(true);
    const { matches, error } = await refreshMatches();
    const usageList = await getAllUsage();
    setEntries(combine(matches, usageList));
    setRefreshError(error);
    const updated = await getLastUpdated();
    setLastUpdated(updated ?? null);
    setRefreshing(false);
  }

  async function handleUsageChange(usage: Usage) {
    setEntries((prev) =>
      prev.map((entry) => (entry.matchID === usage.matchID ? { ...entry, usageEntry: usage } : entry)),
    );
    await putUsage(usage);
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>Dauerkarte FC</h1>
        <p className="app-header__subtitle">1. FC Köln – Heimspiele</p>
      </header>

      <nav className="tabs">
        <button
          type="button"
          className={`tab-button${tab === 'spieltage' ? ' tab-button--active' : ''}`}
          onClick={() => setTab('spieltage')}
        >
          Spieltage
        </button>
        <button
          type="button"
          className={`tab-button${tab === 'uebersicht' ? ' tab-button--active' : ''}`}
          onClick={() => setTab('uebersicht')}
        >
          Übersicht
        </button>
      </nav>

      <main className="app-main">
        {tab === 'spieltage' ? (
          <SpieltageTab
            entries={entries}
            onUsageChange={handleUsageChange}
            onRefresh={handleRefresh}
            refreshing={refreshing}
            lastUpdated={lastUpdated}
            refreshError={refreshError}
          />
        ) : (
          <UebersichtTab entries={entries} onDataImported={reloadFromDb} />
        )}
      </main>
    </div>
  );
}

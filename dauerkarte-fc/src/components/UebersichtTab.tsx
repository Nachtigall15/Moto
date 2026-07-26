import type { MatchWithUsage, UsageType } from '../types';
import { USAGE_LABELS } from '../types';
import { formatMatchDate, formatEuro } from '../format';
import { BackupControls } from './BackupControls';

interface Props {
  entries: MatchWithUsage[];
  onDataImported: () => void;
}

const USAGE_ORDER: UsageType[] = ['eigen', 'sitznachbar', 'freundeskreis', 'boerse'];

function saldoText(saldo: number): string {
  if (saldo > 0) return `Nachbar schuldet dir ${saldo} Spieltag${saldo === 1 ? '' : 'e'}`;
  if (saldo < 0) return `Du schuldest dem Nachbarn ${Math.abs(saldo)} Spieltag${Math.abs(saldo) === 1 ? '' : 'e'}`;
  return 'ausgeglichen';
}

export function UebersichtTab({ entries, onDataImported }: Props) {
  const sitznachbarCount = entries.filter((e) => e.usageEntry.usage === 'sitznachbar').length;
  const gotFromNeighborCount = entries.filter((e) => e.usageEntry.gotFromNeighbor).length;
  const saldo = sitznachbarCount - gotFromNeighborCount;

  const receivedSum = entries
    .filter((e) => e.usageEntry.status === 'erhalten')
    .reduce((sum, e) => sum + e.usageEntry.amount, 0);
  const openSum = entries
    .filter((e) => e.usageEntry.status === 'offen')
    .reduce((sum, e) => sum + e.usageEntry.amount, 0);

  const usageCounts = USAGE_ORDER.reduce<Record<UsageType, number>>(
    (acc, type) => {
      acc[type] = entries.filter((e) => e.usageEntry.usage === type).length;
      return acc;
    },
    { eigen: 0, sitznachbar: 0, freundeskreis: 0, boerse: 0 },
  );
  const unbearbeitetCount = entries.filter((e) => !e.usageEntry.done).length;

  const sortedEntries = [...entries].sort(
    (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime(),
  );

  return (
    <div className="tab-content">
      <div className="stat-tiles">
        <div className="stat-tile">
          <span className="stat-tile__label">Tauschsaldo</span>
          <span className="stat-tile__value">{saldo > 0 ? `+${saldo}` : saldo}</span>
          <span className="stat-tile__sub">{saldoText(saldo)}</span>
        </div>
        <div className="stat-tile">
          <span className="stat-tile__label">Erhaltene Erstattungen</span>
          <span className="stat-tile__value stat-tile__value--positive">{formatEuro(receivedSum)}</span>
        </div>
        <div className="stat-tile">
          <span className="stat-tile__label">Offene Erstattungen</span>
          <span className="stat-tile__value stat-tile__value--warning">{formatEuro(openSum)}</span>
        </div>
      </div>

      <section className="section">
        <h3>Auswertung</h3>
        <ul className="breakdown-list">
          {USAGE_ORDER.map((type) => (
            <li key={type}>
              <span className={`dot dot--${type}`} />
              {USAGE_LABELS[type]}: {usageCounts[type]}×
            </li>
          ))}
          <li>Vom Nachbar bekommen: {gotFromNeighborCount}×</li>
          <li>Unbearbeitet: {unbearbeitetCount}×</li>
        </ul>
      </section>

      <section className="section">
        <h3>Saison-Tabelle</h3>
        <div className="table-wrap">
          <table className="season-table">
            <thead>
              <tr>
                <th>SpT</th>
                <th>Gegner</th>
                <th>Datum</th>
                <th>Nutzung</th>
                <th>Betrag</th>
                <th>✓</th>
              </tr>
            </thead>
            <tbody>
              {sortedEntries.map((entry) => {
                const { usageEntry } = entry;
                const amountClass =
                  usageEntry.status === 'erhalten'
                    ? 'amount--received'
                    : usageEntry.status === 'offen'
                      ? 'amount--open'
                      : '';
                return (
                  <tr key={entry.matchID}>
                    <td>{entry.matchday}</td>
                    <td>{entry.opponent}</td>
                    <td>{formatMatchDate(entry.date)}</td>
                    <td>
                      <span className={`dot dot--${usageEntry.usage}`} />
                      {USAGE_LABELS[usageEntry.usage]}
                      {usageEntry.user ? ` (${usageEntry.user})` : ''}
                    </td>
                    <td className={amountClass}>
                      {usageEntry.status === 'entfaellt' || usageEntry.amount === 0
                        ? '–'
                        : formatEuro(usageEntry.amount)}
                    </td>
                    <td>{usageEntry.done ? '✓' : ''}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section className="section">
        <h3>Backup</h3>
        <BackupControls onImported={onDataImported} />
      </section>
    </div>
  );
}

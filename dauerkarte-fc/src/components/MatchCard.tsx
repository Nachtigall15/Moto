import type { Match, Usage, UsageType, UsageStatus } from '../types';
import { USAGE_LABELS, statusForUsageChange } from '../types';
import { formatMatchDate, parseDecimal } from '../format';
import { downloadMatchIcs } from '../ics';

interface Props {
  match: Match;
  usage: Usage;
  onChange: (usage: Usage) => void;
}

const USAGE_ORDER: UsageType[] = ['eigen', 'sitznachbar', 'freundeskreis', 'boerse'];
const STATUS_ORDER: UsageStatus[] = ['offen', 'erhalten', 'entfaellt'];

export function MatchCard({ match, usage, onChange }: Props) {
  const showRefundFields = usage.usage === 'freundeskreis' || usage.usage === 'boerse';

  function update(patch: Partial<Usage>) {
    onChange({ ...usage, ...patch });
  }

  function handleUsageTypeChange(next: UsageType) {
    update({ usage: next, status: statusForUsageChange(next) });
  }

  return (
    <div className={`match-card${usage.done ? ' match-card--done' : ''}`}>
      <div className="match-card__header">
        <div className="match-card__title">
          <span className="match-card__matchday">Spieltag {match.matchday}</span>
          <h3>1. FC Köln – {match.opponent}</h3>
          <span className="match-card__date">{formatMatchDate(match.date)}</span>
        </div>
        <span className={`badge badge--${usage.usage}`}>{USAGE_LABELS[usage.usage]}</span>
      </div>

      <div className="match-card__body">
        <label className="field">
          <span>Nutzungsart</span>
          <select
            value={usage.usage}
            onChange={(e) => handleUsageTypeChange(e.target.value as UsageType)}
          >
            {USAGE_ORDER.map((type) => (
              <option key={type} value={type}>
                {USAGE_LABELS[type]}
              </option>
            ))}
          </select>
        </label>

        {showRefundFields && (
          <>
            <label className="field">
              <span>Nutzer</span>
              <input
                type="text"
                value={usage.user}
                onChange={(e) => update({ user: e.target.value })}
                placeholder="Name"
              />
            </label>
            <label className="field">
              <span>Erstattung €</span>
              <input
                type="text"
                inputMode="decimal"
                value={usage.amount === 0 ? '' : usage.amount.toString().replace('.', ',')}
                onChange={(e) => update({ amount: parseDecimal(e.target.value) })}
                placeholder="0,00"
              />
            </label>
            <label className="field">
              <span>Status</span>
              <select
                value={usage.status}
                onChange={(e) => update({ status: e.target.value as UsageStatus })}
              >
                {STATUS_ORDER.map((status) => (
                  <option key={status} value={status}>
                    {status}
                  </option>
                ))}
              </select>
            </label>
          </>
        )}

        <label className="checkbox-field">
          <input
            type="checkbox"
            checked={usage.gotFromNeighbor}
            onChange={(e) => update({ gotFromNeighbor: e.target.checked })}
          />
          <span>Karte vom Sitznachbar bekommen</span>
        </label>

        <label className="checkbox-field">
          <input
            type="checkbox"
            checked={usage.done}
            onChange={(e) => update({ done: e.target.checked })}
          />
          <span>Bearbeitet</span>
        </label>

        <button type="button" className="btn btn--ghost" onClick={() => downloadMatchIcs(match)}>
          + Kalender-Erinnerung
        </button>
      </div>
    </div>
  );
}
